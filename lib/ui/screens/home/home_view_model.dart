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
