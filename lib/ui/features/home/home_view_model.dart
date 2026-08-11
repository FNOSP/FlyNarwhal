import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../domain/entities/media_type.dart';
import '../../../data/models/home_models.dart';
import '../../../data/models/media_request_models.dart';
import '../../../providers/providers.dart';

part 'home_view_model.g.dart';

@riverpod
class MediaDbListNotifier extends _$MediaDbListNotifier {
  @override
  FutureOr<List<MediaDbListResponse>> build() async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    try {
      final result = (await remote.getMediaDbList()).getOrThrow();
      return result;
    } catch (error) {
      rethrow;
    }
  }
}

@riverpod
class MediaSumNotifier extends _$MediaSumNotifier {
  @override
  FutureOr<Map<String, int>> build() async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    return (await remote.getMediaSum()).getOrThrow();
  }
}

@riverpod
class PlayListNotifier extends _$PlayListNotifier {
  @override
  FutureOr<List<PlayDetailResponse>> build() async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    return (await remote.getPlayList()).getOrThrow();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

@riverpod
class ItemListNotifier extends _$ItemListNotifier {
  @override
  FutureOr<ItemListQueryResponse> build(String guid) async {
    final request = ItemListQueryRequest(
      ancestorGuid: guid,
      tags: Tags(type: MediaType.libraryBrowseValues),
    );
    final remote = ref.read(mediaRemoteDataSourceProvider);
    try {
      final result = (await remote.getItemList(request)).getOrThrow();
      ref.keepAlive();
      return result;
    } catch (_) {
      rethrow;
    }
  }
}

// Favorite action result
class FavoriteActionResult {
  final String guid;
  final bool isFavorite;
  final bool success;
  final String message;
  final bool previousState;

  const FavoriteActionResult({
    required this.guid,
    required this.isFavorite,
    required this.success,
    required this.message,
    required this.previousState,
  });
}

// Watched action result
class WatchedActionResult {
  final String guid;
  final bool isWatched;
  final bool success;
  final String message;
  final bool previousState;

  const WatchedActionResult({
    required this.guid,
    required this.isWatched,
    required this.success,
    required this.message,
    required this.previousState,
  });
}

@riverpod
class FavoriteNotifier extends _$FavoriteNotifier {
  @override
  FavoriteActionResult? build() => null;

  Future<FavoriteActionResult> toggleFavorite(
      String guid, bool currentFavoriteState) async {
    try {
      final remote = ref.read(mediaRemoteDataSourceProvider);
      final response = await remote.toggleFavorite(
        ItemGuidRequest(itemGuid: guid),
        isFavorite: currentFavoriteState,
      );
      final isSuccess = response.getOrElse(false);

      final result = FavoriteActionResult(
        guid: guid,
        isFavorite: !currentFavoriteState,
        success: isSuccess,
        message: isSuccess
            ? (currentFavoriteState ? '已取消收藏' : '已收藏')
            : (response.failureOrNull?.displayMessage ?? '操作失败'),
        previousState: currentFavoriteState,
      );

      state = result;
      return result;
    } catch (e) {
      final result = FavoriteActionResult(
        guid: guid,
        isFavorite: currentFavoriteState,
        success: false,
        message: '操作失败，$e',
        previousState: currentFavoriteState,
      );
      state = result;
      return result;
    }
  }

  void clear() {
    state = null;
  }
}

@riverpod
class WatchedNotifier extends _$WatchedNotifier {
  @override
  WatchedActionResult? build() => null;

  Future<WatchedActionResult> toggleWatched(
      String guid, bool currentWatchedState) async {
    try {
      final remote = ref.read(mediaRemoteDataSourceProvider);
      final response = await remote.toggleWatched(
        ItemGuidRequest(itemGuid: guid),
        isWatched: currentWatchedState,
      );
      final isSuccess = response.getOrElse(false);
      final result = WatchedActionResult(
        guid: guid,
        isWatched: !currentWatchedState,
        success: isSuccess,
        message: isSuccess
            ? (currentWatchedState ? '标记为未观看' : '标记为已观看')
            : (response.failureOrNull?.displayMessage ?? '操作失败'),
        previousState: currentWatchedState,
      );

      state = result;
      return result;
    } catch (e) {
      final result = WatchedActionResult(
        guid: guid,
        isWatched: currentWatchedState,
        success: false,
        message: '操作失败，$e',
        previousState: currentWatchedState,
      );
      state = result;
      return result;
    }
  }

  void clear() {
    state = null;
  }
}
