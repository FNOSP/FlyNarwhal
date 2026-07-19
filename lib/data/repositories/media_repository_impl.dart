import '../../core/network/api_result.dart';
import '../../domain/entities/index.dart';
import '../../domain/repositories/i_media_repository.dart';
import '../datasources/remote/media_remote_data_source.dart';
import '../mappers/media_mapper.dart';
import '../models/home_models.dart';

/// Implementation of IMediaRepository
class MediaRepositoryImpl implements IMediaRepository {
  final MediaRemoteDataSource _remoteDataSource;

  MediaRepositoryImpl(this._remoteDataSource);

  @override
  Future<ApiResult<List<MediaLibraryEntity>>> getMediaDbList() async {
    final result = await _remoteDataSource.getMediaDbList();
    return result.map((data) => MediaMapper.toLibraryEntityList(data));
  }

  @override
  Future<ApiResult<Map<String, int>>> getMediaSum() async {
    return _remoteDataSource.getMediaSum();
  }

  @override
  Future<ApiResult<List<PlayDetailEntity>>> getPlayList() async {
    final result = await _remoteDataSource.getPlayList();
    return result.map((data) => MediaMapper.toPlayDetailEntityList(data));
  }

  @override
  Future<ApiResult<ItemListEntity>> getItemList(ItemListQueryParams params) async {
    // Convert params to request model
    final request = ItemListQueryRequest(
      ancestorGuid: params.ancestorGuid,
      tags: Tags(
        type: params.types,
        genres: params.genres,
        resolution: params.resolution,
        colorRange: params.colorRange,
        locate: params.locate,
        decade: params.decade,
        recognitionStatus: params.recognitionStatus,
        watched: params.watched,
        audioType: params.audioType,
      ),
      page: params.page,
      pageSize: params.pageSize,
      sortType: params.sortType,
      sortColumn: params.sortColumn,
    );

    final result = await _remoteDataSource.getItemList(request);
    return result.map((data) => MediaMapper.toItemListEntity(data));
  }

  @override
  Future<ApiResult<ActionResult>> toggleFavorite(
    String guid,
    bool currentFavoriteState,
  ) async {
    final result = currentFavoriteState
        ? await _remoteDataSource.removeFavorite(guid)
        : await _remoteDataSource.addFavorite(guid);

    return result.map((success) => ActionResult(
      guid: guid,
      success: success,
      message: currentFavoriteState ? '已取消收藏' : '已收藏',
      previousState: currentFavoriteState,
    ));
  }

  @override
  Future<ApiResult<ActionResult>> toggleWatched(
    String guid,
    bool currentWatchedState,
  ) async {
    final result = currentWatchedState
        ? await _remoteDataSource.markUnwatched(guid)
        : await _remoteDataSource.markWatched(guid);

    return result.map((success) => ActionResult(
      guid: guid,
      success: success,
      message: currentWatchedState ? '标记为未观看' : '标记为已观看',
      previousState: currentWatchedState,
    ));
  }
}