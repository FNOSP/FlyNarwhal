abstract class TalkerAsyncDispatcher {
  Future<void> initialize();

  bool enqueueDesktopConsoleLine(String line);

  bool enqueueFileLine({
    required String directoryPath,
    required String fileName,
    required String line,
  });

  bool enqueueCleanOldLogs({
    required String directoryPath,
    required int retentionDays,
    required String filePrefix,
  });

  Future<void> dispose();
}

class _NoopTalkerAsyncDispatcher implements TalkerAsyncDispatcher {
  @override
  Future<void> initialize() async {}

  @override
  bool enqueueDesktopConsoleLine(String line) => false;

  @override
  bool enqueueFileLine({
    required String directoryPath,
    required String fileName,
    required String line,
  }) {
    return false;
  }

  @override
  bool enqueueCleanOldLogs({
    required String directoryPath,
    required int retentionDays,
    required String filePrefix,
  }) {
    return false;
  }

  @override
  Future<void> dispose() async {}
}

TalkerAsyncDispatcher createPlatformTalkerAsyncDispatcher() =>
    _NoopTalkerAsyncDispatcher();
