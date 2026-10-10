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

  const ThumbnailMenuState({
    this.status = ThumbnailTaskStatus.none,
    this.stale = false,
    this.submitting = false,
    this.serverError,
    this.actionError,
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
    bool clearErrors = false,
  }) {
    return ThumbnailMenuState(
      status: status ?? this.status,
      stale: stale ?? this.stale,
      submitting: submitting ?? this.submitting,
      serverError: clearErrors ? null : (serverError ?? this.serverError),
      actionError: clearErrors ? null : (actionError ?? this.actionError),
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

  ThumbnailMenuController(this._remoteDataSource, this._settings, this._guid)
      : super(const ThumbnailMenuState());

  /// Initial load so the menu can show "已生成/重新生成" before the user triggers.
  Future<void> refresh() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (!_settings.enabled || _guid.isEmpty) return;
    try {
      final result = await _remoteDataSource.getThumbnailStatus(_guid);
      final metadata = result.getOrThrow().data;
      if (metadata == null) return;
      state = ThumbnailMenuState(
        status: metadata.status,
        stale: metadata.stale,
        serverError: metadata.error,
      );
      if (state.isRunning) _schedulePoll();
    } catch (error) {
      // Old servers answer 404 for the whole route; keep the item disabled
      // rather than surfacing an error toast loop on the detail page.
      state = state.copyWith(status: ThumbnailTaskStatus.none);
    }
  }

  Future<void> trigger({required String filePath}) async {
    if (state.submitting || !_settings.enabled || _guid.isEmpty) return;
    state = state.copyWith(submitting: true, clearErrors: true);
    try {
      final result = await _remoteDataSource.generateThumbnails(
        ThumbnailGenerateRequest(guid: _guid, filePath: filePath),
      );
      final metadata = result.getOrThrow().data;
      if (metadata == null) {
        state = state.copyWith(submitting: false);
        return;
      }
      state = ThumbnailMenuState(
        status: metadata.status,
        stale: metadata.stale,
        serverError: metadata.error,
      );
      if (state.isRunning) _schedulePoll();
    } catch (error) {
      state = state.copyWith(
        submitting: false,
        actionError: ErrorDescriber.describe(error),
      );
    }
  }

  void _schedulePoll() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer(_pollingInterval, _pollOnce);
  }

  Future<void> _pollOnce() async {
    if (!_settings.enabled || _guid.isEmpty) return;
    try {
      final result = await _remoteDataSource.getThumbnailStatus(_guid);
      final metadata = result.getOrThrow().data;
      if (metadata == null) {
        state = state.copyWith(submitting: false);
        return;
      }
      state = ThumbnailMenuState(
        status: metadata.status,
        stale: metadata.stale,
        serverError: metadata.error,
      );
      if (state.isRunning) {
        _schedulePoll();
      }
    } catch (error) {
      state = state.copyWith(
        submitting: false,
        actionError: ErrorDescriber.describe(error),
      );
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
