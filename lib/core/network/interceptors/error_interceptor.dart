import 'package:dio/dio.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/network/api_result.dart';

/// Dio interceptor that converts errors to ApiResult
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
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
}