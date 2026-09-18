import '../../../../data/models/player_models.dart';

/// Applies the transport's native timeout immediately before opening media.
/// Quark's local endpoint may wait for a complete bounded CDN chunk; standard
/// sources must restore media_kit's original five-second network timeout.
Future<void> openWithPlaybackNetworkPolicy({
  required PlaybackTransport transport,
  required Future<void> Function() open,
  Future<void> Function(String name, String value)? setProperty,
}) async {
  if (setProperty != null) {
    final timeoutSeconds = switch (transport) {
      PlaybackTransport.standard => 5,
      PlaybackTransport.quarkCdnRange => 60,
    };
    await setProperty('network-timeout', timeoutSeconds.toString());
  }
  await open();
}
