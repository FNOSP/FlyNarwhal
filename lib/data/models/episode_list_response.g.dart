// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EpisodeListResponse _$EpisodeListResponseFromJson(Map<String, dynamic> json) =>
    EpisodeListResponse(
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
      posterWidth: (json['poster_width'] as num?)?.toInt(),
      posterHeight: (json['poster_height'] as num?)?.toInt(),
      runtime: (json['runtime'] as num?)?.toInt(),
      isFavorite: (json['is_favorite'] as num?)?.toInt() ?? 0,
      watched: (json['watched'] as num?)?.toInt() ?? 0,
      watchedTs: (json['watched_ts'] as num?)?.toInt() ?? 0,
      voteAverage: json['vote_average'] as String? ?? '',
      mediaStream:
          MediaStream.fromJson(json['media_stream'] as Map<String, dynamic>),
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
      airDate: json['air_date'] as String?,
      numberOfSeasons: (json['number_of_seasons'] as num?)?.toInt() ?? 0,
      numberOfEpisodes: (json['number_of_episodes'] as num?)?.toInt() ?? 0,
      localNumberOfSeasons:
          (json['local_number_of_seasons'] as num?)?.toInt() ?? 0,
      localNumberOfEpisodes:
          (json['local_number_of_episodes'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      overview: json['overview'] as String?,
      ancestorGuid: json['ancestor_guid'] as String? ?? '',
      ancestorName: json['ancestor_name'] as String? ?? '',
      ancestorCategory: json['ancestor_category'] as String? ?? '',
      ts: (json['ts'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      singleChildGuid: json['single_child_guid'] as String? ?? '',
      videoGuid: json['video_guid'] as String?,
      fileName: json['file_name'] as String? ?? '',
    );

Map<String, dynamic> _$EpisodeListResponseToJson(
        EpisodeListResponse instance) =>
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
      'runtime': instance.runtime,
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
      'local_number_of_seasons': instance.localNumberOfSeasons,
      'local_number_of_episodes': instance.localNumberOfEpisodes,
      'status': instance.status,
      'overview': instance.overview,
      'ancestor_guid': instance.ancestorGuid,
      'ancestor_name': instance.ancestorName,
      'ancestor_category': instance.ancestorCategory,
      'ts': instance.ts,
      'duration': instance.duration,
      'single_child_guid': instance.singleChildGuid,
      'video_guid': instance.videoGuid,
      'file_name': instance.fileName,
    };
