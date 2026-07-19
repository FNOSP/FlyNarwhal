import '../../../../data/models/media_request_models.dart';
import '../../../../data/models/player_models.dart';

PlayRecordRequest? buildPlayRecordRequest({
  required int positionSeconds,
  required String fallbackItemGuid,
  required String deviceId,
  required String deviceName,
  required PlayingInfoCache? cache,
}) {
  final fileStream = cache?.currentFileStream;
  final videoStream = cache?.currentVideoStream;
  if (cache == null || fileStream == null || videoStream == null) {
    return null;
  }

  final quality = cache.currentQuality;

  // Use a dedicated record link for direct-link sessions.
  final playRecordLink =
      cache.isUseDirectLink ? cache.playRecordLink : cache.playLink;

  return PlayRecordRequest(
    itemGuid: cache.itemGuid ?? fallbackItemGuid,
    mediaGuid: fileStream.guid,
    videoGuid: videoStream.guid,
    audioGuid: cache.currentAudioStream?.guid ?? '',
    subtitleGuid: cache.currentSubtitleStream?.guid,
    resolution: quality?.resolution ?? videoStream.resolutionType,
    bitrate: quality?.bitrate ?? videoStream.bps,
    ts: positionSeconds,
    duration: videoStream.duration,
    playLink: playRecordLink,
    deviceId: deviceId,
    directLinkAudioIndex: -1,
    lan: 'zh-CN',
    deviceName: deviceName,
  );
}
