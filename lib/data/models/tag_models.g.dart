// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TagListResponse _$TagListResponseFromJson(Map<String, dynamic> json) =>
    TagListResponse(
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      resolutions: (json['resolutions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      colorRange: (json['color_range'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      audioType: (json['audio_type'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      locate: (json['locate'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      decades: (json['decades'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      recognitionStatus: (json['recognition_status'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TagListResponseToJson(TagListResponse instance) =>
    <String, dynamic>{
      'genres': instance.genres,
      'resolutions': instance.resolutions,
      'color_range': instance.colorRange,
      'audio_type': instance.audioType,
      'locate': instance.locate,
      'decades': instance.decades,
      'recognition_status': instance.recognitionStatus,
    };

QueryTagResponse _$QueryTagResponseFromJson(Map<String, dynamic> json) =>
    QueryTagResponse(
      key: json['key'] as String,
      value: json['value'] as String,
    );

Map<String, dynamic> _$QueryTagResponseToJson(QueryTagResponse instance) =>
    <String, dynamic>{
      'key': instance.key,
      'value': instance.value,
    };

GenresResponse _$GenresResponseFromJson(Map<String, dynamic> json) =>
    GenresResponse(
      id: (json['id'] as num?)?.toInt() ?? 0,
      value: json['value'] as String? ?? '',
    );

Map<String, dynamic> _$GenresResponseToJson(GenresResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': instance.value,
    };
