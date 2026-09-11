import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../data/datasources/remote/media_remote_data_source.dart';
import '../core/network/api_result.dart';
import '../data/models/fly_narwhal/index.dart';

typedef AnalysisDelay = Future<void> Function(Duration duration);
typedef StartSeasonPolling = void Function(String seasonGuid);

class SmartAnalysisSubmissionException implements Exception {
  final String message;

  /// Whether the PREPARING status had already been accepted by the server when
  /// this failure happened; the UI uses this to pick its fallback toast text.
  final bool preparingStarted;

  const SmartAnalysisSubmissionException(
    this.message, {
    this.preparingStarted = false,
  });

  @override
  String toString() => message;
}

/// A server rejection that must reach the user verbatim instead of being
/// replaced by the generic submission-failure toast (e.g. the client version
/// is below the server's minimum). Carrying it as a distinct type also lets
/// the flow abort before optimistic "queued" feedback is shown.
class SmartAnalysisUserMessageException implements Exception {
  final String message;

  const SmartAnalysisUserMessageException(this.message);

  @override
  String toString() => message;
}

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

  bool hasAnySubmitting() {
    return submissions.values.any((submission) => submission.isLoading);
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
  static const String queuedLoadingMessage = '已加入到分析队列';
  static const String fallbackSuccessMessage = '分析请求已提交';

  final FlyNarwhalRemoteDataSource _flyNarwhalRemoteDataSource;
  final MediaRemoteDataSource _mediaRemoteDataSource;
  final AnalysisDelay _delay;
  final StartSeasonPolling _startSeasonPolling;
  final StartSeasonPolling _startSeasonPreparedPolling;
  final String? Function() _resolveUserGuid;
  final Set<String> _submittingSeasonGuids = <String>{};

  SmartAnalysisController(
    this._flyNarwhalRemoteDataSource,
    this._mediaRemoteDataSource, {
    AnalysisDelay? delay,
    StartSeasonPolling? startSeasonPolling,
    StartSeasonPolling? startSeasonPreparedPolling,
    String? Function()? resolveUserGuid,
  })  : _delay = delay ?? Future<void>.delayed,
        _startSeasonPolling = startSeasonPolling ?? _ignorePollingRequest,
        _startSeasonPreparedPolling =
            startSeasonPreparedPolling ?? _ignorePollingRequest,
        _resolveUserGuid = resolveUserGuid ?? (() => null),
        super(const SmartAnalysisSubmissionState());

  static void _ignorePollingRequest(String seasonGuid) {}

  /// Cheap probe of the server's minimum-client-version gate: a status query
  /// carries no side effects, and the server rejects outdated clients on every
  /// non-config endpoint with [FlyNarwhalRemoteDataSource.clientVersionTooLowCode].
  Future<SmartAnalysisUserMessageException?> _clientVersionError() async {
    try {
      final result = await _flyNarwhalRemoteDataSource.getStatus(
        type: 'season',
        guid: '',
      );
      final failure = result.failureOrNull;
      if (failure?.code == FlyNarwhalRemoteDataSource.clientVersionTooLowCode) {
        final message = failure!.displayMessage.trim();
        return SmartAnalysisUserMessageException(
          message.isEmpty ? '客户端版本过低，请升级后重试' : message,
        );
      }
    } catch (_) {
      // Probe failures other than a version rejection must not block the flow.
    }
    return null;
  }

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

    // Reject an outdated client before any optimistic "queued" feedback shows.
    final versionError = await _clientVersionError();
    if (versionError != null) {
      _setSubmission(
        targetKey,
        AsyncError<String>(versionError, StackTrace.current),
      );
      _submittingSeasonGuids.remove(seasonGuid);
      return;
    }

    _setSubmission(targetKey, const AsyncLoading<String>());
    try {
      final message = await _submitSeason(
        seasonGuid,
        tvTitle,
        seasonNumber,
        shouldUpdatePreparingStatus: true,
      );
      _setSubmission(targetKey, AsyncData<String>(message));
    } on SmartAnalysisSubmissionException catch (error, stackTrace) {
      // The server may already hold this season in PREPARING; write the status
      // back to FAILED so cards do not show "准备中" forever.
      if (error.preparingStarted) {
        await _markSeasonsFailed([seasonGuid]);
      }
      _setSubmission(targetKey, AsyncError<String>(error, stackTrace));
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

    final versionError = await _clientVersionError();
    if (versionError != null) {
      _setSubmission(
        targetKey,
        AsyncError<String>(versionError, StackTrace.current),
      );
      return;
    }

    _setSubmission(targetKey, const AsyncLoading<String>());
    final failedSeasonGuids = <String>[];
    final failedSeasonTitlesByGuid = <String, String>{};
    var preparingStarted = false;
    var preparedSeasonGuids = const <String>[];
    try {
      final seasons =
          (await _mediaRemoteDataSource.getSeasonList(tvGuid)).getOrThrow();
      final preparingSeasonGuids =
          seasons.map((season) => season.guid).toList();
      await _updateSeasonStatuses(
        preparingSeasonGuids,
        AnalysisStatus.preparing,
        '设置准备中状态失败',
      );
      preparingStarted = true;
      preparedSeasonGuids = preparingSeasonGuids;
      // Refresh status displays as soon as the server holds PREPARING, before
      // the slow per-season episode collection below.
      for (final seasonGuid in preparingSeasonGuids) {
        _startSeasonPreparedPolling(seasonGuid);
      }

      final successMessages = <String>[];
      for (final season in seasons) {
        // Share the Season GUID lock with direct Season submissions.
        if (!_submittingSeasonGuids.add(season.guid)) {
          failedSeasonGuids.add(season.guid);
          failedSeasonTitlesByGuid[season.guid] = season.title;
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
          failedSeasonGuids.add(season.guid);
          failedSeasonTitlesByGuid[season.guid] = season.title;
        } finally {
          _submittingSeasonGuids.remove(season.guid);
        }
      }

      if (failedSeasonGuids.isNotEmpty) {
        throw SmartAnalysisSubmissionException(
          '失败剧季：${failedSeasonGuids.map((guid) => failedSeasonTitlesByGuid[guid]).join('、')}',
          preparingStarted: true,
        );
      }
      final serviceMessage = successMessages.firstWhere(
        (message) => message.trim().isNotEmpty,
        orElse: () => fallbackSuccessMessage,
      );
      _setSubmission(targetKey, AsyncData<String>(serviceMessage));
    } on SmartAnalysisSubmissionException catch (error, stackTrace) {
      if (error.preparingStarted) {
        await _markSeasonsFailed(failedSeasonGuids);
      }
      _setSubmission(targetKey, AsyncError<String>(error, stackTrace));
    } catch (error, stackTrace) {
      // A mid-flight network failure may leave every season in PREPARING on
      // the server; best-effort write them back to FAILED.
      if (preparingStarted) {
        await _markSeasonsFailed(preparedSeasonGuids);
      }
      _setSubmission(targetKey, AsyncError<String>(error, stackTrace));
    }
  }

  Future<String> _submitSeason(
    String seasonGuid,
    String tvTitle,
    int seasonNumber, {
    required bool shouldUpdatePreparingStatus,
  }) async {
    var preparingStarted = false;
    try {
      if (shouldUpdatePreparingStatus) {
        await _updateSeasonStatuses(
          <String>[seasonGuid],
          AnalysisStatus.preparing,
          '设置准备中状态失败',
        );
        preparingStarted = true;
        _startSeasonPreparedPolling(seasonGuid);
      }

      final episodes = (await _mediaRemoteDataSource.getEpisodeList(seasonGuid))
          .getOrThrow();
      final queuedEpisodes = <QueuedEpisode>[];
      String seasonPath = '';

      for (var episodeIndex = 0;
          episodeIndex < episodes.length;
          episodeIndex++) {
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

      final analyzeResponse = (await _flyNarwhalRemoteDataSource.analyze(
        AnalyzeRequest(
          seasonGuid: seasonGuid,
          seasonPath: seasonPath,
          episodes: queuedEpisodes,
          tvTitle: tvTitle,
          seasonNumber: seasonNumber,
          // The server loads this user's SmartSkipConfig when running analysis.
          userGuid: _resolveUserGuid(),
        ),
      ))
          .getOrThrow();
      if (!analyzeResponse.isSuccess()) {
        throw Exception(_failureMessage(analyzeResponse.msg));
      }

      // Force polling only after the analysis request is accepted.
      _startSeasonPolling(seasonGuid);
      if (analyzeResponse.success == true) {
        return queuedSuccessMessage;
      }

      final serviceMessage = analyzeResponse.msg.trim().isNotEmpty
          ? analyzeResponse.msg.trim()
          : analyzeResponse.data?.trim() ?? '';
      return serviceMessage.isEmpty ? fallbackSuccessMessage : serviceMessage;
    } catch (error) {
      // FailureInfo does not extend Exception and its toString() is useless;
      // surface its server-provided message instead.
      final failure = error is FailureInfo ? error : null;
      throw SmartAnalysisSubmissionException(
        failure != null
            ? _failureMessage(failure.displayMessage)
            : error.toString(),
        preparingStarted: preparingStarted,
      );
    }
  }

  Future<void> _updateSeasonStatuses(
    List<String> seasonGuids,
    AnalysisStatus status,
    String fallbackMessage,
  ) async {
    if (seasonGuids.isEmpty) return;
    final result = (await _flyNarwhalRemoteDataSource.updateSeasonStatus(
      UpdateSeasonStatusRequest(
        seasonGuids: seasonGuids,
        status: status.toJsonValue(),
      ),
    ))
        .getOrThrow();
    if (!result.isSuccess()) {
      throw Exception(_failureMessage(result.msg, fallbackMessage));
    }
  }

  /// Best-effort write-back so seasons stuck in PREPARING surface as FAILED.
  Future<void> _markSeasonsFailed(List<String> seasonGuids) async {
    if (seasonGuids.isEmpty) return;
    try {
      await _updateSeasonStatuses(
        seasonGuids,
        AnalysisStatus.failed,
        '分析请求提交失败',
      );
      // Re-poll with the same force semantics as a successful submission so
      // cards leave "准备中" immediately.
      for (final seasonGuid in seasonGuids) {
        _startSeasonPolling(seasonGuid);
      }
    } catch (_) {
      // Never mask the original submission failure with a status write-back error.
    }
  }

  String _failureMessage(String message, [String fallback = '分析请求提交失败']) {
    final normalizedMessage = message.trim();
    return normalizedMessage.isEmpty ? fallback : normalizedMessage;
  }

  void _setSubmission(
    SmartAnalysisTargetKey key,
    AsyncValue<String> submission,
  ) {
    state = state.withSubmission(key, submission);
  }
}
