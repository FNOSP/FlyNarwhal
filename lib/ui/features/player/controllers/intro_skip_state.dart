import '../models/player_skip_action.dart';
import '../models/resolved_skip_segments.dart';

enum PendingCompletionDecision {
  outroCountdown,
  playbackCompleted,
}

class IntroSkipState {
  const IntroSkipState({
    required this.sessionGeneration,
    required this.episodeGuid,
    required this.mediaOpened,
    required this.effectiveStartPositionMilliseconds,
    required this.currentPositionMilliseconds,
    required this.previousMonitoredPositionMilliseconds,
    required this.durationMilliseconds,
    required this.isPlaying,
    required this.isUserSeeking,
    required this.shouldResetPositionBaseline,
    required this.segments,
    required this.pendingIntroSegment,
    required this.lastSkippedIntroSegment,
    required this.introSuppressedUntilMilliseconds,
    required this.isIntroUndoVisible,
    required this.introUndoRemainingSeconds,
    required this.isOutroPromptVisible,
    required this.outroRemainingSeconds,
    required this.isOutroCancelled,
    required this.isPlaybackEndVisible,
    required this.isAutoPlayEnabled,
    required this.nextEpisodeLoadPhase,
    required this.pendingCompletionDecision,
  });

  factory IntroSkipState.initial() {
    return IntroSkipState(
      sessionGeneration: 0,
      episodeGuid: null,
      mediaOpened: false,
      effectiveStartPositionMilliseconds: 0,
      currentPositionMilliseconds: 0,
      previousMonitoredPositionMilliseconds: null,
      durationMilliseconds: null,
      isPlaying: false,
      isUserSeeking: false,
      shouldResetPositionBaseline: false,
      segments: ResolvedSkipSegments.empty(),
      pendingIntroSegment: null,
      lastSkippedIntroSegment: null,
      introSuppressedUntilMilliseconds: null,
      isIntroUndoVisible: false,
      introUndoRemainingSeconds: 0,
      isOutroPromptVisible: false,
      outroRemainingSeconds: 0,
      isOutroCancelled: false,
      isPlaybackEndVisible: false,
      isAutoPlayEnabled: true,
      nextEpisodeLoadPhase: NextEpisodeLoadPhase.idle,
      pendingCompletionDecision: null,
    );
  }

  final int sessionGeneration;
  final String? episodeGuid;
  final bool mediaOpened;
  final int effectiveStartPositionMilliseconds;
  final int currentPositionMilliseconds;
  final int? previousMonitoredPositionMilliseconds;
  final int? durationMilliseconds;
  final bool isPlaying;
  final bool isUserSeeking;
  final bool shouldResetPositionBaseline;
  final ResolvedSkipSegments segments;
  final SkipSegmentMillis? pendingIntroSegment;
  final SkipSegmentMillis? lastSkippedIntroSegment;
  final int? introSuppressedUntilMilliseconds;
  final bool isIntroUndoVisible;
  final int introUndoRemainingSeconds;
  final bool isOutroPromptVisible;
  final int outroRemainingSeconds;
  final bool isOutroCancelled;
  final bool isPlaybackEndVisible;
  final bool isAutoPlayEnabled;
  final NextEpisodeLoadPhase nextEpisodeLoadPhase;
  final PendingCompletionDecision? pendingCompletionDecision;

  IntroSkipState copyWith({
    int? sessionGeneration,
    Object? episodeGuid = _unset,
    bool? mediaOpened,
    int? effectiveStartPositionMilliseconds,
    int? currentPositionMilliseconds,
    Object? previousMonitoredPositionMilliseconds = _unset,
    Object? durationMilliseconds = _unset,
    bool? isPlaying,
    bool? isUserSeeking,
    bool? shouldResetPositionBaseline,
    ResolvedSkipSegments? segments,
    Object? pendingIntroSegment = _unset,
    Object? lastSkippedIntroSegment = _unset,
    Object? introSuppressedUntilMilliseconds = _unset,
    bool? isIntroUndoVisible,
    int? introUndoRemainingSeconds,
    bool? isOutroPromptVisible,
    int? outroRemainingSeconds,
    bool? isOutroCancelled,
    bool? isPlaybackEndVisible,
    bool? isAutoPlayEnabled,
    NextEpisodeLoadPhase? nextEpisodeLoadPhase,
    Object? pendingCompletionDecision = _unset,
  }) {
    return IntroSkipState(
      sessionGeneration: sessionGeneration ?? this.sessionGeneration,
      episodeGuid: identical(episodeGuid, _unset)
          ? this.episodeGuid
          : episodeGuid as String?,
      mediaOpened: mediaOpened ?? this.mediaOpened,
      effectiveStartPositionMilliseconds: effectiveStartPositionMilliseconds ??
          this.effectiveStartPositionMilliseconds,
      currentPositionMilliseconds:
          currentPositionMilliseconds ?? this.currentPositionMilliseconds,
      previousMonitoredPositionMilliseconds:
          identical(previousMonitoredPositionMilliseconds, _unset)
              ? this.previousMonitoredPositionMilliseconds
              : previousMonitoredPositionMilliseconds as int?,
      durationMilliseconds: identical(durationMilliseconds, _unset)
          ? this.durationMilliseconds
          : durationMilliseconds as int?,
      isPlaying: isPlaying ?? this.isPlaying,
      isUserSeeking: isUserSeeking ?? this.isUserSeeking,
      shouldResetPositionBaseline:
          shouldResetPositionBaseline ?? this.shouldResetPositionBaseline,
      segments: segments ?? this.segments,
      pendingIntroSegment: identical(pendingIntroSegment, _unset)
          ? this.pendingIntroSegment
          : pendingIntroSegment as SkipSegmentMillis?,
      lastSkippedIntroSegment: identical(lastSkippedIntroSegment, _unset)
          ? this.lastSkippedIntroSegment
          : lastSkippedIntroSegment as SkipSegmentMillis?,
      introSuppressedUntilMilliseconds:
          identical(introSuppressedUntilMilliseconds, _unset)
              ? this.introSuppressedUntilMilliseconds
              : introSuppressedUntilMilliseconds as int?,
      isIntroUndoVisible: isIntroUndoVisible ?? this.isIntroUndoVisible,
      introUndoRemainingSeconds:
          introUndoRemainingSeconds ?? this.introUndoRemainingSeconds,
      isOutroPromptVisible: isOutroPromptVisible ?? this.isOutroPromptVisible,
      outroRemainingSeconds:
          outroRemainingSeconds ?? this.outroRemainingSeconds,
      isOutroCancelled: isOutroCancelled ?? this.isOutroCancelled,
      isPlaybackEndVisible: isPlaybackEndVisible ?? this.isPlaybackEndVisible,
      isAutoPlayEnabled: isAutoPlayEnabled ?? this.isAutoPlayEnabled,
      nextEpisodeLoadPhase: nextEpisodeLoadPhase ?? this.nextEpisodeLoadPhase,
      pendingCompletionDecision: identical(pendingCompletionDecision, _unset)
          ? this.pendingCompletionDecision
          : pendingCompletionDecision as PendingCompletionDecision?,
    );
  }

  static const Object _unset = Object();
}

sealed class PlayerSkipEvent {
  const PlayerSkipEvent();
}

final class EpisodeSessionStarted extends PlayerSkipEvent {
  const EpisodeSessionStarted({
    required this.episodeGuid,
    required this.effectiveStartPositionMilliseconds,
    required this.segments,
    required this.isAutoPlayEnabled,
    required this.nextEpisodeLoadPhase,
  });

  final String episodeGuid;
  final int effectiveStartPositionMilliseconds;
  final ResolvedSkipSegments segments;
  final bool isAutoPlayEnabled;
  final NextEpisodeLoadPhase nextEpisodeLoadPhase;
}

final class MediaOpened extends PlayerSkipEvent {
  const MediaOpened();
}

final class PositionChanged extends PlayerSkipEvent {
  const PositionChanged(this.positionMilliseconds);

  final int positionMilliseconds;
}

final class DurationChanged extends PlayerSkipEvent {
  const DurationChanged(this.durationMilliseconds);

  final int? durationMilliseconds;
}

final class PlayingChanged extends PlayerSkipEvent {
  const PlayingChanged(this.isPlaying);

  final bool isPlaying;
}

final class UserSeekStarted extends PlayerSkipEvent {
  const UserSeekStarted();
}

final class UserSeekCompleted extends PlayerSkipEvent {
  const UserSeekCompleted();
}

final class SegmentsChanged extends PlayerSkipEvent {
  const SegmentsChanged(this.segments);

  final ResolvedSkipSegments segments;
}

final class IntroUndoRequested extends PlayerSkipEvent {
  const IntroUndoRequested();
}

final class OutroCancelRequested extends PlayerSkipEvent {
  const OutroCancelRequested();
}

final class PlaybackCompleted extends PlayerSkipEvent {
  const PlaybackCompleted();
}

final class IntroUndoTicked extends PlayerSkipEvent {
  const IntroUndoTicked(this.sessionGeneration);

  final int sessionGeneration;
}

final class OutroCountdownTicked extends PlayerSkipEvent {
  const OutroCountdownTicked(this.sessionGeneration);

  final int sessionGeneration;
}

final class NextEpisodeLoadChanged extends PlayerSkipEvent {
  const NextEpisodeLoadChanged(this.phase);

  final NextEpisodeLoadPhase phase;
}

final class AutoPlayChanged extends PlayerSkipEvent {
  const AutoPlayChanged(this.isEnabled);

  final bool isEnabled;
}

final class NextEpisodeWaitCompleted extends PlayerSkipEvent {
  const NextEpisodeWaitCompleted({
    required this.sessionGeneration,
    required this.phase,
  });

  final int sessionGeneration;
  final NextEpisodeLoadPhase phase;
}

final class FeatureDisabled extends PlayerSkipEvent {
  const FeatureDisabled();
}

final class SessionDisposed extends PlayerSkipEvent {
  const SessionDisposed();
}
