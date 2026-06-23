import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/home_models.dart';
import '../../../domain/entities/tag_entity.dart';
import '../../../providers/providers.dart';
import '../../shared/filter_box.dart';

part 'favorites_view_model.g.dart';

const List<String> favoritesTabs = <String>['全部', '电影', '电视节目', '单集', '人物'];

const String _personTab = '人物';
const String _defaultSortColumn = 'create_time';
const String _defaultSortOrder = 'DESC';
const FilterItem _defaultFilterItem = FilterItem('全部', null);

class FavoritesBrowseQuery {
  final String selectedTab;
  final Map<String, FilterItem> selectedFilters;
  final String sortColumn;
  final String sortOrder;
  final String selectedCacheKey;

  const FavoritesBrowseQuery({
    required this.selectedTab,
    required this.selectedFilters,
    required this.sortColumn,
    required this.sortOrder,
    required this.selectedCacheKey,
  });

  factory FavoritesBrowseQuery.initial() {
    return FavoritesBrowseQuery(
      selectedTab: favoritesTabs.first,
      selectedFilters: const <String, FilterItem>{},
      sortColumn: _defaultSortColumn,
      sortOrder: _defaultSortOrder,
      selectedCacheKey: buildFavoritesCacheKey(
        favoritesTabs.first,
        const <String, FilterItem>{},
        _defaultSortColumn,
        _defaultSortOrder,
      ),
    );
  }

  FavoritesBrowseQuery copyWith({
    String? selectedTab,
    Map<String, FilterItem>? selectedFilters,
    String? sortColumn,
    String? sortOrder,
  }) {
    final nextTab = selectedTab ?? this.selectedTab;
    final nextFilters = Map<String, FilterItem>.unmodifiable(
      selectedFilters ?? this.selectedFilters,
    );
    final nextSortColumn = sortColumn ?? this.sortColumn;
    final nextSortOrder = sortOrder ?? this.sortOrder;
    return FavoritesBrowseQuery(
      selectedTab: nextTab,
      selectedFilters: nextFilters,
      sortColumn: nextSortColumn,
      sortOrder: nextSortOrder,
      selectedCacheKey: buildFavoritesCacheKey(
        nextTab,
        nextFilters,
        nextSortColumn,
        nextSortOrder,
      ),
    );
  }
}

class FavoritesCacheEntry {
  final List<MediaItem> items;
  final int page;
  final bool isLastPage;
  final String? mdbName;

  const FavoritesCacheEntry({
    required this.items,
    required this.page,
    required this.isLastPage,
    required this.mdbName,
  });
}

class FavoritesBrowseState {
  final FavoritesBrowseQuery query;
  final Map<String, FavoritesCacheEntry> cacheEntries;
  final Map<String, TagListEntity> tagListsByTab;
  final List<GenreEntity>? genres;
  final Map<String, String>? iso3166;
  final bool isInitializing;
  final bool isRefreshingSelected;
  final bool isLoadingMore;

  const FavoritesBrowseState({
    required this.query,
    this.cacheEntries = const <String, FavoritesCacheEntry>{},
    this.tagListsByTab = const <String, TagListEntity>{},
    this.genres,
    this.iso3166,
    this.isInitializing = false,
    this.isRefreshingSelected = false,
    this.isLoadingMore = false,
  });

  factory FavoritesBrowseState.initial() {
    return FavoritesBrowseState(
      query: FavoritesBrowseQuery.initial(),
      isInitializing: true,
    );
  }

  FavoritesCacheEntry? get currentEntry => cacheEntries[query.selectedCacheKey];

  List<MediaItem> get items => currentEntry?.items ?? const <MediaItem>[];

  String? get mdbName => currentEntry?.mdbName;

  bool get hasMore => !(currentEntry?.isLastPage ?? false);

  TagListEntity? get selectedTagList => tagListsByTab[query.selectedTab];

  FavoritesBrowseState copyWith({
    FavoritesBrowseQuery? query,
    Map<String, FavoritesCacheEntry>? cacheEntries,
    Map<String, TagListEntity>? tagListsByTab,
    List<GenreEntity>? genres,
    Map<String, String>? iso3166,
    bool? isInitializing,
    bool? isRefreshingSelected,
    bool? isLoadingMore,
  }) {
    return FavoritesBrowseState(
      query: query ?? this.query,
      cacheEntries: cacheEntries ?? this.cacheEntries,
      tagListsByTab: tagListsByTab ?? this.tagListsByTab,
      genres: genres ?? this.genres,
      iso3166: iso3166 ?? this.iso3166,
      isInitializing: isInitializing ?? this.isInitializing,
      isRefreshingSelected: isRefreshingSelected ?? this.isRefreshingSelected,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

String buildFavoritesCacheKey(
  String tab,
  Map<String, FilterItem> filters,
  String sortColumn,
  String sortOrder,
) {
  final entries = filters.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final signature = entries
      .map((entry) => '${entry.key}:${entry.value.value ?? ''}')
      .join('|');
  return '$tab|$sortColumn|$sortOrder|$signature';
}

@riverpod
class FavoritesBrowseNotifier extends _$FavoritesBrowseNotifier {
  int _selectedRequestSerial = 0;
  int _backgroundWarmSerial = 0;

  @override
  FavoritesBrowseState build() {
    final initialState = FavoritesBrowseState.initial();
    unawaited(_bootstrap());
    return initialState;
  }

  Future<void> switchTab(String tab) async {
    _backgroundWarmSerial++;
    final nextQuery = state.query.copyWith(
      selectedTab: tab,
      selectedFilters: const <String, FilterItem>{},
    );
    state = state.copyWith(
      query: nextQuery,
      isRefreshingSelected:
          !state.cacheEntries.containsKey(nextQuery.selectedCacheKey),
      isLoadingMore: false,
    );
    await _loadSelectedPage(page: 1, force: false);
  }

  Future<void> applyFilters(Map<String, FilterItem> filters) async {
    _backgroundWarmSerial++;
    final nextQuery = state.query.copyWith(selectedFilters: filters);
    state = state.copyWith(
      query: nextQuery,
      isRefreshingSelected:
          !state.cacheEntries.containsKey(nextQuery.selectedCacheKey),
      isLoadingMore: false,
    );
    await _loadSelectedPage(page: 1, force: true);
  }

  Future<void> clearFilter(String title) async {
    final nextFilters =
        Map<String, FilterItem>.from(state.query.selectedFilters);
    if (title == 'all') {
      if (nextFilters.isEmpty) {
        await applyFilters(const <String, FilterItem>{});
        return;
      }
      for (final key in nextFilters.keys.toList()) {
        nextFilters[key] = _defaultFilterItem;
      }
    } else if (nextFilters.containsKey(title)) {
      nextFilters[title] = _defaultFilterItem;
    } else {
      for (final key in nextFilters.keys.toList()) {
        nextFilters[key] = _defaultFilterItem;
      }
    }
    await applyFilters(nextFilters);
  }

  Future<void> updateSortColumn(String sortColumn) async {
    if (sortColumn == state.query.sortColumn) {
      return;
    }
    _backgroundWarmSerial++;
    final nextQuery = state.query.copyWith(sortColumn: sortColumn);
    state = state.copyWith(
      query: nextQuery,
      cacheEntries: const <String, FavoritesCacheEntry>{},
      isRefreshingSelected: true,
      isLoadingMore: false,
    );
    await _warmAllTabs(force: true);
  }

  Future<void> updateSortOrder(String sortOrder) async {
    if (sortOrder == state.query.sortOrder) {
      return;
    }
    _backgroundWarmSerial++;
    final nextQuery = state.query.copyWith(sortOrder: sortOrder);
    state = state.copyWith(
      query: nextQuery,
      cacheEntries: const <String, FavoritesCacheEntry>{},
      isRefreshingSelected: true,
      isLoadingMore: false,
    );
    await _warmAllTabs(force: true);
  }

  Future<void> refreshAll({bool resetFilters = false}) async {
    final warmSerial = ++_backgroundWarmSerial;
    var nextQuery = state.query;
    if (resetFilters) {
      nextQuery =
          nextQuery.copyWith(selectedFilters: const <String, FilterItem>{});
    }
    state = state.copyWith(
      query: nextQuery,
      cacheEntries: const <String, FavoritesCacheEntry>{},
      tagListsByTab: const <String, TagListEntity>{},
      isInitializing: true,
      isRefreshingSelected: true,
      isLoadingMore: false,
    );
    await _loadMetadata(force: true);
    if (warmSerial != _backgroundWarmSerial) {
      return;
    }
    await _loadSelectedPage(page: 1, force: true);
    if (warmSerial != _backgroundWarmSerial ||
        state.query.selectedCacheKey != nextQuery.selectedCacheKey) {
      return;
    }
    state = state.copyWith(isInitializing: false, isRefreshingSelected: false);
    unawaited(
      _warmRemainingTabs(
        force: true,
        baseQuery: nextQuery,
        warmSerial: warmSerial,
      ),
    );
  }

  Future<void> refreshCurrent() async {
    _backgroundWarmSerial++;
    state = state.copyWith(isRefreshingSelected: true, isLoadingMore: false);
    await _loadSelectedPage(page: 1, force: true);
    state = state.copyWith(isRefreshingSelected: false);
  }

  Future<void> handleFavoriteSuccess() async {
    await refreshCurrent();
    await _refreshSelectedTagListIfNeeded(force: true);
  }

  Future<void> handleWatchedSuccess() async {
    await refreshCurrent();
  }

  Future<void> loadMore() async {
    final currentEntry = state.currentEntry;
    if (currentEntry == null ||
        currentEntry.isLastPage ||
        state.isLoadingMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    await _fetchFavoritePage(
      query: state.query,
      page: currentEntry.page + 1,
      force: true,
      append: true,
      updateSelected: true,
    );
  }

  Future<void> _bootstrap() async {
    await _loadMetadata(force: false);
    await _warmAllTabs(force: false);
    state = state.copyWith(isInitializing: false, isRefreshingSelected: false);
  }

  Future<void> _loadMetadata({required bool force}) async {
    final repo = ref.read(iTagRepositoryProvider);
    try {
      final genresFuture = repo.getGenres(force: force);
      final iso3166Future = repo.getTag('iso3166', force: force);
      final tagListFuture = Future.wait(
        favoritesTabs
            .where((tab) => tab != _personTab)
            .map((tab) => _fetchTagList(tab, force: force)),
      );

      final genresResult = await genresFuture;
      final iso3166Result = await iso3166Future;
      final tagLists = await tagListFuture;

      final tagMap = <String, TagListEntity>{};
      for (final entry in tagLists) {
        if (entry != null) {
          tagMap[entry.$1] = entry.$2;
        }
      }

      state = state.copyWith(
        genres: genresResult.dataOrNull,
        iso3166: iso3166Result.dataOrNull,
        tagListsByTab: tagMap,
      );
    } catch (_) {
      state = state.copyWith(isInitializing: false);
    }
  }

  Future<(String, TagListEntity)?> _fetchTagList(
    String tab, {
    required bool force,
  }) async {
    final repo = ref.read(iTagRepositoryProvider);
    try {
      final result = await repo.getTagList(
        ancestorGuid: null,
        isFavorite: 1,
        type: _getTypeForTagApi(tab),
      );
      final tagList = result.dataOrNull;
      if (tagList == null) {
        return null;
      }
      return (tab, tagList);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshSelectedTagListIfNeeded({required bool force}) async {
    final selectedTab = state.query.selectedTab;
    if (selectedTab == _personTab) {
      return;
    }
    final refreshed = await _fetchTagList(selectedTab, force: force);
    if (refreshed == null) {
      return;
    }
    final nextTagLists = Map<String, TagListEntity>.from(state.tagListsByTab)
      ..[refreshed.$1] = refreshed.$2;
    state = state.copyWith(tagListsByTab: nextTagLists);
  }

  Future<void> _warmAllTabs({required bool force}) async {
    final selectedTab = state.query.selectedTab;
    for (final tab in favoritesTabs) {
      final query = state.query.copyWith(
        selectedTab: tab,
        selectedFilters: tab == selectedTab
            ? state.query.selectedFilters
            : const <String, FilterItem>{},
      );
      await _fetchFavoritePage(
        query: query,
        page: 1,
        force: force,
        append: false,
        updateSelected: tab == selectedTab,
      );
    }
  }

  Future<void> _warmRemainingTabs({
    required bool force,
    required FavoritesBrowseQuery baseQuery,
    required int warmSerial,
  }) async {
    for (final tab
        in favoritesTabs.where((tab) => tab != baseQuery.selectedTab)) {
      if (warmSerial != _backgroundWarmSerial) {
        return;
      }
      final query = baseQuery.copyWith(
        selectedTab: tab,
        selectedFilters: const <String, FilterItem>{},
      );
      await _fetchFavoritePage(
        query: query,
        page: 1,
        force: force,
        append: false,
        updateSelected: false,
        warmSerial: warmSerial,
      );
    }
  }

  Future<void> _loadSelectedPage({
    required int page,
    required bool force,
  }) async {
    await _fetchFavoritePage(
      query: state.query,
      page: page,
      force: force,
      append: page > 1,
      updateSelected: true,
    );
  }

  Future<void> _fetchFavoritePage({
    required FavoritesBrowseQuery query,
    required int page,
    required bool force,
    required bool append,
    required bool updateSelected,
    int? warmSerial,
  }) async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    final cacheKey = query.selectedCacheKey;
    final cached = state.cacheEntries[cacheKey];
    if (warmSerial != null && warmSerial != _backgroundWarmSerial) {
      return;
    }
    if (!force && page == 1 && cached != null) {
      if (updateSelected) {
        state = state.copyWith(
          query: query,
          isRefreshingSelected: false,
          isLoadingMore: false,
        );
      }
      return;
    }

    final requestSerial =
        updateSelected ? ++_selectedRequestSerial : _selectedRequestSerial;
    try {
      final result = await remote.getFavoriteList(
        ItemListQueryRequest(
          tags: _buildTagsForTab(query.selectedTab, query.selectedFilters),
          page: page,
          pageSize: 50,
          sortColumn: query.sortColumn,
          sortType: query.sortOrder,
        ),
      );
      final data = result.getOrThrow();
      if (warmSerial != null && warmSerial != _backgroundWarmSerial) {
        return;
      }
      final currentCacheEntries =
          Map<String, FavoritesCacheEntry>.from(state.cacheEntries);
      final existing = currentCacheEntries[cacheKey];
      final nextItems = append && existing != null
          ? <MediaItem>[...existing.items, ...data.list]
          : List<MediaItem>.from(data.list);

      currentCacheEntries[cacheKey] = FavoritesCacheEntry(
        items: nextItems,
        page: page,
        isLastPage: data.list.length < 50,
        mdbName: data.mdbName,
      );

      if (updateSelected && requestSerial != _selectedRequestSerial) {
        state = state.copyWith(cacheEntries: currentCacheEntries);
        return;
      }

      state = state.copyWith(
        query: updateSelected ? query : state.query,
        cacheEntries: currentCacheEntries,
        isRefreshingSelected:
            updateSelected ? false : state.isRefreshingSelected,
        isLoadingMore: false,
      );
    } catch (_) {
      if (warmSerial != null && warmSerial != _backgroundWarmSerial) {
        return;
      }
      state = state.copyWith(
        isRefreshingSelected:
            updateSelected ? false : state.isRefreshingSelected,
        isLoadingMore: false,
      );
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

  List<String>? _getTypesForTab(String tab) {
    switch (tab) {
      case '电影':
        return <String>['Movie'];
      case '电视节目':
        return <String>['TV', 'Season'];
      case '单集':
        return <String>['Episode'];
      case '人物':
        return <String>['Person'];
      case '全部':
      default:
        return null;
    }
  }

  Tags _buildTagsForTab(String tab, Map<String, FilterItem> filters) {
    final types = List<String>.from(
      _getTypesForTab(tab) ??
          <String>[
            'Movie',
            'TV',
            'Season',
            'Episode',
            'Person',
            'Directory',
            'Video'
          ],
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
          final value = item.value as int?;
          recognitionStatus = value?.toString();
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
}
