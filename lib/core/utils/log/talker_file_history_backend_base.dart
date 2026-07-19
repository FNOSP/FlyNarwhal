abstract class TalkerFileHistoryBackend {
  void cleanOldLogs({
    required String directoryPath,
    required int retentionDays,
    required String filePrefix,
  });

  void appendLine({
    required String directoryPath,
    required String fileName,
    required String line,
  });
}
