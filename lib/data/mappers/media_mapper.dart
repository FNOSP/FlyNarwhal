import '../../domain/entities/index.dart';
import '../models/home_models.dart';

/// Mapper for converting media models to entities
class MediaMapper {
  const MediaMapper._();

  /// Convert MediaItem model to MediaEntity
  static MediaEntity toEntity(MediaItem model) {
    return MediaEntity(
      guid: model.guid,
      language: model.lan,
      doubanId: model.doubanId,
      imdbId: model.imdbId,
      title: model.title,
      type: MediaType.fromString(model.type),
      poster: model.poster,
      posterWidth: model.posterWidth,
      posterHeight: model.posterHeight,
      isFavorite: model.isFavorite == 1,
      isWatched: model.watched == 1,
      voteAverage: model.voteAverage,
      mediaStream: model.mediaStream != null
          ? _mapMediaStream(model.mediaStream!)
          : null,
      releaseDate: model.releaseDate,
      seasonNumber: model.seasonNumber,
      episodeNumber: model.episodeNumber,
      firstAirDate: model.firstAirDate,
      lastAirDate: model.lastAirDate,
      numberOfSeasons: model.numberOfSeasons,
      numberOfEpisodes: model.numberOfEpisodes,
      status: model.status,
      overview: model.overview,
      ancestorGuid: model.ancestorGuid,
      ancestorName: model.ancestorName,
      ancestorCategory: model.ancestorCategory,
      duration: model.duration,
    );
  }

  /// Convert MediaDbListResponse model to MediaLibraryEntity
  static MediaLibraryEntity toLibraryEntity(MediaDbListResponse model) {
    return MediaLibraryEntity(
      guid: model.guid,
      title: model.title,
      posters: model.posters,
      category: model.category,
      viewType: model.viewType,
    );
  }

  /// Convert PlayDetailResponse model to PlayDetailEntity
  static PlayDetailEntity toPlayDetailEntity(PlayDetailResponse model) {
    return PlayDetailEntity(
      guid: model.guid,
      title: model.title,
      type: MediaType.fromString(model.type),
      poster: model.poster,
      isFavorite: model.isFavorite == 1,
      isWatched: model.watched == 1,
      mediaStream: model.mediaStream != null
          ? _mapMediaStream(model.mediaStream!)
          : null,
      voteAverage: model.voteAverage,
      seasonNumber: model.seasonNumber,
      episodeNumber: model.episodeNumber,
      tvTitle: model.tvTitle,
      duration: model.duration,
      timestamp: model.ts,
      status: model.status,
      parentGuid: model.parentGuid,
    );
  }

  /// Convert ItemListQueryResponse model to ItemListEntity
  static ItemListEntity toItemListEntity(ItemListQueryResponse model) {
    return ItemListEntity(
      items: model.list.map(toEntity).toList(),
      total: model.total,
      mediaDbName: model.mdbName,
    );
  }

  /// Convert list of MediaItem models to list of MediaEntity
  static List<MediaEntity> toEntityList(List<MediaItem> models) {
    return models.map(toEntity).toList();
  }

  /// Convert list of MediaDbListResponse models to list of MediaLibraryEntity
  static List<MediaLibraryEntity> toLibraryEntityList(
    List<MediaDbListResponse> models,
  ) {
    return models.map(toLibraryEntity).toList();
  }

  /// Convert list of PlayDetailResponse models to list of PlayDetailEntity
  static List<PlayDetailEntity> toPlayDetailEntityList(
    List<PlayDetailResponse> models,
  ) {
    return models.map(toPlayDetailEntity).toList();
  }

  static MediaStreamEntity _mapMediaStream(MediaStream stream) {
    return MediaStreamEntity(
      resolutions: stream.resolutions,
      audioType: stream.audioType,
      colorRangeType: stream.colorRangeType,
    );
  }
}