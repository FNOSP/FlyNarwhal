import 'package:dio/dio.dart' hide ResponseDecoder;
import '../network/response_decoder.dart';
import 'failures.dart';
import 'exceptions.dart';

/// Centralized error handler for converting exceptions to failures
class ErrorHandler {
  const ErrorHandler._();

  /// Convert DioException to appropriate Failure type
  static Failure handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return NetworkFailure(
          message: error.message ?? 'Connection timeout',
          type: NetworkErrorType.connectionTimeout,
        );

      case DioExceptionType.sendTimeout:
        return NetworkFailure(
          message: error.message ?? 'Send timeout',
          type: NetworkErrorType.sendTimeout,
        );

      case DioExceptionType.receiveTimeout:
        return NetworkFailure(
          message: error.message ?? 'Receive timeout',
          type: NetworkErrorType.receiveTimeout,
        );

      case DioExceptionType.badResponse:
        return _handleBadResponse(error);

      case DioExceptionType.cancel:
        return NetworkFailure(
          message: 'Request was cancelled',
          type: NetworkErrorType.unknown,
        );

      case DioExceptionType.connectionError:
        return NetworkFailure(
          message: error.message ?? 'Connection error',
          type: NetworkErrorType.connectionError,
        );

      case DioExceptionType.badCertificate:
        return NetworkFailure(
          message: 'SSL certificate error',
          type: NetworkErrorType.connectionError,
        );

      case DioExceptionType.unknown:
        return NetworkFailure(
          message: error.message ?? 'Unknown network error',
          type: NetworkErrorType.unknown,
        );
    }
  }

  static Failure _handleBadResponse(DioException error) {
    final statusCode = error.response?.statusCode;

    // Requests use `ResponseType.bytes`, and only the success path normalizes
    // the body, so an error body arrives here as raw bytes. Normalizing first is
    // what makes a JSON error envelope's `msg` readable; a non-JSON body (e.g.
    // an nginx HTML error page) stays a String and falls back to the defaults.
    final data = ResponseDecoder.normalizeResponseData(error.response?.data);

    // Extract error message from response
    String message = 'Server error';
    int? code;
    var hasServerMessage = false;

    if (data is Map) {
      final serverMessage =
          data['msg']?.toString() ?? data['message']?.toString();
      if (serverMessage != null && serverMessage.trim().isNotEmpty) {
        message = serverMessage;
        hasServerMessage = true;
      }
      code = data['code'] as int?;
    }

    // Handle specific HTTP status codes
    if (statusCode != null) {
      if (statusCode == 401) {
        return AuthFailure(
          message: message,
          code: code ?? statusCode,
          type: AuthErrorType.unauthorized,
          hasServerMessage: hasServerMessage,
        );
      }

      if (statusCode == 403) {
        return AuthFailure(
          message: message,
          code: code ?? statusCode,
          type: AuthErrorType.forbidden,
          hasServerMessage: hasServerMessage,
        );
      }

      if (statusCode >= 500) {
        return ServerFailure(
          message: message,
          code: code ?? statusCode,
        );
      }
    }

    return NetworkFailure(
      message: message,
      code: code ?? statusCode,
      type: NetworkErrorType.badResponse,
    );
  }

  /// Convert any exception to Failure
  static Failure handle(dynamic error) {
    if (error is Failure) {
      return error;
    }

    if (error is DioException) {
      return handleDioError(error);
    }

    if (error is AppException) {
      return _handleAppException(error);
    }

    if (error is FormatException) {
      return const UnknownFailure(message: 'Data format error');
    }

    return UnknownFailure(
      message: error?.toString() ?? 'Unknown error occurred',
    );
  }

  static Failure _handleAppException(AppException error) {
    switch (error.runtimeType) {
      case NetworkException _:
        return NetworkFailure(message: error.message, code: error.code);
      case ServerException _:
        return ServerFailure(message: error.message, code: error.code);
      case AuthException _:
        return AuthFailure(message: error.message, code: error.code);
      case CacheException _:
        return CacheFailure(message: error.message, code: error.code);
      default:
        return UnknownFailure(message: error.message, code: error.code);
    }
  }
}