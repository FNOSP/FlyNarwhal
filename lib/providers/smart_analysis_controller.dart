import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../data/datasources/remote/media_remote_data_source.dart';
import '../data/models/fly_narwhal/index.dart';

class UiState<T> {
  final bool isLoading;
  final T? data;
  final String? errorMessage;

  const UiState._({
    required this.isLoading,
    this.data,
    this.errorMessage,
  });

  const UiState.idle() : this._(isLoading: false);
  const UiState.loading() : this._(isLoading: true);
  const UiState.success(T data) : this._(isLoading: false, data: data);
  const UiState.failure(String message)
      : this._(isLoading: false, errorMessage: message);
}

class SmartAnalysisController extends StateNotifier<UiState<String>> {
  static const Duration _episodeThrottleDelay = Duration(milliseconds: 300);

  final FlyNarwhalRemoteDataSource _flyNarwhalRemoteDataSource;
  final MediaRemoteDataSource _mediaRemoteDataSource;

  SmartAnalysisController(
    this._flyNarwhalRemoteDataSource,
    this._mediaRemoteDataSource,
  ) : super(const UiState.idle());

  Future<void> analyzeSeason(
    String seasonGuid,
    String tvTitle,
    int seasonNumber, {
    bool shouldUpdatePreparingStatus = true,
  }) async {
    state = const UiState.loading();
    try {
      final message = await _analyzeSeasonInternal(
        seasonGuid,
        tvTitle,
        seasonNumber,
        shouldUpdatePreparingStatus: shouldUpdatePreparingStatus,
      );
      state = UiState.success(message);
    } catch (error) {
      state = UiState.failure(error.toString());
    }
  }

  Future<void> analyzeTv(String tvGuid, String tvTitle) async {
    state = const UiState.loading();
    try {
      final seasons = (await _mediaRemoteDataSource.getSeasonList(tvGuid))
          .getOrThrow();
      await _flyNarwhalRemoteDataSource.updateSeasonStatus(
        UpdateSeasonStatusRequest(
          seasonGuids: seasons.map((season) => season.guid).toList(),
          status: AnalysisStatus.preparing.toJsonValue(),
        ),
      );

      final failedSeasonTitles = <String>[];
      for (final season in seasons) {
        try {
          await _analyzeSeasonInternal(
            season.guid,
            tvTitle,
            season.seasonNumber,
            shouldUpdatePreparingStatus: false,
          );
        } catch (_) {
          failedSeasonTitles.add(season.title);
        }
      }

      if (failedSeasonTitles.isEmpty) {
        state = const UiState.success('Analyze request submitted');
      } else {
        state = UiState.failure('Failed seasons: ${failedSeasonTitles.join(', ')}');
      }
    } catch (error) {
      state = UiState.failure(error.toString());
    }
  }

  Future<String> _analyzeSeasonInternal(
    String seasonGuid,
    String tvTitle,
    int seasonNumber, {
    required bool shouldUpdatePreparingStatus,
  }) async {
    if (shouldUpdatePreparingStatus) {
      await _flyNarwhalRemoteDataSource.updateSeasonStatus(
        UpdateSeasonStatusRequest(
          seasonGuids: <String>[seasonGuid],
          status: AnalysisStatus.preparing.toJsonValue(),
        ),
      );
    }

    final episodes =
        (await _mediaRemoteDataSource.getEpisodeList(seasonGuid)).getOrThrow();
    final queuedEpisodes = <QueuedEpisode>[];
    String seasonPath = '';

    for (final episode in episodes) {
      final streamList =
          (await _mediaRemoteDataSource.getStreamList(episode.guid)).getOrThrow();
      final filePath = streamList?.files?.isNotEmpty == true
          ? streamList!.files!.first.path
          : episode.fileName;
      if (seasonPath.isEmpty && filePath.isNotEmpty) {
        seasonPath = path.dirname(filePath);
      }
      queuedEpisodes.add(QueuedEpisode(
        guid: episode.guid,
        filePath: filePath,
        episodeNumber: episode.episodeNumber,
        seasonNumber: episode.seasonNumber,
      ));
      await Future<void>.delayed(_episodeThrottleDelay);
    }

    final result = await _flyNarwhalRemoteDataSource.analyze(
      AnalyzeRequest(
        seasonGuid: seasonGuid,
        seasonPath: seasonPath,
        episodes: queuedEpisodes,
        tvTitle: tvTitle,
        seasonNumber: seasonNumber,
      ),
    );
    return result.getOrThrow().data ?? 'Analyze request submitted';
  }
}
