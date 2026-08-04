import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../data/datasources/remote/media_remote_data_source.dart';
import '../data/models/fly_narwhal/index.dart';

typedef AnalysisDelay = Future<void> Function(Duration duration);
typedef StartSeasonPolling = void Function(String seasonGuid);

enum SmartAnalysisTargetType { tv, season }

class SmartAnalysisTargetKey {
  final SmartAnalysisTargetType type;
  final String guid;

  const SmartAnalysisTargetKey({required this.type, required this.guid});

  @override
  bool operator ==(Object other) {
    return other is SmartAnalysisTargetKey &&
        other.type == type &&
        other.guid == guid;
  }

  @override
  int get hashCode => Object.hash(type, guid);
}

class SmartAnalysisSubmissionState {
  final Map<SmartAnalysisTargetKey, AsyncValue<String>> submissions;

  const SmartAnalysisSubmissionState({this.submissions = const {}});

  AsyncValue<String>? submissionFor(
    SmartAnalysisTargetType type,
    String guid,
  ) {
    return submissions[SmartAnalysisTargetKey(type: type, guid: guid)];
  }

  bool isSubmitting(SmartAnalysisTargetType type, String guid) {
    return submissionFor(type, guid)?.isLoading == true;
  }

  SmartAnalysisSubmissionState withSubmission(
    SmartAnalysisTargetKey key,
    AsyncValue<String> submission,
  ) {
    return SmartAnalysisSubmissionState(
      submissions: <SmartAnalysisTargetKey, AsyncValue<String>>{
        ...submissions,
        key: submission,
      },
    );
  }
}

class SmartAnalysisController
    extends StateNotifier<SmartAnalysisSubmissionState> {
  static const Duration episodeThrottleDelay = Duration(milliseconds: 300);
  static const String queuedSuccessMessage = '已加入分析队列';
  static const String fallbackSuccessMessage = '分析请求已提交';

  final FlyNarwhalRemoteDataSource _flyNarwhalRemoteDataSource;
  final MediaRemoteDataSource _mediaRemoteDataSource;
  final AnalysisDelay _delay;
  final StartSeasonPolling _startSeasonPolling;
  final Set<String> _submittingSeasonGuids = <String>{};

  SmartAnalysisController(
    this._flyNarwhalRemoteDataSource,
    this._mediaRemoteDataSource, {
    AnalysisDelay? delay,
    StartSeasonPolling? startSeasonPolling,
  })  : _delay = delay ?? Future<void>.delayed,
        _startSeasonPolling = startSeasonPolling ?? _ignorePollingRequest,
        super(const SmartAnalysisSubmissionState());

  static void _ignorePollingRequest(String seasonGuid) {}

  Future<void> analyzeSeason(
    String seasonGuid,
    String tvTitle,
    int seasonNumber,
  ) async {
    final targetKey = SmartAnalysisTargetKey(
      type: SmartAnalysisTargetType.season,
      guid: seasonGuid,
    );
    if (!_submittingSeasonGuids.add(seasonGuid)) return;

    _setSubmission(targetKey, const AsyncLoading<String>());
    try {
      final message = await _submitSeason(
        seasonGuid,
        tvTitle,
        seasonNumber,
        shouldUpdatePreparingStatus: true,
      );
      _setSubmission(targetKey, AsyncData<String>(message));
    } catch (error, stackTrace) {
      _setSubmission(targetKey, AsyncError<String>(error, stackTrace));
    } finally {
      _submittingSeasonGuids.remove(seasonGuid);
    }
  }

  Future<void> analyzeTv(String tvGuid, String tvTitle) async {
    final targetKey = SmartAnalysisTargetKey(
      type: SmartAnalysisTargetType.tv,
      guid: tvGuid,
    );
    if (state.isSubmitting(SmartAnalysisTargetType.tv, tvGuid)) return;

    _setSubmission(targetKey, const AsyncLoading<String>());
    try {
      final seasons =
          (await _mediaRemoteDataSource.getSeasonList(tvGuid)).getOrThrow();
      final preparingResult =
          (await _flyNarwhalRemoteDataSource.updateSeasonStatus(
        UpdateSeasonStatusRequest(
          seasonGuids: seasons.map((season) => season.guid).toList(),
          status: AnalysisStatus.preparing.toJsonValue(),
        ),
      ))
              .getOrThrow();
      if (!preparingResult.isSuccess()) {
        throw Exception(_failureMessage(preparingResult.msg));
      }

      final failedSeasonTitles = <String>[];
      final successMessages = <String>[];
      for (final season in seasons) {
        // Share the Season GUID lock with direct Season submissions.
        if (!_submittingSeasonGuids.add(season.guid)) {
          failedSeasonTitles.add(season.title);
          continue;
        }
        try {
          successMessages.add(await _submitSeason(
            season.guid,
            tvTitle,
            season.seasonNumber,
            shouldUpdatePreparingStatus: false,
          ));
        } catch (_) {
          failedSeasonTitles.add(season.title);
        } finally {
          _submittingSeasonGuids.remove(season.guid);
        }
      }

      if (failedSeasonTitles.isNotEmpty) {
        throw Exception('失败剧季：${failedSeasonTitles.join('、')}');
      }
      final serviceMessage = successMessages.firstWhere(
        (message) => message.trim().isNotEmpty,
        orElse: () => fallbackSuccessMessage,
      );
      _setSubmission(targetKey, AsyncData<String>(serviceMessage));
    } catch (error, stackTrace) {
      _setSubmission(targetKey, AsyncError<String>(error, stackTrace));
    }
  }

  Future<String> _submitSeason(
    String seasonGuid,
    String tvTitle,
    int seasonNumber, {
    required bool shouldUpdatePreparingStatus,
  }) async {
    if (shouldUpdatePreparingStatus) {
      final preparingResult =
          (await _flyNarwhalRemoteDataSource.updateSeasonStatus(
        UpdateSeasonStatusRequest(
          seasonGuids: <String>[seasonGuid],
          status: AnalysisStatus.preparing.toJsonValue(),
        ),
      ))
              .getOrThrow();
      if (!preparingResult.isSuccess()) {
        throw Exception(_failureMessage(preparingResult.msg));
      }
    }

    final episodes =
        (await _mediaRemoteDataSource.getEpisodeList(seasonGuid)).getOrThrow();
    final queuedEpisodes = <QueuedEpisode>[];
    String seasonPath = '';

    for (var episodeIndex = 0; episodeIndex < episodes.length; episodeIndex++) {
      final episode = episodes[episodeIndex];
      final streamList =
          (await _mediaRemoteDataSource.getStreamList(episode.guid))
              .getOrThrow();
      // Use file-level guid (matching videoStream.mediaGuid) for segment queries
      final files = streamList?.files;
      final firstFile = (files != null && files.isNotEmpty)
          ? files.firstWhere(
              (f) => f.path.trim().isNotEmpty,
              orElse: () => files.first,
            )
          : null;
      final filePath = firstFile?.path.trim().isNotEmpty == true
          ? firstFile!.path.trim()
          : episode.fileName.trim();
      final fileGuid = firstFile?.guid ?? episode.guid;
      if (seasonPath.isEmpty && filePath.isNotEmpty) {
        seasonPath = path.dirname(filePath);
      }
      queuedEpisodes.add(QueuedEpisode(
        guid: fileGuid,
        filePath: filePath,
        episodeNumber: episode.episodeNumber,
        seasonNumber: episode.seasonNumber,
      ));
      if (episodeIndex < episodes.length - 1) {
        await _delay(episodeThrottleDelay);
      }
    }

    final response = (await _flyNarwhalRemoteDataSource.analyze(
      AnalyzeRequest(
        seasonGuid: seasonGuid,
        seasonPath: seasonPath,
        episodes: queuedEpisodes,
        tvTitle: tvTitle,
        seasonNumber: seasonNumber,
      ),
    ))
        .getOrThrow();
    if (!response.isSuccess()) {
      throw Exception(_failureMessage(response.msg));
    }

    // Force polling only after the analysis request is accepted.
    _startSeasonPolling(seasonGuid);
    if (response.success == true) {
      return queuedSuccessMessage;
    }

    final serviceMessage = response.msg.trim().isNotEmpty
        ? response.msg.trim()
        : response.data?.trim() ?? '';
    return serviceMessage.isEmpty ? fallbackSuccessMessage : serviceMessage;
  }

  String _failureMessage(String message) {
    final normalizedMessage = message.trim();
    return normalizedMessage.isEmpty ? '分析请求提交失败' : normalizedMessage;
  }

  void _setSubmission(
    SmartAnalysisTargetKey key,
    AsyncValue<String> submission,
  ) {
    state = state.withSubmission(key, submission);
  }
}
