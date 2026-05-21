// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CloudStorageInfo _$CloudStorageInfoFromJson(Map<String, dynamic> json) =>
    CloudStorageInfo(
      davUsername: json['dav_username'] as String?,
      valid: json['valid'] as bool?,
      disabled: json['disabled'] as bool?,
      cloudStorageType: (json['cloud_storage_type'] as num?)?.toInt(),
      cloudNickName: json['cloud_nick_name'] as String?,
      fssize: (json['fssize'] as num?)?.toInt(),
      frsize: (json['frsize'] as num?)?.toInt(),
      fusize: (json['fusize'] as num?)?.toInt(),
      isVip: json['is_vip'] as bool?,
      quarkVipType: json['quark_vip_type'] as String?,
      quarkPcPayLink: json['quark_pc_pay_link'] as String?,
      quarkWapPayLink: json['quark_wap_pay_link'] as String?,
    );

Map<String, dynamic> _$CloudStorageInfoToJson(CloudStorageInfo instance) =>
    <String, dynamic>{
      'dav_username': instance.davUsername,
      'valid': instance.valid,
      'disabled': instance.disabled,
      'cloud_storage_type': instance.cloudStorageType,
      'cloud_nick_name': instance.cloudNickName,
      'fssize': instance.fssize,
      'frsize': instance.frsize,
      'fusize': instance.fusize,
      'is_vip': instance.isVip,
      'quark_vip_type': instance.quarkVipType,
      'quark_pc_pay_link': instance.quarkPcPayLink,
      'quark_wap_pay_link': instance.quarkWapPayLink,
    };

StreamResponse _$StreamResponseFromJson(Map<String, dynamic> json) =>
    StreamResponse(
      videoStream: json['video_stream'] == null
          ? null
          : VideoStream.fromJson(json['video_stream'] as Map<String, dynamic>),
      audioStreams: (json['audio_streams'] as List<dynamic>?)
          ?.map((e) => AudioStream.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtitleStreams: (json['subtitle_streams'] as List<dynamic>?)
          ?.map((e) => SubtitleStream.fromJson(e as Map<String, dynamic>))
          .toList(),
      fileStream: json['file_stream'] == null
          ? null
          : FileInfo.fromJson(json['file_stream'] as Map<String, dynamic>),
      qualities: (json['qualities'] as List<dynamic>?)
          ?.map((e) => QualityResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      cloudStorageInfo: json['cloud_storage_info'] == null
          ? null
          : CloudStorageInfo.fromJson(
              json['cloud_storage_info'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$StreamResponseToJson(StreamResponse instance) =>
    <String, dynamic>{
      'video_stream': instance.videoStream,
      'audio_streams': instance.audioStreams,
      'subtitle_streams': instance.subtitleStreams,
      'file_stream': instance.fileStream,
      'qualities': instance.qualities,
      'cloud_storage_info': instance.cloudStorageInfo,
    };

QualityResponse _$QualityResponseFromJson(Map<String, dynamic> json) =>
    QualityResponse(
      bitrate: (json['bitrate'] as num).toInt(),
      resolution: json['resolution'] as String,
      progressive: json['progressive'] as bool? ?? false,
      isM3u8: json['is_m3u8'] as bool? ?? false,
    );

Map<String, dynamic> _$QualityResponseToJson(QualityResponse instance) =>
    <String, dynamic>{
      'bitrate': instance.bitrate,
      'resolution': instance.resolution,
      'progressive': instance.progressive,
      'is_m3u8': instance.isM3u8,
    };

SubtitleSettings _$SubtitleSettingsFromJson(Map<String, dynamic> json) =>
    SubtitleSettings(
      offsetSeconds: (json['offsetSeconds'] as num?)?.toDouble() ?? 0,
      verticalPosition: (json['verticalPosition'] as num?)?.toDouble() ?? 0.1,
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24.0,
      fontColor: json['fontColor'] as String? ?? '#FFFFFF',
      backgroundColor: json['backgroundColor'] as String? ?? '#000000',
    );

Map<String, dynamic> _$SubtitleSettingsToJson(SubtitleSettings instance) =>
    <String, dynamic>{
      'offsetSeconds': instance.offsetSeconds,
      'verticalPosition': instance.verticalPosition,
      'fontScale': instance.fontScale,
      'fontSize': instance.fontSize,
      'fontColor': instance.fontColor,
      'backgroundColor': instance.backgroundColor,
    };

PlayPlayResponse _$PlayPlayResponseFromJson(Map<String, dynamic> json) =>
    PlayPlayResponse(
      playLink: json['play_link'] as String,
    );

Map<String, dynamic> _$PlayPlayResponseToJson(PlayPlayResponse instance) =>
    <String, dynamic>{
      'play_link': instance.playLink,
    };

MediaTranscodeAudio _$MediaTranscodeAudioFromJson(Map<String, dynamic> json) =>
    MediaTranscodeAudio(
      channels: (json['channels'] as num).toInt(),
      encoder: json['encoder'] as String,
    );

Map<String, dynamic> _$MediaTranscodeAudioToJson(
        MediaTranscodeAudio instance) =>
    <String, dynamic>{
      'channels': instance.channels,
      'encoder': instance.encoder,
    };

MediaTranscodeVideo _$MediaTranscodeVideoFromJson(Map<String, dynamic> json) =>
    MediaTranscodeVideo(
      corruptedFrames: (json['corruptedFrames'] as num).toInt(),
      decodeMethod: (json['decodeMethod'] as num).toInt(),
      droppedFrames: (json['droppedFrames'] as num).toInt(),
      dynamicRange: json['dynamicRange'] as String,
      encodeMethod: (json['encodeMethod'] as num).toInt(),
      encoder: json['encoder'] as String,
      selectedGpu: json['selectedGpu'] as String,
      transcodingRate: json['transcodingRate'] as String,
    );

Map<String, dynamic> _$MediaTranscodeVideoToJson(
        MediaTranscodeVideo instance) =>
    <String, dynamic>{
      'corruptedFrames': instance.corruptedFrames,
      'decodeMethod': instance.decodeMethod,
      'droppedFrames': instance.droppedFrames,
      'dynamicRange': instance.dynamicRange,
      'encodeMethod': instance.encodeMethod,
      'encoder': instance.encoder,
      'selectedGpu': instance.selectedGpu,
      'transcodingRate': instance.transcodingRate,
    };

MediaTranscodeResponse _$MediaTranscodeResponseFromJson(
        Map<String, dynamic> json) =>
    MediaTranscodeResponse(
      audio:
          MediaTranscodeAudio.fromJson(json['audio'] as Map<String, dynamic>),
      bitrate: (json['bitrate'] as num).toInt(),
      reqId: json['reqid'] as String,
      resolution: json['resolution'] as String,
      result: json['result'] as String,
      transcoded: json['transcoded'] as bool,
      transcodingReason: (json['transcodingReason'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      video:
          MediaTranscodeVideo.fromJson(json['video'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MediaTranscodeResponseToJson(
        MediaTranscodeResponse instance) =>
    <String, dynamic>{
      'audio': instance.audio,
      'bitrate': instance.bitrate,
      'reqid': instance.reqId,
      'resolution': instance.resolution,
      'result': instance.result,
      'transcoded': instance.transcoded,
      'transcodingReason': instance.transcodingReason,
      'video': instance.video,
    };

MediaResetQualityResponse _$MediaResetQualityResponseFromJson(
        Map<String, dynamic> json) =>
    MediaResetQualityResponse(
      hlsTime: (json['hlsTime'] as num).toInt(),
      reqId: json['reqid'] as String,
      result: json['result'] as String,
      updateM3u8: json['updateM3u8'] as bool,
    );

Map<String, dynamic> _$MediaResetQualityResponseToJson(
        MediaResetQualityResponse instance) =>
    <String, dynamic>{
      'hlsTime': instance.hlsTime,
      'reqid': instance.reqId,
      'result': instance.result,
      'updateM3u8': instance.updateM3u8,
    };

SetConfigByItemRequest _$SetConfigByItemRequestFromJson(
        Map<String, dynamic> json) =>
    SetConfigByItemRequest(
      guid: json['guid'] as String,
      skipOpening: (json['skip_opening'] as num).toInt(),
      skipEnding: (json['skip_ending'] as num).toInt(),
    );

Map<String, dynamic> _$SetConfigByItemRequestToJson(
        SetConfigByItemRequest instance) =>
    <String, dynamic>{
      'guid': instance.guid,
      'skip_opening': instance.skipOpening,
      'skip_ending': instance.skipEnding,
    };

StreamRequest _$StreamRequestFromJson(Map<String, dynamic> json) =>
    StreamRequest(
      mediaGuid: json['media_guid'] as String,
      ip: json['ip'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      header: json['header'] == null
          ? null
          : Header.fromJson(json['header'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$StreamRequestToJson(StreamRequest instance) =>
    <String, dynamic>{
      'media_guid': instance.mediaGuid,
      'ip': instance.ip,
      'level': instance.level,
      'header': instance.header,
    };

Header _$HeaderFromJson(Map<String, dynamic> json) => Header(
      userAgent: (json['User-Agent'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$HeaderToJson(Header instance) => <String, dynamic>{
      'User-Agent': instance.userAgent,
    };

MediaPQuality _$MediaPQualityFromJson(Map<String, dynamic> json) =>
    MediaPQuality(
      resolution: json['resolution'] as String,
      bitrate: (json['bitrate'] as num).toInt(),
    );

Map<String, dynamic> _$MediaPQualityToJson(MediaPQuality instance) =>
    <String, dynamic>{
      'resolution': instance.resolution,
      'bitrate': instance.bitrate,
    };

MediaPRequest _$MediaPRequestFromJson(Map<String, dynamic> json) =>
    MediaPRequest(
      req: json['req'] as String?,
      reqId: json['reqid'] as String?,
      playLink: json['playLink'] as String,
      quality: json['quality'] == null
          ? null
          : MediaPQuality.fromJson(json['quality'] as Map<String, dynamic>),
      startTimestamp: (json['startTimestamp'] as num?)?.toInt(),
      clearCache: json['clearCache'] as bool?,
      audioEncoder: json['audioEncoder'] as String?,
      channels: (json['channels'] as num?)?.toInt(),
      audioIndex: (json['audioIndex'] as num?)?.toInt(),
      subtitleIndex: (json['subtitleIndex'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MediaPRequestToJson(MediaPRequest instance) =>
    <String, dynamic>{
      'req': instance.req,
      'reqid': instance.reqId,
      'playLink': instance.playLink,
      'quality': instance.quality,
      'startTimestamp': instance.startTimestamp,
      'clearCache': instance.clearCache,
      'audioEncoder': instance.audioEncoder,
      'channels': instance.channels,
      'audioIndex': instance.audioIndex,
      'subtitleIndex': instance.subtitleIndex,
    };

PlayPlayRequest _$PlayPlayRequestFromJson(Map<String, dynamic> json) =>
    PlayPlayRequest(
      mediaGuid: json['media_guid'] as String,
      videoGuid: json['video_guid'] as String,
      videoEncoder: json['video_encoder'] as String,
      resolution: json['resolution'] as String,
      bitrate: (json['bitrate'] as num).toInt(),
      startTimestamp: (json['startTimestamp'] as num?)?.toInt() ?? 0,
      audioEncoder: json['audio_encoder'] as String? ?? 'aac',
      audioGuid: json['audio_guid'] as String,
      subtitleGuid: json['subtitle_guid'] as String? ?? '',
      channels: (json['channels'] as num?)?.toInt() ?? 2,
      forcedSdr: (json['forced_sdr'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PlayPlayRequestToJson(PlayPlayRequest instance) =>
    <String, dynamic>{
      'media_guid': instance.mediaGuid,
      'video_guid': instance.videoGuid,
      'video_encoder': instance.videoEncoder,
      'resolution': instance.resolution,
      'bitrate': instance.bitrate,
      'startTimestamp': instance.startTimestamp,
      'audio_encoder': instance.audioEncoder,
      'audio_guid': instance.audioGuid,
      'subtitle_guid': instance.subtitleGuid,
      'channels': instance.channels,
      'forced_sdr': instance.forcedSdr,
    };
