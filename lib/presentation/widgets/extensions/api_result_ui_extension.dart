import '../../../core/network/api_result.dart';

/// Extension on ApiResult for UI handling
extension ApiResultUIExtension<T> on ApiResult<T> {
  /// Handle result with callbacks for UI
  R whenUI<R>({
    required R Function(T data) success,
    required R Function(String message, FailureInfo? failure) error,
  }) {
    return when(
      success: success,
      failure: (failure) => error(failure.displayMessage, failure),
    );
  }

  /// Handle result with loading state support
  AsyncValueUIResult<T> toAsyncValue() {
    return when(
      success: (data) => AsyncValueUISuccess(data),
      failure: (failure) => AsyncValueUIError(failure.displayMessage, failure),
    );
  }

  /// Get error message if any
  String? get errorMessage => failureOrNull?.displayMessage;
}

/// Async value result for UI state management
sealed class AsyncValueUIResult<T> {
  const AsyncValueUIResult();
}

class AsyncValueUISuccess<T> extends AsyncValueUIResult<T> {
  final T data;
  const AsyncValueUISuccess(this.data);
}

class AsyncValueUIError<T> extends AsyncValueUIResult<T> {
  final String message;
  final FailureInfo? failure;
  const AsyncValueUIError(this.message, [this.failure]);
}

/// Extension on FailureInfo for user-friendly messages
extension FailureInfoUIExtension on FailureInfo {
  /// Check if error is retryable
  bool get isRetryable {
    return true;
  }

  /// Get error icon type for UI
  ErrorIconType get iconType {
    return ErrorIconType.unknown;
  }
}

/// Error icon types for UI
enum ErrorIconType {
  network,
  server,
  auth,
  storage,
  unknown,
}