import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../data/models/fly_narwhal/index.dart';
import '../data/storage/fly_narwhal_settings.dart';

class SmartAnalysisStatusState {
  final bool isPolling;
  final AnalysisStatus status;
  final EpisodeSegmentsResponse? segments;
  final String? errorMessage;
  final String? episodeGuid;

  const SmartAnalysisStatusState({
    this.isPolling = false,
    this.status = AnalysisStatus.unknown,
    this.segments,
    this.errorMessage,
    this.episodeGuid,
  });

  SmartAnalysisStatusState copyWith({
    bool? isPolling,
    AnalysisStatus? status,
    EpisodeSegmentsResponse? segments,
    String? errorMessage,
    String? episodeGuid,
  }) {
    return SmartAnalysisStatusState(
      isPolling: isPolling ?? this.isPolling,
      status: status ?? this.status,
      segments: segments ?? this.segments,
      errorMessage: errorMessage,
      episodeGuid: episodeGuid ?? this.episodeGuid,
    );
  }
}

class SmartAnalysisStatusController
    extends StateNotifier<SmartAnalysisStatusState> {
  static const Duration _pollingInterval = Duration(seconds: 10);

  final FlyNarwhalRemoteDataSource _remoteDataSource;
  final FlyNarwhalSettings _settings;
  Timer? _pollingTimer;
  String? _activeType;
  String? _activeGuid;
  bool _smartSkipEnabled = false;

  SmartAnalysisStatusController(this._remoteDataSource, this._settings)
      : super(const SmartAnalysisStatusState());

  bool get smartSkipEnabled => _smartSkipEnabled;

  Future<void> startPolling(
    String type,
    String guid, {
    bool force = false,
  }) async {
    if (guid.isEmpty) return;
    if (!force && _activeType == type && _activeGuid == guid) return;
    stopPolling();
    _activeType = type;
    _activeGuid = guid;
    state = state.copyWith(isPolling: true, episodeGuid: guid);
    await _pollOnce();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _activeType = null;
    _activeGuid = null;
    state = state.copyWith(isPolling: false);
  }

  void updateSmartSkipEnabled(bool enabled) {
    _smartSkipEnabled = enabled;
    final episodeGuid = state.episodeGuid;
    if (enabled && episodeGuid != null) {
      updateEpisodeGuid(episodeGuid);
    } else if (!enabled) {
      stopPolling();
    }
  }

  Future<void> updateEpisodeGuid(String guid) async {
    if (guid == state.episodeGuid && _activeGuid == guid) return;
    stopPolling();
    state = state.copyWith(episodeGuid: guid, segments: null);
    final shouldStartPolling =
        guid.isNotEmpty && _settings.enabled && _smartSkipEnabled;
    if (shouldStartPolling) {
      await startPolling('episode', guid, force: true);
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollOnce() async {
    final type = _activeType;
    final guid = _activeGuid;
    if (type == null || guid == null) return;

    try {
      final result = await _remoteDataSource.getStatus(type: type, guid: guid);
      final status = result.getOrThrow().data ?? AnalysisStatus.unknown;
      state = state.copyWith(status: status, errorMessage: null);

      if (status.isRunning) {
        _pollingTimer = Timer(_pollingInterval, _pollOnce);
        return;
      }
      if (status.isCompleted) {
        final segmentsResult = await _remoteDataSource.getSegments(guid);
        state = state.copyWith(
          isPolling: false,
          segments: segmentsResult.getOrThrow().data,
        );
        stopPolling();
        return;
      }
      stopPolling();
    } catch (error) {
      state = state.copyWith(
        isPolling: false,
        errorMessage: error.toString(),
      );
      stopPolling();
    }
  }
}
