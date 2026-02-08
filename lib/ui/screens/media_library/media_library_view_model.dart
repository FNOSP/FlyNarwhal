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
    final query = _buildQuery(guid, page);
    final endpoint = _resolveEndpoint(guid);

    final response = await dioClient.dio.post(
      endpoint,
      data: query.toJson(),
    );
    
    final baseResponse = FnBaseResponse<ItemListQueryResponse>.fromJson(
        response.data,
        (json) => ItemListQueryResponse.fromJson(json as Map<String, dynamic>)
    );
    
    if (baseResponse.code != 0) throw Exception(baseResponse.msg);
    return baseResponse.data ?? ItemListQueryResponse();
  }

  ItemListQueryRequest _buildQuery(String guid, int page) {
    if (guid.startsWith('category:')) {
      final category = guid.substring('category:'.length);
      final types = _categoryTypes(category);
      return ItemListQueryRequest(
        tags: Tags(type: types),
        page: page,
        pageSize: 50,
      );
    }
    if (guid == 'favorite') {
      return ItemListQueryRequest(
        tags: Tags(type: ["Movie", "TV", "Directory", "Video"]),
        page: page,
        pageSize: 50,
      );
    }
    return ItemListQueryRequest(
      ancestorGuid: guid,
      tags: Tags(type: ["Movie", "TV", "Directory", "Video"]),
      page: page,
      pageSize: 50,
    );
  }

  String _resolveEndpoint(String guid) {
    if (guid == 'favorite') {
      return '/v/api/v1/favorite/list';
    }
    return '/v/api/v1/item/list';
  }

  List<String> _categoryTypes(String category) {
    switch (category) {
      case 'movie':
        return ["Movie"];
      case 'tv':
        return ["TV"];
      case 'video':
        return ["Video"];
      case 'total':
      default:
        return ["Movie", "TV", "Directory", "Video"];
    }
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
