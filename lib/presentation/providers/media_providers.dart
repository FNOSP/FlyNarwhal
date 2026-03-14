import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/index.dart';
import 'providers.dart';

/// Media database list state notifier
class MediaDbListNotifier extends StateNotifier<AsyncValue<List<MediaLibraryEntity>>> {
  final Ref _ref;

  MediaDbListNotifier(this._ref) : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    final useCase = _ref.read(getMediaDbListUseCaseProvider);
    final result = await useCase();

    result.when(
      success: (data) => state = AsyncValue.data(data),
      failure: (failure) => state = AsyncValue.error(failure.displayMessage, StackTrace.current),
    );
  }
}

/// Media database list provider
final mediaDbListNotifierProvider = StateNotifierProvider<MediaDbListNotifier, AsyncValue<List<MediaLibraryEntity>>>((ref) {
  return MediaDbListNotifier(ref)..load();
});

/// Media sum state notifier
class MediaSumNotifier extends StateNotifier<AsyncValue<Map<String, int>>> {
  final Ref _ref;

  MediaSumNotifier(this._ref) : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    final useCase = _ref.read(getMediaSumUseCaseProvider);
    final result = await useCase();

    result.when(
      success: (data) => state = AsyncValue.data(data),
      failure: (failure) => state = AsyncValue.error(failure.displayMessage, StackTrace.current),
    );
  }
}

/// Media sum provider
final mediaSumNotifierProvider = StateNotifierProvider<MediaSumNotifier, AsyncValue<Map<String, int>>>((ref) {
  return MediaSumNotifier(ref)..load();
});

/// Play list state notifier (recently watched)
class PlayListNotifier extends StateNotifier<AsyncValue<List<PlayDetailEntity>>> {
  final Ref _ref;

  PlayListNotifier(this._ref) : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    final useCase = _ref.read(getPlayListUseCaseProvider);
    final result = await useCase();

    result.when(
      success: (data) => state = AsyncValue.data(data),
      failure: (failure) => state = AsyncValue.error(failure.displayMessage, StackTrace.current),
    );
  }

  Future<void> refresh() async {
    await load();
  }
}

/// Play list provider
final playListNotifierProvider = StateNotifierProvider<PlayListNotifier, AsyncValue<List<PlayDetailEntity>>>((ref) {
  return PlayListNotifier(ref)..load();
});

/// Item list state notifier
class ItemListNotifier extends StateNotifier<AsyncValue<ItemListEntity>> {
  final Ref _ref;
  final String guid;

  ItemListNotifier(this._ref, this.guid) : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    final useCase = _ref.read(getItemListUseCaseProvider);
    final params = ItemListParams(
      ItemListQueryParams(
        ancestorGuid: guid,
        types: ["Movie", "TV", "Directory", "Video"],
      ),
    );

    final result = await useCase(params);

    result.when(
      success: (data) => state = AsyncValue.data(data),
      failure: (failure) => state = AsyncValue.error(failure.displayMessage, StackTrace.current),
    );
  }
}

/// Item list provider
final itemListNotifierProvider = StateNotifierProvider.family<ItemListNotifier, AsyncValue<ItemListEntity>, String>((ref, guid) {
  return ItemListNotifier(ref, guid)..load();
});

/// Favorite state notifier
class FavoriteNotifier extends StateNotifier<ActionResult?> {
  final Ref _ref;

  FavoriteNotifier(this._ref) : super(null);

  Future<ActionResult> toggleFavorite(String guid, bool currentFavoriteState) async {
    final useCase = _ref.read(toggleFavoriteUseCaseProvider);
    final params = ToggleFavoriteParams(
      guid: guid,
      currentState: currentFavoriteState,
    );

    final result = await useCase(params);

    return result.when(
      success: (actionResult) {
        state = actionResult;
        return actionResult;
      },
      failure: (failure) {
        final errorResult = ActionResult(
          guid: guid,
          success: false,
          message: 'Operation failed: ${failure.displayMessage}',
          previousState: currentFavoriteState,
        );
        state = errorResult;
        return errorResult;
      },
    );
  }

  void clear() {
    state = null;
  }
}

/// Favorite provider
final favoriteNotifierProvider = StateNotifierProvider<FavoriteNotifier, ActionResult?>((ref) {
  return FavoriteNotifier(ref);
});

/// Watched state notifier
class WatchedNotifier extends StateNotifier<ActionResult?> {
  final Ref _ref;

  WatchedNotifier(this._ref) : super(null);

  Future<ActionResult> toggleWatched(String guid, bool currentWatchedState) async {
    final useCase = _ref.read(toggleWatchedUseCaseProvider);
    final params = ToggleWatchedParams(
      guid: guid,
      currentState: currentWatchedState,
    );

    final result = await useCase(params);

    return result.when(
      success: (actionResult) {
        state = actionResult;
        return actionResult;
      },
      failure: (failure) {
        final errorResult = ActionResult(
          guid: guid,
          success: false,
          message: 'Operation failed: ${failure.displayMessage}',
          previousState: currentWatchedState,
        );
        state = errorResult;
        return errorResult;
      },
    );
  }

  void clear() {
    state = null;
  }
}

/// Watched provider
final watchedNotifierProvider = StateNotifierProvider<WatchedNotifier, ActionResult?>((ref) {
  return WatchedNotifier(ref);
});

/// User info provider
final userInfoEntityProvider = FutureProvider<UserEntity>((ref) async {
  final useCase = ref.read(getUserInfoUseCaseProvider);
  final result = await useCase();

  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.displayMessage),
  );
});