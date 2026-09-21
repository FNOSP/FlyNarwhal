import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/data/models/player_models.dart';
import 'package:fly_narwhal/ui/features/player/models/playback_source_spec.dart';
import 'package:fly_narwhal/ui/features/player/controllers/player_session_coordinator.dart';
import 'package:fly_narwhal/ui/features/player/services/playback_network_policy.dart';
import 'package:fly_narwhal/ui/features/player/services/quark_playback_policy.dart';

bool _blocksFallback(PlayingInfoCache? cache) =>
    shouldBlockQuarkAutomaticNasFallback(
      cache,
      isHlsQuality: PlayerSessionCoordinator.isHlsDirectQuality,
    );

PlayingInfoCache _session({
  int cloudType = CloudStorageInfo.quarkCloudStorageType,
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
              resolution: '原画',
              url: 'https://cdn.example/movie.mkv',
            ),
          ],
      streamInfo: StreamResponse(
        cloudStorageInfo: CloudStorageInfo(cloudStorageType: cloudType),
      ),
    );

void main() {
  test(
    'Given selected Quark HLS by flag or URL, when handling failure, then the single-file guard does not replace the existing fallback',
    () {
      for (final quality in [
        DirectLinkQuality(
          resolution: 'HLS',
          url: 'https://cdn.example/playlist',
          isM3u8: true,
        ),
        DirectLinkQuality(
          resolution: 'HLS',
          url: 'https://cdn.example/video.M3U8?token=example',
        ),
      ]) {
        expect(_blocksFallback(_session(qualities: [quality])), isFalse);
      }
    },
  );

  test(
    'Given mixed Quark qualities, when the selected index changes, then only the single-file choice blocks automatic NAS fallback',
    () {
      final qualities = [
        DirectLinkQuality(
          resolution: '原画',
          url: 'https://cdn.example/movie.mkv',
        ),
        DirectLinkQuality(
          resolution: 'HLS',
          url: 'https://cdn.example/movie.m3u8',
        ),
      ];
      expect(_blocksFallback(_session(qualities: qualities, index: 0)), isTrue);
      expect(
          _blocksFallback(_session(qualities: qualities, index: 1)), isFalse);
    },
  );

  test(
    'Given missing or invalid Quark metadata, when handling a selected direct attempt, then it remains a manual recovery instead of silently using NAS',
    () {
      for (final cache in [
        _session(qualities: []),
        _session(index: -1),
        _session(index: 2),
        _session(qualities: [DirectLinkQuality(resolution: '原画')]),
      ]) {
        expect(_blocksFallback(cache), isTrue);
      }
    },
  );

  test(
    'Given NAS original-file fallback or a non-Quark session, when handling failure, then existing fallback behavior is not guarded',
    () {
      for (final cache in [
        null,
        // NAS original-file / error 8192 fallback.
        _session(index: null),
        _session(direct: false),
        _session(cloudType: 1),
        _session(cloudType: CloudStorageInfo.strmCloudStorageType),
      ]) {
        expect(_blocksFallback(cache), isFalse);
      }
    },
  );

  test(
    'Given a failed open followed by transport cleanup, when choosing recovery, then single-file intent stays guarded while HLS retains the old callback',
    () async {
      final events = <String>[];
      for (final hls in [false, true]) {
        final cache = _session(qualities: [
          DirectLinkQuality(
            resolution: '原画',
            url: hls
                ? 'https://cdn.example/movie.m3u8'
                : 'https://cdn.example/movie.mkv',
          ),
        ]);
        var activeTransport =
            hls ? PlaybackTransport.standard : PlaybackTransport.quarkCdnRange;
        var previousFallbackCalls = 0;
        Future<void> previousFallback() async => previousFallbackCalls++;

        try {
          await openWithPlaybackNetworkPolicy(
            transport: activeTransport,
            setProperty: (name, value) async => events.add('$name=$value'),
            open: () async => throw StateError('simulated open failure'),
          );
        } on StateError {
          // The real player's cleanup resets only the active transport. The
          // selected source remains available for the existing error flow.
          activeTransport = PlaybackTransport.standard;
          if (!_blocksFallback(cache)) await previousFallback();
        }

        expect(activeTransport, PlaybackTransport.standard);
        expect(previousFallbackCalls, hls ? 1 : 0);
      }
      expect(events, ['network-timeout=0', 'network-timeout=5']);
    },
  );
}
