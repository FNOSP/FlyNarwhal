import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/error/error_handler.dart';
import 'package:fly_narwhal/core/error/failures.dart';
import 'package:fly_narwhal/core/error/exceptions.dart';
import 'package:dio/dio.dart';

void main() {
  group('ErrorHandler', () {
    test('handle DioException connection timeout', () {
      final exception = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/test'),
        message: 'Connection timeout',
      );

      final failure = ErrorHandler.handleDioError(exception);

      expect(failure, isA<NetworkFailure>());
      expect((failure as NetworkFailure).type, equals(NetworkErrorType.connectionTimeout));
    });

    test('handle DioException bad response with 401', () {
      final exception = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          statusCode: 401,
          data: {'msg': 'Token expired'},
          requestOptions: RequestOptions(path: '/test'),
        ),
      );

      final failure = ErrorHandler.handleDioError(exception);

      expect(failure, isA<AuthFailure>());
      expect((failure as AuthFailure).type, equals(AuthErrorType.unauthorized));
    });

    test('handle DioException bad response with 500', () {
      final exception = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          statusCode: 500,
          data: {'msg': 'Server error'},
          requestOptions: RequestOptions(path: '/test'),
        ),
      );

      final failure = ErrorHandler.handleDioError(exception);

      expect(failure, isA<ServerFailure>());
      expect(failure.code, equals(500));
    });

    test('handle generic exception', () {
      final failure = ErrorHandler.handle(Exception('Unknown error'));

      expect(failure, isA<UnknownFailure>());
    });

    test('handle FormatException', () {
      final failure = ErrorHandler.handle(FormatException('Invalid format'));

      expect(failure, isA<UnknownFailure>());
      expect(failure.message, equals('Data format error'));
    });

    test('handle AppException', () {
      const exception = CacheException(message: 'Cache read error');
      final failure = ErrorHandler.handle(exception);

      expect(failure, isA<CacheFailure>());
      expect(failure.message, equals('Cache read error'));
    });
  });
}