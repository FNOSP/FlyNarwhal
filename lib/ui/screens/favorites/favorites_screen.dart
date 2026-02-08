import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _isFilterOpen = false;
  Map<String, FilterItem> _selectedFilters = {};
  String _sortColumn = 'create_time';
  String _sortOrder = 'DESC';
  int _page = 1;
  bool _isLoadingMore = false;
  List<MediaItem> _items = [];
  String? _mdbName;

  TagListResponse? _tagList;
  List<GenresResponse>? _genres;
  List<QueryTagResponse>? _iso3166;

  @override
  void initState() {
    super.initState();
    _loadStaticTags();
    _refresh(force: true);
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
    final types = List<String>.from(_getTypesForTab(tab) ?? ['Movie', 'TV', 'Directory', 'Video']);
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

  Future<void> _refresh({bool force = false}) async {
    setState(() {
      _page = 1;
      _items = [];
    });
    await _loadData(page: 1);
  }

  Future<void> _loadData({required int page}) async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    final dioClient = ref.read(dioClientProvider);
    final tags = _buildTagsForTab(_selectedTab, _selectedFilters);
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
      _isLoadingMore = false;
      return;
    }
    final data = baseResponse.data ?? ItemListQueryResponse();
    setState(() {
      _mdbName = data.mdbName;
      if (page == 1) {
        _items = data.list;
      } else {
        _items = [..._items, ...data.list];
      }
      _page = page;
      _isLoadingMore = false;
    });
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
    _refresh(force: true);
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
            _loadData(page: _page + 1);
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
                      child: HoverButton(
                        onPressed: () {
                          if (_selectedTab != tab) {
                            setState(() {
                              _selectedTab = tab;
                              _isFilterOpen = false;
                            });
                            _loadStaticTags();
                            _refresh(force: true);
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
                      _refresh(force: true);
                    },
                    onSortOrderSelected: (order) {
                      setState(() => _sortOrder = order);
                      _refresh(force: true);
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _isFilterOpen ? null : 0,
              child: _isFilterOpen
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FilterBox(
                        tagList: _tagList,
                        genres: _genres,
                        iso3166: _iso3166,
                        initialSelectedFilters: _selectedFilters,
                        onFilterChanged: (filters) {
                          _selectedFilters = Map<String, FilterItem>.from(filters);
                          _refresh(force: true);
                        },
                        onCollapse: () => setState(() => _isFilterOpen = false),
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: ProgressRing())
                  : GridView.builder(
                      padding: EdgeInsets.all(16 * scaleFactor),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200 * scaleFactor,
                        mainAxisSpacing: 16 * scaleFactor,
                        crossAxisSpacing: 16 * scaleFactor,
                        childAspectRatio: 0.6,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return MoviePoster(
                          title: item.title,
                          subtitle: buildPosterSubtitle(item),
                          posterPath: item.poster,
                          score: item.voteAverage,
                          resolutions: item.mediaStream?.resolutions,
                          isFavorite: item.isFavorite == 1,
                          isWatched: (item.watched ?? 0) == 1,
                          width: 150,
                          height: 225,
                          scaleFactor: scaleFactor,
                          onTap: () {},
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
