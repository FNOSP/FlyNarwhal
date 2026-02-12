import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/filter_box.dart';
import '../../widgets/sort_flyout.dart';
import '../../../data/models/home_models.dart';
import '../../../data/models/tag_models.dart';
import '../../../providers/providers.dart';
import '../../../data/models/base_response.dart';
import '../../widgets/movie_poster.dart';

final _tabs = <String>['全部', '电影', '电视节目', '单集', '人物'];

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
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

  TagListResponse? _tagList;
  List<GenresResponse>? _genres;
  List<QueryTagResponse>? _iso3166;

  @override
  void initState() {
    super.initState();
    _loadStaticTags();
    _loadAllTabs(force: true);
  }

  Future<void> _loadStaticTags() async {
    final repo = ref.read(tagRepositoryProvider);
    try {
      TagListResponse? tagList;
      if (_selectedTab != '人物') {
        final type = _getTypeForTagApi(_selectedTab);
        tagList = await repo.getTagList(ancestorGuid: null, isFavorite: 1, type: type);
      }
      final genres = await repo.getGenres(lan: 'zh');
      final iso3166 = await repo.getTag('iso3166', lan: 'zh');
      await repo.getTag('iso6391', lan: 'zh');
      setState(() {
        _tagList = tagList;
        _genres = genres;
        _iso3166 = iso3166;
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

  @override
  Widget build(BuildContext context) {
    final scaleFactor = resolveWindowScaleFactor(context);
    final headerTitle = _mdbName ?? '收藏';

    return ScaffoldPage(
      header: PageHeader(title: Text(headerTitle)),
      content: NotificationListener<ScrollNotification>(
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
                            onTap: () {
                              if (item.type == 'TV') {
                                context.go('/tv/${item.guid}');
                              } else {
                                context.go('/movie/${item.guid}');
                              }
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
