import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

/// Formats errors and stack traces into human-readable strings that survive
/// release obfuscation.
///
/// Release builds pass `--obfuscate`, which replaces class names with short
/// mangled identifiers like `gOa`. Calling `error.toString()` or relying on
/// `runtimeType` in logs therefore produces useless output such as
/// `Instance of 'gOa'`. This utility extracts stable, non-obfuscated fields
/// from known exception types before they reach the logger.
///
/// The functions intentionally avoid `runtimeType.toString()` and only use
/// string fields/constants that are preserved by the obfuscator.
abstract final class ErrorDescriber {
  ErrorDescriber._();

  static const int _maxMessageLength = 500;

  /// Describe an arbitrary error using only fields that are not mangled by
  /// obfuscation.
  static String describe(Object? error) {
    if (error == null) {
      return 'null';
    }

    if (error is DioException) {
      return _describeDioException(error);
    }

    if (error is SocketException) {
      return _describeSocketException(error);
    }

    if (error is FormatException) {
      return _describeFormatException(error);
    }

    if (error is AssertionError) {
      return _describeAssertionError(error);
    }

    if (error is ArgumentError) {
      return _describeArgumentError(error);
    }

    if (error is StateError) {
      return 'StateError: ${error.message}';
    }

    if (error is RangeError) {
      return 'RangeError: ${error.message}';
    }

    if (error is NoSuchMethodError) {
      return 'NoSuchMethodError: ${_truncate(error.toString())}';
    }

    if (error is TypeError) {
      return 'TypeError: ${_truncate(error.toString())}';
    }

    // Fallback: this is the only place where obfuscated class names can leak.
    return _truncate(error.toString());
  }

  static String _describeDioException(DioException error) {
    final buffer = StringBuffer('DioException');
    buffer.write(' method=${error.requestOptions.method}');
    buffer.write(' path=${error.requestOptions.path}');
    buffer.write(' type=${error.type.name}');
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      buffer.write(' status=$statusCode');
    }
    if (error.message != null && error.message!.isNotEmpty) {
      buffer.write(' message=${error.message}');
    }
    if (error.error != null) {
      buffer.write(' cause=${describe(error.error)}');
    }
    return _truncate(buffer.toString());
  }

  static String _describeSocketException(SocketException error) {
    final osError = error.osError;
    final osErrorText = osError == null ? '' : ' osError=$osError';
    return _truncate('SocketException: ${error.message}$osErrorText');
  }

  static String _describeFormatException(FormatException error) {
    final buffer = StringBuffer('FormatException: ${error.message}');
    final source = error.source;
    if (source != null) {
      final sourceText = source.toString();
      buffer.write(
        ' source=${sourceText.length > 100 ? '${sourceText.substring(0, 100)}...' : sourceText}',
      );
    }
    final offset = error.offset;
    if (offset != null) {
      buffer.write(' offset=$offset');
    }
    return _truncate(buffer.toString());
  }

  static String _describeAssertionError(AssertionError error) {
    return 'AssertionError: ${error.message}';
  }

  static String _describeArgumentError(ArgumentError error) {
    final buffer = StringBuffer('ArgumentError: ${error.message}');
    final name = error.name;
    if (name != null && name.isNotEmpty) {
      buffer.write(' name=$name');
    }
    final invalidValue = error.invalidValue;
    if (invalidValue != null) {
      buffer.write(' invalidValue=$invalidValue');
    }
    return _truncate(buffer.toString());
  }

  /// Returns a trimmed stack trace string, keeping the top [maxFrames] frames.
  static String describeStackTrace(StackTrace? stackTrace, {int maxFrames = 20}) {
    if (stackTrace == null || stackTrace == StackTrace.empty) {
      return '';
    }
    final lines = stackTrace.toString().trim().split('\n');
    if (lines.length <= maxFrames) {
      return lines.join('\n');
    }
    return '${lines.take(maxFrames).join('\n')}\n... (${lines.length - maxFrames} more frames)';
  }

  /// Builds a single multi-line message containing both the error description
  /// and a trimmed stack trace.
  static String formatUncaughtError(Object? error, StackTrace? stackTrace) {
    final buffer = StringBuffer(describe(error));
    final stackText = describeStackTrace(stackTrace);
    if (stackText.isNotEmpty) {
      buffer.write('\n$stackText');
    }
    return buffer.toString();
  }

  static String _truncate(String value) {
    if (value.length <= _maxMessageLength) {
      return value;
    }
    return '${value.substring(0, _maxMessageLength)}...';
  }
}
