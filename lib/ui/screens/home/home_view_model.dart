import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/base_response.dart';
import '../../../data/models/home_models.dart';
import '../../../providers/providers.dart';

part 'home_view_model.g.dart';

@riverpod
class MediaDbListNotifier extends _$MediaDbListNotifier {
  @override
  FutureOr<List<MediaDbListResponse>> build() async {
    final dioClient = ref.read(dioClientProvider);
    final response = await dioClient.dio.get('/v/api/v1/mediadb/list');
    final baseResponse = FnBaseResponse<List<MediaDbListResponse>>.fromJson(
        response.data,
        (json) => (json as List).map((e) => MediaDbListResponse.fromJson(e as Map<String, dynamic>)).toList()
    );
    if (baseResponse.code != 0) throw Exception(baseResponse.msg);
    return baseResponse.data ?? [];
  }
}

@riverpod
class MediaSumNotifier extends _$MediaSumNotifier {
  @override
  FutureOr<Map<String, int>> build() async {
    final dioClient = ref.read(dioClientProvider);
    final response = await dioClient.dio.get('/v/api/v1/mediadb/sum');
    final baseResponse = FnBaseResponse<Map<String, int>>.fromJson(
      response.data,
      (json) => (json as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value as int)),
    );
    if (baseResponse.code != 0) throw Exception(baseResponse.msg);
    return baseResponse.data ?? {};
  }
}

@riverpod
class PlayListNotifier extends _$PlayListNotifier {
  @override
  FutureOr<List<PlayDetailResponse>> build() async {
    final dioClient = ref.read(dioClientProvider);
    final response = await dioClient.dio.get('/v/api/v1/play/list');
    final baseResponse = FnBaseResponse<List<PlayDetailResponse>>.fromJson(
        response.data,
        (json) => (json as List).map((e) => PlayDetailResponse.fromJson(e as Map<String, dynamic>)).toList()
    );
    if (baseResponse.code != 0) throw Exception(baseResponse.msg);
    return baseResponse.data ?? [];
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
    final dioClient = ref.read(dioClientProvider);
    
    final request = ItemListQueryRequest(
      ancestorGuid: guid,
      tags: Tags(type: ["Movie", "TV", "Directory", "Video"]),
    );

    final response = await dioClient.dio.post(
      '/v/api/v1/item/list',
      data: request.toJson(),
    );
    
    final baseResponse = FnBaseResponse<ItemListQueryResponse>.fromJson(
        response.data,
        (json) => ItemListQueryResponse.fromJson(json as Map<String, dynamic>)
    );
    if (baseResponse.code != 0) throw Exception(baseResponse.msg);
    return baseResponse.data ?? ItemListQueryResponse();
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

  Future<FavoriteActionResult> toggleFavorite(String guid, bool currentFavoriteState) async {
    try {
      final dioClient = ref.read(dioClientProvider);
      
      final response = currentFavoriteState
          ? await dioClient.dio.delete(
              '/v/api/v1/item/favorite',
              data: {'item_guid': guid},
            )
          : await dioClient.dio.put(
              '/v/api/v1/item/favorite',
              data: {'item_guid': guid},
            );

      final isSuccess = _isSuccessResponse(response.data);
      
      final result = FavoriteActionResult(
        guid: guid,
        isFavorite: !currentFavoriteState,
        success: isSuccess,
        message: currentFavoriteState ? '已取消收藏' : '已收藏',
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

  bool _isSuccessResponse(dynamic data) {
    if (data is bool) return data;
    if (data is Map) {
      // Check for code == 0 (API returns {code: 0, data: true/false})
      if (data['code'] == 0) return true;
      // Also check for success field for backward compatibility
      if (data['success'] == true) return true;
    }
    return false;
  }
}

@riverpod
class WatchedNotifier extends _$WatchedNotifier {
  @override
  WatchedActionResult? build() => null;

  Future<WatchedActionResult> toggleWatched(String guid, bool currentWatchedState) async {
    try {
      final dioClient = ref.read(dioClientProvider);
      
      final response = currentWatchedState
          ? await dioClient.dio.delete(
              '/v/api/v1/item/watched',
              data: {'item_guid': guid},
            )
          : await dioClient.dio.post(
              '/v/api/v1/item/watched',
              data: {'item_guid': guid},
            );

      final isSuccess = _isSuccessResponse(response.data);
      final result = WatchedActionResult(
        guid: guid,
        isWatched: !currentWatchedState,
        success: isSuccess,
        message: currentWatchedState ? '标记为未观看' : '标记为已观看',
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

  bool _isSuccessResponse(dynamic data) {
    if (data is bool) return data;
    if (data is Map) {
      // Check for code == 0 (API returns {code: 0, data: true/false})
      if (data['code'] == 0) return true;
      // Also check for success field for backward compatibility
      if (data['success'] == true) return true;
    }
    return false;
  }
}