/// Shared transport and scheduler defaults for the bounded local CDN proxy.
abstract final class CdnProxyDefaults {
  static const int chunkSize = 10 * 1024 * 1024;
  static const int maxConcurrent = 3;
  static const int outputBlockSize = 64 * 1024;
  static const int maxBodyRetries = 3;
  static const Duration requestTimeout = Duration(hours: 48);
}
