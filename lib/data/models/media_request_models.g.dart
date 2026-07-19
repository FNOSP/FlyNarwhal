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
      'device_id': instance.deviceId,
      'direct_link_audio_index': instance.directLinkAudioIndex,
      'lan': instance.lan,
      'device_name': instance.deviceName,
    };
