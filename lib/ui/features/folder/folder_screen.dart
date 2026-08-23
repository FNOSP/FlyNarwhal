import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/home_models.dart';
import '../../../data/models/media_request_models.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../data/models/user_data_models.dart';
import '../../../domain/entities/live_library_settings.dart';
import '../../../domain/entities/media_type.dart';
import '../../../domain/entities/tag_entity.dart';
import '../../../providers/global_refresh.dart';
import '../../../providers/providers.dart';
import '../../shared/common/app_loading_progress_ring.dart';
import '../../shared/filter_box.dart';
import '../../shared/layout_flyout.dart';
import '../../shared/movie_poster.dart';
import '../../shared/sort_flyout.dart';
import '../../shared/toast.dart';
import '../home/home_view_model.dart';
import '../media_library/media_library_view_model.dart';
import '../movie_detail/detail_components.dart';

/// 文件夹（子目录）浏览页，对齐 Web `/v/folder/:guid`：
/// 面包屑 → 大标题 → 继续播放胶囊 + 收藏/看过/更多圆形按钮 → 分隔线 →
/// 筛选/排序/布局工具条 + 共 N 项 → 海报网格。
class FolderScreen extends ConsumerStatefulWidget {
  final String guid;
  const FolderScreen({super.key, required this.guid});

  @override
  ConsumerState<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends ConsumerState<FolderScreen> {
  static const String _globalRefreshConsumerId = 'folder-screen';
  static const String _settingsKey = 'mdb:list:setting';

  bool _isFilterOpen = false;
  Map<String, FilterItem> _selectedFilters = {};
  // 文件夹默认按标题升序（与 Web 文件夹视图一致）。
  String _sortColumn = 'sort_title';
  String _sortOrder = 'ASC';
  LiveLibrarySettings _settings = const LiveLibrarySettings();

  ItemResponse? _folderInfo;
  bool _isFavorite = false;
  bool _isWatched = false;
  bool _favoriteLoading = false;
  bool _watchedLoading = false;
  bool _moreActionLoading = false;

  TagListEntity? _tagList;
  List<GenreEntity>? _genres;
  Map<String, String>? _iso3166;

  String? _libraryGuid;
  bool _settingsBootstrapped = false;

  late final ScrollController _scrollController = ScrollController();
  late final FlyoutController _moreFlyoutController = FlyoutController();
  final Map<String, Function(bool success)> _pendingFavoriteCallbacks = {};
  final Map<String, Function(bool success)> _pendingWatchedCallbacks = {};

  @override
  void initState() {
    super.initState();
    _loadFolderInfo();
    _loadStaticTags();
    _refreshBrowse();
  }

  @override
  void didUpdateWidget(covariant FolderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guid != widget.guid) {
      setState(() {
        _isFilterOpen = false;
        _selectedFilters = {};
        _sortColumn = 'sort_title';
        _sortOrder = 'ASC';
        _settings = const LiveLibrarySettings();
        _folderInfo = null;
        _libraryGuid = null;
        _settingsBootstrapped = false;
        _tagList = null;
        _genres = null;
        _iso3166 = null;
      });
      _loadFolderInfo();
      _loadStaticTags();
      _refreshBrowse();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _moreFlyoutController.dispose();
    super.dispose();
  }

  Future<void> _loadFolderInfo() async {
    final dataSource = ref.read(mediaRemoteDataSourceProvider);
    try {
      final result = await dataSource.getItemDetail(widget.guid);
      final info = result.dataOrNull;
      if (!mounted) return;
      setState(() {
        _folderInfo = info;
        _isFavorite = info?.isFavorite == 1;
        _isWatched = info?.isWatched == 1;
      });
    } catch (_) {}
  }

  Future<void> _loadStaticTags() async {
    final repo = ref.read(iTagRepositoryProvider);
    try {
      final tagListResult = await repo.getTagList(
        // Web `/v/folder/:guid` 用 parent_guid 请求 tag/list；ancestor_guid
        // 对目录项返回空集合，会导致筛选行只剩「全部」。
        parentGuid: widget.guid,
        isFavorite: 0,
      );
      if (!mounted) return;
      setState(() => _tagList = tagListResult.dataOrNull);

      final genresResult = await repo.getGenres();
      if (!mounted) return;
      setState(() => _genres = genresResult.dataOrNull);

      final iso3166Result = await repo.getTag('iso3166');
      if (!mounted) return;
      setState(() => _iso3166 = iso3166Result.dataOrNull);

      // 仅用于预热缓存，失败不影响筛选展示。
      await repo.getTag('iso6391');
    } catch (_) {}
  }

  MediaLibraryBrowseRequest _buildBrowseRequest() {
    return MediaLibraryBrowseRequest(
      parentGuid: widget.guid,
      excludeGroupedVideo: 0,
      page: 1,
      pageSize: 50,
      sortColumn: _sortColumn,
      sortType: _sortOrder,
      tags: _buildTags(_selectedFilters),
    );
  }

  Tags _buildTags(Map<String, FilterItem> filters) {
    final types = List<String>.from(MediaType.libraryBrowseValues);
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

  Future<void> _refreshBrowse() async {
    await ref
        .read(mediaLibraryNotifierProvider(widget.guid).notifier)
        .refreshWithQuery(_buildBrowseRequest());
  }

  /// 首次拿到浏览数据后提取所属媒体库 guid，再按 Web 语义
  /// （mdb:list:setting + mdb_guid + item_guid）读取本文件夹的布局/排序偏好。
  void _maybeBootstrapSettings(MediaLibraryState? libraryData) {
    if (_settingsBootstrapped || libraryData == null) return;
    String? libGuid;
    for (final item in libraryData.items) {
      if (item.ancestorGuid?.isNotEmpty == true) {
        libGuid = item.ancestorGuid;
        break;
      }
    }
    if (libGuid == null) return;
    _settingsBootstrapped = true;
    _libraryGuid = libGuid;
    unawaited(_loadFolderSettings());
  }

  Future<void> _loadFolderSettings() async {
    final dataSource = ref.read(userRemoteDataSourceProvider);
    try {
      final result = await dataSource.getUserData(UserDataGetRequest(
        key: _settingsKey,
        mdbGuid: _libraryGuid,
        itemGuid: widget.guid,
      ));
      final raw = result.getOrThrow().value;
      final settings = LiveLibrarySettings.fromJsonString(raw);
      if (!mounted) return;
      if (raw != null && raw.isNotEmpty) {
        setState(() {
          _settings = settings;
          _sortColumn = settings.sortField;
          _sortOrder = settings.sortType;
        });
        await _refreshBrowse();
      }
    } catch (_) {}
  }

  Future<void> _saveFolderSettings({LiveViewType? viewType}) async {
    final next = _settings.copyWith(
      sortType: _sortOrder,
      sortField: _sortColumn,
      viewType: viewType,
    );
    setState(() {
      _settings = next;
    });
    final libGuid = _libraryGuid;
    if (libGuid == null) {
      await _refreshBrowse();
      return;
    }
    final dataSource = ref.read(userRemoteDataSourceProvider);
    try {
      await dataSource.setUserData(UserDataSetRequest(
        key: _settingsKey,
        mdbGuid: libGuid,
        itemGuid: widget.guid,
        value: next.toJsonString(),
      ));
    } catch (_) {}
    await _refreshBrowse();
  }

  Future<void> _handleGlobalRefresh(GlobalRefreshRequest request) async {
    await request.runBaseMediaLibraryRefresh();
    if (!mounted) return;
    setState(() {
      _isFilterOpen = false;
      _selectedFilters = {};
    });
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    await Future.wait([
      _loadStaticTags(),
      _loadFolderInfo(),
      _refreshBrowse(),
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
    _refreshBrowse();
  }

  void _handleFavoriteToggle(
      String guid, bool currentFavoriteState, Function(bool success) callback) {
    _pendingFavoriteCallbacks[guid] = callback;
    ref
        .read(favoriteNotifierProvider.notifier)
        .toggleFavorite(guid, currentFavoriteState);
  }

  void _handleWatchedToggle(
      String guid, bool currentWatchedState, Function(bool success) callback) {
    _pendingWatchedCallbacks[guid] = callback;
    ref
        .read(watchedNotifierProvider.notifier)
        .toggleWatched(guid, currentWatchedState);
  }

  void _handleFavoriteResult(FavoriteActionResult? result) {
    if (result == null) return;
    ref.read(toastManagerProvider.notifier).showToast(
          result.message,
          type: result.success ? ToastType.success : ToastType.failed,
          category: 'favorite:${result.guid}',
        );
    if (result.guid == widget.guid && result.success) {
      setState(() => _isFavorite = !result.previousState);
    }
    _pendingFavoriteCallbacks[result.guid]?.call(result.success);
    _pendingFavoriteCallbacks.remove(result.guid);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(favoriteNotifierProvider.notifier).clear();
      }
    });
  }

  void _handleWatchedResult(WatchedActionResult? result) {
    if (result == null) return;
    ref.read(toastManagerProvider.notifier).showToast(
          result.message,
          type: result.success ? ToastType.success : ToastType.failed,
          category: 'watched:${result.guid}',
        );
    if (result.guid == widget.guid && result.success) {
      setState(() => _isWatched = !result.previousState);
    }
    _pendingWatchedCallbacks[result.guid]?.call(result.success);
    _pendingWatchedCallbacks.remove(result.guid);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(watchedNotifierProvider.notifier).clear();
      }
    });
  }

  // ── 「更多」菜单动作 ────────────────────────────────────────────────

  void _showMoreMenu() {
    if (_moreFlyoutController.isOpen) {
      _moreFlyoutController.close();
      return;
    }
    // jumpList 末项是当前文件夹，首项是媒体库；长度为 2 说明当前就是库根目录，
    // 与 Web 一致隐藏删除项。
    final isLibraryRoot =
        (ref.read(mediaLibraryNotifierProvider(widget.guid)).asData?.value
                .jumpList.length ??
            0) <=
        2;
    _moreFlyoutController.showFlyout<void>(
      placementMode: FlyoutPlacementMode.bottomRight,
      builder: (flyoutContext) => MenuFlyout(
        items: [
          MenuFlyoutItem(
            key: ValueKey('folder-rescrap-${widget.guid}'),
            leading: const Icon(FluentIcons.refresh, size: 16),
            text: const Text('重新识别'),
            onPressed: _moreActionLoading
                ? null
                : () {
                    Flyout.of(flyoutContext).close();
                    _rescrap();
                  },
          ),
          MenuFlyoutItem(
            key: ValueKey('folder-refresh-${widget.guid}'),
            leading: const Icon(FluentIcons.sync, size: 16),
            text: const Text('刷新元数据'),
            onPressed: _moreActionLoading
                ? null
                : () {
                    Flyout.of(flyoutContext).close();
                    _refreshMetadata();
                  },
          ),
          if (!isLibraryRoot) ...[
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              key: ValueKey('folder-delete-${widget.guid}'),
              leading: const Icon(FluentIcons.delete,
                  size: 16, color: kDangerDefaultColor),
              text: const Text('删除',
                  style: TextStyle(color: kDangerDefaultColor)),
              onPressed: _moreActionLoading
                  ? null
                  : () {
                      Flyout.of(flyoutContext).close();
                      _confirmDelete();
                    },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _rescrap() async {
    setState(() => _moreActionLoading = true);
    final dataSource = ref.read(mediaRemoteDataSourceProvider);
    try {
      final result = await dataSource.rescrapItem(
          widget.guid, MediaType.directory.value);
      final ok = result.isSuccess && result.dataOrNull == true;
      ref.read(toastManagerProvider.notifier).showToast(
            ok ? '已发起重新识别' : '重新识别失败',
            type: ok ? ToastType.success : ToastType.failed,
            category: 'folder-rescrap:${widget.guid}',
          );
    } catch (e) {
      ref.read(toastManagerProvider.notifier).showToast(
            '重新识别失败：$e',
            type: ToastType.failed,
            category: 'folder-rescrap:${widget.guid}',
          );
    } finally {
      if (mounted) setState(() => _moreActionLoading = false);
    }
  }

  Future<void> _refreshMetadata() async {
    setState(() => _moreActionLoading = true);
    final dataSource = ref.read(mediaRemoteDataSourceProvider);
    try {
      final result = await dataSource.refreshItemMetadata(widget.guid);
      final ok = result.isSuccess && result.dataOrNull == true;
      ref.read(toastManagerProvider.notifier).showToast(
            ok ? '已发起刷新元数据' : '刷新元数据失败',
            type: ok ? ToastType.success : ToastType.failed,
            category: 'folder-refresh:${widget.guid}',
          );
    } catch (e) {
      ref.read(toastManagerProvider.notifier).showToast(
            '刷新元数据失败：$e',
            type: ToastType.failed,
            category: 'folder-refresh:${widget.guid}',
          );
    } finally {
      if (mounted) setState(() => _moreActionLoading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final title = ref
            .read(mediaLibraryNotifierProvider(widget.guid))
            .asData
            ?.value
            .jumpList
            .lastOrNull
            ?.baseName ??
        '该文件夹';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('删除'),
        content: Text('确定要从媒体库删除「$title」吗？\n仅移除媒体库条目，不会删除磁盘上的文件。'),
        actions: [
          Button(
            child: const Text('取消'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          FilledButton(
            style: const ButtonStyle(
              backgroundColor:
                  WidgetStatePropertyAll(kDangerDefaultColor),
            ),
            child: const Text('删除'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _moreActionLoading = true);
    final dataSource = ref.read(mediaRemoteDataSourceProvider);
    try {
      final result =
          await dataSource.deleteItem(widget.guid, deleteFile: false);
      final ok = result.isSuccess && result.dataOrNull == true;
      ref.read(toastManagerProvider.notifier).showToast(
            ok ? '已删除' : '删除失败',
            type: ok ? ToastType.success : ToastType.failed,
            category: 'folder-delete:${widget.guid}',
          );
      if (ok && mounted) _navigateToParent();
    } catch (e) {
      ref.read(toastManagerProvider.notifier).showToast(
            '删除失败：$e',
            type: ToastType.failed,
            category: 'folder-delete:${widget.guid}',
          );
    } finally {
      if (mounted) setState(() => _moreActionLoading = false);
    }
  }

  void _navigateToParent() {
    final jumpList = ref
            .read(mediaLibraryNotifierProvider(widget.guid))
            .asData
            ?.value
            .jumpList ??
        const <JumpItem>[];
    // 去掉末项（当前文件夹）后，倒数第一项是父级。
    final crumbs =
        jumpList.length > 1 ? jumpList.sublist(0, jumpList.length - 1) : const <JumpItem>[];
    if (crumbs.isNotEmpty && crumbs.last.fvGuid.isNotEmpty) {
      context.go('/folder/${crumbs.last.fvGuid}');
      return;
    }
    final libGuid = _libraryGuid;
    if (libGuid != null) {
      context.go('/library/$libGuid');
    } else {
      context.go('/home');
    }
  }

  // ── 头部区域 ──────────────────────────────────────────────────────

  Widget _buildBreadcrumb(
      MediaLibraryState? libraryData, double scaleFactor) {
    final theme = FluentTheme.of(context);
    final jumpList = libraryData?.jumpList ?? const <JumpItem>[];
    final crumbs = jumpList.length > 1
        ? jumpList.sublist(0, jumpList.length - 1)
        : const <JumpItem>[];
    if (crumbs.isEmpty) return const SizedBox.shrink();
    final mutedColor = theme.typography.body?.color?.withValues(alpha: 0.7);

    void goCrumb(JumpItem crumb) {
      if (crumb.fvGuid.isNotEmpty) {
        context.go('/folder/${crumb.fvGuid}');
        return;
      }
      final libGuid = _libraryGuid;
      if (libGuid != null) context.go('/library/$libGuid');
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/images/folder_breadcrumb.svg',
          width: 16 * scaleFactor,
          height: 16 * scaleFactor,
          colorFilter: ColorFilter.mode(
            mutedColor ?? Colors.white,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 6),
        for (var i = 0; i < crumbs.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(FluentIcons.chevron_right,
                  size: 10 * scaleFactor, color: mutedColor),
            ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => goCrumb(crumbs[i]),
              child: Text(
                crumbs[i].baseName,
                style: theme.typography.body?.copyWith(
                  fontSize: 14 * scaleFactor,
                  color: mutedColor,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _circleIconButton({
    Key? key,
    required String tooltip,
    required Widget icon,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return CircleIconButton(
      key: key,
      tooltip: tooltip,
      icon: FluentIcons.circle_ring,
      iconColor: Colors.transparent,
      iconWidget: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: ProgressRing(strokeWidth: 2),
            )
          : Opacity(opacity: onPressed == null ? 0.5 : 1, child: icon),
      onPressed: loading || onPressed == null ? () {} : onPressed,
    );
  }

  Widget _buildHero(
      MediaLibraryState? libraryData, double scaleFactor) {
    final theme = FluentTheme.of(context);
    final title = libraryData?.jumpList.isNotEmpty == true
        ? libraryData!.jumpList.last.baseName
        : (libraryData?.mdbName ?? '文件夹');

    // 继续播放：播放历史中父级为当前文件夹的条目（与 Web can_play 逻辑对齐）。
    final resumeEntry = (ref.watch(playListNotifierProvider).asData?.value ??
            const <PlayDetailResponse>[])
        .cast<PlayDetailResponse?>()
        .firstWhere(
          (e) => e?.parentGuid == widget.guid,
          orElse: () => null,
        );
    final canPlay = _folderInfo?.canPlay == 1;
    final hasProgress =
        (resumeEntry?.ts ?? 0) > 0 && (resumeEntry?.duration ?? 0) > 0;

    final iconColor =
        theme.typography.body?.color ?? Colors.white;

    return Padding(
      padding: EdgeInsets.fromLTRB(24 * scaleFactor, 16 * scaleFactor,
          24 * scaleFactor, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBreadcrumb(libraryData, scaleFactor),
          SizedBox(height: 12 * scaleFactor),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.title?.copyWith(
              fontSize: 40 * scaleFactor,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          SizedBox(height: 20 * scaleFactor),
          Row(
            children: [
              if (resumeEntry != null && canPlay) ...[
                Button(
                  key: ValueKey('folder-continue-play-${resumeEntry.guid}'),
                  onPressed: () {
                    ref.read(navigationStackProvider.notifier)
                        .playerSourcePath =
                        GoRouterState.of(context).uri.toString();
                    context.go('/player/${resumeEntry.guid}');
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                        (states) {
                      final primary = theme.accentColor.normal;
                      return states.contains(WidgetState.hovered)
                          ? primary.withValues(alpha: 0.85)
                          : primary;
                    }),
                    foregroundColor:
                        const WidgetStatePropertyAll(Colors.white),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(27 * scaleFactor),
                      ),
                    ),
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 24 * scaleFactor),
                    ),
                  ),
                  child: SizedBox(
                    height: 54 * scaleFactor,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.play,
                            size: 20 * scaleFactor, color: Colors.white),
                        SizedBox(width: 8 * scaleFactor),
                        Text(
                          hasProgress ? '继续播放' : '播放',
                          style: theme.typography.body?.copyWith(
                            fontSize: 18 * scaleFactor,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8 * scaleFactor),
              ],
              _circleIconButton(
                key: ValueKey('folder-favorite-btn-${widget.guid}'),
                tooltip: _isFavorite ? '已收藏' : '收藏',
                onPressed: _folderInfo == null
                    ? null
                    : () {
                        setState(() => _favoriteLoading = true);
                        _handleFavoriteToggle(widget.guid, _isFavorite, (_) {
                          if (mounted) setState(() => _favoriteLoading = false);
                        });
                      },
                loading: _favoriteLoading,
                icon: SvgPicture.asset(
                  _isFavorite
                      ? 'assets/images/favorite_fill.svg'
                      : 'assets/images/favorite.svg',
                  width: 24 * scaleFactor,
                  height: 24 * scaleFactor,
                  colorFilter: ColorFilter.mode(
                    _isFavorite ? kDangerDefaultColor : iconColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              SizedBox(width: 8 * scaleFactor),
              _circleIconButton(
                key: ValueKey('folder-watched-btn-${widget.guid}'),
                tooltip: _isWatched ? '标记为未看过' : '标记为看过',
                onPressed: _folderInfo == null
                    ? null
                    : () {
                        setState(() => _watchedLoading = true);
                        _handleWatchedToggle(widget.guid, _isWatched, (_) {
                          if (mounted) setState(() => _watchedLoading = false);
                        });
                      },
                loading: _watchedLoading,
                icon: SvgPicture.asset(
                  _isWatched
                      ? 'assets/images/watched_fill.svg'
                      : 'assets/images/watched.svg',
                  width: 24 * scaleFactor,
                  height: 24 * scaleFactor,
                  colorFilter: ColorFilter.mode(
                    _isWatched ? theme.accentColor.normal : iconColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              SizedBox(width: 8 * scaleFactor),
              FlyoutTarget(
                controller: _moreFlyoutController,
                child: _circleIconButton(
                  key: ValueKey('folder-more-btn-${widget.guid}'),
                  tooltip: '更多',
                  onPressed: _folderInfo == null ? null : _showMoreMenu,
                  loading: _moreActionLoading,
                  icon: Icon(
                    FluentIcons.more,
                    size: 24 * scaleFactor,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * scaleFactor),
          Container(
            height: 1,
            color: (theme.typography.body?.color ?? Colors.white)
                .withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  // ── 内容网格 ──────────────────────────────────────────────────────

  void _navigateItem(MediaItem item) {
    switch (MediaType.tryParse(item.type)) {
      case MediaType.tv:
        context.go('/tv/${item.guid}');
        break;
      case MediaType.season:
        context.go('/tv/season/${item.guid}');
        break;
      case MediaType.directory:
        context.go('/folder/${item.guid}');
        break;
      default:
        context.go('/movie/${item.guid}');
    }
  }

  void _playItem(MediaItem item) {
    // Record the source page for the player's back button (VOD and live).
    ref.read(navigationStackProvider.notifier).playerSourcePath =
        GoRouterState.of(context).uri.toString();
    if (item.type == MediaType.liveChannel.value) {
      context.go('/live/${item.guid}');
    } else {
      context.go('/player/${item.guid}');
    }
  }

  Widget _buildVerticalGrid(List<MediaItem> items, double scaleFactor) {
    const posterHeight = 200.0;
    const posterWidth = posterHeight * 2 / 3;
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16 * scaleFactor),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180 * scaleFactor,
        mainAxisSpacing: 8,
        crossAxisSpacing: 0,
        childAspectRatio: 0.6,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isDirectory =
            MediaType.tryParse(item.type) == MediaType.directory;
        return MoviePoster(
          title: item.title,
          // 文件夹卡片仅显示标题（与 Web 一致）。
          subtitle: isDirectory ? null : buildPosterSubtitle(item),
          posterPath: item.effectivePoster,
          score: item.voteAverage,
          resolutions: item.mediaStream?.resolutions,
          isFavorite: item.isFavorite == 1,
          isWatched: (item.watched ?? 0) == 1,
          width: posterWidth,
          height: posterHeight,
          scaleFactor: scaleFactor,
          type: item.type,
          guid: item.guid,
          onTap: () => _navigateItem(item),
          onPlayTap: isDirectory ? null : () => _playItem(item),
          onFavoriteToggle: _handleFavoriteToggle,
          onWatchedToggle: _handleWatchedToggle,
        );
      },
    );
  }

  Widget _buildHorizontalGrid(List<MediaItem> items, double scaleFactor) {
    final theme = FluentTheme.of(context);
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16 * scaleFactor),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 264 * scaleFactor,
        mainAxisSpacing: 24,
        crossAxisSpacing: 16,
        childAspectRatio: 16 / 13,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isDirectory =
            MediaType.tryParse(item.type) == MediaType.directory;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BannerPoster(
                posterPath: item.effectivePoster,
                score: item.voteAverage,
                type: item.type,
                guid: item.guid,
                isFavorite: item.isFavorite == 1,
                isWatched: (item.watched ?? 0) == 1,
                scaleFactor: scaleFactor,
                onTap: () => _navigateItem(item),
                onPlayTap: isDirectory ? null : () => _playItem(item),
                onFavoriteToggle: _handleFavoriteToggle,
                onWatchedToggle: _handleWatchedToggle,
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

  @override
  Widget build(BuildContext context) {
    final globalRefreshManager = ref.read(globalRefreshManagerProvider);

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

    ref.listen<FavoriteActionResult?>(favoriteNotifierProvider,
        (previous, next) {
      _handleFavoriteResult(next);
    });
    ref.listen<WatchedActionResult?>(watchedNotifierProvider, (previous, next) {
      _handleWatchedResult(next);
    });

    final scaleFactor = resolveWindowScaleFactor(context);
    final mediaLibraryState =
        ref.watch(mediaLibraryNotifierProvider(widget.guid));
    final libraryData = mediaLibraryState.asData?.value;
    final items = libraryData?.items ?? const <MediaItem>[];

    // 首次拿到浏览数据后引导读取本文件夹的布局/排序偏好。
    _maybeBootstrapSettings(libraryData);

    return ScaffoldPage(
      header: null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(libraryData, scaleFactor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  // key 含排序状态：默认标题升序在异步读取偏好后才最终确定。
                  key: ValueKey('folder-sort-${widget.guid}-$_sortColumn-$_sortOrder'),
                  sortOptions: const [
                    SortItem('标题', 'sort_title'),
                    SortItem('添加日期', 'create_time'),
                  ],
                  initialSortColumn: _sortColumn,
                  initialSortOrder: _sortOrder,
                  onSortTypeSelected: (type) {
                    setState(() => _sortColumn = type);
                    _saveFolderSettings();
                  },
                  onSortOrderSelected: (order) {
                    setState(() => _sortOrder = order);
                    _saveFolderSettings();
                  },
                ),
                const SizedBox(width: 8),
                LayoutFlyout(
                  key: ValueKey(
                      'folder-layout-${widget.guid}-${_settings.viewType.value}'),
                  variant: LayoutMenuVariant.compact,
                  viewType: _settings.viewType,
                  onLayoutSelected: (viewType) =>
                      _saveFolderSettings(viewType: viewType),
                ),
                const Spacer(),
                Text(
                  '共 ${libraryData?.total ?? 0} 项',
                  style: FluentTheme.of(context).typography.body?.copyWith(
                        color: FluentTheme.of(context)
                            .typography
                            .body
                            ?.color
                            ?.withValues(alpha: 0.6),
                      ),
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
                    key: const ValueKey('folder-filter-box'),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FilterBox(
                      tagList: _tagList,
                      genres: _genres,
                      iso3166: _iso3166,
                      liveOnly: false,
                      folderOnly: true,
                      maxHeight: 260,
                      initialSelectedFilters: _selectedFilters,
                      onFilterChanged: (filters) {
                        _selectedFilters =
                            Map<String, FilterItem>.from(filters);
                        _refreshBrowse();
                      },
                      onCollapse: () =>
                          setState(() => _isFilterOpen = false),
                    ),
                  )
                : const SizedBox(key: ValueKey('folder-filter-box-empty')),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                if (scrollInfo.metrics.pixels >=
                    scrollInfo.metrics.maxScrollExtent - 200) {
                  ref
                      .read(
                          mediaLibraryNotifierProvider(widget.guid).notifier)
                      .loadMore();
                }
                return false;
              },
              child: mediaLibraryState.isLoading && items.isEmpty
                  ? const Center(child: AppLoadingProgressRing())
                  : mediaLibraryState.hasError
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              '加载失败：${mediaLibraryState.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _settings.viewType == LiveViewType.horizontalPoster
                          ? _buildHorizontalGrid(items, scaleFactor)
                          : _buildVerticalGrid(items, scaleFactor),
            ),
          ),
        ],
      ),
    );
  }
}
