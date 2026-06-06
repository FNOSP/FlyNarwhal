import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/player/player_manager.dart';
import '../ui/screens/home/home_view_model.dart';

typedef BaseMediaLibraryRefreshCallback = Future<void> Function();

class GlobalRefreshRequest {
  final int id;
  final BaseMediaLibraryRefreshCallback onBaseMediaLibraryRefresh;

  const GlobalRefreshRequest({
    required this.id,
    required this.onBaseMediaLibraryRefresh,
  });

  Future<void> runBaseMediaLibraryRefresh() {
    return onBaseMediaLibraryRefresh();
  }
}

class TitleBarRefreshVisibility {
  final String currentRoutePath;
  final bool isPlayerVisible;

  const TitleBarRefreshVisibility({
    required this.currentRoutePath,
    required this.isPlayerVisible,
  });

  bool get shouldHideRefreshAction {
    return isPlayerVisible || currentRoutePath.startsWith('/player/');
  }

  bool get shouldShowRefreshAction {
    return !shouldHideRefreshAction;
  }
}

final currentRoutePathProvider = StateProvider<String>((ref) => '/login');

final currentGlobalRefreshRequestProvider =
    StateProvider<GlobalRefreshRequest?>((ref) => null);

final consumedGlobalRefreshRequestProvider =
    StateProvider.family<int?, String>((ref, consumerId) => null);

final titleBarRefreshVisibilityProvider =
    Provider<TitleBarRefreshVisibility>((ref) {
  final currentRoutePath = ref.watch(currentRoutePathProvider);
  final isPlayerVisible =
      ref.watch(playerManagerProvider.select((state) => state.isVisible));
  return TitleBarRefreshVisibility(
    currentRoutePath: currentRoutePath,
    isPlayerVisible: isPlayerVisible,
  );
});

class GlobalRefreshManager {
  GlobalRefreshManager(this._ref);

  final Ref _ref;

  void updateCurrentRoutePath(String path) {
    if (path.isEmpty) {
      return;
    }
    final routePathNotifier = _ref.read(currentRoutePathProvider.notifier);
    if (routePathNotifier.state != path) {
      routePathNotifier.state = path;
    }
  }

  Future<GlobalRefreshRequest> requestRefresh() async {
    final request = GlobalRefreshRequest(
      id: DateTime.now().microsecondsSinceEpoch,
      onBaseMediaLibraryRefresh: _runBaseMediaLibraryRefresh,
    );
    _ref.read(currentGlobalRefreshRequestProvider.notifier).state = request;
    return request;
  }

  bool consumeOnce({
    required String consumerId,
    required GlobalRefreshRequest? request,
  }) {
    if (request == null) {
      return false;
    }

    final consumedRequestNotifier =
        _ref.read(consumedGlobalRefreshRequestProvider(consumerId).notifier);
    if (consumedRequestNotifier.state == request.id) {
      return false;
    }

    consumedRequestNotifier.state = request.id;
    return true;
  }

  Future<bool> handleRefresh({
    required String consumerId,
    required GlobalRefreshRequest? request,
    required Future<void> Function() onRefresh,
    bool refreshBaseMediaLibrary = true,
  }) async {
    if (!consumeOnce(consumerId: consumerId, request: request)) {
      return false;
    }

    // Refresh shared media library data before page-specific refresh logic.
    if (refreshBaseMediaLibrary && request != null) {
      await request.runBaseMediaLibraryRefresh();
    }

    // Run the page-specific refresh only after the shared refresh completes.
    await onRefresh();
    return true;
  }

  // Refresh shared media library metadata before page-specific refresh logic.
  Future<void> _runBaseMediaLibraryRefresh() async {
    _ref.invalidate(mediaDbListNotifierProvider);
    _ref.invalidate(mediaSumNotifierProvider);

    await Future.wait([
      _ref.read(mediaDbListNotifierProvider.future),
      _ref.read(mediaSumNotifierProvider.future),
    ]);
  }
}

final globalRefreshManagerProvider = Provider<GlobalRefreshManager>((ref) {
  return GlobalRefreshManager(ref);
});
