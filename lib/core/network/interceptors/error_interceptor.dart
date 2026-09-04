import 'package:dio/dio.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/network/api_result.dart';
import '../../../core/utils/log/app_talker.dart';
import '../../../core/utils/log/error_describer.dart';

/// Dio interceptor that converts errors to ApiResult
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Log the underlying cause before it is replaced by FailureInfo below.
    // Without this, obfuscated builds print `Instance of 'gOa'` and the real
    // SocketException (refused / reset / unreachable) is lost.
    AppTalker.warning(
      'Network',
      'request failed: ${err.requestOptions.method} ${err.requestOptions.path} '
          'type=${err.type.name} '
          'status=${err.response?.statusCode} '
          'cause=${_describeError(err.error)}',
    );

    // Convert DioException to Failure and wrap in error
    final failure = ErrorHandler.handleDioError(err);
    final failureInfo = FailureInfo(
      message: failure.message,
      code: failure.code,
      displayMessage: failure.displayMessage,
    );

    // Create a new error with failure info attached
    final newError = DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: failureInfo,
      message: failure.message,
    );

    super.onError(newError, handler);
  }

  /// Extracts the readable cause from the underlying error. App-level classes
  /// are obfuscated in release builds, so relying on toString() alone would
  /// print `Instance of 'gOa'`.
  static String _describeError(Object? error) => ErrorDescriber.describe(error);
}
