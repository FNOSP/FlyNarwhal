import 'dart:io';

import 'package:path/path.dart' as path;

import 'talker_file_history_backend_base.dart';

class _IoTalkerFileHistoryBackend implements TalkerFileHistoryBackend {
  @override
  void cleanOldLogs({
    required String directoryPath,
    required int retentionDays,
    required String filePrefix,
  }) {
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

      final datePart =
          fileName.substring(filePrefix.length, fileName.length - '.log'.length);
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
