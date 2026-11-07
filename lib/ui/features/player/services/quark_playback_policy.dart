import '../../../../data/models/cloud_storage_type.dart';
import '../../../../data/models/player_models.dart';
import '../models/playback_source_spec.dart';

/// Snapshot only an explicitly selected direct session. NAS/HLS callers omit
/// the context, so a later change to the page's current cache cannot reroute them.
///
/// [preferCdnRange] is the player's 夸克 CDN 分片直连 switch. When off, every
/// caller keeps [playUri] as-is, which for a Quark direct session is the NAS
/// `/media/range` link mpv opens itself (the pre-CDN-range behavior).
PlaybackSourceSpec snapshotPlaybackSource({
  required String playUri,
  PlayingInfoCache? directLinkContext,
  bool preferCdnRange = true,
}) {
  final context = directLinkContext;
  final index = context?.directLinkQualityIndex;
  if (!preferCdnRange ||
      context == null ||
      !context.isUseDirectLink ||
      !CloudStorageType.fromValue(
              context.streamInfo?.cloudStorageInfo?.cloudStorageType)
          .isQuarkPan ||
      index == null ||
      index < 0 ||
      index >= context.directLinkQualities.length) {
    return PlaybackSourceSpec(playUri: playUri);
  }

  final quality = context.directLinkQualities[index];
  final uri = Uri.tryParse(quality.url);
  if (quality.isM3u8 || (uri?.path.toLowerCase().contains('.m3u8') ?? false)) {
    return PlaybackSourceSpec(playUri: playUri);
  }
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return PlaybackSourceSpec(
      playUri: quality.url,
      sourceError: '夸克直连地址不可用',
    );
  }
  return PlaybackSourceSpec(
    playUri: quality.url,
    transport: PlaybackTransport.quarkCdnRange,
    bitrate: _effectiveBitrate(context, quality),
  );
}

/// Picks the bitrate used to size download concurrency.
///
/// The NAS omits `bitrate` on direct-link qualities (it reports 0), so when
/// that happens the source file size is divided by the media duration. This
/// estimate is available before playback starts, unlike an mpv probe, and is
/// only used to choose how many connections to open; a wrong estimate is
/// corrected by the throughput measurement once the first chunks arrive.
int _effectiveBitrate(PlayingInfoCache context, DirectLinkQuality quality) {
  if (quality.bitrate > 0) return quality.bitrate;
  final size = context.currentFileStream?.size;
  if (size == null || size <= 0) return 0;
  final durationSeconds =
      context.item?.duration ?? context.currentVideoStream?.duration ?? 0;
  if (durationSeconds <= 0) return 0;
  return (size * 8 ~/ durationSeconds);
}
