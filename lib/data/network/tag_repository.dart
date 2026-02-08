import '../models/base_response.dart';
import '../models/tag_models.dart';
import 'dio_client.dart';

class TagRepository {
  final DioClient _dioClient;

  List<GenresResponse>? _genresCache;
  final Map<String, List<QueryTagResponse>> _tagCache = {};

  TagRepository(this._dioClient);

  Future<List<GenresResponse>> getGenres({String? lan, bool force = false}) async {
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

  Future<List<QueryTagResponse>> getTag(
    String tag, {
    String? lan,
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
    if (data.isNotEmpty) {
      _tagCache[tag] = data;
    }
    return data;
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
