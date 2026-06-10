import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../domain/entities/tag_entity.dart';
import '../../../providers/global_refresh.dart';
import '../../widgets/filter_box.dart';
import '../../widgets/sort_flyout.dart';
import '../../widgets/toast.dart';
import '../../../data/models/home_models.dart';
import '../../../providers/providers.dart';
import '../../../data/models/base_response.dart';
import '../../widgets/movie_poster.dart';
import '../home/home_view_model.dart';

final _tabs = <String>['全部', '电影', '电视节目', '单集', '人物'];

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  static const String _globalRefreshConsumerId = 'favorites-screen';
  String _selectedTab = _tabs.first;
  int _selectedTabIndex = 0;
  int _tabSwitchDirection = 1;
  bool _enableTabAnimation = false;
  bool _isFilterOpen = false;
  Map<String, FilterItem> _selectedFilters = {};
  String _sortColumn = 'create_time';
  String _sortOrder = 'DESC';
  int _page = 1;
  bool _isLoadingMore = false;
  List<MediaItem> _items = [];
  String? _mdbName;
  final Map<String, List<MediaItem>> _tabItemsCache = {};
  final Map<String, int> _tabPageCache = {};
  final Map<String, bool> _tabLastPageCache = {};
  final Map<String, String?> _tabMdbNameCache = {};
  final Set<String> _loadingKeys = {};

  TagListEntity? _tagList;
  List<GenreEntity>? _genres;
  Map<String, String>? _iso3166;

  late final ToastManager _toastManager = ToastManager();
  late final ScrollController _scrollController = ScrollController();
  final Map<String, Function(bool success)> _pendingFavoriteCallbacks = {};
  final Map<String, Function(bool success)> _pendingWatchedCallbacks = {};

  @override
  void initState() {
    super.initState();
    _loadStaticTags();
    _loadAllTabs(force: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStaticTags() async {
    final repo = ref.read(iTagRepositoryProvider);
    try {
      TagListEntity? tagList;
      if (_selectedTab != '人物') {
        final type = _getTypeForTagApi(_selectedTab);
        final tagListResult = await repo.getTagList(
          ancestorGuid: null,
          isFavorite: 1,
          type: type,
        );
        tagList = tagListResult.dataOrNull;
      }
      // Load static tag dictionaries through the shared repository abstraction.
      final genresResult = await repo.getGenres();
      final iso3166Result = await repo.getTag('iso3166');
      await repo.getTag('iso6391');
      if (!mounted) {
        return;
      }
      setState(() {
        _tagList = tagList;
        _genres = genresResult.dataOrNull;
        _iso3166 = iso3166Result.dataOrNull;
      });
    } catch (_) {
    }
  }

  String _buildCacheKey(String tab, Map<String, FilterItem> filters) {
    final entries = filters.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final signature = entries.map((e) => '${e.key}:${e.value.value ?? ''}').join('|');
    return '$tab|$_sortColumn|$_sortOrder|$signature';
  }

  void _applyCacheToSelected(Map<String, FilterItem> filters) {
    final key = _buildCacheKey(_selectedTab, filters);
    final cached = _tabItemsCache[key];
    if (cached == null) return;
    setState(() {
      _items = cached;
      _page = _tabPageCache[key] ?? 1;
      _mdbName = _tabMdbNameCache[key];
      _isLoadingMore = false;
    });
  }

  void _clearCaches() {
    _tabItemsCache.clear();
    _tabPageCache.clear();
    _tabLastPageCache.clear();
    _tabMdbNameCache.clear();
    _loadingKeys.clear();
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
    // Run the shared media-library refresh before updating favorites data.
    await request.runBaseMediaLibraryRefresh();
    if (!mounted) {
      return;
    }

    // Reset the current browsing state so refresh uses the default filters.
    setState(() {
      _isFilterOpen = false;
      _selectedFilters = {};
    });
    _clearCaches();
    await _scrollToTop();

    // Reload the current tab and related metadata after the shared refresh.
    await Future.wait([
      _loadStaticTags(),
      _loadData(
        tab: _selectedTab,
        page: 1,
        filters: const {},
        force: true,
      ),
    ]);
  }

  List<String>? _getTypesForTab(String tab) {
    switch (tab) {
      case '电影':
        return ['Movie'];
      case '电视节目':
        return ['TV', 'Season'];
      case '单集':
        return ['Episode'];
      case '人物':
        return ['Person'];
      case '全部':
      default:
        return null;
    }
  }

  String? _getTypeForTagApi(String tab) {
    switch (tab) {
      case '电影':
        return 'Movie';
      case '电视节目':
        return 'TV';
      case '单集':
        return 'Episode';
      default:
        return null;
    }
  }

  Tags _buildTagsForTab(String tab, Map<String, FilterItem> filters) {
    final types = List<String>.from(
      _getTypesForTab(tab) ?? ['Movie', 'TV', 'Season', 'Episode', 'Person', 'Directory', 'Video'],
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

  Future<void> _loadAllTabs({bool force = false}) async {
    for (final tab in _tabs) {
      await _loadData(
        tab: tab,
        page: 1,
        filters: const {},
        force: force,
        updateSelected: tab == _selectedTab,
      );
    }
  }

  Future<void> _loadData({
    required String tab,
    required int page,
    required Map<String, FilterItem> filters,
    bool force = false,
    bool updateSelected = true,
  }) async {
    final cacheKey = _buildCacheKey(tab, filters);
    if (_loadingKeys.contains(cacheKey)) return;
    if (!force && page == 1 && _tabItemsCache.containsKey(cacheKey)) {
      if (updateSelected) {
        _applyCacheToSelected(filters);
      }
      return;
    }
    _loadingKeys.add(cacheKey);
    if (updateSelected) {
      setState(() {
        _isLoadingMore = true;
      });
    }
    final dioClient = ref.read(dioClientProvider);
    final tags = _buildTagsForTab(tab, filters);
    final request = ItemListQueryRequest(
      tags: tags,
      page: page,
      pageSize: 50,
      sortColumn: _sortColumn,
      sortType: _sortOrder,
    );
    final response = await dioClient.dio.post(
      '/v/api/v1/favorite/list',
      data: request.toJson(),
    );
    final baseResponse = FnBaseResponse<ItemListQueryResponse>.fromJson(
      response.data,
      (json) => ItemListQueryResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != 0) {
      _loadingKeys.remove(cacheKey);
      if (updateSelected) {
        setState(() => _isLoadingMore = false);
      }
      return;
    }
    final data = baseResponse.data ?? ItemListQueryResponse();
    final cachedList = page == 1
        ? List<MediaItem>.from(data.list)
        : [...(_tabItemsCache[cacheKey] ?? const <MediaItem>[]), ...data.list];
    _tabItemsCache[cacheKey] = cachedList;
    _tabPageCache[cacheKey] = page;
    _tabLastPageCache[cacheKey] = data.list.length < 50;
    _tabMdbNameCache[cacheKey] = data.mdbName;
    _loadingKeys.remove(cacheKey);
    if (updateSelected) {
      setState(() {
        _mdbName = data.mdbName;
        _items = cachedList;
        _page = page;
        _isLoadingMore = false;
      });
    }
  }

  void _onClearFilter(String title) {
    if (_selectedFilters.containsKey(title)) {
      setState(() {
        _selectedFilters[title] = const FilterItem('全部', null);
      });
    } else {
      setState(() {
        _selectedFilters = {
          for (final e in _selectedFilters.entries) e.key: const FilterItem('全部', null),
        };
      });
    }
    _loadData(
      tab: _selectedTab,
      page: 1,
      filters: _selectedFilters,
      force: true,
    );
  }

  // Handle favorite toggle
  void _handleFavoriteToggle(String guid, bool currentFavoriteState, Function(bool success) callback) {
    _pendingFavoriteCallbacks[guid] = callback;
    ref.read(favoriteNotifierProvider.notifier).toggleFavorite(guid, currentFavoriteState);
  }

  // Handle watched toggle
  void _handleWatchedToggle(String guid, bool currentWatchedState, Function(bool success) callback) {
    _pendingWatchedCallbacks[guid] = callback;
    ref.read(watchedNotifierProvider.notifier).toggleWatched(guid, currentWatchedState);
  }

  // Handle favorite result
  void _handleFavoriteResult(FavoriteActionResult? result) {
    if (result == null) return;

    _toastManager.showToast(
      result.message,
      type: result.success ? ToastType.success : ToastType.failed,
    );

    _pendingFavoriteCallbacks[result.guid]?.call(result.success);
    _pendingFavoriteCallbacks.remove(result.guid);

    // Remove item from list if unfavorited successfully
    if (result.success && !result.isFavorite) {
      setState(() {
        _items = _items.where((item) => item.guid != result.guid).toList();
      });
      // Update cache
      final cacheKey = _buildCacheKey(_selectedTab, _selectedFilters);
      if (_tabItemsCache.containsKey(cacheKey)) {
        _tabItemsCache[cacheKey] = _tabItemsCache[cacheKey]!
            .where((item) => item.guid != result.guid)
            .toList();
      }
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(favoriteNotifierProvider.notifier).clear();
      }
    });
  }

  // Handle watched result
  void _handleWatchedResult(WatchedActionResult? result) {
    if (result == null) return;

    _toastManager.showToast(
      result.message,
      type: result.success ? ToastType.success : ToastType.failed,
    );

    _pendingWatchedCallbacks[result.guid]?.call(result.success);
    _pendingWatchedCallbacks.remove(result.guid);

    // Update item's watched status in the list
    if (result.success) {
      setState(() {
        final index = _items.indexWhere((item) => item.guid == result.guid);
        if (index != -1) {
          final item = _items[index];
          _items[index] = MediaItem(
            guid: item.guid,
            title: item.title,
            poster: item.poster,
            type: item.type,
            voteAverage: item.voteAverage,
            isFavorite: item.isFavorite,
            watched: result.isWatched ? 1 : 0,
            mediaStream: item.mediaStream,
            releaseDate: item.releaseDate,
            seasonNumber: item.seasonNumber,
            episodeNumber: item.episodeNumber,
          );
        }
      });
      // Update cache
      final cacheKey = _buildCacheKey(_selectedTab, _selectedFilters);
      if (_tabItemsCache.containsKey(cacheKey)) {
        final cacheList = _tabItemsCache[cacheKey]!;
        final index = cacheList.indexWhere((item) => item.guid == result.guid);
        if (index != -1) {
          final item = cacheList[index];
          cacheList[index] = MediaItem(
            guid: item.guid,
            title: item.title,
            poster: item.poster,
            type: item.type,
            voteAverage: item.voteAverage,
            isFavorite: item.isFavorite,
            watched: result.isWatched ? 1 : 0,
            mediaStream: item.mediaStream,
            releaseDate: item.releaseDate,
            seasonNumber: item.seasonNumber,
            episodeNumber: item.episodeNumber,
          );
        }
      }
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(watchedNotifierProvider.notifier).clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final globalRefreshManager = ref.read(globalRefreshManagerProvider);

    // Consume each global refresh event once for the favorites page.
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
    ref.listen<FavoriteActionResult?>(favoriteNotifierProvider, (previous, next) {
      _handleFavoriteResult(next);
    });

    // Listen to watched result changes
    ref.listen<WatchedActionResult?>(watchedNotifierProvider, (previous, next) {
      _handleWatchedResult(next);
    });

    final scaleFactor = resolveWindowScaleFactor(context);
    final headerTitle = _mdbName ?? '收藏';

    return ScaffoldPage(
      header: PageHeader(title: Text(headerTitle)),
      content: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                final cacheKey = _buildCacheKey(_selectedTab, _selectedFilters);
                if (_isLoadingMore || (_tabLastPageCache[cacheKey] ?? false)) {
                  return false;
                }
                _loadData(
                  tab: _selectedTab,
                  page: _page + 1,
                  filters: _selectedFilters,
                  force: true,
                );
              }
              return false;
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      ..._tabs.map((tab) {
                        final isSelected = tab == _selectedTab;
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: HoverButton(
                              onPressed: () {
                                if (_selectedTab != tab) {
                                  final nextIndex = _tabs.indexOf(tab);
                                  setState(() {
                                    _enableTabAnimation = true;
                                    _tabSwitchDirection = nextIndex >= _selectedTabIndex ? 1 : -1;
                                    _selectedTabIndex = nextIndex;
                                    _selectedTab = tab;
                                    _isFilterOpen = false;
                                    _selectedFilters = {};
                                  });
                                  _loadStaticTags();
                                  _applyCacheToSelected(const {});
                                  _loadData(
                                    tab: _selectedTab,
                                    page: 1,
                                    filters: const {},
                                    force: false,
                                  );
                                }
                              },
                              builder: (context, states) => Text(
                                tab,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? const Color(0xFF2073DF) : FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  height: 1,
                  color: FluentTheme.of(context).resources.controlStrokeColorDefault.withValues(alpha: 0.1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      if (_selectedTab != '人物')
                        FilterButton(
                          isSelected: _isFilterOpen,
                          selectedFilters: _selectedFilters,
                          onFilterClear: _onClearFilter,
                          onClick: () => setState(() => _isFilterOpen = !_isFilterOpen),
                        ),
                      const SizedBox(width: 8),
                      SortFlyout(
                        onSortTypeSelected: (type) {
                          setState(() => _sortColumn = type);
                          _clearCaches();
                          _loadAllTabs(force: true);
                        },
                        onSortOrderSelected: (order) {
                          setState(() => _sortOrder = order);
                          _clearCaches();
                          _loadAllTabs(force: true);
                        },
                        sortOptions: const [
                          SortItem('收藏时间', 'create_time'),
                          SortItem('发行年份', 'release_date'),
                          SortItem('标题', 'sort_title'),
                          SortItem('评分', 'vote_average'),
                        ],
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
                        axisAlignment: -1,
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
                              _selectedFilters = Map<String, FilterItem>.from(filters);
                              _loadData(
                                tab: _selectedTab,
                                page: 1,
                                filters: _selectedFilters,
                                force: true,
                              );
                            },
                            onCollapse: () => setState(() => _isFilterOpen = false),
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('filter-box-empty'),
                        ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: _enableTabAnimation ? const Duration(milliseconds: 300) : Duration.zero,
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                        reverseCurve: Curves.easeIn,
                      );
                      final isCurrent = child.key == ValueKey('favorites-grid-$_selectedTab') ||
                          child.key == const ValueKey('favorites-empty');
                      final baseAnimation = isCurrent ? curved : ReverseAnimation(curved);
                      final slideAnimation = Tween<Offset>(
                        begin: isCurrent ? Offset(_tabSwitchDirection.toDouble(), 0) : Offset.zero,
                        end: isCurrent ? Offset.zero : Offset(-_tabSwitchDirection.toDouble(), 0),
                      ).animate(baseAnimation);
                      return SlideTransition(
                        position: slideAnimation,
                        child: FadeTransition(opacity: curved, child: child),
                      );
                    },
                    child: _items.isEmpty
                        ? Center(
                            key: const ValueKey('favorites-empty'),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  'assets/images/empty_folder.svg',
                                  width: 160 * scaleFactor,
                                  height: 150 * scaleFactor,
                                ),
                                const SizedBox(height: 12),
                                const Text('无数据'),
                              ],
                            ),
                          )
                        : GridView.builder(
                            key: ValueKey('favorites-grid-$_selectedTab'),
                            controller: _scrollController,
                            padding: EdgeInsets.all(16 * scaleFactor),
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 160 * scaleFactor,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 0,
                              childAspectRatio: 0.6,
                            ),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              const posterHeight = 200.0;
                              const posterWidth = posterHeight * 2 / 3;
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
                ),
              ],
            ),
          ),
          // Toast overlay
          ToastHost(toastManager: _toastManager),
        ],
      ),
    );
  }
}
