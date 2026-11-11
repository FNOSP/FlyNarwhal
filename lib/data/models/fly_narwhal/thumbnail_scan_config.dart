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
    this.lastScannedCount = 0,
    this.lastQueuedCount = 0,
    this.lastError,
  });

  static const String lastStatusNever = 'NEVER';
  static const String lastStatusRunning = 'RUNNING';
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
  final int lastScannedCount;
  final int lastQueuedCount;
  final String? lastError;

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
      lastScannedCount: (json['lastScannedCount'] as num?)?.toInt() ?? 0,
      lastQueuedCount: (json['lastQueuedCount'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
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
      lastScannedCount: lastScannedCount,
      lastQueuedCount: lastQueuedCount,
      lastError: lastError,
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
