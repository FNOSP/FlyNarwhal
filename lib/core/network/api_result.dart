/// Sealed class for API result handling
/// Use pattern matching to handle Success and Failure cases
sealed class ApiResult<T> {
  const ApiResult();

  /// Check if result is success
  bool get isSuccess => this is Success<T>;

  /// Check if result is failure
  bool get isFailure => this is ResultFailure<T>;

  /// Get data if success, null otherwise
  T? get dataOrNull => switch (this) {
        Success<T>(data: final d) => d,
        ResultFailure<T>() => null,
      };

  /// Get failure info if failure, null otherwise
  FailureInfo? get failureOrNull => switch (this) {
        Success<T>() => null,
        ResultFailure<T>(info: final f) => f,
      };

  /// Transform success data to another type
  ApiResult<R> map<R>(R Function(T data) transform) => switch (this) {
        Success<T>(data: final d) => Success(transform(d)),
        ResultFailure<T>(info: final f) => ResultFailure(f),
      };

  /// Transform success data asynchronously
  Future<ApiResult<R>> asyncMap<R>(
    Future<R> Function(T data) transform,
  ) async {
    return switch (this) {
      Success<T>(data: final d) => Success(await transform(d)),
      ResultFailure<T>(info: final f) => ResultFailure(f),
    };
  }

  /// Execute callback based on result type
  R when<R>({
    required R Function(T data) success,
    required R Function(FailureInfo failure) failure,
  }) {
    return switch (this) {
      Success<T>(data: final d) => success(d),
      ResultFailure<T>(info: final f) => failure(f),
    };
  }

  /// Execute callback based on result type with async support
  Future<R> whenAsync<R>({
    required Future<R> Function(T data) success,
    required Future<R> Function(FailureInfo failure) failure,
  }) async {
    return switch (this) {
      Success<T>(data: final d) => await success(d),
      ResultFailure<T>(info: final f) => await failure(f),
    };
  }

  /// Get data or throw failure
  T getOrThrow() => switch (this) {
        Success<T>(data: final d) => d,
        ResultFailure<T>(info: final f) => throw f,
      };

  /// Get data or return default value
  T getOrElse(T defaultValue) => switch (this) {
        Success<T>(data: final d) => d,
        ResultFailure<T>() => defaultValue,
      };

  /// Get data or compute default value
  T getOrElseCompute(T Function(FailureInfo failure) compute) => switch (this) {
        Success<T>(data: final d) => d,
        ResultFailure<T>(info: final f) => compute(f),
      };
}

/// Success result containing data
class Success<T> extends ApiResult<T> {
  final T data;

  const Success(this.data);
}

/// Failure result containing error information
class ResultFailure<T> extends ApiResult<T> {
  final FailureInfo info;

  const ResultFailure(this.info);
}

/// Failure information wrapper
class FailureInfo {
  final String message;
  final int? code;
  final String displayMessage;

  const FailureInfo({
    required this.message,
    this.code,
    required this.displayMessage,
  });

  /// Create from an exception message
  factory FailureInfo.fromMessage(String message) {
    return FailureInfo(
      message: message,
      displayMessage: message,
    );
  }
}