import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/data/models/player_models.dart';
import 'package:fly_narwhal/ui/features/player/models/playback_source_spec.dart';
import 'package:fly_narwhal/ui/features/player/services/quark_playback_policy.dart';

const _nas = 'https://nas.example/v/api/v1/media/range/movie';

PlayingInfoCache _session({
  int cloudType = quarkCloudStorageType,
  bool direct = true,
  int? index = 0,
  List<DirectLinkQuality>? qualities,
}) =>
    PlayingInfoCache(
      isUseDirectLink: direct,
      directLinkQualityIndex: index,
      directLinkQualities: qualities ??
          [
            DirectLinkQuality(
                resolution: 'Original', url: 'https://cdn.example/movie.mkv')
          ],
      streamInfo: StreamResponse(
          cloudStorageInfo: CloudStorageInfo(cloudStorageType: cloudType)),
    );

void main() {
  test(
      'Given an explicit Quark direct selection, when routing, then only its raw single-file URL uses the proxy',
      () {
    final source =
        snapshotPlaybackSource(playUri: _nas, directLinkContext: _session());
    expect(source.playUri, 'https://cdn.example/movie.mkv');
    expect(source.transport, PlaybackTransport.quarkCdnRange);
    expect(source.sourceError, isNull);
  });

  test(
      'Given HLS metadata or a playlist URL, when routing, then the upstream NAS/HLS address remains intact',
      () {
    for (final quality in [
      DirectLinkQuality(
          resolution: 'HLS', url: 'https://cdn.example/playlist', isM3u8: true),
      DirectLinkQuality(
          resolution: 'HLS',
          url: 'https://cdn.example/video.M3U8?token=example'),
      DirectLinkQuality(resolution: 'HLS', isM3u8: true),
    ]) {
      final source = snapshotPlaybackSource(
          playUri: _nas, directLinkContext: _session(qualities: [quality]));
      expect(source.playUri, _nas);
      expect(source.transport, PlaybackTransport.standard);
      expect(source.sourceError, isNull);
    }
  });

  test(
      'Given standard, NAS, missing or non-Quark context, when routing, then upstream address and error handling remain intact',
      () {
    for (final context in [
      null,
      _session(direct: false),
      _session(cloudType: 1),
      _session(cloudType: CloudStorageInfo.strmCloudStorageType),
      _session(index: null),
      _session(index: -1),
      _session(index: 2),
      _session(qualities: []),
      const PlayingInfoCache(),
    ]) {
      final source =
          snapshotPlaybackSource(playUri: _nas, directLinkContext: context);
      expect(source.playUri, _nas);
      expect(source.transport, PlaybackTransport.standard);
      expect(source.sourceError, isNull);
    }
  });

  test(
      'Given an invalid selected single-file URL, when routing, then validation fails rather than silently selecting NAS',
      () {
    for (final url in [
      '',
      'movie.mp4',
      'file:///movie.mp4',
      'https://',
      'http://[invalid'
    ]) {
      final source = snapshotPlaybackSource(
          playUri: _nas,
          directLinkContext: _session(qualities: [
            DirectLinkQuality(resolution: 'Original', url: url)
          ]));
      expect(source.sourceError, isNotNull, reason: url);
      expect(source.playUri, url);
    }
  });

  test(
      'Given mixed qualities, when selecting one, then HLS and CDN routes follow that selection',
      () {
    final qualities = [
      DirectLinkQuality(
          resolution: 'Original', url: 'https://cdn.example/movie.mkv'),
      DirectLinkQuality(
          resolution: 'HLS', url: 'https://cdn.example/movie.m3u8'),
    ];
    expect(
        snapshotPlaybackSource(
                playUri: _nas,
                directLinkContext: _session(qualities: qualities, index: 0))
            .transport,
        PlaybackTransport.quarkCdnRange);
    expect(
        snapshotPlaybackSource(
                playUri: _nas,
                directLinkContext: _session(qualities: qualities, index: 1))
            .transport,
        PlaybackTransport.standard);
  });
}
