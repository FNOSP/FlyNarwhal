import 'package:flutter/widgets.dart';
import '../../../core/network/api_result.dart';

/// Mixin for handling ApiResult in widgets/state notifiers
mixin ApiResultHandler {
  /// Handle ApiResult and return appropriate UI action
  void handleApiResult<T>(
    ApiResult<T> result, {
    required void Function(T data) onSuccess,
    void Function(String message, FailureInfo failure)? onError,
    void Function()? onFinally,
  }) {
    try {
      result.when(
        success: (data) => onSuccess(data),
        failure: (failure) {
          onError?.call(failure.displayMessage, failure);
        },
      );
    } finally {
      onFinally?.call();
    }
  }

  /// Handle ApiResult with loading state
  Future<void> handleApiResultAsync<T>(
    Future<ApiResult<T>> Function() request, {
    required void Function(T data) onSuccess,
    void Function(String message, FailureInfo failure)? onError,
    void Function()? onLoading,
    void Function()? onFinally,
  }) async {
    onLoading?.call();
    try {
      final result = await request();
      handleApiResult(
        result,
        onSuccess: onSuccess,
        onError: onError,
      );
    } finally {
      onFinally?.call();
    }
  }
}

/// Helper class for building UI from ApiResult
class ApiResultBuilder<T> {
  final ApiResult<T> _result;

  ApiResultBuilder(this._result);

  /// Build widget based on result state
  Widget build({
    required Widget Function(T data) success,
    Widget Function(String message, FailureInfo? failure)? error,
    Widget Function()? loading,
  }) {
    return _result.when(
      success: success,
      failure: (failure) {
        if (error != null) {
          return error(failure.displayMessage, failure);
        }
        return _buildDefaultError(failure);
      },
    );
  }

  Widget _buildDefaultError(FailureInfo failure) {
    return Center(
      child: Text('Error: ${failure.displayMessage}'),
    );
  }
}