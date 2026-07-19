import 'talker_file_history_backend_base.dart';

class _NoopTalkerFileHistoryBackend implements TalkerFileHistoryBackend {
  @override
  void appendLine({
    required String directoryPath,
    required String fileName,
    required String line,
  }) {}

  @override
  void cleanOldLogs({
    required String directoryPath,
    required int retentionDays,
    required String filePrefix,
  }) {}
}

TalkerFileHistoryBackend createPlatformTalkerFileHistoryBackend() =>
    _NoopTalkerFileHistoryBackend();
