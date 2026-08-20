import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/home_models.dart';
import '../../../domain/entities/media_type.dart';
import '../../../providers/global_refresh.dart';
import '../../../providers/providers.dart';
import '../../../providers/smart_analysis_controller.dart';
import '../../shared/common/app_loading_progress_ring.dart';
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
  static const Duration _tabSwitchAnimationDuration =
      Duration(milliseconds: 300);

  String _selectedTab = favoritesTabs.first;
  int _selectedTabIndex = 0;
  int _tabSwitchDirection = 1;
  bool _enableTabAnimation = false;
  bool _isFilterOpen = false;
  Timer? _tabAnimationTimer;

  final Map<String, ScrollController> _scrollControllers = {};
  final Map<String, Function(bool success)> _pendingFavoriteCallbacks = {};
  final Map<String, Function(bool success)> _pendingWatchedCallbacks = {};
  late final FlyoutController _smartAnalysisFlyoutController =
      FlyoutController();

  @override
  void initState() {
    super.initState();
    ref.read(favoritesBrowseNotifierProvider.notifier);
  }

  @override
  void dispose() {
    _tabAnimationTimer?.cancel();
    _smartAnalysisFlyoutController.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _enableOneShotTabAnimation() {
    _tabAnimationTimer?.cancel();
    _enableTabAnimation = true;
    _tabAnimationTimer = Timer(_tabSwitchAnimationDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _enableTabAnimation = false;
      });
    });
  }

  void _disableTabAnimation() {
    _tabAnimationTimer?.cancel();
    _tabAnimationTimer = null;
    _enableTabAnimation = false;
  }

  ScrollController _getScrollController(String cacheKey) {
    return _scrollControllers.putIfAbsent(cacheKey, ScrollController.new);
  }

  Future<void> _scrollToTop() async {
    final scrollController = _getScrollController(
      ref.read(favoritesBrowseNotifierProvider).query.selectedCacheKey,
    );
    if (!scrollController.hasClients) {
      return;
    }
    await scrollController.animateTo(
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
      _disableTabAnimation();
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

    ref.read(toastManagerProvider.notifier).showToast(
          result.message,
          type: result.success ? ToastType.success : ToastType.failed,
          category: 'favorite:${result.guid}',
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

    ref.read(toastManagerProvider.notifier).showToast(
          result.message,
          type: result.success ? ToastType.success : ToastType.failed,
          category: 'watched:${result.guid}',
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

    ref.listen<FavoriteActionResult?>(favoriteNotifierProvider, (
      previous,
      next,
    ) {
      _handleFavoriteResult(next);
    });

    ref.listen<WatchedActionResult?>(watchedNotifierProvider, (previous, next) {
      _handleWatchedResult(next);
    });

    final scaleFactor = resolveWindowScaleFactor(context);
    final items = favoritesState.items;

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

    final selectedFilters = favoritesState.query.selectedFilters;
    final headerTitle = favoritesState.mdbName ?? '收藏';
    final selectedCacheKey = favoritesState.query.selectedCacheKey;
    final scrollController = _getScrollController(selectedCacheKey);
    final contentKey = favoritesState.isInitializing ||
            (favoritesState.isRefreshingSelected && items.isEmpty)
        ? ValueKey('favorites-loading-$_selectedTab')
        : items.isEmpty
            ? const ValueKey('favorites-empty')
            : ValueKey('favorites-grid-$selectedCacheKey');

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
                          padding: const EdgeInsets.only(right: 48),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: HoverButton(
                              onPressed: () {
                                if (_selectedTab == tab) {
                                  return;
                                }
                                setState(() {
                                  _enableOneShotTabAnimation();
                                  final selectedTabIndex =
                                      favoritesTabs.indexOf(tab);
                                  _tabSwitchDirection =
                                      selectedTabIndex >= _selectedTabIndex
                                          ? 1
                                          : -1;
                                  _selectedTabIndex = selectedTabIndex;
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
                        alignment: AlignmentDirectional.topCenter,
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
                        ? _tabSwitchAnimationDuration
                        : Duration.zero,
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      if (!_enableTabAnimation) {
                        return child;
                      }
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                        reverseCurve: Curves.easeIn,
                      );
                      final childKey = child.key;
                      final isIncomingChild = childKey == contentKey;
                      final slideBeginOffset = Offset(
                        _tabSwitchDirection.toDouble(),
                        0,
                      );

                      if (!isIncomingChild) {
                        return FadeTransition(opacity: curved, child: child);
                      }

                      final slideAnimation = Tween<Offset>(
                        begin: slideBeginOffset,
                        end: Offset.zero,
                      ).animate(curved);
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
                            child: const AppLoadingProgressRing(),
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
                                key: ValueKey(
                                    'favorites-grid-$selectedCacheKey'),
                                controller: scrollController,
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
                                    onTap: () {
                                      if (item.type == 'TV') {
                                        context.go('/tv/${item.guid}');
                                      } else if (item.type == 'Season') {
                                        context.go('/tv/season/${item.guid}');
                                      } else if (item.type == 'Directory') {
                                        context.go('/folder/${item.guid}');
                                      } else {
                                        context.go('/movie/${item.guid}');
                                      }
                                    },
                                    onPlayTap:
                                        item.type == 'Directory'
                                            ? null
                                            : () {
                                                if (item.type ==
                                                    MediaType
                                                        .liveChannel.value) {
                                                  ref
                                                      .read(
                                                          navigationStackProvider
                                                              .notifier)
                                                      .playerSourcePath =
                                                      GoRouterState.of(context)
                                                          .uri
                                                          .toString();
                                                  context
                                                      .go('/live/${item.guid}');
                                                } else {
                                                  context.go(
                                                      '/player/${item.guid}');
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
