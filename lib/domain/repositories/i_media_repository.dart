import '../../core/network/api_result.dart';
import '../entities/index.dart';

/// Query parameters for item list
class ItemListQueryParams {
  final String? ancestorGuid;
  final List<String> types;
  final int? genres;
  final String? resolution;
  final String? colorRange;
  final String? locate;
  final String? decade;
  final String? recognitionStatus;
  final String? watched;
  final String? audioType;
  final int page;
  final int pageSize;
  final String sortType;
  final String sortColumn;

  const ItemListQueryParams({
    this.ancestorGuid,
    this.types = const ['Movie', 'TV', 'Directory', 'Video'],
    this.genres,
    this.resolution,
    this.colorRange,
    this.locate,
    this.decade,
    this.recognitionStatus,
    this.watched,
    this.audioType,
    this.page = 1,
    this.pageSize = 22,
    this.sortType = 'DESC',
    this.sortColumn = 'create_time',
  });

  ItemListQueryParams copyWith({
    String? ancestorGuid,
    List<String>? types,
    int? genres,
    String? resolution,
    String? colorRange,
    String? locate,
    String? decade,
    String? recognitionStatus,
    String? watched,
    String? audioType,
    int? page,
    int? pageSize,
    String? sortType,
    String? sortColumn,
  }) {
    return ItemListQueryParams(
      ancestorGuid: ancestorGuid ?? this.ancestorGuid,
      types: types ?? this.types,
      genres: genres ?? this.genres,
      resolution: resolution ?? this.resolution,
      colorRange: colorRange ?? this.colorRange,
      locate: locate ?? this.locate,
      decade: decade ?? this.decade,
      recognitionStatus: recognitionStatus ?? this.recognitionStatus,
      watched: watched ?? this.watched,
      audioType: audioType ?? this.audioType,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      sortType: sortType ?? this.sortType,
      sortColumn: sortColumn ?? this.sortColumn,
    );
  }
}

/// Media repository interface
abstract class IMediaRepository {
  /// Get list of media databases
  Future<ApiResult<List<MediaLibraryEntity>>> getMediaDbList();

  /// Get media statistics summary
  Future<ApiResult<Map<String, int>>> getMediaSum();

  /// Get play list (recently watched)
  Future<ApiResult<List<PlayDetailEntity>>> getPlayList();

  /// Get item list by query
  Future<ApiResult<ItemListEntity>> getItemList(ItemListQueryParams params);

  /// Toggle favorite status
  Future<ApiResult<ActionResult>> toggleFavorite(String guid, bool currentFavoriteState);

  /// Toggle watched status
  Future<ApiResult<ActionResult>> toggleWatched(String guid, bool currentWatchedState);
}