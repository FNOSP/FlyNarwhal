/// Shared transport and scheduler defaults for the bounded local CDN proxy.
abstract final class CdnProxyDefaults {
  static const int chunkSize = 10 * 1024 * 1024;
  static const int maxConcurrent = 3;
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration sendTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration idleTimeout = Duration(seconds: 20);
  static const Duration retryDelay = Duration(seconds: 1);
}
