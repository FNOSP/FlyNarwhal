import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_result.dart';
import '../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../data/models/fly_narwhal/index.dart';
import 'season_analysis_status_controller.dart';

const Object _unsetEpisodeField = Object();

class EpisodeAnalysisState {
  final String? episodeGuid;
  final String? mediaGuid;
  final int requestGeneration;
  final bool isPolling;
  final AnalysisStatus? status;
  final EpisodeSegmentsResponse? smartSegments;
  final String? errorMessage;

  const EpisodeAnalysisState({
    this.episodeGuid,
    this.mediaGuid,
    this.requestGeneration = 0,
    this.isPolling = false,
    this.status,
    this.smartSegments,
    this.errorMessage,
  });

  EpisodeAnalysisState copyWith({
    Object? episodeGuid = _unsetEpisodeField,
    Object? mediaGuid = _unsetEpisodeField,
    int? requestGeneration,
    bool? isPolling,
    Object? status = _unsetEpisodeField,
    Object? smartSegments = _unsetEpisodeField,
    Object? errorMessage = _unsetEpisodeField,
  }) {
    return EpisodeAnalysisState(
      episodeGuid: identical(episodeGuid, _unsetEpisodeField)
          ? this.episodeGuid
          : episodeGuid as String?,
      mediaGuid: identical(mediaGuid, _unsetEpisodeField)
          ? this.mediaGuid
          : mediaGuid as String?,
      requestGeneration: requestGeneration ?? this.requestGeneration,
      isPolling: isPolling ?? this.isPolling,
      status: identical(status, _unsetEpisodeField)
          ? this.status
          : status as AnalysisStatus?,
      smartSegments: identical(smartSegments, _unsetEpisodeField)
          ? this.smartSegments
          : smartSegments as EpisodeSegmentsResponse?,
      errorMessage: identical(errorMessage, _unsetEpisodeField)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class EpisodeAnalysisController extends StateNotifier<EpisodeAnalysisState> {
  static const Duration pollingInterval = Duration(seconds: 10);

  final FlyNarwhalRemoteDataSource _remoteDataSource;
  final PollingDelay _pollingDelay;

  EpisodeAnalysisController(
    this._remoteDataSource, {
    PollingDelay? pollingDelay,
  })  : _pollingDelay = pollingDelay ?? Future<void>.delayed,
        super(const EpisodeAnalysisState());

  Future<void> updateContext({
    required bool isEpisode,
    required bool serviceEnabled,
    required bool smartSkipEnabled,
    String? episodeGuid,
    String? mediaGuid,
  }) async {
    final normalizedEpisodeGuid = _normalizeGuid(episodeGuid);
    final normalizedMediaGuid = _normalizeGuid(mediaGuid);
    final contextChanged = state.episodeGuid != normalizedEpisodeGuid ||
        state.mediaGuid != normalizedMediaGuid;
    final shouldPoll = isEpisode &&
        serviceEnabled &&
        smartSkipEnabled &&
        normalizedMediaGuid != null;

    if (!shouldPoll) {
      stopAndClear();
      return;
    }
    if (!contextChanged && state.isPolling) return;

    final generation = state.requestGeneration + 1;
    state = EpisodeAnalysisState(
      episodeGuid: normalizedEpisodeGuid,
      mediaGuid: normalizedMediaGuid,
      requestGeneration: generation,
      isPolling: true,
    );
    await _poll(normalizedMediaGuid, generation);
  }

  void stopAndClear() {
    state = EpisodeAnalysisState(
      requestGeneration: state.requestGeneration + 1,
    );
  }

  @override
  void dispose() {
    stopAndClear();
    super.dispose();
  }

  Future<void> _poll(String mediaGuid, int generation) async {
    final result = await _remoteDataSource.getStatus(
      type: 'EPISODE',
      guid: mediaGuid,
    );
    if (!_isCurrent(mediaGuid, generation)) return;

    if (result case ResultFailure(info: final failure)) {
      _stopWithError(failure.displayMessage);
      return;
    }

    final response =
        (result as Success<SmartAnalysisResult<AnalysisStatus>>).data;
    if (!response.isSuccess()) {
      _stopWithError(response.msg);
      return;
    }

    final status = response.data;
    state = state.copyWith(status: status, errorMessage: null);
    if (status == null) {
      await _requestSegments(mediaGuid, generation);
      return;
    }

    if (status.isRunning) {
      await _pollingDelay(pollingInterval);
      if (!_isCurrent(mediaGuid, generation)) return;
      await _poll(mediaGuid, generation);
      return;
    }

    if (status == AnalysisStatus.completed) {
      await _requestSegments(mediaGuid, generation);
      return;
    }

    state = state.copyWith(isPolling: false);
  }

  Future<void> _requestSegments(String mediaGuid, int generation) async {
    final segmentsResult = await _remoteDataSource.getSegments(mediaGuid);
    if (!_isCurrent(mediaGuid, generation)) return;
    if (segmentsResult
        case Success<SmartAnalysisResult<EpisodeSegmentsResponse>>(
          data: final segmentsResponse,
        )) {
      state = state.copyWith(
        isPolling: false,
        smartSegments:
            segmentsResponse.isSuccess() ? segmentsResponse.data : null,
        errorMessage:
            segmentsResponse.isSuccess() ? null : segmentsResponse.msg,
      );
      return;
    }
    final failure = segmentsResult.failureOrNull;
    _stopWithError(failure?.displayMessage ?? 'Failed to get segments');
  }

  bool _isCurrent(String mediaGuid, int generation) {
    return mounted &&
        state.requestGeneration == generation &&
        state.mediaGuid == mediaGuid;
  }

  String? _normalizeGuid(String? guid) {
    final normalizedGuid = guid?.trim() ?? '';
    return normalizedGuid.isEmpty ? null : normalizedGuid;
  }

  void _stopWithError(String message) {
    state = state.copyWith(isPolling: false, errorMessage: message);
  }
}
