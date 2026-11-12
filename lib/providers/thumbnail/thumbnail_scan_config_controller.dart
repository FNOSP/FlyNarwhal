import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../../data/models/fly_narwhal/index.dart';
import '../../l10n/generated/app_localizations.dart';

class ThumbnailScanConfigState {
  /// Server-sourced config + live scan state. The server is the single source
  /// of truth; the client keeps no local copy.
  final AsyncValue<ThumbnailScanConfig> config;
  final bool isSaving;
  final bool isTriggering;
  final String? loadError;
  /// The mutation failure as [ApiResult] reported it, before server reasons are
  /// localized — callers match on it when the original wording matters.
  final String? actionErrorRaw;
  final String? actionError;

  const ThumbnailScanConfigState({
    this.config = const AsyncLoading<ThumbnailScanConfig>(),
    this.isSaving = false,
    this.isTriggering = false,
    this.loadError,
    this.actionErrorRaw,
    this.actionError,
  });

  ThumbnailScanConfigState copyWith({
    AsyncValue<ThumbnailScanConfig>? config,
    bool? isSaving,
    bool? isTriggering,
    String? loadError,
    bool clearLoadError = false,
    String? actionErrorRaw,
    String? actionError,
    bool clearActionError = false,
  }) {
    return ThumbnailScanConfigState(
      config: config ?? this.config,
      isSaving: isSaving ?? this.isSaving,
      isTriggering: isTriggering ?? this.isTriggering,
      loadError: clearLoadError ? null : loadError ?? this.loadError,
      actionErrorRaw:
          clearActionError ? null : actionErrorRaw ?? this.actionErrorRaw,
      actionError: clearActionError ? null : actionError ?? this.actionError,
    );
  }
}

/// Loads and mutates the scheduled thumbnail scan configuration on the
/// fly-narwhal server (>= 2.1.0). Mutations reload the snapshot afterwards so
/// the dialog always mirrors stored state, and the dialog polls [load] while
/// a scan is queued/running to follow its progress.
class ThumbnailScanConfigController
    extends StateNotifier<ThumbnailScanConfigState> {
  final FlyNarwhalRemoteDataSource _dataSource;
  final AppLocalizations Function() _getL10n;

  ThumbnailScanConfigController(this._dataSource,
      {required AppLocalizations Function() getL10n})
      : _getL10n = getL10n,
        super(const ThumbnailScanConfigState());

  /// Server rejection prefix of a manual trigger naming folders that are not saved.
  static const String scanDirsNotSavedPrefix = 'scan directories are not saved: ';

  /// Task failure of a file the server cannot read: its path follows the colon.
  static const String scanNotFoundPrefix =
      'media file not found or unreadable: ';

  /// The file path of a [scanNotFoundPrefix] message, or the message unchanged.
  static String scanNotFoundPath(String error) =>
      error.startsWith(scanNotFoundPrefix)
          ? error.substring(scanNotFoundPrefix.length).trim()
          : error.trim();

  Future<void> load() async {
    // Keep the previous values as the loading state's data so a poll or a
    // post-save reload never blanks the dialog (same anti-flash rule as the
    // danmu source config controller).
    final previous = state.config.valueOrNull;
    state = state.copyWith(
      config: previous == null
          ? const AsyncLoading<ThumbnailScanConfig>()
          : const AsyncLoading<ThumbnailScanConfig>()
              .copyWithPrevious(AsyncData(previous)),
      clearLoadError: true,
    );
    try {
      final result = await _dataSource.getThumbnailScanConfig();
      result.when(
        success: (smart) {
          final data = smart.data;
          if (data == null) {
            state = state.copyWith(
              loadError: _localizeServerError(smart.msg),
            );
            return;
          }
          state = state.copyWith(
            config: AsyncData(data),
            clearLoadError: true,
          );
        },
        failure: (failure) {
          state = state.copyWith(loadError: failure.displayMessage);
        },
      );
    } catch (_) {
      state = state.copyWith(loadError: _getL10n().thumbnailScanDialogLoadFailed);
    }
  }

  /// Saves the configuration; the server validates the cron expression and
  /// rejects an enabled schedule without directories. Returns false and
  /// records [ThumbnailScanConfigState.actionError] on failure.
  Future<bool> save({
    required bool enabled,
    required String cron,
    required List<String> dirs,
  }) {
    return _mutate(
      () => _dataSource.saveThumbnailScanConfig(
          enabled: enabled, cron: cron, dirs: dirs),
      _getL10n().thumbnailScanDialogSaveFailedGeneric,
      isSavingFlag: true,
    );
  }

  /// Queues a scan now. The server dedupes: an already queued/running scan
  /// answers with its current state, which is a success from the UI's side.
  Future<bool> triggerScan({List<String> dirs = const []}) {
    return _mutate(
      () => _dataSource.triggerThumbnailScan(dirs: dirs),
      _getL10n().thumbnailScanDialogTriggerFailedGeneric,
      isSavingFlag: false,
      rawOnGenericFailure: true,
    );
  }

  /// Validates [cron] on the server and returns its next fire times; null when
  /// the request itself failed (offline server), which callers treat as
  /// "no verdict yet" rather than "invalid".
  Future<CronPreviewResult?> previewCron(String cron) async {
    if (cron.trim().isEmpty) return null;
    try {
      final result = await _dataSource.previewThumbnailCron(cron: cron.trim());
      return result.when(
        success: (smart) => smart.data,
        failure: (_) => null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Drops a stale [ThumbnailScanConfigState.actionError] on dialog entry.
  void clearActionError() {
    if (state.actionError == null) return;
    state = state.copyWith(clearActionError: true);
  }

  /// Fetches one run's status by id and adopts it as the snapshot's last-run
  /// block, so callers keep reading one type. Returns false when the request
  /// itself failed; the widget-side state (live progress) is left untouched.
  Future<bool> refreshRun(int runId) async {
    try {
      final result = await _dataSource.getThumbnailScanRun(runId);
      final run = result.getOrThrow().data;
      final current = state.config.valueOrNull;
      if (run == null || current == null) return false;
      state = state.copyWith(config: AsyncData(current.mergeRun(run)));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The mutation error to show the user, or null when the last one succeeded.
  String? get actionError => state.actionError;

  /// The same failure before localization, so callers can match the server's
  /// own wording; null when the request failed without a server answer.
  String? get actionErrorRaw => state.actionErrorRaw;

  Future<bool> _mutate(
    Future<ApiResult<SmartAnalysisResult<ThumbnailScanConfig>>> Function()
        request,
    String fallbackError, {
    required bool isSavingFlag,
    bool rawOnGenericFailure = false,
  }) async {
    state = state.copyWith(
      isSaving: isSavingFlag ? true : null,
      isTriggering: isSavingFlag ? null : true,
      clearActionError: true,
    );
    var ok = false;
    String? error;
    String? rawError;
    ThumbnailScanConfig? saved;
    try {
      final result = await request();
      result.when(
        success: (smart) {
          final data = smart.data;
          if (data != null && smart.isSuccess()) {
            ok = true;
            saved = data;
          } else {
            rawError = smart.msg;
            error = _localizeServerError(smart.msg);
          }
        },
        failure: (failure) {
          rawError = failure.displayMessage;
          error = failure.displayMessage;
        },
      );
    } catch (_) {
      error = fallbackError;
      rawError = rawOnGenericFailure ? fallbackError : null;
    }
    if (ok) {
      // The mutation response already carries the fresh snapshot; adopt it
      // directly and refresh in the background so nextRunTime stays current.
      state = state.copyWith(
        config: AsyncData(saved!),
        isSaving: false,
        isTriggering: false,
        clearActionError: true,
      );
      return true;
    }
    state = state.copyWith(
      isSaving: false,
      isTriggering: false,
      actionErrorRaw: rawError,
      actionError: error ?? fallbackError,
    );
    return false;
  }

  /// Maps the server's fixed English rejection reasons to the user's language.
  String _localizeServerError(String message) {
    final l10n = _getL10n();
    switch (message.trim()) {
      case 'cron expression is required':
        return l10n.thumbnailScanDialogCronRequired;
      case 'at least one scan directory is required':
        return l10n.thumbnailScanDialogDirsRequired;
      case 'no scan directories configured':
        return l10n.thumbnailScanDialogDirsRequired;
      case 'too many scan directories':
        return l10n.thumbnailScanDialogTooManyDirs;
      case 'scan is already running':
        return l10n.thumbnailScanDialogAlreadyRunning;
      default:
        if (message.startsWith('invalid cron expression')) {
          return l10n.thumbnailScanDialogCronInvalidShort;
        }
        if (message.startsWith(scanDirsNotSavedPrefix)) {
          return l10n.thumbnailScanDialogDirsNotSaved(
              message.substring(scanDirsNotSavedPrefix.length).split(',').length);
        }
        return message;
    }
  }
}
