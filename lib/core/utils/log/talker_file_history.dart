import 'package:talker/talker.dart';

import 'talker_file_history_backend_base.dart';
import 'talker_file_history_backend.dart';
import 'talker_formatter.dart';
import 'talker_log_sanitizer.dart';

/// Custom talker history that keeps memory history and desktop file logs aligned.
class TalkerFileHistory implements TalkerHistory {
  TalkerFileHistory({
    required this.settings,
    required this.sanitizer,
    this.directoryPath,
    this.filePrefix = 'FlyNarwhal-',
    this.retentionDays = 3,
    TalkerFileHistoryBackend? backend,
  })  : _backend = backend ?? createTalkerFileHistoryBackend(),
        _inMemoryHistory = DefaultTalkerHistory(settings) {
    if (directoryPath != null && directoryPath!.isNotEmpty) {
      _backend.cleanOldLogs(
        directoryPath: directoryPath!,
        retentionDays: retentionDays,
        filePrefix: filePrefix,
      );
    }
  }

  final TalkerSettings settings;
  final TalkerLogSanitizer sanitizer;
  final String? directoryPath;
  final String filePrefix;
  final int retentionDays;
  final DefaultTalkerHistory _inMemoryHistory;
  final TalkerFileHistoryBackend _backend;

  @override
  List<TalkerData> get history => _inMemoryHistory.history;

  @override
  void clean() {
    _inMemoryHistory.clean();
  }

  @override
  void write(TalkerData data) {
    _inMemoryHistory.write(data);
    if (!settings.useHistory || directoryPath == null || directoryPath!.isEmpty) {
      return;
    }

    try {
      final fileName = '$filePrefix${_formatDate(data.time)}.log';
      final formatted = AppTalkerMessageFormatter.formatFileMessage(data);
      final sanitized = sanitizer.sanitize(formatted);

      // Write-through keeps the file history consistent with talker's memory history.
      _backend.appendLine(
        directoryPath: directoryPath!,
        fileName: fileName,
        line: sanitized,
      );
    } catch (_) {
      // Ignore file logging failures to avoid impacting business flow.
    }
  }

  String _formatDate(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
