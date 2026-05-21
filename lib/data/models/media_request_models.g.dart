// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_request_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$ItemGuidRequestToJson(ItemGuidRequest instance) =>
    <String, dynamic>{
      'item_guid': instance.itemGuid,
    };

Map<String, dynamic> _$PlayRecordRequestToJson(PlayRecordRequest instance) =>
    <String, dynamic>{
      'item_guid': instance.itemGuid,
      'media_guid': instance.mediaGuid,
      'video_guid': instance.videoGuid,
      'audio_guid': instance.audioGuid,
      'subtitle_guid': instance.subtitleGuid,
      'resolution': instance.resolution,
      'bitrate': instance.bitrate,
      'ts': instance.ts,
      'duration': instance.duration,
      'play_link': instance.playLink,
    };

Map<String, dynamic> _$MediaLibraryBrowseRequestToJson(
        MediaLibraryBrowseRequest instance) =>
    <String, dynamic>{
      'ancestor_guid': instance.ancestorGuid,
      'page_size': instance.pageSize,
      'page': instance.page,
      'sort_column': instance.sortColumn,
      'sort_type': instance.sortType,
    };
