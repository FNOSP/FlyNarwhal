import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/player_seek_origin.dart';
import '../models/player_skip_action.dart';
import '../models/resolved_skip_segments.dart';
import 'intro_skip_state.dart';

typedef SkipTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

class IntroSkipController extends StateNotifier<IntroSkipState> {
  IntroSkipController({
    SkipTimerFactory timerFactory = _defaultTimerFactory,
  })  : _timerFactory = timerFactory,
        super(IntroSkipState.initial());

  static const Duration introUndoDuration = Duration(seconds: 5);
  static const Duration outroCountdownDuration = Duration(seconds: 5);
  static const Duration nextEpisodeWaitTimeout = Duration(seconds: 5);
  static const int introConfirmationToleranceMilliseconds = 200;
  static const int contentAfterCreditsToleranceMilliseconds = 1000;

  final SkipTimerFactory _timerFactory;
  final StreamController<PlayerSkipAction> _actionsController =
      StreamController<PlayerSkipAction>.broadcast();
  Timer? _introUndoTimer;
  Timer? _outroCountdownTimer;
  bool _isDisposed = false;

  Stream<PlayerSkipAction> get actions => _actionsController.stream;

  void dispatch(PlayerSkipEvent event) {
    if (_isDisposed && event is! SessionDisposed) {
      return;
    }

    switch (event) {
      case EpisodeSessionStarted():
        _startEpisodeSession(event);
      case MediaOpened():
        state = state.copyWith(mediaOpened: true);
      case PositionChanged():
        _handlePositionChanged(event.positionMilliseconds);
      case DurationChanged():
        state = state.copyWith(
          durationMilliseconds: event.durationMilliseconds,
        );
      case PlayingChanged():
        _handlePlayingChanged(event.isPlaying);
      case UserSeekStarted():
        state = state.copyWith(isUserSeeking: true);
      case UserSeekCompleted():
        state = state.copyWith(
          isUserSeeking: false,
          shouldResetPositionBaseline: true,
        );
      case SegmentsChanged():
        state = state.copyWith(
          segments: event.segments,
          durationMilliseconds: event.segments.durationMilliseconds,
        );
      case IntroUndoRequested():
        _undoIntro();
      case OutroCancelRequested():
        _cancelOutro();
      case PlaybackCompleted():
        _completePlayback();
      case IntroUndoTicked():
        _tickIntroUndo(event.sessionGeneration);
      case OutroCountdownTicked():
        _tickOutroCountdown(event.sessionGeneration);
      case NextEpisodeLoadChanged():
        state = state.copyWith(nextEpisodeLoadPhase: event.phase);
      case AutoPlayChanged():
        state = state.copyWith(isAutoPlayEnabled: event.isEnabled);
      case NextEpisodeWaitCompleted():
        _completeNextEpisodeWait(event);
      case FeatureDisabled():
        _disableFeature();
      case SessionDisposed():
        _disposeSession();
    }
  }

  void _startEpisodeSession(EpisodeSessionStarted event) {
    _cancelTimers();
    final nextGeneration = state.sessionGeneration + 1;
    state = IntroSkipState.initial().copyWith(
      sessionGeneration: nextGeneration,
      episodeGuid: event.episodeGuid,
      effectiveStartPositionMilliseconds:
          event.effectiveStartPositionMilliseconds,
      currentPositionMilliseconds: event.effectiveStartPositionMilliseconds,
      durationMilliseconds: event.segments.durationMilliseconds,
      segments: event.segments,
      isAutoPlayEnabled: event.isAutoPlayEnabled,
      nextEpisodeLoadPhase: event.nextEpisodeLoadPhase,
    );
  }

  void _handlePositionChanged(int positionMilliseconds) {
    final previousPosition = state.previousMonitoredPositionMilliseconds;
    final isBaselineOnly = state.shouldResetPositionBaseline;
    var nextState = state.copyWith(
      currentPositionMilliseconds: positionMilliseconds,
      previousMonitoredPositionMilliseconds: positionMilliseconds,
      shouldResetPositionBaseline: false,
    );

    final pendingIntro = nextState.pendingIntroSegment;
    if (pendingIntro != null &&
        positionMilliseconds >=
            pendingIntro.endMilliseconds -
                introConfirmationToleranceMilliseconds) {
      nextState = nextState.copyWith(
        pendingIntroSegment: null,
        lastSkippedIntroSegment: pendingIntro,
        isIntroUndoVisible: true,
        introUndoRemainingSeconds: introUndoDuration.inSeconds,
      );
      state = nextState;
      _scheduleIntroUndoTick();
      return;
    }

    final suppressionEnd = nextState.introSuppressedUntilMilliseconds;
    if (suppressionEnd != null && positionMilliseconds >= suppressionEnd) {
      nextState = nextState.copyWith(
        introSuppressedUntilMilliseconds: null,
      );
    }

    nextState = _updateOutroRangeExit(nextState, positionMilliseconds);
    state = nextState;
    if (isBaselineOnly) {
      return;
    }

    final isNaturalPlayback = state.mediaOpened &&
        state.isPlaying &&
        !state.isUserSeeking &&
        (previousPosition == null || positionMilliseconds >= previousPosition);
    if (!isNaturalPlayback) {
      return;
    }

    if (_shouldTriggerIntro(previousPosition, positionMilliseconds)) {
      _triggerIntro(state.segments.introSegment!);
      return;
    }
    if (_shouldTriggerOutro(previousPosition, positionMilliseconds)) {
      _triggerOutro();
    }
  }

  IntroSkipState _updateOutroRangeExit(
    IntroSkipState currentState,
    int positionMilliseconds,
  ) {
    final credits = currentState.segments.creditsSegment;
    if (credits == null) {
      if (currentState.isOutroPromptVisible) {
        _outroCountdownTimer?.cancel();
      }
      return currentState.copyWith(
        isOutroPromptVisible: false,
        outroRemainingSeconds: 0,
        isOutroCancelled: false,
      );
    }

    final isBeforeCredits = positionMilliseconds < credits.startMilliseconds;
    final isAfterCredits = positionMilliseconds >= credits.endMilliseconds;
    if (!isBeforeCredits && !isAfterCredits) {
      return currentState;
    }
    _outroCountdownTimer?.cancel();
    return currentState.copyWith(
      isOutroPromptVisible: false,
      outroRemainingSeconds: 0,
      isOutroCancelled: isBeforeCredits ? false : currentState.isOutroCancelled,
    );
  }

  bool _shouldTriggerIntro(
    int? previousPosition,
    int currentPosition,
  ) {
    final intro = state.segments.introSegment;
    if (intro == null ||
        state.pendingIntroSegment != null ||
        state.lastSkippedIntroSegment != null ||
        state.isIntroUndoVisible ||
        state.isOutroPromptVisible ||
        state.introSuppressedUntilMilliseconds != null ||
        !intro.contains(currentPosition)) {
      return false;
    }

    // If this session resumed at or past the intro end, the intro was already
    // watched — never auto-skip it again. Without this guard, a quality switch
    // that reopens an HLS stream transiently reports position ~0 (the mpv
    // `start` property is ignored for HLS until the correction seek applies),
    // and the crossing detection below mistakes that 0->small jump for natural
    // playback crossing the intro start.
    if (state.effectiveStartPositionMilliseconds >= intro.endMilliseconds) {
      return false;
    }

    if (previousPosition == null) {
      return true;
    }
    return previousPosition <= intro.startMilliseconds &&
        currentPosition >= intro.startMilliseconds;
  }

  bool _shouldTriggerOutro(
    int? previousPosition,
    int currentPosition,
  ) {
    final credits = state.segments.creditsSegment;
    if (credits == null ||
        previousPosition == null ||
        state.isOutroCancelled ||
        state.isOutroPromptVisible ||
        state.isPlaybackEndVisible ||
        state.pendingIntroSegment != null ||
        state.isIntroUndoVisible ||
        _hasActiveIntroSuppression(currentPosition) ||
        !credits.contains(currentPosition)) {
      return false;
    }
    return previousPosition < credits.startMilliseconds &&
        currentPosition >= credits.startMilliseconds;
  }

  bool _hasActiveIntroSuppression(int currentPosition) {
    final suppressionEnd = state.introSuppressedUntilMilliseconds;
    return suppressionEnd != null && currentPosition < suppressionEnd;
  }

  void _triggerIntro(SkipSegmentMillis intro) {
    state = state.copyWith(pendingIntroSegment: intro);
    _emitAction(
      SeekTo(
        sessionGeneration: state.sessionGeneration,
        milliseconds: intro.endMilliseconds,
        origin: PlayerSeekOrigin.introAutoSkip,
      ),
    );
  }

  void _undoIntro() {
    final skippedIntro = state.lastSkippedIntroSegment;
    if (!state.isIntroUndoVisible || skippedIntro == null) {
      return;
    }
    // Restore the resumed position when the auto-skip jumped over it
    // (start position before the intro end); otherwise fall back to the
    // intro start for a fresh play or a resume already past the intro.
    final startPosition = state.effectiveStartPositionMilliseconds;
    final undoTarget =
        startPosition > 0 && startPosition < skippedIntro.endMilliseconds
            ? startPosition
            : skippedIntro.startMilliseconds;
    _introUndoTimer?.cancel();
    state = state.copyWith(
      isIntroUndoVisible: false,
      introUndoRemainingSeconds: 0,
      introSuppressedUntilMilliseconds: skippedIntro.endMilliseconds,
      lastSkippedIntroSegment: null,
    );
    _emitAction(
      SeekTo(
        sessionGeneration: state.sessionGeneration,
        milliseconds: undoTarget,
        origin: PlayerSeekOrigin.introUndo,
      ),
    );
  }

  void _triggerOutro() {
    state = state.copyWith(
      isOutroPromptVisible: true,
      outroRemainingSeconds: outroCountdownDuration.inSeconds,
    );
    _scheduleOutroCountdownTick();
  }

  void _cancelOutro() {
    if (!state.isOutroPromptVisible) {
      return;
    }
    _outroCountdownTimer?.cancel();
    state = state.copyWith(
      isOutroPromptVisible: false,
      outroRemainingSeconds: 0,
      isOutroCancelled: true,
    );
  }

  void _handlePlayingChanged(bool isPlaying) {
    state = state.copyWith(isPlaying: isPlaying);
    if (!state.isOutroPromptVisible) {
      return;
    }
    if (isPlaying) {
      _scheduleOutroCountdownTick();
    } else {
      _outroCountdownTimer?.cancel();
    }
  }

  void _tickIntroUndo(int sessionGeneration) {
    if (sessionGeneration != state.sessionGeneration ||
        !state.isIntroUndoVisible) {
      return;
    }
    final remainingSeconds = state.introUndoRemainingSeconds - 1;
    if (remainingSeconds <= 0) {
      state = state.copyWith(
        isIntroUndoVisible: false,
        introUndoRemainingSeconds: 0,
      );
      return;
    }
    state = state.copyWith(introUndoRemainingSeconds: remainingSeconds);
    _scheduleIntroUndoTick();
  }

  void _tickOutroCountdown(int sessionGeneration) {
    if (sessionGeneration != state.sessionGeneration ||
        !state.isOutroPromptVisible ||
        !state.isPlaying) {
      return;
    }
    final remainingSeconds = state.outroRemainingSeconds - 1;
    if (remainingSeconds <= 0) {
      state = state.copyWith(
        isOutroPromptVisible: false,
        outroRemainingSeconds: 0,
      );
      _decideOutroCompletion();
      return;
    }
    state = state.copyWith(outroRemainingSeconds: remainingSeconds);
    _scheduleOutroCountdownTick();
  }

  void _decideOutroCompletion() {
    final credits = state.segments.creditsSegment;
    if (credits == null) {
      return;
    }
    final durationMilliseconds =
        state.durationMilliseconds ?? state.segments.durationMilliseconds;
    final hasContentAfterCredits = durationMilliseconds == null ||
        credits.endMilliseconds <
            durationMilliseconds - contentAfterCreditsToleranceMilliseconds;
    if (!state.isAutoPlayEnabled || hasContentAfterCredits) {
      _emitOutroSeek(credits.endMilliseconds);
      return;
    }
    _decideNextEpisode(
      PendingCompletionDecision.outroCountdown,
      durationMilliseconds: durationMilliseconds,
    );
  }

  void _completePlayback() {
    _outroCountdownTimer?.cancel();
    state = state.copyWith(
      isOutroPromptVisible: false,
      outroRemainingSeconds: 0,
    );
    if (!state.isAutoPlayEnabled) {
      _showPlaybackEnd();
      return;
    }
    _decideNextEpisode(PendingCompletionDecision.playbackCompleted);
  }

  void _decideNextEpisode(
    PendingCompletionDecision decision, {
    int? durationMilliseconds,
  }) {
    switch (state.nextEpisodeLoadPhase) {
      case NextEpisodeLoadPhase.available:
        state = state.copyWith(pendingCompletionDecision: null);
        _emitAction(
          PlayNextEpisode(sessionGeneration: state.sessionGeneration),
        );
      case NextEpisodeLoadPhase.loading:
      case NextEpisodeLoadPhase.idle:
        state = state.copyWith(pendingCompletionDecision: decision);
        _emitAction(
          AwaitNextEpisode(
            sessionGeneration: state.sessionGeneration,
            timeout: nextEpisodeWaitTimeout,
          ),
        );
      case NextEpisodeLoadPhase.unavailable:
      case NextEpisodeLoadPhase.failed:
        state = state.copyWith(pendingCompletionDecision: null);
        if (decision == PendingCompletionDecision.outroCountdown) {
          _finishAtMediaEnd(durationMilliseconds);
        } else {
          _showPlaybackEnd();
        }
    }
  }

  void _completeNextEpisodeWait(NextEpisodeWaitCompleted event) {
    if (event.sessionGeneration != state.sessionGeneration ||
        state.pendingCompletionDecision == null) {
      return;
    }
    final decision = state.pendingCompletionDecision!;
    state = state.copyWith(
      nextEpisodeLoadPhase: event.phase,
      pendingCompletionDecision: null,
    );
    if (event.phase == NextEpisodeLoadPhase.available) {
      _emitAction(PlayNextEpisode(sessionGeneration: state.sessionGeneration));
      return;
    }
    if (decision == PendingCompletionDecision.outroCountdown) {
      _finishAtMediaEnd(state.durationMilliseconds);
    } else {
      _showPlaybackEnd();
    }
  }

  void _finishAtMediaEnd(int? durationMilliseconds) {
    final mediaEnd = durationMilliseconds ?? state.currentPositionMilliseconds;
    _emitOutroSeek(mediaEnd);
    _emitAction(PausePlayback(sessionGeneration: state.sessionGeneration));
    _showPlaybackEnd();
  }

  void _emitOutroSeek(int milliseconds) {
    _emitAction(
      SeekTo(
        sessionGeneration: state.sessionGeneration,
        milliseconds: milliseconds,
        origin: PlayerSeekOrigin.outroAutoSkip,
      ),
    );
  }

  void _showPlaybackEnd() {
    state = state.copyWith(isPlaybackEndVisible: true);
    _emitAction(ShowPlaybackEnd(sessionGeneration: state.sessionGeneration));
  }

  void _disableFeature() {
    _cancelTimers();
    state = state.copyWith(
      segments: ResolvedSkipSegments.empty(
        episodeGuid: state.episodeGuid ?? '',
        durationMilliseconds: state.durationMilliseconds,
      ),
      pendingIntroSegment: null,
      lastSkippedIntroSegment: null,
      introSuppressedUntilMilliseconds: null,
      isIntroUndoVisible: false,
      introUndoRemainingSeconds: 0,
      isOutroPromptVisible: false,
      outroRemainingSeconds: 0,
      isOutroCancelled: false,
      pendingCompletionDecision: null,
    );
  }

  void _disposeSession() {
    _cancelTimers();
    state = IntroSkipState.initial().copyWith(
      sessionGeneration: state.sessionGeneration + 1,
    );
  }

  void _scheduleIntroUndoTick() {
    _introUndoTimer?.cancel();
    final capturedGeneration = state.sessionGeneration;
    _introUndoTimer = _timerFactory(const Duration(seconds: 1), () {
      dispatch(IntroUndoTicked(capturedGeneration));
    });
  }

  void _scheduleOutroCountdownTick() {
    _outroCountdownTimer?.cancel();
    if (!state.isOutroPromptVisible || !state.isPlaying) {
      return;
    }
    final capturedGeneration = state.sessionGeneration;
    _outroCountdownTimer = _timerFactory(const Duration(seconds: 1), () {
      dispatch(OutroCountdownTicked(capturedGeneration));
    });
  }

  void _cancelTimers() {
    _introUndoTimer?.cancel();
    _outroCountdownTimer?.cancel();
    _introUndoTimer = null;
    _outroCountdownTimer = null;
  }

  void _emitAction(PlayerSkipAction action) {
    if (!_actionsController.isClosed) {
      _actionsController.add(action);
    }
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _disposeSession();
    _isDisposed = true;
    _actionsController.close();
    super.dispose();
  }

  static Timer _defaultTimerFactory(
    Duration duration,
    void Function() callback,
  ) {
    return Timer(duration, callback);
  }
}
