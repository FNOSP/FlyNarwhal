import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/log/error_describer.dart';
import '../../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../../data/models/fly_narwhal/index.dart';
import '../../data/storage/fly_narwhal_settings.dart';

/// Movie-detail "生成缩略图" menu state for one media guid.
class ThumbnailMenuState {
  final ThumbnailTaskStatus status;
  final bool stale;
  final bool submitting;
  final String? serverError;
  final String? actionError;

  /// True while a poll chain is armed. Mirrors the smart-analysis controller:
  /// without it, nothing can tell "no poll running" from "poll already ended",
  /// so a trigger can never force the chain back to life.
  final bool isPolling;

  const ThumbnailMenuState({
    this.status = ThumbnailTaskStatus.none,
    this.stale = false,
    this.submitting = false,
    this.serverError,
    this.actionError,
    this.isPolling = false,
  });

  bool get isRunning =>
      status == ThumbnailTaskStatus.pending ||
      status == ThumbnailTaskStatus.inProgress;

  ThumbnailMenuState copyWith({
    ThumbnailTaskStatus? status,
    bool? stale,
    bool? submitting,
    String? serverError,
    String? actionError,
    bool? isPolling,
    bool clearErrors = false,
  }) {
    return ThumbnailMenuState(
      status: status ?? this.status,
      stale: stale ?? this.stale,
      submitting: submitting ?? this.submitting,
      serverError: clearErrors ? null : (serverError ?? this.serverError),
      actionError: clearErrors ? null : (actionError ?? this.actionError),
      isPolling: isPolling ?? this.isPolling,
    );
  }
}

/// One instance per movie guid (family provider). Polls the task status every
/// 10s while it runs, mirroring the smart-analysis status controller.
class ThumbnailMenuController extends StateNotifier<ThumbnailMenuState> {
  static const Duration _pollingInterval = Duration(seconds: 10);

  final FlyNarwhalRemoteDataSource _remoteDataSource;
  final FlyNarwhalSettings _settings;
  final String _guid;
  Timer? _pollingTimer;

  /// Bumped whenever a chain is started or stopped, including on dispose. An
  /// in-flight poll captures it and drops its (late) reply if the value moved
  /// on — the provider is not autoDispose, so a response can land after the
  /// page that watches it is gone, and publishing then makes Riverpod call
  /// markNeedsBuild on a defunct element (AssertionError). Same guard as
  /// SeasonAnalysisStatusController._generations.
  int _generation = 0;

  ThumbnailMenuController(this._remoteDataSource, this._settings, this._guid)
      : super(const ThumbnailMenuState());

  /// Initial load so the menu can show "已生成/重新生成" before the user triggers.
  /// Also the entry point for re-entering the detail page, so it resumes a
  /// chain that outlived the page instead of leaving a running task unwatched.
  Future<void> refresh() async {
    stopPolling();
    if (!_settings.enabled || _guid.isEmpty) return;
    final generation = _generation;
    try {
      final result = await _remoteDataSource.getThumbnailStatus(_guid);
      if (_generation != generation) return;
      final metadata = result.getOrThrow().data;
      if (metadata == null) return;
      final running = metadata.status == ThumbnailTaskStatus.pending ||
          metadata.status == ThumbnailTaskStatus.inProgress;
      state = ThumbnailMenuState(
        status: metadata.status,
        stale: metadata.stale,
        serverError: metadata.error,
        isPolling: running,
      );
      if (running) _armTimer();
    } catch (error) {
      if (_generation != generation) return;
      // Old servers answer 404 for the whole route; keep the item disabled
      // rather than surfacing an error toast loop on the detail page.
      state = state.copyWith(status: ThumbnailTaskStatus.none);
    }
  }

  Future<void> trigger({required String filePath, bool force = false}) async {
    if (state.submitting || !_settings.enabled || _guid.isEmpty) return;
    final generation = _generation;
    state = state.copyWith(submitting: true, clearErrors: true);
    try {
      final result = await _remoteDataSource.generateThumbnails(
        ThumbnailGenerateRequest(guid: _guid, filePath: filePath, force: force),
      );
      if (_generation != generation) return;
      final metadata = result.getOrThrow().data;
      if (metadata == null) {
        state = state.copyWith(submitting: false);
        return;
      }
      // One state write, with the poll flag already set: writing `state` and
      // then re-writing it from _startPolling() notifies listeners twice in the
      // same synchronous turn, and the second notification lands while Riverpod
      // is still dispatching the first (markNeedsBuild re-entrancy assertion).
      final shouldPoll = _settings.enabled && _guid.isNotEmpty;
      state = ThumbnailMenuState(
        status: metadata.status,
        stale: metadata.stale,
        serverError: metadata.error,
        isPolling: shouldPoll,
      );
      // A trigger that reached the server always owes the client a poll: the
      // reply can legitimately be a non-running status (a job still queued
      // behind the unchanged-file guard, or one that finished before this
      // response) and treating that as "nothing to watch" is what left the
      // page with no status updates after a re-generate.
      if (shouldPoll) _armTimer();
    } catch (error) {
      if (_generation != generation) return;
      state = state.copyWith(
        submitting: false,
        actionError: ErrorDescriber.describe(error),
      );
    }
  }

  /// Arms the timer only. Kept separate from the `isPolling` flag so a caller
  /// that has already written its state can start the chain without a second
  /// synchronous notification (see trigger()).
  void _armTimer() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer(_pollingInterval, _pollOnce);
  }

  /// Ends the chain and clears the flag; the last known status is kept so the
  /// tag still shows 已完成/生成失败 after polling stops. Bumping the generation
  /// also strands any reply already in flight.
  ///
  /// Pass `notifyListeners: false` when the caller runs inside a widget
  /// lifecycle phase where Riverpod forbids modifying providers — a page
  /// teardown (deactivate/dispose) does, and writing `state` there trips
  /// `_debugCanModifyProviders` and takes the whole tree down with it.
  void stopPolling({bool notifyListeners = true}) {
    _generation++;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (!notifyListeners) return;
    if (state.isPolling) state = state.copyWith(isPolling: false);
  }

  Future<void> _pollOnce() async {
    if (!_settings.enabled || _guid.isEmpty) {
      return;
    }
    final generation = _generation;
    try {
      final result = await _remoteDataSource.getThumbnailStatus(_guid);
      if (_generation != generation) {
        return;
      }
      final metadata = result.getOrThrow().data;
      if (metadata == null) {
        _generation++;
        _pollingTimer?.cancel();
        _pollingTimer = null;
        state = state.copyWith(submitting: false, isPolling: false);
        return;
      }
      state = ThumbnailMenuState(
        status: metadata.status,
        stale: metadata.stale,
        serverError: metadata.error,
        isPolling: metadata.status == ThumbnailTaskStatus.pending ||
            metadata.status == ThumbnailTaskStatus.inProgress,
      );
      if (state.isRunning) {
        _armTimer();
      } else {
        // Ends the chain without a second state write (isPolling was just set
        // to false above).
        _generation++;
        _pollingTimer?.cancel();
        _pollingTimer = null;
      }
    } catch (error) {
      if (_generation != generation) return;
      _generation++;
      _pollingTimer?.cancel();
      _pollingTimer = null;
      state = state.copyWith(
        submitting: false,
        actionError: ErrorDescriber.describe(error),
        isPolling: false,
      );
    }
  }

  @override
  void dispose() {
    _generation++;
    _pollingTimer?.cancel();
    super.dispose();
  }
}
