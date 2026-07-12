import 'package:json_annotation/json_annotation.dart';
import 'movie_detail_models.dart';

part 'player_models.g.dart';

// Speed options for playback
class SpeedItem {
  final String label;
  final double value;

  const SpeedItem(this.label, this.value);

  static const List<SpeedItem> defaults = [
    SpeedItem('2.0x', 2.0),
    SpeedItem('1.75x', 1.75),
    SpeedItem('1.5x', 1.5),
    SpeedItem('1.25x', 1.25),
    SpeedItem('1.0x', 1.0),
    SpeedItem('0.75x', 0.75),
    SpeedItem('0.5x', 0.5),
  ];
}

@JsonSerializable()
class CloudStorageInfo {
  @JsonKey(name: 'dav_username')
  final String? davUsername;
  final bool? valid;
  final bool? disabled;
  @JsonKey(name: 'cloud_storage_type')
  final int? cloudStorageType;
  @JsonKey(name: 'cloud_nick_name')
  final String? cloudNickName;
  final int? fssize;
  final int? frsize;
  final int? fusize;
  @JsonKey(name: 'is_vip')
  final bool? isVip;
  @JsonKey(name: 'quark_vip_type')
  final String? quarkVipType;
  @JsonKey(name: 'quark_pc_pay_link')
  final String? quarkPcPayLink;
  @JsonKey(name: 'quark_wap_pay_link')
  final String? quarkWapPayLink;

  CloudStorageInfo({
    this.davUsername,
    this.valid,
    this.disabled,
    this.cloudStorageType,
    this.cloudNickName,
    this.fssize,
    this.frsize,
    this.fusize,
    this.isVip,
    this.quarkVipType,
    this.quarkPcPayLink,
    this.quarkWapPayLink,
  });

  factory CloudStorageInfo.fromJson(Map<String, dynamic> json) =>
      _$CloudStorageInfoFromJson(json);
  Map<String, dynamic> toJson() => _$CloudStorageInfoToJson(this);
}

@JsonSerializable()
class StreamResponse {
  @JsonKey(name: 'video_stream')
  final VideoStream? videoStream;
  @JsonKey(name: 'audio_streams')
  final List<AudioStream>? audioStreams;
  @JsonKey(name: 'subtitle_streams')
  final List<SubtitleStream>? subtitleStreams;
  @JsonKey(name: 'file_stream')
  final FileInfo? fileStream;
  final List<QualityResponse>? qualities;
  @JsonKey(name: 'cloud_storage_info')
  final CloudStorageInfo? cloudStorageInfo;

  StreamResponse({
    this.videoStream,
    this.audioStreams,
    this.subtitleStreams,
    this.fileStream,
    this.qualities,
    this.cloudStorageInfo,
  });

  factory StreamResponse.fromJson(Map<String, dynamic> json) =>
      _$StreamResponseFromJson(json);
  Map<String, dynamic> toJson() => _$StreamResponseToJson(this);
}

@JsonSerializable()
class QualityResponse {
  final int bitrate;
  final String resolution;
  final bool progressive;
  @JsonKey(name: 'is_m3u8')
  final bool isM3u8;

  QualityResponse({
    required this.bitrate,
    required this.resolution,
    this.progressive = false,
    this.isM3u8 = false,
  });

  factory QualityResponse.fromJson(Map<String, dynamic> json) =>
      _$QualityResponseFromJson(json);
  Map<String, dynamic> toJson() => _$QualityResponseToJson(this);
}

@JsonSerializable()
class SubtitleSettings {
  final double offsetSeconds;
  final double verticalPosition;
  final double fontScale;
  final double fontSize;
  final String fontColor;
  final String backgroundColor;

  const SubtitleSettings({
    this.offsetSeconds = 0,
    this.verticalPosition = 0.02,
    this.fontScale = 1.0,
    this.fontSize = 24.0,
    this.fontColor = '#FFFFFF',
    this.backgroundColor = '#000000',
  });

  factory SubtitleSettings.fromJson(Map<String, dynamic> json) =>
      _$SubtitleSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$SubtitleSettingsToJson(this);

  SubtitleSettings copyWith({
    double? offsetSeconds,
    double? verticalPosition,
    double? fontScale,
    double? fontSize,
    String? fontColor,
    String? backgroundColor,
  }) {
    return SubtitleSettings(
      offsetSeconds: offsetSeconds ?? this.offsetSeconds,
      verticalPosition: verticalPosition ?? this.verticalPosition,
      fontScale: fontScale ?? this.fontScale,
      fontSize: fontSize ?? this.fontSize,
      fontColor: fontColor ?? this.fontColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}

@JsonSerializable()
class PlayPlayResponse {
  @JsonKey(name: 'play_link')
  final String playLink;

  PlayPlayResponse({required this.playLink});

  factory PlayPlayResponse.fromJson(Map<String, dynamic> json) =>
      _$PlayPlayResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PlayPlayResponseToJson(this);
}

@JsonSerializable()
class MediaTranscodeAudio {
  final int channels;
  final String encoder;

  MediaTranscodeAudio({
    required this.channels,
    required this.encoder,
  });

  factory MediaTranscodeAudio.fromJson(Map<String, dynamic> json) =>
      _$MediaTranscodeAudioFromJson(json);
  Map<String, dynamic> toJson() => _$MediaTranscodeAudioToJson(this);
}

@JsonSerializable()
class MediaTranscodeVideo {
  @JsonKey(name: 'corruptedFrames')
  final int corruptedFrames;
  @JsonKey(name: 'decodeMethod')
  final int decodeMethod;
  @JsonKey(name: 'droppedFrames')
  final int droppedFrames;
  @JsonKey(name: 'dynamicRange')
  final String dynamicRange;
  @JsonKey(name: 'encodeMethod')
  final int encodeMethod;
  final String encoder;
  @JsonKey(name: 'selectedGpu')
  final String selectedGpu;
  @JsonKey(name: 'transcodingRate')
  final String transcodingRate;

  MediaTranscodeVideo({
    required this.corruptedFrames,
    required this.decodeMethod,
    required this.droppedFrames,
    required this.dynamicRange,
    required this.encodeMethod,
    required this.encoder,
    required this.selectedGpu,
    required this.transcodingRate,
  });

  factory MediaTranscodeVideo.fromJson(Map<String, dynamic> json) =>
      _$MediaTranscodeVideoFromJson(json);
  Map<String, dynamic> toJson() => _$MediaTranscodeVideoToJson(this);
}

@JsonSerializable()
class MediaTranscodeResponse {
  final MediaTranscodeAudio audio;
  final int bitrate;
  @JsonKey(name: 'reqid')
  final String reqId;
  final String resolution;
  final String result;
  final bool transcoded;
  @JsonKey(name: 'transcodingReason')
  final List<int> transcodingReason;
  final MediaTranscodeVideo video;

  MediaTranscodeResponse({
    required this.audio,
    required this.bitrate,
    required this.reqId,
    required this.resolution,
    required this.result,
    required this.transcoded,
    required this.transcodingReason,
    required this.video,
  });

  factory MediaTranscodeResponse.fromJson(Map<String, dynamic> json) =>
      _$MediaTranscodeResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MediaTranscodeResponseToJson(this);
}

class MediaResetQualityResponse {
  @JsonKey(name: 'hlsTime')
  final int? hlsTime;
  @JsonKey(name: 'reqid')
  final String reqId;
  final String result;
  @JsonKey(name: 'updateM3u8')
  final bool? updateM3u8;
  final int? errno;

  MediaResetQualityResponse({
    this.hlsTime,
    required this.reqId,
    required this.result,
    this.updateM3u8,
    this.errno,
  });

  bool get isSuccess => result == 'succ';

  String describeFailure(String action) {
    final details = <String>[
      if (errno != null) 'errno=$errno',
      if (reqId.isNotEmpty) 'reqid=$reqId',
      if (result.isNotEmpty) 'result=$result',
    ];
    if (details.isEmpty) {
      return '$action failed';
    }
    return '$action failed: ${details.join(', ')}';
  }

  factory MediaResetQualityResponse.fromJson(Map<String, dynamic> json) {
    return MediaResetQualityResponse(
      hlsTime: json['hlsTime'] as int?,
      reqId: json['reqid'] as String? ?? '',
      result: json['result'] as String? ?? '',
      updateM3u8: json['updateM3u8'] as bool?,
      errno: json['errno'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'hlsTime': hlsTime,
      'reqid': reqId,
      'result': result,
      'updateM3u8': updateM3u8,
      'errno': errno,
    };
  }
}

// Playing info cache to store current playback state
class PlayingInfoCache {
  static const Object _unset = Object();

  final String? itemGuid;
  final String? parentGuid;
  final ItemResponse? item;
  final FileInfo? currentFileStream;
  final VideoStream? currentVideoStream;
  final AudioStream? currentAudioStream;
  final SubtitleStream? currentSubtitleStream;
  final SubtitleStream? previousSubtitle;
  final List<QualityResponse> currentQualities;
  final QualityResponse? currentQuality;
  final List<AudioStream> currentAudioStreamList;
  final List<SubtitleStream> currentSubtitleStreamList;
  // Server-side playback session link reused by media/p requests.
  // Direct-link playback must leave this null.
  final String? playLink;
  // Client-side record session link used by play/record requests.
  final String? playRecordLink;
  final bool isUseDirectLink;
  final PlayConfig? playConfig;
  final StreamResponse? streamInfo;
  final bool isEpisode;
  final String subhead;

  const PlayingInfoCache({
    this.itemGuid,
    this.parentGuid,
    this.item,
    this.currentFileStream,
    this.currentVideoStream,
    this.currentAudioStream,
    this.currentSubtitleStream,
    this.previousSubtitle,
    this.currentQualities = const [],
    this.currentQuality,
    this.currentAudioStreamList = const [],
    this.currentSubtitleStreamList = const [],
    this.playLink,
    this.playRecordLink,
    this.isUseDirectLink = true,
    this.playConfig,
    this.streamInfo,
    this.isEpisode = false,
    this.subhead = '',
  });

  PlayingInfoCache copyWith({
    String? itemGuid,
    String? parentGuid,
    ItemResponse? item,
    FileInfo? currentFileStream,
    VideoStream? currentVideoStream,
    Object? currentAudioStream = _unset,
    Object? currentSubtitleStream = _unset,
    Object? previousSubtitle = _unset,
    List<QualityResponse>? currentQualities,
    Object? currentQuality = _unset,
    List<AudioStream>? currentAudioStreamList,
    List<SubtitleStream>? currentSubtitleStreamList,
    Object? playLink = _unset,
    Object? playRecordLink = _unset,
    bool? isUseDirectLink,
    Object? playConfig = _unset,
    StreamResponse? streamInfo,
    bool? isEpisode,
    String? subhead,
  }) {
    return PlayingInfoCache(
      itemGuid: itemGuid ?? this.itemGuid,
      parentGuid: parentGuid ?? this.parentGuid,
      item: item ?? this.item,
      currentFileStream: currentFileStream ?? this.currentFileStream,
      currentVideoStream: currentVideoStream ?? this.currentVideoStream,
      currentAudioStream: identical(currentAudioStream, _unset)
          ? this.currentAudioStream
          : currentAudioStream as AudioStream?,
      currentSubtitleStream: identical(currentSubtitleStream, _unset)
          ? this.currentSubtitleStream
          : currentSubtitleStream as SubtitleStream?,
      previousSubtitle: identical(previousSubtitle, _unset)
          ? this.previousSubtitle
          : previousSubtitle as SubtitleStream?,
      currentQualities: currentQualities ?? this.currentQualities,
      currentQuality: identical(currentQuality, _unset)
          ? this.currentQuality
          : currentQuality as QualityResponse?,
      currentAudioStreamList:
          currentAudioStreamList ?? this.currentAudioStreamList,
      currentSubtitleStreamList:
          currentSubtitleStreamList ?? this.currentSubtitleStreamList,
      playLink:
          identical(playLink, _unset) ? this.playLink : playLink as String?,
      playRecordLink: identical(playRecordLink, _unset)
          ? this.playRecordLink
          : playRecordLink as String?,
      isUseDirectLink: isUseDirectLink ?? this.isUseDirectLink,
      playConfig: identical(playConfig, _unset)
          ? this.playConfig
          : playConfig as PlayConfig?,
      streamInfo: streamInfo ?? this.streamInfo,
      isEpisode: isEpisode ?? this.isEpisode,
      subhead: subhead ?? this.subhead,
    );
  }
}

// Player UI state
class PlayerState {
  final bool isVisible;
  final bool isUiVisible;
  final bool isLoading;
  final String itemGuid;
  final String mediaTitle;
  final String subhead;
  final int duration;
  final bool isEpisode;

  const PlayerState({
    this.isVisible = false,
    this.isUiVisible = true,
    this.isLoading = false,
    this.itemGuid = '',
    this.mediaTitle = '',
    this.subhead = '',
    this.duration = 0,
    this.isEpisode = false,
  });

  PlayerState copyWith({
    bool? isVisible,
    bool? isUiVisible,
    bool? isLoading,
    String? itemGuid,
    String? mediaTitle,
    String? subhead,
    int? duration,
    bool? isEpisode,
  }) {
    return PlayerState(
      isVisible: isVisible ?? this.isVisible,
      isUiVisible: isUiVisible ?? this.isUiVisible,
      isLoading: isLoading ?? this.isLoading,
      itemGuid: itemGuid ?? this.itemGuid,
      mediaTitle: mediaTitle ?? this.mediaTitle,
      subhead: subhead ?? this.subhead,
      duration: duration ?? this.duration,
      isEpisode: isEpisode ?? this.isEpisode,
    );
  }
}

@JsonSerializable()
class SetConfigByItemRequest {
  final String guid;
  @JsonKey(name: 'skip_opening')
  final int skipOpening;
  @JsonKey(name: 'skip_ending')
  final int skipEnding;

  SetConfigByItemRequest({
    required this.guid,
    required this.skipOpening,
    required this.skipEnding,
  });

  factory SetConfigByItemRequest.fromJson(Map<String, dynamic> json) =>
      _$SetConfigByItemRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SetConfigByItemRequestToJson(this);
}

@JsonSerializable()
class StreamRequest {
  @JsonKey(name: 'media_guid')
  final String mediaGuid;
  final String? ip;
  final int level;
  final Header? header;

  StreamRequest({
    required this.mediaGuid,
    this.ip,
    this.level = 1,
    this.header,
  });

  factory StreamRequest.fromJson(Map<String, dynamic> json) =>
      _$StreamRequestFromJson(json);
  Map<String, dynamic> toJson() => _$StreamRequestToJson(this);
}

@JsonSerializable()
class Header {
  @JsonKey(name: 'User-Agent')
  final List<String> userAgent;

  Header({required this.userAgent});

  factory Header.fromJson(Map<String, dynamic> json) => _$HeaderFromJson(json);
  Map<String, dynamic> toJson() => _$HeaderToJson(this);
}

@JsonSerializable()
class MediaPQuality {
  final String resolution;
  final int bitrate;

  MediaPQuality({
    required this.resolution,
    required this.bitrate,
  });

  factory MediaPQuality.fromJson(Map<String, dynamic> json) =>
      _$MediaPQualityFromJson(json);
  Map<String, dynamic> toJson() => _$MediaPQualityToJson(this);
}

@JsonSerializable()
class MediaPRequest {
  final String? req;
  @JsonKey(name: 'reqid')
  final String? reqId;
  @JsonKey(name: 'playLink')
  final String playLink;
  final MediaPQuality? quality;
  @JsonKey(name: 'startTimestamp')
  final int? startTimestamp;
  @JsonKey(name: 'clearCache')
  final bool? clearCache;
  @JsonKey(name: 'audioEncoder')
  final String? audioEncoder;
  final int? channels;
  @JsonKey(name: 'audioIndex')
  final int? audioIndex;
  @JsonKey(name: 'subtitleIndex')
  final int? subtitleIndex;

  MediaPRequest({
    this.req,
    this.reqId,
    required this.playLink,
    this.quality,
    this.startTimestamp,
    this.clearCache,
    this.audioEncoder,
    this.channels,
    this.audioIndex,
    this.subtitleIndex,
  });

  MediaPRequest copyWith({
    String? req,
    String? reqId,
    String? playLink,
    MediaPQuality? quality,
    int? startTimestamp,
    bool? clearCache,
    String? audioEncoder,
    int? channels,
    int? audioIndex,
    int? subtitleIndex,
  }) {
    return MediaPRequest(
      req: req ?? this.req,
      reqId: reqId ?? this.reqId,
      playLink: playLink ?? this.playLink,
      quality: quality ?? this.quality,
      startTimestamp: startTimestamp ?? this.startTimestamp,
      clearCache: clearCache ?? this.clearCache,
      audioEncoder: audioEncoder ?? this.audioEncoder,
      channels: channels ?? this.channels,
      audioIndex: audioIndex ?? this.audioIndex,
      subtitleIndex: subtitleIndex ?? this.subtitleIndex,
    );
  }

  factory MediaPRequest.fromJson(Map<String, dynamic> json) =>
      _$MediaPRequestFromJson(json);
  Map<String, dynamic> toJson() => _$MediaPRequestToJson(this);
}

@JsonSerializable()
class PlayPlayRequest {
  @JsonKey(name: 'media_guid')
  final String mediaGuid;
  @JsonKey(name: 'video_guid')
  final String videoGuid;
  @JsonKey(name: 'video_encoder')
  final String videoEncoder;
  final String resolution;
  final int bitrate;
  @JsonKey(name: 'startTimestamp')
  final int startTimestamp;
  @JsonKey(name: 'audio_encoder')
  final String audioEncoder;
  @JsonKey(name: 'audio_guid')
  final String audioGuid;
  @JsonKey(name: 'subtitle_guid')
  final String subtitleGuid;
  final int channels;
  @JsonKey(name: 'forced_sdr')
  final int forcedSdr;

  PlayPlayRequest({
    required this.mediaGuid,
    required this.videoGuid,
    required this.videoEncoder,
    required this.resolution,
    required this.bitrate,
    this.startTimestamp = 0,
    this.audioEncoder = 'aac',
    required this.audioGuid,
    this.subtitleGuid = '',
    this.channels = 2,
    this.forcedSdr = 0,
  });

  factory PlayPlayRequest.fromJson(Map<String, dynamic> json) =>
      _$PlayPlayRequestFromJson(json);
  Map<String, dynamic> toJson() => _$PlayPlayRequestToJson(this);
}
