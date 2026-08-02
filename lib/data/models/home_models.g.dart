// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaDbListResponse _$MediaDbListResponseFromJson(Map<String, dynamic> json) =>
    MediaDbListResponse(
      guid: json['guid'] as String,
      title: json['title'] as String,
      posters: (json['posters'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      category: json['category'] as String,
      viewType: (json['view_type'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MediaDbListResponseToJson(
        MediaDbListResponse instance) =>
    <String, dynamic>{
      'guid': instance.guid,
      'title': instance.title,
      'posters': instance.posters,
      'category': instance.category,
      'view_type': instance.viewType,
    };

MediaStream _$MediaStreamFromJson(Map<String, dynamic> json) => MediaStream(
      resolutions: (json['resolutions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      audioType: json['audio_type'] as String?,
      colorRangeType: json['color_range_type'] as String?,
    );

Map<String, dynamic> _$MediaStreamToJson(MediaStream instance) =>
    <String, dynamic>{
      'resolutions': instance.resolutions,
      'audio_type': instance.audioType,
      'color_range_type': instance.colorRangeType,
    };

MediaItem _$MediaItemFromJson(Map<String, dynamic> json) => MediaItem(
      guid: json['guid'] as String,
      lan: json['lan'] as String?,
      doubanId: (json['douban_id'] as num?)?.toInt(),
      imdbId: json['imdb_id'] as String?,
      title: json['title'] as String,
      type: json['type'] as String?,
      poster: json['poster'] as String?,
      posterWidth: (json['poster_width'] as num?)?.toInt(),
      posterHeight: (json['poster_height'] as num?)?.toInt(),
      isFavorite: (json['is_favorite'] as num?)?.toInt() ?? 0,
      watched: (json['watched'] as num?)?.toInt(),
      voteAverage: json['vote_average'] as String?,
      mediaStream: json['media_stream'] == null
          ? null
          : MediaStream.fromJson(json['media_stream'] as Map<String, dynamic>),
      releaseDate: json['release_date'] as String?,
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
      firstAirDate: json['first_air_date'] as String?,
      lastAirDate: json['last_air_date'] as String?,
      numberOfSeasons: (json['number_of_seasons'] as num?)?.toInt(),
      numberOfEpisodes: (json['number_of_episodes'] as num?)?.toInt(),
      localNumberOfSeasons: (json['local_number_of_seasons'] as num?)?.toInt(),
      localNumberOfEpisodes: (json['local_number_of_episodes'] as num?)?.toInt(),
      status: json['status'] as String?,
      overview: json['overview'] as String?,
      ancestorGuid: json['ancestor_guid'] as String?,
      ancestorName: json['ancestor_name'] as String?,
      ancestorCategory: json['ancestor_category'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      genres: (json['genres'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      numberOfItem: (json['number_of_item'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MediaItemToJson(MediaItem instance) => <String, dynamic>{
      'guid': instance.guid,
      'lan': instance.lan,
      'douban_id': instance.doubanId,
      'imdb_id': instance.imdbId,
      'title': instance.title,
      'type': instance.type,
      'poster': instance.poster,
      'poster_width': instance.posterWidth,
      'poster_height': instance.posterHeight,
      'is_favorite': instance.isFavorite,
      'watched': instance.watched,
      'vote_average': instance.voteAverage,
      'media_stream': instance.mediaStream,
      'release_date': instance.releaseDate,
      'season_number': instance.seasonNumber,
      'episode_number': instance.episodeNumber,
      'first_air_date': instance.firstAirDate,
      'last_air_date': instance.lastAirDate,
      'number_of_seasons': instance.numberOfSeasons,
      'number_of_episodes': instance.numberOfEpisodes,
      'local_number_of_seasons': instance.localNumberOfSeasons,
      'local_number_of_episodes': instance.localNumberOfEpisodes,
      'status': instance.status,
      'overview': instance.overview,
      'ancestor_guid': instance.ancestorGuid,
      'ancestor_name': instance.ancestorName,
      'ancestor_category': instance.ancestorCategory,
      'duration': instance.duration,
      'genres': instance.genres,
      'number_of_item': instance.numberOfItem,
    };

ItemListQueryResponse _$ItemListQueryResponseFromJson(
        Map<String, dynamic> json) =>
    ItemListQueryResponse(
      list: (json['list'] as List<dynamic>?)
              ?.map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      mdbName: json['mdb_name'] as String?,
    );

Map<String, dynamic> _$ItemListQueryResponseToJson(
        ItemListQueryResponse instance) =>
    <String, dynamic>{
      'list': instance.list,
      'total': instance.total,
      'mdb_name': instance.mdbName,
    };

PlayDetailResponse _$PlayDetailResponseFromJson(Map<String, dynamic> json) =>
    PlayDetailResponse(
      guid: json['guid'] as String,
      title: json['title'] as String,
      type: json['type'] as String?,
      poster: json['poster'] as String?,
      isFavorite: (json['is_favorite'] as num?)?.toInt() ?? 0,
      watched: (json['watched'] as num?)?.toInt() ?? 0,
      mediaStream: json['media_stream'] == null
          ? null
          : MediaStream.fromJson(json['media_stream'] as Map<String, dynamic>),
      voteAverage: json['vote_average'] as String?,
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
      tvTitle: json['tv_title'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      ts: (json['ts'] as num?)?.toInt(),
      status: json['status'] as String?,
      parentGuid: json['parent_guid'] as String?,
    );

Map<String, dynamic> _$PlayDetailResponseToJson(PlayDetailResponse instance) =>
    <String, dynamic>{
      'guid': instance.guid,
      'title': instance.title,
      'type': instance.type,
      'poster': instance.poster,
      'is_favorite': instance.isFavorite,
      'watched': instance.watched,
      'media_stream': instance.mediaStream,
      'vote_average': instance.voteAverage,
      'season_number': instance.seasonNumber,
      'episode_number': instance.episodeNumber,
      'tv_title': instance.tvTitle,
      'duration': instance.duration,
      'ts': instance.ts,
      'status': instance.status,
      'parent_guid': instance.parentGuid,
    };

Map<String, dynamic> _$ItemListQueryRequestToJson(
        ItemListQueryRequest instance) =>
    <String, dynamic>{
      'ancestor_guid': instance.ancestorGuid,
      'exclude_grouped_video': instance.excludeGroupedVideo,
      'sort_type': instance.sortType,
      'sort_column': instance.sortColumn,
      'page_size': instance.pageSize,
      'page': instance.page,
      'tags': instance.tags,
    };

Tags _$TagsFromJson(Map<String, dynamic> json) => Tags(
      type: (json['type'] as List<dynamic>).map((e) => e as String).toList(),
      genres: (json['genres'] as num?)?.toInt(),
      resolution: json['resolution'] as String?,
      colorRange: json['color_range'] as String?,
      locate: json['locate'] as String?,
      decade: json['decade'] as String?,
      recognitionStatus: json['recognition_status'] as String?,
      watched: json['watched'] as String?,
      audioType: json['audio_type'] as String?,
    );

Map<String, dynamic> _$TagsToJson(Tags instance) => <String, dynamic>{
      'type': instance.type,
      'genres': instance.genres,
      'resolution': instance.resolution,
      'color_range': instance.colorRange,
      'locate': instance.locate,
      'decade': instance.decade,
      'recognition_status': instance.recognitionStatus,
      'watched': instance.watched,
      'audio_type': instance.audioType,
    };
