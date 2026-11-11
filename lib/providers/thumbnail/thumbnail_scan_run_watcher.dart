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

  /// Starts watching for the run a manual trigger just queued.
  ///
  /// [baselineRunMs] is the snapshot's `lastRunTimeMs` captured *before* the
  /// trigger: the run counts as finished only once a strictly newer run has a
  /// finish time at or after its start, so the previous run's stored result is
  /// never mistaken for this one's. Server-side timestamps throughout — the
  /// client clock is not compared against them.
  void watchManualRun(int? baselineRunMs) {
    _timer?.cancel();
    final deadline = DateTime.now().add(_maxWindow);
    _timer = Timer.periodic(_pollInterval, (timer) {
      unawaited(_tick(timer, baselineRunMs, deadline));
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick(Timer timer, int? baselineRunMs, DateTime deadline) async {
    await _controller.load();
    final config =
        _ref.read(thumbnailScanConfigControllerProvider).config.valueOrNull;
    if (config == null) {
      if (DateTime.now().isAfter(deadline)) timer.cancel();
      return;
    }
    final runMs = config.lastRunTime?.millisecondsSinceEpoch;
    final finishMs = config.lastFinishTime?.millisecondsSinceEpoch;
    final isNewRun =
        runMs != null && (baselineRunMs == null || runMs > baselineRunMs);
    final finished = !config.isBusy &&
        runMs != null &&
        isNewRun &&
        finishMs != null &&
        finishMs >= runMs;
    if (finished) {
      timer.cancel();
      _toastResult(config);
    } else if (DateTime.now().isAfter(deadline)) {
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
    if (config.lastStatus == ThumbnailScanConfig.lastStatusFailed ||
        error.isNotEmpty) {
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
      l10n.thumbnailScanRunFinished(
          config.lastScannedCount, config.lastQueuedCount),
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
