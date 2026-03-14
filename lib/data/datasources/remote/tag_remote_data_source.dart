import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/base_response.dart';
import '../../models/tag_models.dart';

/// Remote data source for tag-related API calls
class TagRemoteDataSource {
  final DioClient _dioClient;

  // Cache
  List<GenresResponse>? _genresCache;
  final Map<String, Map<String, String>> _tagCache = {};

  TagRemoteDataSource(this._dioClient);

  /// Get genres list
  Future<ApiResult<List<GenresResponse>>> getGenres({
    String? language = 'zh-CN',
    bool force = false,
  }) async {
    // Check cache
    if (!force && _genresCache != null && _genresCache!.isNotEmpty) {
      return Success(_genresCache!);
    }

    final result = await _dioClient.get<List<GenresResponse>>(
      ApiEndpoints.tagGenres,
      queryParameters: language != null ? {'lan': language} : null,
      converter: (data) => _parseGenresResponse(data),
    );

    // Update cache on success
    if (result.isSuccess) {
      final data = result.dataOrNull;
      if (data != null && data.isNotEmpty) {
        _genresCache = data;
      }
    }

    return result;
  }

  /// Get tag map by tag name
  Future<ApiResult<Map<String, String>>> getTag(
    String tag, {
    String? language = 'zh-CN',
    bool force = false,
  }) async {
    // Check cache
    final cached = _tagCache[tag];
    if (!force && cached != null && cached.isNotEmpty) {
      return Success(cached);
    }

    final result = await _dioClient.get<List<QueryTagResponse>>(
      '${ApiEndpoints.tagGenres}/$tag',
      queryParameters: language != null ? {'lan': language} : null,
      converter: (data) => _parseTagResponse(data),
    );

    // Convert to map and update cache on success
    if (result.isSuccess) {
      final data = result.dataOrNull;
      if (data != null && data.isNotEmpty) {
        final dataMap = {for (final item in data) item.key: item.value};
        if (dataMap.isNotEmpty) {
          _tagCache[tag] = dataMap;
        }
        return Success(dataMap);
      }
    }

    // Return the original result converted to map type
    return result.map((data) => {for (final item in data) item.key: item.value});
  }

  /// Get tag list for filtering
  Future<ApiResult<TagListResponse>> getTagList({
    String? ancestorGuid,
    required int isFavorite,
    String? type,
  }) async {
    final result = await _dioClient.get<TagListResponse>(
      ApiEndpoints.tagList,
      queryParameters: {
        if (ancestorGuid != null) 'ancestor_guid': ancestorGuid,
        'is_favorite': isFavorite,
        if (type != null) 'type': type,
      },
      converter: (data) => _parseTagListResponse(data),
    );

    return result;
  }

  // Private parsing methods
  List<GenresResponse> _parseGenresResponse(dynamic data) {
    final baseResponse = FnBaseResponse<List<GenresResponse>>.fromJson(
      data,
      (json) => (json as List)
          .map((e) => GenresResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? [];
  }

  List<QueryTagResponse> _parseTagResponse(dynamic data) {
    final baseResponse = FnBaseResponse<List<QueryTagResponse>>.fromJson(
      data,
      (json) => (json as List)
          .map((e) => QueryTagResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? [];
  }

  TagListResponse _parseTagListResponse(dynamic data) {
    final baseResponse = FnBaseResponse<TagListResponse>.fromJson(
      data,
      (json) => TagListResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? TagListResponse();
  }
}