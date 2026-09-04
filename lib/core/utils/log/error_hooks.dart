import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'app_talker.dart';
import 'error_describer.dart';

/// Registers global error hooks so uncaught exceptions are routed through
/// [AppTalker] with readable, obfuscation-safe descriptions.
///
/// This is intended to be called once during app bootstrap, before `runApp`.
/// The hooks are safe to register repeatedly; subsequent calls replace the
/// previously installed handlers.
Future<void> setupErrorHooks(Talker talker) async {
  _setupFlutterErrorHook();
  _setupPlatformDispatcherErrorHook();
  _setupIsolateErrorListener();
}

void Function(FlutterErrorDetails)? _originalFlutterErrorHandler;
bool Function(Object, StackTrace)? _originalPlatformErrorHandler;

/// Installs a [FlutterError.onError] handler that logs framework errors through
/// [AppTalker] and then forwards to the original handler (usually dumping to
/// the console in debug builds).
void _setupFlutterErrorHook() {
  final original = FlutterError.onError;
  if (original == _wrappedFlutterErrorHandler) {
    return;
  }
  _originalFlutterErrorHandler = original;
  FlutterError.onError = _wrappedFlutterErrorHandler;
}

void _wrappedFlutterErrorHandler(FlutterErrorDetails details) {
  try {
    final error = details.exception;
    final stackTrace = details.stack;
    final message = ErrorDescriber.formatUncaughtError(error, stackTrace);
    AppTalker.error(
      'FlutterError',
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  } catch (loggingError, loggingStack) {
    // If logging itself fails, at least try to keep the original handler.
    _safeLogFailure('FlutterError hook failed', loggingError, loggingStack);
  } finally {
    _originalFlutterErrorHandler?.call(details);
  }
}

/// Installs a [PlatformDispatcher.instance.onError] handler that catches
/// uncaught asynchronous errors and platform channel errors.
///
/// Returning `true` tells the engine the error has been handled so it does not
/// propagate to the default red screen / crash handler.
void _setupPlatformDispatcherErrorHook() {
  final original = PlatformDispatcher.instance.onError;
  if (original == _wrappedPlatformErrorHandler) {
    return;
  }
  _originalPlatformErrorHandler = original;
  PlatformDispatcher.instance.onError = _wrappedPlatformErrorHandler;
}

bool _wrappedPlatformErrorHandler(Object error, StackTrace stackTrace) {
  try {
    final message = ErrorDescriber.formatUncaughtError(error, stackTrace);
    AppTalker.error(
      'PlatformDispatcher',
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  } catch (loggingError, loggingStack) {
    _safeLogFailure(
      'PlatformDispatcher hook failed',
      loggingError,
      loggingStack,
    );
  } finally {
    // Forward to the previously installed handler so existing behavior is
    // preserved; then mark the error as handled.
    _originalPlatformErrorHandler?.call(error, stackTrace);
  }
  return true;
}

/// Listens for uncaught errors in the current isolate.
///
/// This is a last-resort safety net for errors that slip past the framework
/// and platform dispatchers.
void _setupIsolateErrorListener() {
  Isolate.current.addErrorListener(
    RawReceivePort((dynamic pair) {
      if (pair is! List<dynamic> || pair.length < 2) {
        return;
      }
      final error = pair[0];
      final stackTrace = pair[1];
      try {
        final stack = stackTrace is StackTrace ? stackTrace : StackTrace.empty;
        final message = ErrorDescriber.formatUncaughtError(error, stack);
        AppTalker.error(
          'Isolate',
          message: message,
          error: error,
          stackTrace: stack,
        );
      } catch (loggingError, loggingStack) {
        _safeLogFailure('Isolate hook failed', loggingError, loggingStack);
      }
    }).sendPort,
  );
}

/// Emergency fallback when the main error hooks fail. It uses the engine's
/// native [debugPrint] directly to avoid any recursion back into [AppTalker].
void _safeLogFailure(String context, Object error, StackTrace stackTrace) {
  try {
    debugPrint('$context: $error');
    debugPrint(stackTrace.toString());
  } catch (_) {
    // Nothing more we can do; do not let hook failures crash the app.
  }
}
