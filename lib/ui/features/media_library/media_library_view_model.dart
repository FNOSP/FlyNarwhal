import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../domain/entities/media_type.dart';
import '../../../data/models/home_models.dart';
import '../../../data/models/media_request_models.dart';
import '../../../providers/providers.dart';

part 'media_library_view_model.g.dart';

class MediaLibraryState {
  final List<MediaItem> items;
  final int total;
  final String? mdbName;
  final bool hasMore;
  final bool isLoadingMore;

  const MediaLibraryState({
    this.items = const [],
    this.total = 0,
    this.mdbName,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  MediaLibraryState copyWith({
    List<MediaItem>? items,
    int? total,
    String? mdbName,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return MediaLibraryState(
      items: items ?? this.items,
      total: total ?? this.total,
      mdbName: mdbName ?? this.mdbName,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

@riverpod
class MediaLibraryNotifier extends _$MediaLibraryNotifier {
  MediaLibraryBrowseRequest? _currentRequest;

  @override
  FutureOr<MediaLibraryState> build(String guid) async {
    final request = _initialRequestFromGuid(guid);
    _currentRequest = request;
    return _fetch(request);
  }

  Future<void> refreshWithQuery(MediaLibraryBrowseRequest request) async {
    _currentRequest = request.copyWith(page: 1);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(_currentRequest!));
  }

  Future<void> loadMore() async {
    final currentState = state.value;
    final currentRequest = _currentRequest;
    if (currentState == null ||
        currentRequest == null ||
        currentState.isLoadingMore ||
        !currentState.hasMore) {
      return;
    }

    state = AsyncValue.data(currentState.copyWith(isLoadingMore: true));
    try {
      final nextRequest =
          currentRequest.copyWith(page: currentRequest.page + 1);
      final nextState = await _fetch(nextRequest);
      _currentRequest = nextRequest;
      state = AsyncValue.data(MediaLibraryState(
        items: [...currentState.items, ...nextState.items],
        total: nextState.total,
        mdbName: nextState.mdbName ?? currentState.mdbName,
        hasMore: nextState.hasMore,
        isLoadingMore: false,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      state = AsyncValue.data(currentState.copyWith(isLoadingMore: false));
    }
  }

  MediaLibraryBrowseRequest _initialRequestFromGuid(String guid) {
    if (guid.startsWith('category:')) {
      final category = guid.substring('category:'.length);
      return MediaLibraryBrowseRequest(
        categoryType: category,
        tags: Tags(type: _categoryTypes(category)),
      );
    }

    if (guid == 'favorite') {
      return MediaLibraryBrowseRequest(
        favoriteOnly: true,
        tags: Tags(type: MediaType.libraryBrowseValues),
      );
    }

    return MediaLibraryBrowseRequest(
      ancestorGuid: guid,
      tags: Tags(type: MediaType.libraryBrowseValues),
    );
  }

  Future<MediaLibraryState> _fetch(MediaLibraryBrowseRequest request) async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    final query = request.toItemListQueryRequest();
    final result = request.favoriteOnly
        ? await remote.getFavoriteList(query)
        : await remote.getItemList(query);
    final data = result.getOrThrow();
    final resolvedMdbName =
        data.mdbName != null && data.mdbName!.trim().isNotEmpty
            ? data.mdbName
            : null;

    return MediaLibraryState(
      items: data.list,
      total: data.total,
      mdbName: request.ancestorGuid != null ? resolvedMdbName : null,
      hasMore: data.list.length >= query.pageSize,
      isLoadingMore: false,
    );
  }

  List<String> _categoryTypes(String category) {
    switch (category) {
      case 'movie':
        return ["Movie"];
      case 'tv':
        return ["TV"];
      case 'video':
        return ["Video"];
      case 'live':
        return ["LiveChannel"];
      case 'total':
      default:
        return ["Movie", "TV", "Directory", "Video"];
    }
  }
}
