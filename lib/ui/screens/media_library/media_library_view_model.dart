import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/base_response.dart';
import '../../../data/models/home_models.dart';
import '../../../providers/providers.dart';

part 'media_library_view_model.g.dart';

@riverpod
class MediaLibraryNotifier extends _$MediaLibraryNotifier {
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  FutureOr<ItemListQueryResponse> build(String guid) async {
    _page = 1;
    _hasMore = true;
    return _fetch(guid, page: 1);
  }

  Future<ItemListQueryResponse> _fetch(String guid, {required int page}) async {
    final dioClient = ref.read(dioClientProvider);
    
    final request = ItemListQueryRequest(
      ancestorGuid: guid,
      tags: Tags(type: ["Movie", "TV", "Directory", "Video"]),
      page: page,
      pageSize: 50,
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

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || state.value == null) return;
    
    _isLoadingMore = true;
    try {
      final nextPage = _page + 1;
      final newData = await _fetch(guid, page: nextPage);
      
      if (newData.list.isEmpty) {
        _hasMore = false;
      } else {
        _page = nextPage;
        final currentData = state.value!;
        state = AsyncValue.data(ItemListQueryResponse(
          list: [...currentData.list, ...newData.list],
          total: newData.total,
          mdbName: newData.mdbName,
        ));
      }
    } catch (e) {
      // Handle error (maybe show toast)
    } finally {
      _isLoadingMore = false;
    }
  }
}
