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
  );
}
