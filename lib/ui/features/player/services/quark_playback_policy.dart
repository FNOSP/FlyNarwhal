import '../../../../data/models/player_models.dart';
import '../models/playback_source_spec.dart';

/// Backend identifier used only by the Quark proxy integration.
const int quarkCloudStorageType = 4;

/// Snapshot only an explicitly selected direct session. NAS/HLS callers omit
/// the context, so a later change to the page's current cache cannot reroute them.
PlaybackSourceSpec snapshotPlaybackSource({
  required String playUri,
  PlayingInfoCache? directLinkContext,
}) {
  final context = directLinkContext;
  final index = context?.directLinkQualityIndex;
  if (context == null ||
      !context.isUseDirectLink ||
      context.streamInfo?.cloudStorageInfo?.cloudStorageType !=
          quarkCloudStorageType ||
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
