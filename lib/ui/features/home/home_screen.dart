import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'home_view_model.dart';
import '../../../providers/global_refresh.dart';
import '../../../providers/providers.dart';
import 'widgets/media_lib_card_row.dart';
import 'widgets/media_lib_gallery.dart';
import 'widgets/recently_watched.dart';
import '../../shared/toast.dart';
import '../../shared/common/app_loading_progress_ring.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const String _globalRefreshConsumerId = 'home-screen';
  late final ToastManager _toastManager = ToastManager();
  late final ScrollController _scrollController = ScrollController();
  
  // Pending callbacks for favorite/watched operations
  final Map<String, Function(bool success)> _pendingFavoriteCallbacks = {};
  final Map<String, Function(bool success)> _pendingWatchedCallbacks = {};
  
  // Track items to be removed from recently watched
  Set<String> _itemsToBeRemoved = {};

  @override
  void initState() {
    super.initState();

    // Load user info once when the home page enters, mirroring the KMP home screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(userInfoProvider.notifier).loadUserInfo();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaDbListAsync = ref.watch(mediaDbListNotifierProvider);
    final playListAsync = ref.watch(playListNotifierProvider);
    final globalRefreshManager = ref.read(globalRefreshManagerProvider);

    // Consume each global refresh event once and keep the home data in sync.
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
    
    return ScaffoldPage(
      header: const PageHeader(title: Text('首页')),
      content: Stack(
        children: [
          Scrollbar(
            controller: _scrollController,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                mediaDbListAsync.when(
                  data: (data) => SliverToBoxAdapter(
                    child: MediaLibCardRow(
                      items: data,
                      onItemClick: (item) {
                        context.go('/library/${item.guid}');
                      },
                    ),
                  ),
                  loading: () => const SliverToBoxAdapter(child: Center(child: AppLoadingProgressRing())),
                  error: (err, stack) => SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('Error loading libraries: $err'),
                  )),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(
                  child: playListAsync.when(
                    data: (data) {
                      final filteredData = data.where((item) => !_itemsToBeRemoved.contains(item.guid)).toList();
                      return RecentlyWatched(
                        title: "继续观看",
                        items: filteredData,
                        onFavoriteToggle: _handleFavoriteToggle,
                        onWatchedToggle: _handleWatchedToggle,
                        onItemRemoved: _onItemRemoved,
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (err, stack) => const SizedBox.shrink(),
                  ),
                ),
                mediaDbListAsync.when(
                  data: (data) {
                    if (data.isEmpty) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    return SliverList.builder(
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        final lib = data[index];
                        return MediaLibGallery(
                          title: lib.title,
                          guid: lib.guid,
                          onFavoriteToggle: _handleFavoriteToggle,
                          onWatchedToggle: _handleWatchedToggle,
                        );
                      },
                    );
                  },
                  loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                  error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
          // Toast overlay
          ToastHost(toastManager: _toastManager),
        ],
      ),
    );
  }

  Future<void> _handleGlobalRefresh(GlobalRefreshRequest request) async {
    // Run the shared media-library refresh before page-specific refresh work.
    await request.runBaseMediaLibraryRefresh();
    if (!mounted) {
      return;
    }
    final libraries = await ref.read(mediaDbListNotifierProvider.future);
    if (!mounted) {
      return;
    }

    // Clear local removal state so refreshed data reflects the source of truth.
    setState(() {
      _itemsToBeRemoved = {};
    });

    // 复位滚动条到顶部，使仅有顶部可视区域的 gallery 重建并自动重新请求。
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    // 使所有 gallery provider 失效但不主动全量重拉——仅顶部可视区域的 gallery 会因
    // SliverList.builder 重建而自动重新请求，屏幕外的等滚动到再拉。
    for (final library in libraries) {
      ref.invalidate(itemListNotifierProvider(library.guid));
    }

    await Future.wait([
      ref.read(playListNotifierProvider.notifier).refresh(),
      ref.read(userInfoProvider.notifier).loadUserInfo(force: true),
    ]);
  }

  // Handle favorite toggle
  void _handleFavoriteToggle(String guid, bool currentFavoriteState, Function(bool success) callback) {
    // Store the callback
    _pendingFavoriteCallbacks[guid] = callback;
    // Call the notifier
    ref.read(favoriteNotifierProvider.notifier).toggleFavorite(guid, currentFavoriteState);
  }

  // Handle watched toggle
  void _handleWatchedToggle(String guid, bool currentWatchedState, Function(bool success) callback) {
    // Store the callback
    _pendingWatchedCallbacks[guid] = callback;
    // Call the notifier
    ref.read(watchedNotifierProvider.notifier).toggleWatched(guid, currentWatchedState);
  }

  // Handle favorite result
  void _handleFavoriteResult(FavoriteActionResult? result) {
    if (result == null) return;
    
    // Show toast
    _toastManager.showToast(
      result.message,
      type: result.success ? ToastType.success : ToastType.failed,
    );
    
    // Call the pending callback
    _pendingFavoriteCallbacks[result.guid]?.call(result.success);
    _pendingFavoriteCallbacks.remove(result.guid);
    
    // Clear the state after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(favoriteNotifierProvider.notifier).clear();
      }
    });
  }

  // Handle watched result
  void _handleWatchedResult(WatchedActionResult? result) {
    if (result == null) return;
    
    // Show toast
    _toastManager.showToast(
      result.message,
      type: result.success ? ToastType.success : ToastType.failed,
    );
    
    // Call the pending callback
    _pendingWatchedCallbacks[result.guid]?.call(result.success);
    _pendingWatchedCallbacks.remove(result.guid);
    
    // Refresh play list if marked as watched
    if (result.success && result.isWatched) {
      ref.read(playListNotifierProvider.notifier).refresh();
    }
    
    // Clear the state after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(watchedNotifierProvider.notifier).clear();
      }
    });
  }

  // Handle item removed from recently watched
  void _onItemRemoved(String guid) {
    setState(() {
      _itemsToBeRemoved.add(guid);
    });
  }
}
