import 'package:dio/dio.dart';

/// Retry interceptor for automatic request retry on failure
class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration retryDelay;
  final List<int> retryableStatusCodes;

  RetryInterceptor({
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.retryableStatusCodes = const [408, 429, 500, 502, 503, 504],
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Check if request has extra data for retry count
    final extra = err.requestOptions.extra;
    int retryCount = extra['retryCount'] as int? ?? 0;

    // Check if should retry
    if (_shouldRetry(err, retryCount)) {
      retryCount++;
      err.requestOptions.extra['retryCount'] = retryCount;

      // Wait before retry
      await Future.delayed(retryDelay * retryCount);

      // Retry the request
      try {
        final dio = Dio();
        final response = await dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (e) {
        // If retry fails, continue with error handling
      }
    }

    super.onError(err, handler);
  }

  bool _shouldRetry(DioException err, int retryCount) {
    if (retryCount >= maxRetries) return false;

    // Retry on timeout or connection errors
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    // Retry on specific status codes
    final statusCode = err.response?.statusCode;
    if (statusCode != null && retryableStatusCodes.contains(statusCode)) {
      return true;
    }

    return false;
  }
}