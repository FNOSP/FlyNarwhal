import 'package:talker/talker.dart';

/// Custom talker log that keeps business tag separate from log message.
class AppTaggedTalkerLog extends TalkerLog {
  AppTaggedTalkerLog({
    required this.tag,
    required String message,
    required LogLevel level,
    Object? exception,
    StackTrace? stackTrace,
  }) : super(
          message,
          logLevel: level,
          exception: exception is Error ? null : exception,
          error: exception is Error ? exception : null,
          stackTrace: stackTrace,
        );

  final String tag;

  @override
  String generateTextMessage({
    TimeFormat timeFormat = TimeFormat.timeAndSeconds,
  }) {
    final buffer = StringBuffer('[$tag] ${message ?? ''}');

    if (error != null) {
      buffer.write('\nError: $error');
    }

    if (exception != null) {
      buffer.write('\nException: $exception');
    }

    if (stackTrace != null && stackTrace != StackTrace.empty) {
      buffer.write('\nStackTrace: $stackTrace');
    }

    return buffer.toString();
  }
}
