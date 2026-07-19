import '../../core/network/api_result.dart';
import '../entities/index.dart';
import '../repositories/i_media_repository.dart';

/// Base use case interface
abstract class UseCase<T, Params> {
  Future<ApiResult<T>> call(Params params);
}

/// Use case for getting media database list
class GetMediaDbListUseCase implements UseCase<List<MediaLibraryEntity>, void> {
  final IMediaRepository _repository;

  GetMediaDbListUseCase(this._repository);

  @override
  Future<ApiResult<List<MediaLibraryEntity>>> call([void _]) {
    return _repository.getMediaDbList();
  }
}

/// Use case for getting media sum statistics
class GetMediaSumUseCase implements UseCase<Map<String, int>, void> {
  final IMediaRepository _repository;

  GetMediaSumUseCase(this._repository);

  @override
  Future<ApiResult<Map<String, int>>> call([void _]) {
    return _repository.getMediaSum();
  }
}

/// Use case for getting play list
class GetPlayListUseCase implements UseCase<List<PlayDetailEntity>, void> {
  final IMediaRepository _repository;

  GetPlayListUseCase(this._repository);

  @override
  Future<ApiResult<List<PlayDetailEntity>>> call([void _]) {
    return _repository.getPlayList();
  }
}

/// Parameters for item list query
class ItemListParams {
  final ItemListQueryParams query;

  const ItemListParams(this.query);
}

/// Use case for getting item list
class GetItemListUseCase implements UseCase<ItemListEntity, ItemListParams> {
  final IMediaRepository _repository;

  GetItemListUseCase(this._repository);

  @override
  Future<ApiResult<ItemListEntity>> call(ItemListParams params) {
    return _repository.getItemList(params.query);
  }
}

/// Parameters for toggle favorite
class ToggleFavoriteParams {
  final String guid;
  final bool currentState;

  const ToggleFavoriteParams({
    required this.guid,
    required this.currentState,
  });
}

/// Use case for toggling favorite
class ToggleFavoriteUseCase implements UseCase<ActionResult, ToggleFavoriteParams> {
  final IMediaRepository _repository;

  ToggleFavoriteUseCase(this._repository);

  @override
  Future<ApiResult<ActionResult>> call(ToggleFavoriteParams params) {
    return _repository.toggleFavorite(params.guid, params.currentState);
  }
}

/// Parameters for toggle watched
class ToggleWatchedParams {
  final String guid;
  final bool currentState;

  const ToggleWatchedParams({
    required this.guid,
    required this.currentState,
  });
}

/// Use case for toggling watched status
class ToggleWatchedUseCase implements UseCase<ActionResult, ToggleWatchedParams> {
  final IMediaRepository _repository;

  ToggleWatchedUseCase(this._repository);

  @override
  Future<ApiResult<ActionResult>> call(ToggleWatchedParams params) {
    return _repository.toggleWatched(params.guid, params.currentState);
  }
}