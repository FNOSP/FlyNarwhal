import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/base_response.dart';
import '../../models/home_models.dart';

/// Remote data source for media-related API calls
class MediaRemoteDataSource {
  final DioClient _dioClient;

  MediaRemoteDataSource(this._dioClient);

  /// Get list of media databases
  Future<ApiResult<List<MediaDbListResponse>>> getMediaDbList() async {
    final result = await _dioClient.get<List<MediaDbListResponse>>(
      ApiEndpoints.mediaDbList,
      converter: (data) => _parseMediaDbListResponse(data),
    );
    return result;
  }

  /// Get media statistics summary
  Future<ApiResult<Map<String, int>>> getMediaSum() async {
    final result = await _dioClient.get<Map<String, int>>(
      ApiEndpoints.mediaDbSum,
      converter: (data) => _parseMediaSumResponse(data),
    );
    return result;
  }

  /// Get play list (recently watched)
  Future<ApiResult<List<PlayDetailResponse>>> getPlayList() async {
    final result = await _dioClient.get<List<PlayDetailResponse>>(
      ApiEndpoints.playList,
      converter: (data) => _parsePlayListResponse(data),
    );
    return result;
  }

  /// Get item list by query
  Future<ApiResult<ItemListQueryResponse>> getItemList(
    ItemListQueryRequest request,
  ) async {
    final result = await _dioClient.post<ItemListQueryResponse>(
      ApiEndpoints.itemList,
      data: request.toJson(),
      converter: (data) => _parseItemListResponse(data),
    );
    return result;
  }

  /// Toggle favorite status (add)
  Future<ApiResult<bool>> addFavorite(String guid) async {
    final result = await _dioClient.put<bool>(
      ApiEndpoints.favorite,
      data: {'item_guid': guid},
      converter: (data) => _parseSuccessResponse(data),
    );
    return result;
  }

  /// Toggle favorite status (remove)
  Future<ApiResult<bool>> removeFavorite(String guid) async {
    final result = await _dioClient.delete<bool>(
      ApiEndpoints.favorite,
      data: {'item_guid': guid},
      converter: (data) => _parseSuccessResponse(data),
    );
    return result;
  }

  /// Toggle watched status (mark as watched)
  Future<ApiResult<bool>> markWatched(String guid) async {
    final result = await _dioClient.post<bool>(
      ApiEndpoints.watched,
      data: {'item_guid': guid},
      converter: (data) => _parseSuccessResponse(data),
    );
    return result;
  }

  /// Toggle watched status (mark as unwatched)
  Future<ApiResult<bool>> markUnwatched(String guid) async {
    final result = await _dioClient.delete<bool>(
      ApiEndpoints.watched,
      data: {'item_guid': guid},
      converter: (data) => _parseSuccessResponse(data),
    );
    return result;
  }

  // Private parsing methods
  List<MediaDbListResponse> _parseMediaDbListResponse(dynamic data) {
    final baseResponse = FnBaseResponse<List<MediaDbListResponse>>.fromJson(
      data,
      (json) => (json as List)
          .map((e) => MediaDbListResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? [];
  }

  Map<String, int> _parseMediaSumResponse(dynamic data) {
    final baseResponse = FnBaseResponse<Map<String, int>>.fromJson(
      data,
      (json) => (json as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value as int)),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? {};
  }

  List<PlayDetailResponse> _parsePlayListResponse(dynamic data) {
    final baseResponse = FnBaseResponse<List<PlayDetailResponse>>.fromJson(
      data,
      (json) => (json as List)
          .map((e) => PlayDetailResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? [];
  }

  ItemListQueryResponse _parseItemListResponse(dynamic data) {
    final baseResponse = FnBaseResponse<ItemListQueryResponse>.fromJson(
      data,
      (json) => ItemListQueryResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? ItemListQueryResponse();
  }

  bool _parseSuccessResponse(dynamic data) {
    if (data is bool) return data;
    if (data is Map) {
      if (data['code'] == ResponseCodes.success) return true;
      if (data['success'] == true) return true;
    }
    return false;
  }
}