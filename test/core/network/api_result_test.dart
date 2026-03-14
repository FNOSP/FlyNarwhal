import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/core/error/failures.dart';

void main() {
  group('ApiResult', () {
    test('Success should contain data', () {
      const result = Success<int>(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, equals(42));
      expect(result.failureOrNull, isNull);
    });

    test('Failure should contain failure info', () {
      final failure = FailureInfo(
        message: 'Connection error',
        displayMessage: 'Connection error',
      );
      final result = ResultFailure<int>(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, isNotNull);
      expect(result.failureOrNull?.message, equals('Connection error'));
    });

    test('map should transform success data', () {
      const result = Success<int>(42);
      final mapped = result.map((data) => data * 2);

      expect(mapped.isSuccess, isTrue);
      expect(mapped.dataOrNull, equals(84));
    });

    test('map should preserve failure', () {
      final failure = FailureInfo(
        message: 'Error',
        displayMessage: 'Error',
      );
      final result = ResultFailure<int>(failure);
      final mapped = result.map((data) => data * 2);

      expect(mapped.isFailure, isTrue);
      expect(mapped.failureOrNull?.message, equals('Error'));
    });

    test('when should execute correct callback', () {
      const success = Success<int>(42);
      final failureResult = ResultFailure<int>(FailureInfo(
        message: 'Error',
        displayMessage: 'Error',
      ));

      final successResult = success.when(
        success: (data) => 'Success: $data',
        failure: (f) => 'Error: ${f.message}',
      );

      final failureOutput = failureResult.when(
        success: (data) => 'Success: $data',
        failure: (f) => 'Error: ${f.message}',
      );

      expect(successResult, equals('Success: 42'));
      expect(failureOutput, equals('Error: Error'));
    });

    test('getOrElse should return data or default', () {
      const success = Success<int>(42);
      final failureResult = ResultFailure<int>(FailureInfo(
        message: 'Error',
        displayMessage: 'Error',
      ));

      expect(success.getOrElse(0), equals(42));
      expect(failureResult.getOrElse(0), equals(0));
    });

    test('getOrThrow should return data or throw', () {
      const success = Success<int>(42);
      final failureResult = ResultFailure<int>(FailureInfo(
        message: 'Error',
        displayMessage: 'Error',
      ));

      expect(success.getOrThrow(), equals(42));
      expect(() => failureResult.getOrThrow(), throwsA(isA<FailureInfo>()));
    });
  });

  group('Failures', () {
    test('NetworkFailure should have correct display message', () {
      const failure = NetworkFailure(
        message: 'Timeout',
        type: NetworkErrorType.connectionTimeout,
      );

      expect(failure.displayMessage, equals('Connection timeout, please check your network'));
    });

    test('AuthFailure should have correct display message', () {
      const failure = AuthFailure(
        message: 'Unauthorized',
        type: AuthErrorType.unauthorized,
      );

      expect(failure.displayMessage, equals('Authentication required, please login'));
    });

    test('ServerFailure should preserve message', () {
      const failure = ServerFailure(
        message: 'Internal server error',
        code: 500,
      );

      expect(failure.message, equals('Internal server error'));
      expect(failure.code, equals(500));
    });
  });
}