import 'package:talker/talker.dart';

/// Shared formatter for console and file outputs.
class AppTalkerMessageFormatter {
  AppTalkerMessageFormatter._();

  static final AnsiPen _timePen = AnsiPen()..white();
  static final AnsiPen _tagPen = AnsiPen()..cyan();

  static String formatConsoleMessage(
    String rawMessage,
    LogLevel level, {
    required bool enableColors,
  }) {
    final normalizedMessage = _normalizeMessage(rawMessage);
    final lines = normalizedMessage.split('\n');
    final firstLine = lines.first;
    final remainingLines = lines.skip(1).map((line) => '  $line').toList();
    final timestamp = _formatTimestamp(DateTime.now());
    final levelLabel = level.name.toUpperCase().padRight(7);
    final formattedFirstLine = enableColors
        ? '${_timePen.write('[$timestamp]')} ${_levelPen(level).write('[$levelLabel]')} ${_colorizeTag(firstLine)}'
        : '[$timestamp] [$levelLabel] $firstLine';

    if (remainingLines.isEmpty) {
      return formattedFirstLine;
    }

    return <String>[formattedFirstLine, ...remainingLines].join('\n');
  }

  static String formatFileMessage(TalkerData data) {
    final normalizedMessage =
        _normalizeMessage(
      data.generateTextMessage(timeFormat: TimeFormat.timeAndSeconds),
    );
    final lines = normalizedMessage.split('\n');
    final timestamp = _formatTimestamp(data.time);
    final level = (data.logLevel ?? LogLevel.info).name.toUpperCase().padRight(7);
    final firstLine = '[$timestamp] [$level] ${lines.first}';

    if (lines.length == 1) {
      return firstLine;
    }

    final remainingLines = lines.skip(1).map((line) => '  $line');
    return <String>[firstLine, ...remainingLines].join('\n');
  }

  static String _normalizeMessage(String rawMessage) {
    final normalized = rawMessage.trim();
    if (normalized.isEmpty) {
      return '[App]';
    }

    final talkerMatch = RegExp(
      r'^\[([^\]]+)\]\s+\|\s+[^|]+\s+\|\s*([\s\S]+)$',
      multiLine: false,
    ).firstMatch(normalized);
    if (talkerMatch != null) {
      final title = talkerMatch.group(1) ?? 'Talker';
      final message = talkerMatch.group(2) ?? '';
      final nestedDioMessage = _normalizeDioMessage(message);
      if (nestedDioMessage != null) {
        return nestedDioMessage;
      }
      return '[${_normalizeTag(title)}] $message';
    }

    final dioMessage = _normalizeDioMessage(normalized);
    if (dioMessage != null) {
      return dioMessage;
    }

    if (normalized.startsWith('[')) {
      return normalized;
    }

    return '[App] $normalized';
  }

  static String _normalizeTag(String title) {
    final normalized = title.trim();
    if (normalized.startsWith('http-request')) {
      return 'DioRequest';
    }
    if (normalized.startsWith('http-response')) {
      return 'DioResponse';
    }
    if (normalized.startsWith('http-error')) {
      return 'DioError';
    }
    if (normalized.isEmpty) {
      return 'App';
    }
    return normalized;
  }

  static String? _normalizeDioMessage(String rawMessage) {
    final dioMatch = RegExp(
      r'^\[(http-request|http-response|http-error)\]\s*([\s\S]*)$',
      caseSensitive: false,
      multiLine: false,
    ).firstMatch(rawMessage.trim());
    if (dioMatch == null) {
      return null;
    }

    final kind = dioMatch.group(1) ?? '';
    final message = dioMatch.group(2)?.trimLeft() ?? '';
    return '[${_normalizeTag(kind)}] $message';
  }

  static String _formatTimestamp(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  static AnsiPen _levelPen(LogLevel level) {
    switch (level) {
      case LogLevel.critical:
      case LogLevel.error:
        return AnsiPen()..red();
      case LogLevel.warning:
        return AnsiPen()..yellow();
      case LogLevel.info:
        return AnsiPen()..green();
      case LogLevel.verbose:
        return AnsiPen()..white();
      case LogLevel.debug:
        return AnsiPen()..blue();
    }
  }

  static String _colorizeTag(String line) {
    final match = RegExp(r'^(\[[^\]]+\])(.*)$').firstMatch(line);
    if (match == null) {
      return line;
    }

    final tag = match.group(1) ?? '';
    final message = match.group(2) ?? '';
    return '${_tagPen.write(tag)}$message';
  }
}

/// Logger formatter that keeps talker output on a single clean text shape.
class AppTalkerFormatter implements LoggerFormatter {
  const AppTalkerFormatter();

  @override
  String fmt(LogDetails details, TalkerLoggerSettings settings) {
    return AppTalkerMessageFormatter.formatConsoleMessage(
      details.message?.toString() ?? '',
      details.level,
      enableColors: settings.enableColors,
    );
  }
}
