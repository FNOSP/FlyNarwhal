/// State of the server-side scheduled thumbnail scan, mirroring
/// `ThumbnailScanConfigResponse` (server >= 2.1.0).
library;

/// Live state of the scan worker.
enum ThumbnailScanState {
  idle,
  queued,
  running;

  static ThumbnailScanState fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'QUEUED':
        return ThumbnailScanState.queued;
      case 'RUNNING':
        return ThumbnailScanState.running;
      default:
        return ThumbnailScanState.idle;
    }
  }
}

/// Snapshot of the scan configuration plus the outcome of the last run.
/// All timestamps arrive as epoch millis; `null` means "never".
final class ThumbnailScanConfig {
  const ThumbnailScanConfig({
    required this.enabled,
    required this.cron,
    required this.dirs,
    required this.cronValid,
    this.cronError,
    this.nextRunTime,
    this.scanState = ThumbnailScanState.idle,
    this.currentDir,
    this.scannedFiles,
    this.lastRunTime,
    this.lastFinishTime,
    this.lastStatus = lastStatusNever,
    this.lastQueuedCount = 0,
    this.lastError,
    this.lastInaccessibleDirs = const [],
    this.lastRunId,
    this.lastRunSource,
    this.lastPhase,
    this.lastSourcedCount = 0,
    this.lastGeneratedCount = 0,
    this.lastFailedCount = 0,
  });

  static const String lastStatusNever = 'NEVER';
  static const String lastStatusQueued = 'QUEUED';
  static const String lastStatusRunning = 'RUNNING';
  /// Phases inside a run; the status stays RUNNING while either one is set.
  static const String phaseQueued = 'QUEUED';
  static const String phaseScanning = 'SCANNING';
  static const String phaseGenerating = 'GENERATING';
  static const String lastStatusSuccess = 'SUCCESS';
  static const String lastStatusFailed = 'FAILED';

  final bool enabled;
  final String cron;
  final List<String> dirs;

  /// Re-validation of the stored expression by the server.
  final bool cronValid;
  final String? cronError;

  /// Next scheduled fire time; null unless enabled with a valid cron.
  final DateTime? nextRunTime;

  final ThumbnailScanState scanState;

  /// In-memory progress while [scanState] is running.
  final String? currentDir;
  final int? scannedFiles;

  final DateTime? lastRunTime;
  final DateTime? lastFinishTime;

  /// NEVER / RUNNING / SUCCESS / FAILED.
  final String lastStatus;
  /// Videos this run needed sprites for (the ones it queued); see
  /// [lastSourcedCount] for everything it matched.
  final int lastQueuedCount;
  final String? lastError;

  /// Configured folders the last run could not open — missing, or created
  /// without granting this server access (server >= 2.1.0).
  final List<String> lastInaccessibleDirs;

  /// Id of the run the last-* fields describe; the trigger response and the
  /// run-status endpoint both carry it, so a poll can follow one exact run.
  final int? lastRunId;

  /// MANUAL / SCHEDULED.
  final String? lastRunSource;

  /// QUEUED / SCANNING / GENERATING, then SUCCESS or FAILED once closed.
  final String? lastPhase;

  /// Videos that run matched (sprites or not); how many of them needed
  /// generation; and how many of those it finished / failed.
  final int lastSourcedCount;
  final int lastGeneratedCount;
  final int lastFailedCount;

  /// The run is still working (queued on the worker, walking folders, or
  /// waiting for the sprites it queued).
  bool get lastRunWorking =>
      lastPhase == phaseQueued ||
      lastPhase == phaseScanning ||
      lastPhase == phaseGenerating;

  /// Generation progress: how many of the videos this run queued have been
  /// produced or have failed, out of how many it queued.
  int get lastRunDoneCount => lastGeneratedCount + lastFailedCount;

  /// QUEUED / RUNNING mean this run is still in flight.
  bool get lastRunInFlight =>
      lastStatus == lastStatusQueued || lastStatus == lastStatusRunning;

  bool get isBusy => scanState != ThumbnailScanState.idle;

  static ThumbnailScanConfig fromJson(Map<String, dynamic> json) {
    return ThumbnailScanConfig(
      enabled: json['enabled'] == true,
      cron: (json['cron'] as String?) ?? '',
      dirs: (json['dirs'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      cronValid: json['cronValid'] != false,
      cronError: json['cronError'] as String?,
      nextRunTime: _dateTimeFromMillis(json['nextRunTimeMs']),
      scanState: ThumbnailScanState.fromString(json['scanState'] as String?),
      currentDir: json['currentDir'] as String?,
      scannedFiles: (json['scannedFiles'] as num?)?.toInt(),
      lastRunTime: _dateTimeFromMillis(json['lastRunTimeMs']),
      lastFinishTime: _dateTimeFromMillis(json['lastFinishTimeMs']),
      lastStatus: (json['lastStatus'] as String?) ?? lastStatusNever,
      lastQueuedCount: (json['lastQueuedCount'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
      lastInaccessibleDirs: (json['lastInaccessibleDirs'] as List<dynamic>? ??
              const [])
          .whereType<String>()
          .toList(growable: false),
      lastRunId: (json['lastRunId'] as num?)?.toInt(),
      lastRunSource: json['lastRunSource'] as String?,
      lastPhase: json['lastPhase'] as String?,
      lastSourcedCount: (json['lastSourcedCount'] as num?)?.toInt() ?? 0,
      lastGeneratedCount: (json['lastGeneratedCount'] as num?)?.toInt() ?? 0,
      lastFailedCount: (json['lastFailedCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Request body of the save endpoint; the rest of the snapshot is read-only.
  Map<String, dynamic> toSaveJson() => <String, dynamic>{
        'enabled': enabled,
        'cron': cron,
        'dirs': dirs,
      };

  ThumbnailScanConfig copyWith({
    bool? enabled,
    String? cron,
    List<String>? dirs,
  }) {
    return ThumbnailScanConfig(
      enabled: enabled ?? this.enabled,
      cron: cron ?? this.cron,
      dirs: dirs ?? this.dirs,
      cronValid: cronValid,
      cronError: cronError,
      nextRunTime: nextRunTime,
      scanState: scanState,
      currentDir: currentDir,
      scannedFiles: scannedFiles,
      lastRunTime: lastRunTime,
      lastFinishTime: lastFinishTime,
      lastStatus: lastStatus,
      lastQueuedCount: lastQueuedCount,
      lastError: lastError,
      lastInaccessibleDirs: lastInaccessibleDirs,
      lastRunId: lastRunId,
      lastRunSource: lastRunSource,
      lastPhase: lastPhase,
      lastSourcedCount: lastSourcedCount,
      lastGeneratedCount: lastGeneratedCount,
      lastFailedCount: lastFailedCount,
    );
  }

  /// This config snapshot with the last-run block replaced by [run]'s.
  ///
  /// The run-status endpoint answers only the run's own fields; everything
  /// describing the schedule (cron, folders, next fire time, live worker
  /// state) stays exactly as the config snapshot had it.
  ThumbnailScanConfig mergeRun(ThumbnailScanConfig run) {
    return ThumbnailScanConfig(
      enabled: enabled,
      cron: cron,
      dirs: dirs,
      cronValid: cronValid,
      cronError: cronError,
      nextRunTime: nextRunTime,
      scanState: scanState,
      currentDir: currentDir,
      scannedFiles: scannedFiles,
      lastRunTime: run.lastRunTime,
      lastFinishTime: run.lastFinishTime,
      lastStatus: run.lastStatus,
      lastQueuedCount: run.lastQueuedCount,
      lastError: run.lastError,
      lastInaccessibleDirs: run.lastInaccessibleDirs,
      lastRunId: run.lastRunId,
      lastRunSource: run.lastRunSource,
      lastPhase: run.lastPhase,
      lastSourcedCount: run.lastSourcedCount,
      lastGeneratedCount: run.lastGeneratedCount,
      lastFailedCount: run.lastFailedCount,
    );
  }

  static DateTime? _dateTimeFromMillis(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }
}

/// Result of the stateless cron validation + upcoming-runs preview endpoint.
final class CronPreviewResult {
  const CronPreviewResult({
    required this.valid,
    this.error,
    this.nextRuns = const [],
  });

  final bool valid;
  final String? error;
  final List<DateTime> nextRuns;

  static CronPreviewResult fromJson(Map<String, dynamic> json) {
    return CronPreviewResult(
      valid: json['valid'] == true,
      error: json['error'] as String?,
      nextRuns: (json['nextRuns'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((ms) => DateTime.fromMillisecondsSinceEpoch(ms.toInt()))
          .toList(growable: false),
    );
  }
}
