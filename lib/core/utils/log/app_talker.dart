import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'talker_async_dispatcher.dart';
import 'talker_file_history.dart';
import 'talker_formatter.dart';
import 'talker_log_sanitizer.dart';
import 'talker_log_types.dart';

/// Shared talker entrypoint used across the whole app.
class AppTalker {
  AppTalker._();

  static const TalkerLogSanitizer _sanitizer = TalkerLogSanitizer();
  static TalkerAsyncDispatcher _dispatcher = sharedTalkerAsyncDispatcher;
  static Talker? _instance;
  static bool _desktopAsyncOutputEnabled = false;
  static Future<String?> Function()? _logDirectoryResolverOverride;

  static Talker get instance => _instance ??= _createFallbackTalker();

  static Future<Talker> initialize() async {
    if (_instance != null) {
      return _instance!;
    }

    // Start desktop log I/O off the main isolate before wiring Talker outputs.
    try {
      await _dispatcher.initialize();
      _desktopAsyncOutputEnabled = true;
    } catch (_) {
      _desktopAsyncOutputEnabled = false;
    }

    final logDirectoryPath = await _resolveLogDirectoryPath();
    final logger = TalkerLogger(
      formatter: const AppTalkerFormatter(),
      output: _outputToConsole,
      settings: TalkerLoggerSettings(
        enableColors: !kIsWeb,
        level: LogLevel.info,
      ),
    );
    final settings = TalkerSettings(
      timeFormat: TimeFormat.timeAndSeconds,
      useHistory: true,
      useConsoleLogs: true,
      titles: {
        TalkerKey.httpRequest: 'DioRequest',
        TalkerKey.httpResponse: 'DioResponse',
        TalkerKey.httpError: 'DioError',
      },
    );
    final history = TalkerFileHistory(
      settings: settings,
      sanitizer: _sanitizer,
      directoryPath: logDirectoryPath,
    );

    _instance = Talker(
      logger: logger,
      settings: settings,
      history: history,
    );
    return _instance!;
  }

  static void verbose(String tag, String message) {
    _log(tag: tag, message: message, level: LogLevel.verbose);
  }

  static void debug(String tag, String message) {
    _log(tag: tag, message: message, level: LogLevel.debug);
  }

  static void info(String tag, String message) {
    _log(tag: tag, message: message, level: LogLevel.info);
  }

  static void warning(String tag, String message) {
    _log(tag: tag, message: message, level: LogLevel.warning);
  }

  static void critical(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      tag: tag,
      message: message,
      level: LogLevel.critical,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(
    String tag, {
    required Object error,
    StackTrace? stackTrace,
    String? message,
  }) {
    _log(
      tag: tag,
      message: message ?? error.toString(),
      level: LogLevel.error,
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Centralize all app logs through a single custom Talker log model.
  static void _log({
    required String tag,
    required String message,
    required LogLevel level,
    Object? error,
    StackTrace? stackTrace,
  }) {
    instance.logCustom(
      AppTaggedTalkerLog(
        tag: tag,
        message: message,
        level: level,
        exception: error,
        stackTrace: stackTrace,
      ),
    );
  }

  static Future<String?> _resolveLogDirectoryPath() async {
    final overrideResolver = _logDirectoryResolverOverride;
    if (overrideResolver != null) {
      return overrideResolver();
    }

    if (kIsWeb || !_isDesktopPlatform()) {
      return null;
    }

    final supportDirectory = await getApplicationSupportDirectory();
    return path.join(supportDirectory.path, 'logs');
  }

  static bool _isDesktopPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  static void _outputToConsole(String message) {
    if (kIsWeb) {
      // ignore: avoid_print
      print(message);
      return;
    }

    // Route desktop logs through the async worker when it is available.
    if (_isDesktopPlatform() &&
        _desktopAsyncOutputEnabled &&
        _dispatcher.enqueueDesktopConsoleLine(message)) {
      return;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        developer.log(message, name: 'Talker');
        break;
      case TargetPlatform.windows:
        // Windows debug output can synchronously block when the debugger pipe
        // applies backpressure, so file history remains the fallback log sink.
        break;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        debugPrint(message);
        break;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        debugPrint(message);
        break;
    }
  }

  @visibleForTesting
  static void debugSetDispatcherForTest(TalkerAsyncDispatcher dispatcher) {
    _dispatcher = dispatcher;
    _desktopAsyncOutputEnabled = false;
  }

  @visibleForTesting
  static void debugSetLogDirectoryResolverForTest(
    Future<String?> Function()? resolver,
  ) {
    _logDirectoryResolverOverride = resolver;
  }

  @visibleForTesting
  static Future<void> debugResetForTest() async {
    _instance = null;
    _desktopAsyncOutputEnabled = false;
    _logDirectoryResolverOverride = null;
    await _dispatcher.dispose();
    _dispatcher = sharedTalkerAsyncDispatcher;
  }

  static Talker _createFallbackTalker() {
    return Talker(
      logger: TalkerLogger(
        formatter: const AppTalkerFormatter(),
        output: _outputToConsole,
        settings: TalkerLoggerSettings(
          enableColors: !kIsWeb,
          level: LogLevel.info,
        ),
      ),
      settings: TalkerSettings(
        timeFormat: TimeFormat.timeAndSeconds,
        useHistory: true,
        useConsoleLogs: true,
        titles: {
          TalkerKey.httpRequest: 'DioRequest',
          TalkerKey.httpResponse: 'DioResponse',
          TalkerKey.httpError: 'DioError',
        },
      ),
    );
  }
}
