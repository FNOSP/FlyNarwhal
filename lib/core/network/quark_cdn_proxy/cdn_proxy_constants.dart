/// Shared transport and scheduler defaults for the bounded local CDN proxy.
abstract final class CdnProxyDefaults {
  static const int chunkSize = 10 * 1024 * 1024;
  static const int outputBlockSize = 64 * 1024;
  static const int maxBodyRetries = 3;
  static const Duration requestTimeout = Duration(hours: 48);

  /// Bounds on the number of chunk downloads a reader keeps in flight.
  ///
  /// The floor keeps one connection on the wire so playback never stalls for
  /// lack of a fetch. The ceiling caps the load a single session places on the
  /// netdisk account; four was the highest count measured to still improve
  /// aggregate throughput on a fast link.
  static const int minChunksPerReader = 1;
  static const int maxChunksPerReader = 4;

  /// Starting concurrency before any throughput measurement exists.
  ///
  /// The count moves in response to what the link actually delivers, so this
  /// value only has to be safe. Matches the previous fixed concurrency so an
  /// unknown bitrate keeps the original three-chunk behavior.
  static const int initialChunksPerReader = 3;

  /// Throughput one upstream connection is assumed to deliver before any
  /// measurement exists, in bytes per second. Deliberately low: overestimating
  /// it would under-provision the connection count for the first seconds of
  /// playback.
  static const int assumedBytesPerConnectionPerSecond = 2000000;

  /// How long traffic is accumulated before the throughput is read from it.
  static const int throughputMeasurementWindowMs = 4000;

  /// Headroom factor applied to the stream bitrate when deciding how much
  /// aggregate download throughput is enough.
  static const int throughputHeadroomFactor = 2;

  /// Ceiling on how far the concurrency probe may climb without having shown a
  /// measurable throughput gain.
  static const int maxUnproductiveProbes = 2;
}
