import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Logging interceptor for request/response debugging
class LoggingInterceptor extends Interceptor {
  final bool printRequestBody;
  final bool printResponseBody;
  final bool printError;

  LoggingInterceptor({
    this.printRequestBody = false,
    this.printResponseBody = false,
    this.printError = true,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      final method = options.method.toUpperCase();
      final uri = options.uri.toString();
      debugPrint('[Dio] --> $method $uri');

      if (printRequestBody && options.data != null) {
        debugPrint('[Dio] Request Body: ${options.data}');
      }

      if (options.headers.isNotEmpty) {
        debugPrint('[Dio] Headers: ${options.headers}');
      }
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final method = response.requestOptions.method.toUpperCase();
      final uri = response.requestOptions.uri.toString();
      final statusCode = response.statusCode;

      debugPrint('[Dio] <-- $method $uri [$statusCode]');

      if (printResponseBody && response.data != null) {
        final data = response.data.toString();
        // Limit response body output
        final truncated = data.length > 500 ? '${data.substring(0, 1000)}...' : data;
        debugPrint('[Dio] Response: $truncated');
      }
    }

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode && printError) {
      final method = err.requestOptions.method.toUpperCase();
      final uri = err.requestOptions.uri.toString();
      final statusCode = err.response?.statusCode;

      debugPrint('[Dio] ERROR $method $uri [$statusCode]');
      debugPrint('[Dio] Error: ${err.message}');
      debugPrint('[Dio] Type: ${err.type}');

      if (err.response?.data != null) {
        debugPrint('[Dio] Response: ${err.response?.data}');
      }
    }

    super.onError(err, handler);
  }
}
