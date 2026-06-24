// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PersonResponse _$PersonResponseFromJson(Map<String, dynamic> json) =>
    PersonResponse(
      guid: json['guid'] as String,
      name: json['name'] as String,
      imdbId: json['imdb_id'] as String?,
      originalName: json['original_name'] as String?,
      profile: json['profile'] as String?,
      biography: json['biography'] as String?,
      isFavorite: (json['is_favorite'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PersonResponseToJson(PersonResponse instance) =>
    <String, dynamic>{
      'guid': instance.guid,
      'name': instance.name,
      'imdb_id': instance.imdbId,
      'original_name': instance.originalName,
      'profile': instance.profile,
      'biography': instance.biography,
      'is_favorite': instance.isFavorite,
    };

PersonItemList _$PersonItemListFromJson(Map<String, dynamic> json) =>
    PersonItemList(
      guid: json['guid'] as String,
      title: json['title'] as String,
      poster: json['poster'] as String?,
      posterWidth: (json['poster_width'] as num?)?.toInt(),
      posterHeight: (json['poster_height'] as num?)?.toInt(),
      releaseDate: json['release_date'] as String?,
      voteAverage: json['vote_average'] as String?,
      isFavorite: (json['is_favorite'] as num?)?.toInt() ?? 0,
      watched: (json['watched'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt(),
      status: json['status'] as String?,
      type: json['type'] as String?,
      mediaStream: json['media_stream'] == null
          ? null
          : MediaStream.fromJson(json['media_stream'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PersonItemListToJson(PersonItemList instance) =>
    <String, dynamic>{
      'guid': instance.guid,
      'title': instance.title,
      'poster': instance.poster,
      'poster_width': instance.posterWidth,
      'poster_height': instance.posterHeight,
      'release_date': instance.releaseDate,
      'vote_average': instance.voteAverage,
      'is_favorite': instance.isFavorite,
      'watched': instance.watched,
      'duration': instance.duration,
      'status': instance.status,
      'type': instance.type,
      'media_stream': instance.mediaStream,
    };

PersonItemListQueryResponse _$PersonItemListQueryResponseFromJson(
        Map<String, dynamic> json) =>
    PersonItemListQueryResponse(
      list: (json['list'] as List<dynamic>?)
              ?.map((e) => PersonItemList.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PersonItemListQueryResponseToJson(
        PersonItemListQueryResponse instance) =>
    <String, dynamic>{
      'list': instance.list,
      'total': instance.total,
    };

Map<String, dynamic> _$PersonItemListRequestToJson(
        PersonItemListRequest instance) =>
    <String, dynamic>{
      'person_guid': instance.personGuid,
      'page': instance.page,
      'page_size': instance.pageSize,
      'job': instance.job,
      'sort_column': instance.sortColumn,
      'sort_type': instance.sortType,
    };
