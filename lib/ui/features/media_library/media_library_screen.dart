import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/media_type.dart';
import '../../../domain/entities/tag_entity.dart';
import '../../../domain/entities/live_library_settings.dart';
import '../../../data/models/home_models.dart';
import '../../../data/models/media_request_models.dart';
import '../../../data/models/user_data_models.dart';
import '../../../providers/global_refresh.dart';
import '../../../providers/providers.dart';
import '../../../providers/smart_analysis_controller.dart';
import '../../shared/common/app_loading_progress_ring.dart';
import '../../shared/common/fn_cached_image.dart';
import '../../shared/common/media_poster_placeholder.dart';
import '../../shared/movie_poster.dart';
import '../../shared/filter_box.dart';
import '../../shared/layout_flyout.dart';
import '../../shared/sort_flyout.dart';
import '../../shared/toast.dart';
import '../home/home_view_model.dart';
import 'media_library_view_model.dart';

class MediaLibraryScreen extends ConsumerStatefulWidget {
  final String? id;
  final String? categoryType;
  const MediaLibraryScreen({super.key, this.id, this.categoryType});

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  static const String _globalRefreshConsumerId = 'media-library-screen';
  bool _isFilterOpen = false;
  Map<String, FilterItem> _selectedFilters = {};
  String _sortColumn = 'create_time';
  String _sortOrder = 'DESC';

  // 直播库（IPTV）页的浏览偏好，镜像 Web 端三个工具按钮的持久化状态。
  LiveLibrarySettings _liveSettings = const LiveLibrarySettings();

  TagListEntity? _tagList;
  List<GenreEntity>? _genres;
  Map<String, String>? _iso3166;

  late final ScrollController _scrollController = ScrollController();
  late final FlyoutController _smartAnalysisFlyoutController =
      FlyoutController();
  final Map<String, Function(bool success)> _pendingFavoriteCallbacks = {};
  final Map<String, Function(bool success)> _pendingWatchedCallbacks = {};

  @override
  void initState() {
    super.initState();
    _loadStaticTags(
      type: widget.categoryType == 'live' ? 'LiveChannel' : null,
    );
    _bootstrapLibrarySettings();
  }

  @override
  void didUpdateWidget(covariant MediaLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.categoryType != widget.categoryType) {
      setState(() {
        _isFilterOpen = false;
        _selectedFilters = {};
        _sortColumn = 'create_time';
        _sortOrder = 'DESC';
        _liveSettings = const LiveLibrarySettings();
        _tagList = null;
        _genres = null;
        _iso3166 = null;
      });
      _loadStaticTags(
        type: widget.categoryType == 'live' ? 'LiveChannel' : null,
      );
      _bootstrapLibrarySettings();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _smartAnalysisFlyoutController.dispose();
    super.dispose();
  }

  String get _providerGuid => widget.id ?? 'category:${widget.categoryType!}';

  String _resolveTitle() {
    switch (widget.categoryType) {
      case 'total':
        return '全部';
      case 'tv':
        return '电视节目';
      case 'movie':
        return '电影';
      case 'video':
        return '其他';
      case 'live':
        return '电视直播';
      default:
        return '媒体库';
    }
  }

  String? _resolveMediaDbTitle(List<MediaDbListResponse> list) {
    if (widget.id == null) return null;
    for (final item in list) {
      if (item.guid == widget.id) {
        return item.title;
      }
    }
    return null;
  }

  List<String> _categoryTypes(String? category) {
    return MediaType.valuesFromCategory(category);
  }

  Future<void> _loadStaticTags({String? type}) async {
    final repo = ref.read(iTagRepositoryProvider);
    try {
      // Match the KMP metadata request and keep tag list type unset here;
      // live pages request LiveChannel tags so the genre row mirrors web.
      final tagListResult = await repo.getTagList(
        ancestorGuid: widget.id,
        isFavorite: 0,
        type: type,
      );
      final genresResult = await repo.getGenres();
      final iso3166Result = await repo.getTag('iso3166');
      await repo.getTag('iso6391');
      if (!mounted) {
        return;
      }
      setState(() {
        _tagList = tagListResult.dataOrNull;
        _genres = genresResult.dataOrNull;
        _iso3166 = iso3166Result.dataOrNull;
      });
    } catch (_) {}
  }

  Tags _buildTags(Map<String, FilterItem> filters) {
    final types = List<String>.from(
      widget.id == null
          ? _categoryTypes(widget.categoryType)
          : MediaType.libraryBrowseValues,
    );
    int? genres;
    String? resolution;
    String? colorRange;
    String? audioType;
    String? locate;
    String? decade;
    String? recognitionStatus;
    String? watched;
    filters.forEach((title, item) {
      switch (title) {
        case '影视类型':
          if (item.value != null) {
            types
              ..clear()
              ..add(item.value.toString());
          }
          break;
        case '类型':
          genres = item.value as int?;
          break;
        case '分辨率':
          resolution = item.value as String?;
          break;
        case '视频动态范围':
          colorRange = item.value as String?;
          break;
        case '音频规格':
          audioType = item.value as String?;
          break;
        case '国家和地区':
          locate = item.value as String?;
          break;
        case '发行年份':
          decade = item.value as String?;
          break;
        case '匹配状态':
          final v = item.value as int?;
          recognitionStatus = v?.toString();
          break;
        case '是否已观看':
          watched = item.value as String?;
          break;
      }
    });
    return Tags(
      type: types,
      genres: genres,
      resolution: resolution,
      colorRange: colorRange,
      locate: locate,
      decade: decade,
      recognitionStatus: recognitionStatus,
      watched: watched,
      audioType: audioType,
    );
  }

  bool get _isLiveLibrary =>
      widget.categoryType == 'live' || _isIptvLibrary;

  bool get _isIptvLibrary {
    final mediaDbList =
        ref.read(mediaDbListNotifierProvider).asData?.value ?? const [];
    for (final item in mediaDbList) {
      if (item.guid == widget.id) {
        return item.category == 'IPTV';
      }
    }
    return false;
  }

  // Web 端设置键：具体库（/library/:id，含 IPTV 与普通库）按库隔离存
  // `mdb:list:setting`；分类直播页（无 id）全局共享 `iptv:list:setting`。
  String _settingsKeyFor() =>
      widget.id != null ? 'mdb:list:setting' : 'iptv:list:setting';

  // 是否持久化布局/排序：直播库（含分类页）或有 id 的具体库都持久化；
  // 普通分类页（无 id 且非直播）不持久化，保持现状。
  bool get _supportsLibrarySettings => widget.id != null;

  Future<void> _bootstrapLibrarySettings() async {
    if (!_isLiveLibrary && !_supportsLibrarySettings) {
      return;
    }
    final dataSource = ref.read(userRemoteDataSourceProvider);
    try {
      final result = await dataSource.getUserData(UserDataGetRequest(
        key: _settingsKeyFor(),
        mdbGuid: widget.id,
      ));
      final raw = result.getOrThrow().value;
      final settings = LiveLibrarySettings.fromJsonString(raw);
      // 仅在确有存值时套用其排序字段；无存值沿用各库默认排序
      //（直播库标题升序，普通库当前组件默认 create_time 降序）。
      final hasStored = raw != null && raw.isNotEmpty;
      if (!mounted) {
        return;
      }
      setState(() {
        _liveSettings = settings;
        if (hasStored) {
          _sortColumn = settings.sortField;
          _sortOrder = settings.sortType;
        } else if (_isLiveLibrary) {
          _sortColumn = settings.sortField;
          _sortOrder = settings.sortType;
        } else {
          _sortColumn = 'create_time';
          _sortOrder = 'DESC';
        }
      });
      await ref
          .read(mediaLibraryNotifierProvider(_providerGuid).notifier)
          .refreshWithQuery(_buildBrowseRequest());
    } catch (_) {
      // 读取失败时沿用各库默认：直播库标题升序，普通库保持桌面默认。
      if (mounted) {
        setState(() {
          if (_isLiveLibrary) {
            _sortColumn = _liveSettings.sortField;
            _sortOrder = _liveSettings.sortType;
          } else {
            _sortColumn = 'create_time';
            _sortOrder = 'DESC';
          }
        });
        await ref
            .read(mediaLibraryNotifierProvider(_providerGuid).notifier)
            .refreshWithQuery(_buildBrowseRequest());
      }
    }
  }

  /// 把当前布局/排序写入 user data（镜像 Web `/library/:id` 的 mdb:list:setting）。
  /// [viewType] 传 null 表示仅排序变更（布局不变）。
  Future<void> _saveLibrarySettings({LiveViewType? viewType}) async {
    final next = _liveSettings.copyWith(
      sortType: _sortOrder,
      sortField: _sortColumn,
      viewType: viewType,
    );
    setState(() {
      _liveSettings = next;
    });
    final dataSource = ref.read(userRemoteDataSourceProvider);
    try {
      await dataSource.setUserData(UserDataSetRequest(
        key: _settingsKeyFor(),
        mdbGuid: widget.id,
        value: next.toJsonString(),
      ));
    } catch (_) {}
    await _refresh();
  }

  void _toggleLiveSortOrder(String order) {
    setState(() => _sortOrder = order);
    _saveLibrarySettings();
  }

  void _selectLibraryLayout(LiveViewType viewType) {
    _saveLibrarySettings(viewType: viewType);
  }

  MediaLibraryBrowseRequest _buildBrowseRequest() {
    return MediaLibraryBrowseRequest(
      ancestorGuid: widget.id,
      categoryType: widget.categoryType,
      page: 1,
      pageSize: 50,
      sortColumn: _sortColumn,
      sortType: _sortOrder,
      tags: _buildTags(_selectedFilters),
    );
  }

  Future<void> _refresh() async {
    await ref
        .read(mediaLibraryNotifierProvider(_providerGuid).notifier)
        .refreshWithQuery(_buildBrowseRequest());
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _handleGlobalRefresh(GlobalRefreshRequest request) async {
    // Run the shared media-library refresh before updating this page.
    await request.runBaseMediaLibraryRefresh();
    if (!mounted) {
      return;
    }

    // Reset local browse state so the refreshed query matches the default filters.
    setState(() {
      _isFilterOpen = false;
      _selectedFilters = {};
    });
    await _scrollToTop();

    // Reload page-specific data after the shared metadata has completed.
    await Future.wait([
      _loadStaticTags(
        type: widget.categoryType == 'live' ? 'LiveChannel' : null,
      ),
      ref
          .read(mediaLibraryNotifierProvider(_providerGuid).notifier)
          .refreshWithQuery(_buildBrowseRequest()),
    ]);
  }

  void _onClearFilter(String title) {
    if (_selectedFilters.containsKey(title)) {
      setState(() {
        _selectedFilters[title] = const FilterItem('全部', null);
      });
    } else {
      setState(() {
        _selectedFilters = {
          for (final e in _selectedFilters.entries)
            e.key: const FilterItem('全部', null),
        };
      });
    }
    _refresh();
  }

  // 直播库“列表”布局：小方图 + 标题 + 收藏心，镜像 Web 端列表行。
  Widget _buildLiveListView(List<MediaItem> items, double scaleFactor) {
    final theme = FluentTheme.of(context);
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
          horizontal: 24 * scaleFactor, vertical: 8 * scaleFactor),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final hasPoster =
            item.poster?.trim().isNotEmpty == true;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go('/live/${item.guid}'),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8 * scaleFactor),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 56 * scaleFactor,
                    height: 56 * scaleFactor,
                    child: hasPoster
                        ? FnCachedImage(posterPath: item.poster!)
                        : Container(
                            color: theme
                                .resources.controlStrokeColorSecondary,
                            child: Center(
                              child: MediaPosterPlaceholder(
                                type: MediaType.liveChannel,
                                size: 28 * scaleFactor,
                              ),
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 16 * scaleFactor),
                Expanded(
                  child: Text(
                    item.title,
                    style: theme.typography.body?.copyWith(fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                HoverButton(
                  onPressed: () => _handleFavoriteToggle(
                    item.guid,
                    item.isFavorite == 1,
                    (_) {},
                  ),
                  builder: (context, states) {
                    final favorite = item.isFavorite == 1;
                    return SvgPicture.asset(
                      favorite
                          ? 'assets/images/favorite_fill.svg'
                          : 'assets/images/favorite.svg',
                      width: 18 * scaleFactor,
                      height: 18 * scaleFactor,
                      colorFilter: ColorFilter.mode(
                        favorite
                            ? kDangerDefaultColor
                            : (theme.typography.caption?.color ??
                                    Colors.white)
                                .withValues(alpha: 0.8),
                        BlendMode.srcIn,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 直播库“横幅海报”布局：16:9 横幅卡 + 标题，镜像 Web 端。
  Widget _buildLiveHorizontalGrid(List<MediaItem> items, double scaleFactor) {
    final theme = FluentTheme.of(context);
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16 * scaleFactor),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320 * scaleFactor,
        mainAxisSpacing: 24,
        crossAxisSpacing: 16,
        childAspectRatio: 16 / 11,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BannerPoster(
                posterPath: item.poster,
                type: item.type,
                guid: item.guid,
                isFavorite: item.isFavorite == 1,
                scaleFactor: scaleFactor,
                contentPadding: 12 * scaleFactor,
                onTap: () => context.go('/live/${item.guid}'),
                onPlayTap: () => context.go('/live/${item.guid}'),
                onFavoriteToggle: _handleFavoriteToggle,
                // 直播台无“已观看”/智能分析状态，故不传 onWatchedToggle /
                // onMoreTap → 遮罩上仅显示播放按钮与收藏按钮（与 Web 一致）。
              ),
            ),
            SizedBox(height: 8 * scaleFactor),
            // 标题居中对齐（与 Web 端一致）。
            Center(
              child: Text(
                item.title,
                textAlign: TextAlign.center,
                style: theme.typography.body?.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  // 普通媒体库“横幅海报”布局：16:10 横幅卡 + 居中标题，镜像 Web `/library/:id`。
  Widget _buildGeneralHorizontalGrid(
      List<MediaItem> items, double scaleFactor) {
    final theme = FluentTheme.of(context);
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16 * scaleFactor),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 264 * scaleFactor,
        mainAxisSpacing: 24,
        crossAxisSpacing: 16,
        // 格高须容纳 16:9 图 + 8px 间距 + 单行标题。标题用 body.copyWith(15)，
        // 继承 fluent body 的 line-height(20/14→15pt≈21.4px)，旧 16/11 在列宽
        // <235px 时会 RenderFlex 溢出；16/13(=0.8125) 安全下限放宽到 ~118px，
        // 即便窄列/缩放/高 DPI 也留足余量。
        childAspectRatio: 16 / 13,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final smartAnalysisEnabled =
            ref.watch(settingsProvider).flyNarwhalServerEnabled;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BannerPoster(
                posterPath: item.poster,
                score: item.voteAverage,
                type: item.type,
                guid: item.guid,
                isFavorite: item.isFavorite == 1,
                isWatched: (item.watched ?? 0) == 1,
                scaleFactor: scaleFactor,
                onTap: () => _navigateGeneralLibraryItem(item),
                onPlayTap: () {
                  if (item.type == MediaType.liveChannel.value) {
                    context.go('/live/${item.guid}');
                  } else {
                    context.go('/player/${item.guid}');
                  }
                },
                onFavoriteToggle: _handleFavoriteToggle,
                onWatchedToggle: _handleWatchedToggle,
                onMoreTap: smartAnalysisEnabled &&
                        (item.type == 'Season' || item.type == 'TV')
                    ? () => _showSmartAnalysisFlyout(item)
                    : null,
              ),
            ),
            SizedBox(height: 8 * scaleFactor),
            Center(
              child: Text(
                item.title,
                textAlign: TextAlign.center,
                style: theme.typography.body?.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateGeneralLibraryItem(MediaItem item) {
    switch (MediaType.tryParse(item.type)) {
      case MediaType.tv:
        context.go('/tv/${item.guid}');
        break;
      case MediaType.season:
        context.go('/tv/season/${item.guid}');
        break;
      default:
        context.go('/movie/${item.guid}');
    }
  }

  // Handle favorite toggle
  void _handleFavoriteToggle(
      String guid, bool currentFavoriteState, Function(bool success) callback) {
    _pendingFavoriteCallbacks[guid] = callback;
    ref
        .read(favoriteNotifierProvider.notifier)
        .toggleFavorite(guid, currentFavoriteState);
  }

  // Handle watched toggle
  void _handleWatchedToggle(
      String guid, bool currentWatchedState, Function(bool success) callback) {
    _pendingWatchedCallbacks[guid] = callback;
    ref
        .read(watchedNotifierProvider.notifier)
        .toggleWatched(guid, currentWatchedState);
  }

  // Handle favorite result
  void _handleFavoriteResult(FavoriteActionResult? result) {
    if (result == null) return;

    ref.read(toastManagerProvider.notifier).showToast(
          result.message,
          type: result.success ? ToastType.success : ToastType.failed,
          category: 'favorite:${result.guid}',
        );

    _pendingFavoriteCallbacks[result.guid]?.call(result.success);
    _pendingFavoriteCallbacks.remove(result.guid);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(favoriteNotifierProvider.notifier).clear();
      }
    });
  }

  // Handle watched result
  void _handleWatchedResult(WatchedActionResult? result) {
    if (result == null) return;

    ref.read(toastManagerProvider.notifier).showToast(
          result.message,
          type: result.success ? ToastType.success : ToastType.failed,
          category: 'watched:${result.guid}',
        );

    _pendingWatchedCallbacks[result.guid]?.call(result.success);
    _pendingWatchedCallbacks.remove(result.guid);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(watchedNotifierProvider.notifier).clear();
      }
    });
  }

  // Show smart analysis flyout for Season/TV items
  void _showSmartAnalysisFlyout(MediaItem item) {
    if (_smartAnalysisFlyoutController.isOpen) {
      _smartAnalysisFlyoutController.close();
      return;
    }
    final isSeason = MediaType.tryParse(item.type) == MediaType.season;
    final isSubmitting = ref.read(smartAnalysisControllerProvider).isSubmitting(
          isSeason
              ? SmartAnalysisTargetType.season
              : SmartAnalysisTargetType.tv,
          item.guid,
        );
    _smartAnalysisFlyoutController.showFlyout<void>(
      placementMode: FlyoutPlacementMode.bottomCenter,
      builder: (context) => MenuFlyout(
        items: [
          MenuFlyoutItem(
            key: ValueKey('smart-analysis-${item.guid}'),
            text: const Text('智能分析片头/片尾'),
            onPressed: isSubmitting
                ? null
                : () {
                    Flyout.of(context).close();
                    _handleSmartAnalysis(item);
                  },
          ),
        ],
      ),
    );
  }

  // Trigger smart analysis for a Season or TV item
  Future<void> _handleSmartAnalysis(MediaItem item) async {
    final settings = ref.read(settingsProvider);
    // Guard: require full FlyNarwhal config before triggering analysis
    if (!settings.isFlyNarwhalServerAvailable) {
      ref.read(toastManagerProvider.notifier).showToast(
            buildFlyNarwhalConfigWarning(
              missingUrl: settings.flyNarwhalServerBaseUrl.isEmpty,
              missingAuthCode: !settings.hasFlyNarwhalAuthCode,
            ),
            type: ToastType.warning,
            category: 'fly-narwhal-config',
          );
      return;
    }
    if (MediaType.tryParse(item.type) == MediaType.season) {
      // Use ancestorName as the TV title for Season items
      final tvTitle = (item.ancestorName?.isNotEmpty == true)
          ? item.ancestorName!
          : item.title;
      await ref
          .read(smartAnalysisControllerProvider.notifier)
          .analyzeSeason(item.guid, tvTitle, item.seasonNumber);
    } else {
      await ref
          .read(smartAnalysisControllerProvider.notifier)
          .analyzeTv(item.guid, item.title);
    }
  }

  // Show toast for smart analysis submission result
  void _showAnalysisToast(
    SmartAnalysisTargetType targetType,
    String targetGuid,
    AsyncValue<String>? previous,
    AsyncValue<String>? next,
  ) {
    if (next == null || next.isLoading || identical(previous, next)) return;
    next.when(
      data: (message) {
        ref.read(toastManagerProvider.notifier).showToast(
              message,
              type: ToastType.success,
              category: 'smart-analysis:${targetType.name}:$targetGuid',
            );
      },
      loading: () {},
      error: (error, stackTrace) {
        ref.read(toastManagerProvider.notifier).showToast(
              error.toString(),
              type: ToastType.failed,
              category: 'smart-analysis:${targetType.name}:$targetGuid',
            );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.id == null && widget.categoryType == null) {
      return const Center(child: Text("Invalid Library ID"));
    }

    final globalRefreshManager = ref.read(globalRefreshManagerProvider);

    // Consume each global refresh event once for the current media-library page.
    ref.listen<GlobalRefreshRequest?>(currentGlobalRefreshRequestProvider, (
      previous,
      next,
    ) {
      if (!globalRefreshManager.consumeOnce(
        consumerId: _globalRefreshConsumerId,
        request: next,
      )) {
        return;
      }
      unawaited(_handleGlobalRefresh(next!));
    });

    // Listen to favorite result changes
    ref.listen<FavoriteActionResult?>(favoriteNotifierProvider,
        (previous, next) {
      _handleFavoriteResult(next);
    });

    // Listen to watched result changes
    ref.listen<WatchedActionResult?>(watchedNotifierProvider, (previous, next) {
      _handleWatchedResult(next);
    });

    final scaleFactor = resolveWindowScaleFactor(context);
    final mediaDbList =
        ref.watch(mediaDbListNotifierProvider).asData?.value ?? const [];
    final mediaLibraryState =
        ref.watch(mediaLibraryNotifierProvider(_providerGuid));
    final libraryData = mediaLibraryState.asData?.value;
    final items = libraryData?.items ?? const <MediaItem>[];

    // Listen to smart analysis submission results for Season/TV items
    final smartAnalysisEnabled =
        ref.watch(settingsProvider).flyNarwhalServerEnabled;
    for (final item in items) {
      final mediaType = MediaType.tryParse(item.type);
      if (mediaType != MediaType.season && mediaType != MediaType.tv) {
        continue;
      }
      final targetType = mediaType == MediaType.season
          ? SmartAnalysisTargetType.season
          : SmartAnalysisTargetType.tv;
      ref.listen<AsyncValue<String>?>(
        smartAnalysisControllerProvider.select(
          (state) => state.submissionFor(targetType, item.guid),
        ),
        (previous, next) =>
            _showAnalysisToast(targetType, item.guid, previous, next),
      );
    }
    const posterHeight = 200.0;
    const posterWidth = posterHeight * 2 / 3;
    final mediaDbTitle = _resolveMediaDbTitle(mediaDbList);
    final title = widget.id != null
        ? (libraryData?.mdbName ?? mediaDbTitle ?? '媒体库')
        : _resolveTitle();

    return ScaffoldPage(
      header: PageHeader(title: Text(title)),
      content: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 200) {
                ref
                    .read(mediaLibraryNotifierProvider(_providerGuid).notifier)
                    .loadMore();
              }
              return false;
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      FilterButton(
                        isSelected: _isFilterOpen,
                        selectedFilters: _selectedFilters,
                        onFilterClear: _onClearFilter,
                        onClick: () =>
                            setState(() => _isFilterOpen = !_isFilterOpen),
                      ),
                      const SizedBox(width: 8),
                      if (_isLiveLibrary) ...[
                        SortFlyout(
                          key: ValueKey(
                              'sort-$_providerGuid-${_liveSettings.sortType}'),
                          hideSortMenu: true,
                          initialSortColumn: _liveSettings.sortField,
                          initialSortOrder: _liveSettings.sortType,
                          onSortTypeSelected: (_) {},
                          onSortOrderSelected: _toggleLiveSortOrder,
                        ),
                        const SizedBox(width: 8),
                        LayoutFlyout(
                          key: ValueKey(
                              'layout-$_providerGuid-${_liveSettings.viewType.value}'),
                          viewType: _liveSettings.viewType,
                          onLayoutSelected: _selectLibraryLayout,
                        ),
                      ] else ...[
                        SortFlyout(
                          key: ValueKey('sort-$_providerGuid'),
                          onSortTypeSelected: (type) {
                            setState(() => _sortColumn = type);
                            if (_supportsLibrarySettings) {
                              _saveLibrarySettings();
                            } else {
                              _refresh();
                            }
                          },
                          onSortOrderSelected: (order) {
                            setState(() => _sortOrder = order);
                            if (_supportsLibrarySettings) {
                              _saveLibrarySettings();
                            } else {
                              _refresh();
                            }
                          },
                        ),
                        // 普通媒体库也复刻 Web 的「布局」按钮（仅 竖幅/横幅 两项）。
                        if (_supportsLibrarySettings) ...[
                          const SizedBox(width: 8),
                          LayoutFlyout(
                            key: ValueKey(
                                'layout-$_providerGuid-${_liveSettings.viewType.value}'),
                            variant: LayoutMenuVariant.compact,
                            viewType: _liveSettings.viewType,
                            onLayoutSelected: _selectLibraryLayout,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return ClipRect(
                      child: SizeTransition(
                        sizeFactor: animation,
                        alignment: Alignment.topCenter,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                    );
                  },
                  child: _isFilterOpen
                      ? Padding(
                          key: const ValueKey('filter-box'),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: FilterBox(
                            tagList: _tagList,
                            genres: _genres,
                            iso3166: _iso3166,
                            liveOnly: _isLiveLibrary,
                            initialSelectedFilters: _selectedFilters,
                            onFilterChanged: (filters) {
                              _selectedFilters =
                                  Map<String, FilterItem>.from(filters);
                              _refresh();
                            },
                            onCollapse: () =>
                                setState(() => _isFilterOpen = false),
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('filter-box-empty'),
                        ),
                ),
                Expanded(
                  child: mediaLibraryState.isLoading && items.isEmpty
                      ? const Center(child: AppLoadingProgressRing())
                      : _isLiveLibrary &&
                              _liveSettings.viewType == LiveViewType.list
                          ? _buildLiveListView(items, scaleFactor)
                          : _isLiveLibrary &&
                                  _liveSettings.viewType ==
                                      LiveViewType.horizontalPoster
                              ? _buildLiveHorizontalGrid(items, scaleFactor)
                              : (widget.id != null) &&
                                      _liveSettings.viewType ==
                                          LiveViewType.horizontalPoster
                                  ? _buildGeneralHorizontalGrid(
                                      items, scaleFactor)
                                  : GridView.builder(
                                  controller: _scrollController,
                                  padding: EdgeInsets.all(16 * scaleFactor),
                                  gridDelegate:
                                      SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 180 * scaleFactor,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 0,
                                    childAspectRatio: 0.6,
                                  ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return MoviePoster(
                              title: item.title,
                              subtitle: buildPosterSubtitle(item),
                              posterPath: item.poster,
                              score: item.voteAverage,
                              resolutions: item.mediaStream?.resolutions,
                              isFavorite: item.isFavorite == 1,
                              isWatched: (item.watched ?? 0) == 1,
                              width: posterWidth,
                              height: posterHeight,
                              scaleFactor: scaleFactor,
                              type: item.type,
                              guid: item.guid,
                              onTap: () {
                                switch (MediaType.tryParse(item.type)) {
                                  case MediaType.tv:
                                    context.go('/tv/${item.guid}');
                                    break;
                                  case MediaType.season:
                                    context.go('/tv/season/${item.guid}');
                                    break;
                                  default:
                                    context.go('/movie/${item.guid}');
                                }
                              },
                              onPlayTap: () {
                                if (item.type == MediaType.liveChannel.value) {
                                  context.go('/live/${item.guid}');
                                } else {
                                  context.go('/player/${item.guid}');
                                }
                              },
                              onFavoriteToggle: _handleFavoriteToggle,
                              onWatchedToggle: _handleWatchedToggle,
                              onMoreTap: smartAnalysisEnabled &&
                                      (item.type == 'Season' ||
                                          item.type == 'TV')
                                  ? () => _showSmartAnalysisFlyout(item)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
