/// App-local playback routing; this is not part of a server response model.
enum PlaybackTransport { standard, quarkCdnRange }

/// Immutable routing input captured by the playback source controller.
class PlaybackSourceSpec {
  final String playUri;
  final PlaybackTransport transport;
  final String? sourceError;

  const PlaybackSourceSpec({
    required this.playUri,
    this.transport = PlaybackTransport.standard,
    this.sourceError,
  });
}

class PlaybackSourceSuperseded implements Exception {
  const PlaybackSourceSuperseded();
}

class PlaybackSourceRejected implements Exception {
  final String message;
  const PlaybackSourceRejected(this.message);

  @override
  String toString() => message;
}
