import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/entities/tag_entity.dart';
import '../../../data/models/home_models.dart';
import '../../../data/models/media_request_models.dart';
import '../../../providers/global_refresh.dart';
import '../../../providers/providers.dart';
import '../../shared/common/app_loading_progress_ring.dart';
import '../../shared/movie_poster.dart';
import '../../shared/filter_box.dart';
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

  TagListEntity? _tagList;
  List<GenreEntity>? _genres;
  Map<String, String>? _iso3166;

  late final ScrollController _scrollController = ScrollController();
  final Map<String, Function(bool success)> _pendingFavoriteCallbacks = {};
  final Map<String, Function(bool success)> _pendingWatchedCallbacks = {};

  @override
  void initState() {
    super.initState();
    _loadStaticTags();
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
        _tagList = null;
        _genres = null;
        _iso3166 = null;
      });
      _loadStaticTags();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    switch (category) {
      case 'movie':
        return ['Movie'];
      case 'tv':
        return ['TV', 'Season'];
      case 'video':
        return ['Video'];
      case 'total':
      default:
        return ['Movie', 'TV', 'Directory', 'Video'];
    }
  }

  Future<void> _loadStaticTags() async {
    final repo = ref.read(iTagRepositoryProvider);
    try {
      // Match the KMP metadata request and keep tag list type unset here.
      final tagListResult = await repo.getTagList(
        ancestorGuid: widget.id,
        isFavorite: 0,
        type: null,
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
          : ['Movie', 'TV', 'Directory', 'Video'],
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
      _loadStaticTags(),
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
                      SortFlyout(
                        onSortTypeSelected: (type) {
                          setState(() => _sortColumn = type);
                          _refresh();
                        },
                        onSortOrderSelected: (order) {
                          setState(() => _sortOrder = order);
                          _refresh();
                        },
                      ),
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
                                if (item.type == 'TV') {
                                  context.go('/tv/${item.guid}');
                                } else {
                                  context.go('/movie/${item.guid}');
                                }
                              },
                              onPlayTap: () {
                                context.go('/player/${item.guid}');
                              },
                              onFavoriteToggle: _handleFavoriteToggle,
                              onWatchedToggle: _handleWatchedToggle,
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
