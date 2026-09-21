/// App-local playback routing; this is not part of a server response model.
enum PlaybackTransport { standard, quarkCdnRange }

/// Keeps routing and validation attached to the original playback address.
/// Invalid cloud links remain part of the session so the UI can offer retry/NAS.
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
