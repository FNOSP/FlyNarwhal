import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_result.dart';
import '../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../data/models/fly_narwhal/index.dart';

typedef PollingDelay = Future<void> Function(Duration duration);

enum SeasonAnalysisViewPhase {
  initial,
  loading,
  notDetected,
  available,
  failed,
}

class SeasonAnalysisStatusEntry {
  final String seasonGuid;
  final SeasonAnalysisViewPhase phase;
  final AnalysisStatus? status;
  final String? errorMessage;
  final bool isPolling;

  const SeasonAnalysisStatusEntry({
    required this.seasonGuid,
    this.phase = SeasonAnalysisViewPhase.initial,
    this.status,
    this.errorMessage,
    this.isPolling = false,
  });
}

class SeasonAnalysisStatusController
    extends StateNotifier<Map<String, SeasonAnalysisStatusEntry>> {
  static const Duration pollingInterval = Duration(seconds: 10);
  static const int startupRetryCount = 6;

  final FlyNarwhalRemoteDataSource _remoteDataSource;
  final PollingDelay _pollingDelay;
  final Map<String, int> _generations = <String, int>{};

  SeasonAnalysisStatusController(
    this._remoteDataSource, {
    PollingDelay? pollingDelay,
  })  : _pollingDelay = pollingDelay ?? Future<void>.delayed,
        super(const <String, SeasonAnalysisStatusEntry>{});

  Future<void> startPolling(String seasonGuid) async {
    if (seasonGuid.trim().isEmpty) return;
    final generation = _nextGeneration(seasonGuid);
    _setEntry(SeasonAnalysisStatusEntry(
      seasonGuid: seasonGuid,
      phase: SeasonAnalysisViewPhase.loading,
      isPolling: true,
    ));
    await _poll(
      seasonGuid,
      generation,
      forced: false,
      hasObservedRunningStatus: false,
      remainingStartupRetries: 0,
    );
  }

  Future<void> startForcedPolling(String seasonGuid) async {
    if (seasonGuid.trim().isEmpty) return;
    final generation = _nextGeneration(seasonGuid);
    _setEntry(SeasonAnalysisStatusEntry(
      seasonGuid: seasonGuid,
      phase: SeasonAnalysisViewPhase.loading,
      isPolling: true,
    ));
    await _poll(
      seasonGuid,
      generation,
      forced: true,
      hasObservedRunningStatus: false,
      remainingStartupRetries: startupRetryCount,
    );
  }

  void stopPolling(String seasonGuid, {bool notifyListeners = true}) {
    _nextGeneration(seasonGuid);
    final entry = state[seasonGuid];
    if (!notifyListeners || entry == null) return;
    _setEntry(SeasonAnalysisStatusEntry(
      seasonGuid: seasonGuid,
      phase: entry.phase,
      status: entry.status,
      errorMessage: entry.errorMessage,
    ));
  }

  @override
  void dispose() {
    for (final seasonGuid in _generations.keys.toList()) {
      _nextGeneration(seasonGuid);
    }
    super.dispose();
  }

  Future<void> _poll(
    String seasonGuid,
    int generation, {
    required bool forced,
    required bool hasObservedRunningStatus,
    required int remainingStartupRetries,
  }) async {
    final result = await _remoteDataSource.getStatus(
      type: 'SEASON',
      guid: seasonGuid,
    );
    if (!_isCurrent(seasonGuid, generation)) return;

    if (result case ResultFailure(info: final failure)) {
      _setFailure(seasonGuid, failure.displayMessage);
      return;
    }

    final response =
        (result as Success<SmartAnalysisResult<AnalysisStatus>>).data;
    if (!response.isSuccess()) {
      _setFailure(seasonGuid, response.msg);
      return;
    }

    final status = response.data;
    if (status == null) {
      _setEntry(SeasonAnalysisStatusEntry(
        seasonGuid: seasonGuid,
        phase: SeasonAnalysisViewPhase.notDetected,
      ));
      return;
    }

    if (status.isRunning) {
      _setAvailable(seasonGuid, status, isPolling: true);
      await _pollingDelay(pollingInterval);
      if (!_isCurrent(seasonGuid, generation)) return;
      await _poll(
        seasonGuid,
        generation,
        forced: forced,
        hasObservedRunningStatus: true,
        remainingStartupRetries: remainingStartupRetries,
      );
      return;
    }

    final shouldWaitForStartup =
        forced && !hasObservedRunningStatus && remainingStartupRetries > 0;
    if (shouldWaitForStartup) {
      _setAvailable(seasonGuid, status, isPolling: true);
      await _pollingDelay(pollingInterval);
      if (!_isCurrent(seasonGuid, generation)) return;
      await _poll(
        seasonGuid,
        generation,
        forced: true,
        hasObservedRunningStatus: false,
        remainingStartupRetries: remainingStartupRetries - 1,
      );
      return;
    }

    _setAvailable(seasonGuid, status, isPolling: false);
  }

  int _nextGeneration(String seasonGuid) {
    final generation = (_generations[seasonGuid] ?? 0) + 1;
    _generations[seasonGuid] = generation;
    return generation;
  }

  bool _isCurrent(String seasonGuid, int generation) {
    return mounted && _generations[seasonGuid] == generation;
  }

  void _setAvailable(
    String seasonGuid,
    AnalysisStatus status, {
    required bool isPolling,
  }) {
    _setEntry(SeasonAnalysisStatusEntry(
      seasonGuid: seasonGuid,
      phase: status == AnalysisStatus.failed
          ? SeasonAnalysisViewPhase.failed
          : SeasonAnalysisViewPhase.available,
      status: status,
      isPolling: isPolling,
    ));
  }

  void _setFailure(String seasonGuid, String message) {
    _setEntry(SeasonAnalysisStatusEntry(
      seasonGuid: seasonGuid,
      phase: SeasonAnalysisViewPhase.failed,
      errorMessage: message,
    ));
  }

  void _setEntry(SeasonAnalysisStatusEntry entry) {
    state = <String, SeasonAnalysisStatusEntry>{
      ...state,
      entry.seasonGuid: entry,
    };
  }
}
