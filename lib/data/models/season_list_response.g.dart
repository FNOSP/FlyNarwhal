// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'season_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

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

SeasonListResponse _$SeasonListResponseFromJson(Map<String, dynamic> json) =>
    SeasonListResponse(
      guid: json['guid'] as String,
      lan: json['lan'] as String,
      imdbId: json['imdb_id'] as String?,
      trimId: json['trim_id'] as String,
      tvTitle: json['tv_title'] as String,
      parentGuid: json['parent_guid'] as String,
      parentTitle: json['parent_title'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      poster: json['poster'] as String?,
      posterWidth: (json['poster_width'] as num).toInt(),
      posterHeight: (json['poster_height'] as num).toInt(),
      isFavorite: (json['is_favorite'] as num).toInt(),
      watched: (json['watched'] as num).toInt(),
      watchedTs: (json['watched_ts'] as num).toInt(),
      voteAverage: json['vote_average'] as String,
      mediaStream:
          MediaStream.fromJson(json['media_stream'] as Map<String, dynamic>),
      seasonNumber: (json['season_number'] as num).toInt(),
      episodeNumber: (json['episode_number'] as num).toInt(),
      airDate: json['air_date'] as String?,
      numberOfSeasons: (json['number_of_seasons'] as num).toInt(),
      numberOfEpisodes: (json['number_of_episodes'] as num).toInt(),
      localNumberOfEpisodes: (json['local_number_of_episodes'] as num).toInt(),
      localNumberOfSeasons: (json['local_number_of_seasons'] as num).toInt(),
      status: json['status'] as String,
      overview: json['overview'] as String?,
      ancestorGuid: json['ancestor_guid'] as String,
      ancestorName: json['ancestor_name'] as String,
      ancestorCategory: json['ancestor_category'] as String,
      ts: (json['ts'] as num).toInt(),
      duration: (json['duration'] as num).toInt(),
      singleChildGuid: json['single_child_guid'] as String,
      fileName: json['file_name'] as String,
    );

Map<String, dynamic> _$SeasonListResponseToJson(SeasonListResponse instance) =>
    <String, dynamic>{
      'guid': instance.guid,
      'lan': instance.lan,
      'imdb_id': instance.imdbId,
      'trim_id': instance.trimId,
      'tv_title': instance.tvTitle,
      'parent_guid': instance.parentGuid,
      'parent_title': instance.parentTitle,
      'title': instance.title,
      'type': instance.type,
      'poster': instance.poster,
      'poster_width': instance.posterWidth,
      'poster_height': instance.posterHeight,
      'is_favorite': instance.isFavorite,
      'watched': instance.watched,
      'watched_ts': instance.watchedTs,
      'vote_average': instance.voteAverage,
      'media_stream': instance.mediaStream,
      'season_number': instance.seasonNumber,
      'episode_number': instance.episodeNumber,
      'air_date': instance.airDate,
      'number_of_seasons': instance.numberOfSeasons,
      'number_of_episodes': instance.numberOfEpisodes,
      'local_number_of_episodes': instance.localNumberOfEpisodes,
      'local_number_of_seasons': instance.localNumberOfSeasons,
      'status': instance.status,
      'overview': instance.overview,
      'ancestor_guid': instance.ancestorGuid,
      'ancestor_name': instance.ancestorName,
      'ancestor_category': instance.ancestorCategory,
      'ts': instance.ts,
      'duration': instance.duration,
      'single_child_guid': instance.singleChildGuid,
      'file_name': instance.fileName,
    };
