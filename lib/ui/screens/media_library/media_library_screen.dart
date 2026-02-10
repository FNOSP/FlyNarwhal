import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/home_models.dart';
import '../../../data/models/base_response.dart';
import '../../../data/models/tag_models.dart';
import '../../../providers/providers.dart';
import '../../widgets/movie_poster.dart';
import '../../widgets/filter_box.dart';
import '../../widgets/sort_flyout.dart';
import '../home/home_view_model.dart';

class MediaLibraryScreen extends ConsumerStatefulWidget {
  final String? id;
  final String? categoryType;
  const MediaLibraryScreen({super.key, this.id, this.categoryType});

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
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

  @override
  void didUpdateWidget(covariant MediaLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.categoryType != widget.categoryType) {
      setState(() {
        _isFilterOpen = false;
        _selectedFilters = {};
        _sortColumn = 'create_time';
        _sortOrder = 'DESC';
        _page = 1;
        _isLoadingMore = false;
        _items = [];
        _mdbName = null;
        _tagList = null;
        _genres = null;
        _iso3166 = null;
      });
      _loadStaticTags();
      _refresh(force: true);
    }
  }

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

  String? _categoryTagType(String? category) {
    switch (category) {
      case 'movie':
        return 'Movie';
      case 'tv':
        return 'TV';
      case 'video':
        return 'Video';
      case 'total':
        return null;
      default:
        return null;
    }
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
    final repo = ref.read(tagRepositoryProvider);
    try {
      final tagList = await repo.getTagList(
        ancestorGuid: widget.id,
        isFavorite: 0,
        type: widget.id == null ? _categoryTagType(widget.categoryType) : null,
      );
      final genres = await repo.getGenres(lan: 'zh');
      final iso3166 = await repo.getTag('iso3166', lan: 'zh');
      await repo.getTag('iso6391', lan: 'zh');
      setState(() {
        _tagList = tagList;
        _genres = genres;
        _iso3166 = iso3166;
      });
    } catch (_) {}
  }

  Tags _buildTags(Map<String, FilterItem> filters) {
    final types = List<String>.from(
      widget.id == null ? _categoryTypes(widget.categoryType) : ['Movie', 'TV', 'Directory', 'Video'],
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
    final tags = _buildTags(_selectedFilters);
    final request = ItemListQueryRequest(
      ancestorGuid: widget.id,
      tags: tags,
      page: page,
      pageSize: 50,
      sortColumn: _sortColumn,
      sortType: _sortOrder,
    );
    final response = await dioClient.dio.post(
      '/v/api/v1/item/list',
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
    final resolvedMdbName = (data.mdbName != null && data.mdbName!.trim().isNotEmpty)
        ? data.mdbName
        : null;
    setState(() {
      _mdbName = widget.id != null ? resolvedMdbName : null;
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
    if (widget.id == null && widget.categoryType == null) {
      return const Center(child: Text("Invalid Library ID"));
    }
    final scaleFactor = resolveWindowScaleFactor(context);
    final mediaDbList = ref.watch(mediaDbListNotifierProvider).asData?.value ?? const [];
    const posterHeight = 200.0;
    const posterWidth = posterHeight * 2 / 3;
    final mediaDbTitle = _resolveMediaDbTitle(mediaDbList);
    final title = widget.id != null ? (_mdbName ?? mediaDbTitle ?? '媒体库') : _resolveTitle();

    return ScaffoldPage(
      header: PageHeader(title: Text(title)),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
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
                          _refresh(force: true);
                        },
                        onCollapse: () => setState(() => _isFilterOpen = false),
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('filter-box-empty'),
                    ),
            ),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: ProgressRing())
                  : GridView.builder(
                      padding: EdgeInsets.all(16 * scaleFactor),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180 * scaleFactor,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 0,
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
                          width: posterWidth,
                          height: posterHeight,
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
