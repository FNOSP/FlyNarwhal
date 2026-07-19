import 'dart:io';

import 'package:path/path.dart' as path;

import 'talker_async_dispatcher.dart';
import 'talker_file_history_backend_base.dart';

class _IoTalkerFileHistoryBackend implements TalkerFileHistoryBackend {
  _IoTalkerFileHistoryBackend({
    TalkerAsyncDispatcher? dispatcher,
  }) : _dispatcher = dispatcher ?? sharedTalkerAsyncDispatcher;

  final TalkerAsyncDispatcher _dispatcher;

  @override
  void cleanOldLogs({
    required String directoryPath,
    required int retentionDays,
    required String filePrefix,
  }) {
    // Fall back to direct cleanup only when the async worker is unavailable.
    if (_dispatcher.enqueueCleanOldLogs(
      directoryPath: directoryPath,
      retentionDays: retentionDays,
      filePrefix: filePrefix,
    )) {
      return;
    }

    final logDirectory = Directory(directoryPath);
    if (!logDirectory.existsSync()) {
      logDirectory.createSync(recursive: true);
      return;
    }

    final today = DateTime.now();

    // Clean only files that match the expected rolling naming convention.
    for (final entity in logDirectory.listSync()) {
      if (entity is! File) {
        continue;
      }

      final fileName = path.basename(entity.path);
      if (!fileName.startsWith(filePrefix) || !fileName.endsWith('.log')) {
        continue;
      }

      final datePart = fileName.substring(
          filePrefix.length, fileName.length - '.log'.length);
      final fileDate = DateTime.tryParse(datePart);
      if (fileDate == null) {
        continue;
      }

      if (today.difference(fileDate).inDays >= retentionDays) {
        entity.deleteSync();
      }
    }
  }

  @override
  void appendLine({
    required String directoryPath,
    required String fileName,
    required String line,
  }) {
    // Fall back to direct writes only when the async worker is unavailable.
    if (_dispatcher.enqueueFileLine(
      directoryPath: directoryPath,
      fileName: fileName,
      line: line,
    )) {
      return;
    }

    final logDirectory = Directory(directoryPath);
    if (!logDirectory.existsSync()) {
      logDirectory.createSync(recursive: true);
    }

    final file = File(path.join(directoryPath, fileName));
    file.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  }
}

TalkerFileHistoryBackend createPlatformTalkerFileHistoryBackend() =>
    _IoTalkerFileHistoryBackend();
