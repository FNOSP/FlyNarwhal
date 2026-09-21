import '../models/playback_source_spec.dart';

/// Player policy travels with a prepared source instead of being inferred by UI.
class PlaybackOpenPolicy {
  final Duration networkTimeout;
  final bool waitForRecovery;
  final Duration? stalledStartTimeout;

  const PlaybackOpenPolicy._({
    required this.networkTimeout,
    required this.waitForRecovery,
    required this.stalledStartTimeout,
  });

  static const standard = PlaybackOpenPolicy._(
    networkTimeout: Duration(seconds: 5),
    waitForRecovery: false,
    stalledStartTimeout: Duration(seconds: 8),
  );
  static const cdnBuffered = PlaybackOpenPolicy._(
    networkTimeout: Duration(seconds: 60),
    waitForRecovery: false,
    stalledStartTimeout: Duration(seconds: 8),
  );

  static PlaybackOpenPolicy forTransport(PlaybackTransport transport) =>
      switch (transport) {
        PlaybackTransport.standard => standard,
        PlaybackTransport.quarkCdnRange => cdnBuffered,
      };

  bool shouldAbortStalledStart({
    required Duration elapsed,
    required Duration mediaDuration,
    required bool hasVideo,
    required Duration buffered,
  }) {
    final timeout = stalledStartTimeout;
    return timeout != null &&
        elapsed >= timeout &&
        mediaDuration > Duration.zero &&
        !hasVideo &&
        buffered <= Duration.zero;
  }
}

/// A buffered CDN source can wait longer for a full chunk; each standard
/// source restores media_kit's original timeout after a source switch.
Future<void> openWithPlaybackNetworkPolicy({
  required PlaybackTransport transport,
  required Future<void> Function() open,
  Future<void> Function(String name, String value)? setProperty,
}) async {
  if (setProperty != null) {
    final policy = PlaybackOpenPolicy.forTransport(transport);
    await setProperty(
        'network-timeout', policy.networkTimeout.inSeconds.toString());
  }
  await open();
}

bool shouldAbortStalledPlaybackStart({
  required PlaybackTransport transport,
  required Duration elapsed,
  required Duration mediaDuration,
  required bool hasVideo,
  required Duration buffered,
}) =>
    PlaybackOpenPolicy.forTransport(transport).shouldAbortStalledStart(
      elapsed: elapsed,
      mediaDuration: mediaDuration,
      hasVideo: hasVideo,
      buffered: buffered,
    );
