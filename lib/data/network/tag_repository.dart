
import '../models/base_response.dart';
import '../models/tag_models.dart';
import 'dio_client.dart';

class TagRepository {
  final DioClient _dioClient;

  List<GenresResponse>? _genresCache;
  final Map<String, Map<String, String>> _tagCache = {};

  TagRepository(this._dioClient);

  Future<List<GenresResponse>> getGenres({String? lan = 'zh-CN', bool force = false}) async {
    if (!force && _genresCache != null && _genresCache!.isNotEmpty) {
      return _genresCache!;
    }
    final response = await _dioClient.dio.get(
      '/v/api/v1/tag/genres',
      queryParameters: lan == null ? null : {'lan': lan},
    );
    final baseResponse = FnBaseResponse<List<GenresResponse>>.fromJson(
      response.data,
      (json) => (json as List)
          .map((e) => GenresResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (baseResponse.code != 0) throw Exception(baseResponse.msg);
    final data = baseResponse.data ?? [];
    if (data.isNotEmpty) {
      _genresCache = data;
    }
    return data;
  }

  Future<Map<String, String>> getTag(
    String tag, {
    String? lan = 'zh-CN',
    bool force = false,
  }) async {
    final cached = _tagCache[tag];
    if (!force && cached != null && cached.isNotEmpty) {
      return cached;
    }
    final response = await _dioClient.dio.get(
      '/v/api/v1/tag/$tag',
      queryParameters: lan == null ? null : {'lan': lan},
    );
    
    final baseResponse = FnBaseResponse<List<QueryTagResponse>>.fromJson(
      response.data,
      (json) => (json as List)
          .map((e) => QueryTagResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (baseResponse.code != 0) throw Exception(baseResponse.msg);
    final data = baseResponse.data ?? [];
    final dataMap = {for (final item in data) item.key: item.value};
    if (dataMap.isNotEmpty) {
      _tagCache[tag] = dataMap;
    }
    return dataMap;
  }

  Future<TagListResponse> getTagList({
    String? ancestorGuid,
    required int isFavorite,
    String? type,
  }) async {
    final response = await _dioClient.dio.get(
      '/v/api/v1/tag/list',
      queryParameters: {
        if (ancestorGuid != null) 'ancestor_guid': ancestorGuid,
        'is_favorite': isFavorite,
        if (type != null) 'type': type,
      },
    );
    final baseResponse = FnBaseResponse<TagListResponse>.fromJson(
      response.data,
      (json) => TagListResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != 0) throw Exception(baseResponse.msg);
    return baseResponse.data ?? TagListResponse();
  }
}
