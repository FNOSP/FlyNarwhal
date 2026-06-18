import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/home_models.dart';
import '../../../providers/global_refresh.dart';
import '../../shared/filter_box.dart';
import '../../shared/movie_poster.dart';
import '../../shared/sort_flyout.dart';
import '../../shared/toast.dart';
import '../home/home_view_model.dart';
import 'favorites_view_model.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  static const String _globalRefreshConsumerId = 'favorites-screen';

  String _selectedTab = favoritesTabs.first;
  int _selectedTabIndex = 0;
  int _tabSwitchDirection = 1;
  bool _enableTabAnimation = false;
  bool _isFilterOpen = false;

  late final ToastManager _toastManager = ToastManager();
  late final ScrollController _scrollController = ScrollController();
  final Map<String, Function(bool success)> _pendingFavoriteCallbacks = {};
  final Map<String, Function(bool success)> _pendingWatchedCallbacks = {};

  @override
  void initState() {
    super.initState();
    ref.read(favoritesBrowseNotifierProvider.notifier);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    await request.runBaseMediaLibraryRefresh();
    if (!mounted) {
      return;
    }

    setState(() {
      _isFilterOpen = false;
    });
    await _scrollToTop();
    await ref.read(favoritesBrowseNotifierProvider.notifier).refreshAll(
          resetFilters: true,
        );
  }

  void _handleFavoriteToggle(
    String guid,
    bool currentFavoriteState,
    Function(bool success) callback,
  ) {
    _pendingFavoriteCallbacks[guid] = callback;
    ref
        .read(favoriteNotifierProvider.notifier)
        .toggleFavorite(guid, currentFavoriteState);
  }

  void _handleWatchedToggle(
    String guid,
    bool currentWatchedState,
    Function(bool success) callback,
  ) {
    _pendingWatchedCallbacks[guid] = callback;
    ref
        .read(watchedNotifierProvider.notifier)
        .toggleWatched(guid, currentWatchedState);
  }

  void _handleFavoriteResult(FavoriteActionResult? result) {
    if (result == null) {
      return;
    }

    _toastManager.showToast(
      result.message,
      type: result.success ? ToastType.success : ToastType.failed,
    );

    _pendingFavoriteCallbacks[result.guid]?.call(result.success);
    _pendingFavoriteCallbacks.remove(result.guid);

    if (result.success) {
      unawaited(
        ref
            .read(favoritesBrowseNotifierProvider.notifier)
            .handleFavoriteSuccess(),
      );
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(favoriteNotifierProvider.notifier).clear();
      }
    });
  }

  void _handleWatchedResult(WatchedActionResult? result) {
    if (result == null) {
      return;
    }

    _toastManager.showToast(
      result.message,
      type: result.success ? ToastType.success : ToastType.failed,
    );

    _pendingWatchedCallbacks[result.guid]?.call(result.success);
    _pendingWatchedCallbacks.remove(result.guid);

    if (result.success) {
      unawaited(
        ref
            .read(favoritesBrowseNotifierProvider.notifier)
            .handleWatchedSuccess(),
      );
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
    final favoritesState = ref.watch(favoritesBrowseNotifierProvider);
    final favoritesNotifier =
        ref.read(favoritesBrowseNotifierProvider.notifier);

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
    final items = favoritesState.items;
    final selectedFilters = favoritesState.query.selectedFilters;
    final headerTitle = favoritesState.mdbName ?? '收藏';

    return ScaffoldPage(
      header: PageHeader(title: Text(headerTitle)),
      content: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 200) {
                if (favoritesState.isLoadingMore || !favoritesState.hasMore) {
                  return false;
                }
                unawaited(favoritesNotifier.loadMore());
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
                      ...favoritesTabs.map((tab) {
                        final isSelected = tab == _selectedTab;
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: HoverButton(
                              onPressed: () {
                                if (_selectedTab == tab) {
                                  return;
                                }
                                final nextIndex = favoritesTabs.indexOf(tab);
                                setState(() {
                                  _enableTabAnimation = true;
                                  _tabSwitchDirection =
                                      nextIndex >= _selectedTabIndex ? 1 : -1;
                                  _selectedTabIndex = nextIndex;
                                  _selectedTab = tab;
                                  _isFilterOpen = false;
                                });
                                unawaited(favoritesNotifier.switchTab(tab));
                              },
                              builder: (context, states) => Text(
                                tab,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? const Color(0xFF2073DF)
                                      : FluentTheme.of(context)
                                          .typography
                                          .body
                                          ?.color
                                          ?.withValues(alpha: 0.8),
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
                  color: FluentTheme.of(context)
                      .resources
                      .controlStrokeColorDefault
                      .withValues(alpha: 0.1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      if (_selectedTab != '人物')
                        FilterButton(
                          isSelected: _isFilterOpen,
                          selectedFilters: selectedFilters,
                          onFilterClear: (title) {
                            unawaited(favoritesNotifier.clearFilter(title));
                          },
                          onClick: () =>
                              setState(() => _isFilterOpen = !_isFilterOpen),
                        ),
                      const SizedBox(width: 8),
                      SortFlyout(
                        onSortTypeSelected: (type) {
                          unawaited(favoritesNotifier.updateSortColumn(type));
                        },
                        onSortOrderSelected: (order) {
                          unawaited(favoritesNotifier.updateSortOrder(order));
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
                            tagList: favoritesState.selectedTagList,
                            genres: favoritesState.genres,
                            iso3166: favoritesState.iso3166,
                            initialSelectedFilters: selectedFilters,
                            onFilterChanged: (filters) {
                              unawaited(
                                  favoritesNotifier.applyFilters(filters));
                            },
                            onCollapse: () =>
                                setState(() => _isFilterOpen = false),
                          ),
                        )
                      : const SizedBox(key: ValueKey('filter-box-empty')),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: _enableTabAnimation
                        ? const Duration(milliseconds: 300)
                        : Duration.zero,
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                        reverseCurve: Curves.easeIn,
                      );
                      final isCurrent = child.key ==
                              ValueKey('favorites-grid-$_selectedTab') ||
                          child.key ==
                              ValueKey('favorites-loading-$_selectedTab') ||
                          child.key == const ValueKey('favorites-empty');
                      final baseAnimation =
                          isCurrent ? curved : ReverseAnimation(curved);
                      final slideAnimation = Tween<Offset>(
                        begin: isCurrent
                            ? Offset(_tabSwitchDirection.toDouble(), 0)
                            : Offset.zero,
                        end: isCurrent
                            ? Offset.zero
                            : Offset(-_tabSwitchDirection.toDouble(), 0),
                      ).animate(baseAnimation);
                      return SlideTransition(
                        position: slideAnimation,
                        child: FadeTransition(opacity: curved, child: child),
                      );
                    },
                    child: favoritesState.isInitializing ||
                            (favoritesState.isRefreshingSelected &&
                                items.isEmpty)
                        ? Center(
                            key: ValueKey('favorites-loading-$_selectedTab'),
                            child: const ProgressRing(),
                          )
                        : items.isEmpty
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
                                gridDelegate:
                                    SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 160 * scaleFactor,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 0,
                                  childAspectRatio: 0.6,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
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
          ToastHost(toastManager: _toastManager),
        ],
      ),
    );
  }
}
