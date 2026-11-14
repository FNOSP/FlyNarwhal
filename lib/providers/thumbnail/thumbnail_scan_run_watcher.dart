import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/fly_narwhal/index.dart';
import '../../data/utils/fn_data_convertor.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/settings/app_language.dart';
import '../../ui/shared/toast.dart';
import '../file_providers.dart';
import '../providers.dart';
import 'thumbnail_scan_config_controller.dart';

/// Separator between the folder names of a multi-folder permission toast; zh
/// uses the ideographic comma, English the regular one.
String get scanDirNameSeparator {
  final language = PlatformDispatcher.instance.locale.languageCode;
  return language == 'zh' || language == 'ja' ? '、' : ', ';
}

/// Follows a manually triggered thumbnail scan to completion, app-wide: the
/// dialog may close while the scan runs, but the user still owes an outcome.
/// Polls the server snapshot on a global timer until the triggered run has
/// finished, then toasts its result — success included. Scheduled runs are
/// never watched here and never toast.
class ThumbnailScanRunWatcher {
  ThumbnailScanRunWatcher(this._ref);

  static const Duration _pollInterval = Duration(seconds: 5);

  /// Safety valve: a stuck server must not keep the client polling forever.
  static const Duration _maxWindow = Duration(minutes: 30);

  final Ref _ref;
  Timer? _timer;

  ThumbnailScanConfigController get _controller =>
      _ref.read(thumbnailScanConfigControllerProvider.notifier);

  AppLocalizations get _l10n => lookupAppLocalizations(
        AppLanguage.localeFromValue(_ref.read(settingsProvider).language),
      );

  /// Starts watching the run a manual trigger just queued, by its id.
  ///
  /// Every trigger opens its own run row on the server and answers with that
  /// id, so polling that id can only ever report this run — never another
  /// run's leftover status, and never a run the client merely guessed is the
  /// newest. The dialog's snapshot is updated with each poll so the status card
  /// and this watcher always agree.
  void watchManualRun(int runId) {
    _timer?.cancel();
    final deadline = DateTime.now().add(_maxWindow);
    _timer = Timer.periodic(_pollInterval, (timer) {
      unawaited(_tick(timer, runId, deadline));
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick(Timer timer, int runId, DateTime deadline) async {
    await _controller.refreshRun(runId);
    final config =
        _ref.read(thumbnailScanConfigControllerProvider).config.valueOrNull;
    // A failed poll (server unreachable) keeps the chain alive until the
    // deadline; only a finished run ends it.
    if (config != null && !config.lastRunInFlight) {
      timer.cancel();
      _toastResult(config);
      return;
    }
    if (DateTime.now().isAfter(deadline)) {
      timer.cancel();
    }
  }

  void _toastResult(ThumbnailScanConfig config) {
    final l10n = _l10n;
    final toast = _ref.read(toastManagerProvider.notifier);
    if (config.lastInaccessibleDirs.isNotEmpty) {
      toast.showToast(
        inaccessibleToastMessage(config.lastInaccessibleDirs),
        style: ToastStyle.fluent,
        type: ToastType.failed,
        duration: const Duration(seconds: 10),
        category: 'thumbnail-scan-inaccessible',
      );
      return;
    }
    final error = config.lastError?.trim() ?? '';
    // lastInaccessibleDirs is authoritative: the server reports unreadable
    // folders there AND repeats them in lastError, so a run that only hit
    // permission problems must not also toast the raw error text.
    if (config.lastStatus == ThumbnailScanConfig.lastStatusFailed ||
        (error.isNotEmpty && config.lastInaccessibleDirs.isEmpty)) {
      toast.showToast(
        error.isEmpty
            ? l10n.thumbnailScanRunFailedGeneric
            : l10n.thumbnailScanRunFailed(error),
        style: ToastStyle.fluent,
        type: ToastType.failed,
        duration: const Duration(seconds: 10),
        category: 'thumbnail-scan-result',
      );
      return;
    }
    toast.showToast(
      config.lastFailedCount > 0
          ? l10n.thumbnailScanRunFinishedFailed(
              config.lastSourcedCount,
              config.lastQueuedCount,
              config.lastGeneratedCount,
              config.lastFailedCount,
            )
          : l10n.thumbnailScanRunFinished(
              config.lastSourcedCount,
              config.lastQueuedCount,
              config.lastGeneratedCount,
            ),
      style: ToastStyle.fluent,
      type: ToastType.success,
      duration: const Duration(seconds: 10),
      category: 'thumbnail-scan-result',
    );
  }

  /// The permission toast text naming [dirs] by the readable form the scan
  /// dialog lists them in.
  String inaccessibleToastMessage(List<String> dirs) {
    final authDirs = _ref.read(authorizedDirsProvider).valueOrNull;
    final names = dirs
        .map((dir) =>
            FnDataConvertor.formatFileLocation(dir, authDirs: authDirs))
        .join(scanDirNameSeparator);
    return _l10n.thumbnailScanDialogDirsInaccessible(names);
  }
}

final thumbnailScanRunWatcherProvider = Provider<ThumbnailScanRunWatcher>((ref) {
  final watcher = ThumbnailScanRunWatcher(ref);
  ref.onDispose(watcher.cancel);
  return watcher;
});
