import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../shared/common/app_loading_progress_ring.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart' hide DragToMoveArea;
import '../../../core/network/api_result.dart';
import '../../../data/models/episode_list_response.dart';
import '../../../data/models/media_request_models.dart';
import '../../../data/models/player_models.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../data/models/fly_narwhal/danmaku.dart';
import '../../../data/storage/player_settings_store.dart';
import '../../../data/storage/shortcut_settings_store.dart';
import '../../../core/utils/app_fonts.dart';
import '../../../core/utils/log/app_talker.dart';
import '../../../providers/file_providers.dart';
import '../../../providers/danmaku_controller.dart';
import '../../../providers/episode_analysis_controller.dart';
import '../../../providers/providers.dart';
import '../../../providers/smart_skip_settings_controller.dart';
import 'controllers/intro_skip_controller.dart';
import 'controllers/intro_skip_state.dart';
import 'controllers/player_seek_executor.dart';
import 'models/player_seek_origin.dart';
import 'models/player_skip_action.dart';
import 'models/resolved_skip_segments.dart';
import 'services/skip_segment_resolver.dart';
import 'services/direct_link_audio_track_resolver.dart';
import 'services/direct_link_subtitle_track_resolver.dart';
import 'services/hls_subtitle_repository.dart';
import 'services/player_device_context_service.dart';
import 'services/play_record_request_builder.dart';
import 'controllers/desktop_pseudo_fullscreen_controller.dart';
import 'controllers/pip_window_mode_controller.dart';
import 'controllers/player_manager.dart';
import 'viewmodels/media_playback_view_model.dart';
import 'controllers/player_overlay_controller.dart';
import 'controllers/player_session_coordinator.dart';
import 'services/player_service.dart';
import 'viewmodels/player_view_model.dart';
import 'widgets/episode_selection_flyout.dart';
import 'widgets/player_danmaku_overlay.dart';
import 'widgets/danmaku_settings_flyout.dart';
import 'widgets/player_subtitle_overlay.dart';
import 'widgets/video_player_progress_bar.dart';
import 'widgets/speed_control_flyout.dart';
import 'widgets/quality_control_flyout.dart';
import 'widgets/volume_control.dart';
import 'widgets/fullscreen_control.dart';
import 'widgets/next_episode_preview_flyout.dart';
import 'widgets/player_action_button.dart';
import 'widgets/player_settings_menu.dart';
import 'widgets/skip_intro_prompt.dart';
import 'widgets/skip_outro_prompt.dart';
import 'widgets/playback_end_overlay.dart';
import 'widgets/subtitle_control_flyout.dart';
import 'widgets/subtitle_search_dialog.dart';
import '../../shared/nas/add_nas_subtitle_dialog.dart';
import '../../shared/toast.dart';
import '../../shared/window_caption.dart';

enum _PlaybackIndicatorType { play, pause }

class PlayerScreen extends ConsumerStatefulWidget {
  final String guid;
  final String? mediaGuid;
  final String? audioGuid;
  final String? subtitleGuid;
  final int? initialPositionMs;

  const PlayerScreen({
    super.key,
    required this.guid,
    this.mediaGuid,
    this.audioGuid,
    this.subtitleGuid,
    this.initialPositionMs,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with TickerProviderStateMixin, WindowListener {
  static const int _controlFlyoutOffset = 15;
  static const double _trailingControlSpacing = 12;
  static const Duration _playbackIndicatorVisibleDuration =
      Duration(milliseconds: 200);
  static const Duration _playbackIndicatorExitDuration =
      Duration(milliseconds: 300);
  static const Duration _hlsSubtitleInitTimeout = Duration(seconds: 5);
  static const Duration _directLinkEmbeddedSubtitleTracksTimeout =
      Duration(seconds: 3);
  static const Duration _directLinkEmbeddedAudioTracksTimeout =
      Duration(seconds: 3);
  static const String _defaultMpvSubtitleFontSize = '60';
  static const String _defaultMpvSubtitlePosition = '100';
  static const String _defaultMpvCachePauseWait = '1.0';
  static const String _directLinkMpvCachePauseWait = '0.1';
  static const String _defaultMpvCachePause = 'yes';
  static const String _directLinkMpvCachePause = 'no';
  static const String _defaultMpvReadAheadSeconds = '120';
  static const String _directLinkMpvReadAheadSeconds = '120';
  static const String _defaultMpvDemuxerMaxBytes = '268435456';
  static const String _directLinkMpvDemuxerMaxBytes = '268435456';

  final FocusNode _playerFocusNode = FocusNode(debugLabel: 'player-shortcuts');
  Player? _player;
  VideoController? _videoController;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isFullscreen = false;
  int _currentPosition = 0;
  int _bufferedPosition = 0;
  int _duration = 0;
  double _volume = 1.0;
  double _lastVolumeBeforeMute = 0.0;
  double _speed = 1.0;
  List<QualityResponse> _qualities = [];
  QualityResponse? _currentQuality;
  String _currentResolution = '';
  int? _currentBitrate;
  PlayingInfoCache? _playingInfoCache;
  PlayInfoResponse? _playInfo;
  StreamResponse? _streamInfo;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _bufferSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<Tracks>? _tracksSubscription;
  StreamSubscription<PlayerSkipAction>? _skipActionSubscription;
  void Function()? _removeIntroSkipStateListener;
  late final IntroSkipController _introSkipController;
  IntroSkipState _introSkipState = IntroSkipState.initial();
  late final PlayerSeekExecutor _seekExecutor;
  final SkipSegmentResolver _skipSegmentResolver = const SkipSegmentResolver();
  ResolvedSkipSegments _resolvedSkipSegments = ResolvedSkipSegments.empty();
  NextEpisodeLoadPhase _nextEpisodeLoadPhase = NextEpisodeLoadPhase.idle;
  bool _isSavingSkipConfig = false;
  Timer? _playRecordTimer;
  Timer? _playbackIndicatorTimer;
  late final AnimationController _playbackIndicatorExitController;
  int _lastRecordedPosition = 0;
  bool _hasSetupProviderListeners = false;
  bool _suspendPlaybackTransitionFeedback = true;
  bool _isPlaybackIndicatorVisible = false;
  _PlaybackIndicatorType? _playbackIndicatorType;
  int _loadRequestToken = 0;
  int _hlsSessionToken = 0;
  late String _currentItemGuid;
  String? _currentMediaGuid;
  String? _requestedAudioGuid;
  String? _requestedSubtitleGuid;
  String? _selectedAudioGuid;
  String? _selectedSubtitleGuid;
  List<EpisodeListResponse> _episodeList = [];
  EpisodeListResponse? _currentEpisode;
  EpisodeListResponse? _nextEpisode;
  HlsSubtitleRepository? _hlsSubtitleRepository;
  VoidCallback? _hlsSubtitleTextsListener;
  final ValueNotifier<List<String>> _hlsSubtitleTexts =
      ValueNotifier<List<String>>(const []);
  final ValueNotifier<Duration> _danmakuPosition =
      ValueNotifier<Duration>(Duration.zero);
  int _danmakuResetGeneration = 0;
  bool _useHlsSubtitleOverlay = false;
  // True when the active external subtitle uses absolute positioning
  // (\pos/\move on most events, e.g. danmaku), making sub-pos ineffective.
  bool _isPositionLockedSubtitle = false;
  Map<String, String> _iso6391Map = const {};
  Map<String, String> _iso6392Map = const {};
  bool _showSubtitleSearchDialog = false;
  bool _showAddNasSubtitleDialog = false;
  bool _isUploadingLocalSubtitle = false;
  bool _isSubtitleSwitching = false;
  List<AudioTrack> _embeddedAudioTracks = const <AudioTrack>[];
  int _audioSwitchToken = 0;
  final DirectLinkAudioTrackResolver _directLinkAudioTrackResolver =
      const DirectLinkAudioTrackResolver();
  List<SubtitleTrack> _embeddedSubtitleTracks = const <SubtitleTrack>[];
  String? _pendingEmbeddedSubtitleGuid;
  SubtitleStream? _pendingEmbeddedSubtitlePrevious;
  int _embeddedSubtitleSwitchToken = 0;
  final DirectLinkSubtitleTrackResolver _directLinkSubtitleTrackResolver =
      const DirectLinkSubtitleTrackResolver();
  final DesktopPseudoFullscreenController _fullscreenController =
      DesktopPseudoFullscreenController();
  final PipWindowModeController _pipController = PipWindowModeController();
  late final EpisodeAnalysisController _episodeAnalysisController;
  bool _isPipMode = false;
  bool _isPipHovered = false;
  bool _isPipTransitioning = false;
  Timer? _pipBoundsSaveTimer;
  Timer? _pipIdleTimer;
  bool? _lastMacOSWindowButtonsVisibility;
  bool? _pendingMacOSWindowButtonsVisibility;
  bool _pendingMacOSWindowButtonsForce = false;
  bool _macOSWindowButtonsSyncQueued = false;
  static const Duration _pipIdleHideDuration = Duration(seconds: 3);
  AnimationController? _pipTransitionController;

  PlayerOverlayController get _overlayController =>
      ref.read(playerOverlayControllerProvider.notifier);

  PlayerSessionCoordinator get _sessionCoordinator =>
      ref.read(playerSessionCoordinatorProvider);

  @override
  void initState() {
    super.initState();
    _episodeAnalysisController =
        ref.read(episodeAnalysisControllerProvider.notifier);
    _introSkipController = IntroSkipController();
    _removeIntroSkipStateListener = _introSkipController.addListener((state) {
      _introSkipState = state;
      if (mounted) setState(() {});
    });
    _skipActionSubscription =
        _introSkipController.actions.listen(_handleSkipAction);
    _seekExecutor = PlayerSeekExecutor(
      playerAdapter: CallbackPlayerSeekAdapter((targetMilliseconds) async {
        await _player?.seek(Duration(milliseconds: targetMilliseconds));
      }),
      authoritativeDurationMilliseconds: () => _duration,
      resetDanmaku: () => _danmakuResetGeneration++,
      updateDanmakuPosition: (targetMilliseconds) {
        _danmakuPosition.value = Duration(milliseconds: targetMilliseconds);
      },
      updatePlayRecord: (targetMilliseconds) {
        _queuePlayRecordUpdate(positionMs: targetMilliseconds);
      },
      notifyUserSeekStarted: () {
        _introSkipController.dispatch(const UserSeekStarted());
      },
      notifyUserSeekCompleted: () {
        _introSkipController.dispatch(const UserSeekCompleted());
      },
    );
    if (_isDesktopPlatform()) {
      windowManager.addListener(this);
      unawaited(_syncFullscreenState());
    }
    _playbackIndicatorExitController = AnimationController(
      vsync: this,
      duration: _playbackIndicatorExitDuration,
    )..addStatusListener((status) {
        if (status != AnimationStatus.completed || !mounted) {
          return;
        }
        setState(() => _isPlaybackIndicatorVisible = false);
        _playbackIndicatorExitController.value = 0;
      });
    _pipTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _syncPlaybackTargetsFromWidget();
    _restoreAutoPlaySetting();
    unawaited(_ensureSubtitleLanguageMapsLoaded());
    _initializePlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isMacOS) {
        return;
      }
      final overlayVisible =
          ref.read(playerOverlayControllerProvider).isUiVisible;
      _scheduleMacOSWindowButtonsSync(
        visible: overlayVisible,
        force: true,
      );
    });
  }

  @override
  void didUpdateWidget(covariant PlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeArgsChanged = oldWidget.guid != widget.guid ||
        oldWidget.mediaGuid != widget.mediaGuid ||
        oldWidget.audioGuid != widget.audioGuid ||
        oldWidget.subtitleGuid != widget.subtitleGuid ||
        oldWidget.initialPositionMs != widget.initialPositionMs;
    if (!routeArgsChanged) return;

    final shouldReload = widget.guid != _currentItemGuid ||
        widget.mediaGuid != _currentMediaGuid ||
        widget.audioGuid != _requestedAudioGuid ||
        widget.subtitleGuid != _requestedSubtitleGuid;
    if (!shouldReload) return;

    unawaited(_switchPlaybackTarget(
      guid: widget.guid,
      mediaGuid: widget.mediaGuid,
      audioGuid: widget.audioGuid,
      subtitleGuid: widget.subtitleGuid,
    ));
  }

  Future<void> _initializePlayer() async {
    _player = Player(
      configuration: const PlayerConfiguration(libass: true),
    );
    await _applyDefaultMpvSubtitleSettings(_player!);
    _videoController = VideoController(_player!);
    _setupPlayerPlaybackListener();
    _setupPlayerPositionListener();
    _setupPlayerBufferListener();
    _setupPlayerDurationListener();
    _setupPlayerCompletedListener();
    _setupProviderListeners();

    await _loadAndPlayMedia();
    if (mounted) {
      _playerFocusNode.requestFocus();
    }
  }

  Future<void> _applyDefaultMpvSubtitleSettings(Player player) async {
    final platform = player.platform;
    if (platform is! NativePlayer) {
      return;
    }

    await platform.setProperty(
      'sub-font-size',
      _defaultMpvSubtitleFontSize,
    );
    await platform.setProperty(
      'sub-pos',
      _defaultMpvSubtitlePosition,
    );
  }

  Future<void> _applyDirectLinkCachePolicy(Player player) async {
    final platform = player.platform;
    if (platform is! NativePlayer) {
      return;
    }

    final isDirectLink = _playingInfoCache?.isUseDirectLink == true;
    final cachePauseWait =
        isDirectLink ? _directLinkMpvCachePauseWait : _defaultMpvCachePauseWait;
    final cachePause =
        isDirectLink ? _directLinkMpvCachePause : _defaultMpvCachePause;
    final readAheadSeconds = isDirectLink
        ? _directLinkMpvReadAheadSeconds
        : _defaultMpvReadAheadSeconds;
    final demuxerMaxBytes = isDirectLink
        ? _directLinkMpvDemuxerMaxBytes
        : _defaultMpvDemuxerMaxBytes;
    await platform.setProperty(
      'cache',
      'yes',
      waitForInitialization: false,
    );
    await platform.setProperty(
      'demuxer-readahead-secs',
      readAheadSeconds,
      waitForInitialization: false,
    );
    await platform.setProperty(
      'demuxer-max-bytes',
      demuxerMaxBytes,
      waitForInitialization: false,
    );
    await platform.setProperty(
      'cache-pause-wait',
      cachePauseWait,
      waitForInitialization: false,
    );
    await platform.setProperty(
      'cache-pause',
      cachePause,
      waitForInitialization: false,
    );
  }

  void _setupPlayerPositionListener() {
    _positionSubscription?.cancel();
    final player = _player;
    if (player == null) return;
    _positionSubscription = player.stream.position.listen((position) {
      final positionMilliseconds = position.inMilliseconds;
      if (mounted && _currentPosition != positionMilliseconds) {
        setState(() => _currentPosition = positionMilliseconds);
      } else {
        _currentPosition = positionMilliseconds;
      }
      _hlsSubtitleRepository?.onPlaybackPosition(positionMilliseconds);
      _danmakuPosition.value = position;
      _introSkipController.dispatch(PositionChanged(positionMilliseconds));
    });
  }

  void _setupPlayerBufferListener() {
    _bufferSubscription?.cancel();
    final player = _player;
    if (player == null) return;

    _bufferSubscription = player.stream.buffer.listen((bufferPosition) {
      final bufferMilliseconds = bufferPosition.inMilliseconds;
      if (mounted && _bufferedPosition != bufferMilliseconds) {
        setState(() => _bufferedPosition = bufferMilliseconds);
      } else {
        _bufferedPosition = bufferMilliseconds;
      }
    });
  }

  double get _bufferedProgressRatio {
    if (_duration <= 0) return 0.0;
    final effectiveBufferedPosition =
        _bufferedPosition > _currentPosition
            ? _bufferedPosition
            : _currentPosition;
    return (effectiveBufferedPosition / _duration).clamp(0.0, 1.0);
  }

  void _setupPlayerDurationListener() {
    _durationSubscription?.cancel();
    final player = _player;
    if (player == null) return;
    _durationSubscription = player.stream.duration.listen((duration) {
      final durationMilliseconds = duration.inMilliseconds;
      if (durationMilliseconds <= 0 || durationMilliseconds == _duration) {
        return;
      }
      if (mounted) {
        setState(() => _duration = durationMilliseconds);
      } else {
        _duration = durationMilliseconds;
      }
      _resolveAndDispatchSkipSegments();
      _introSkipController.dispatch(DurationChanged(durationMilliseconds));
    });
  }

  void _setupPlayerPlaybackListener() {
    _playingSubscription?.cancel();
    final player = _player;
    if (player == null) return;

    _isPlaying = player.state.playing;
    _introSkipController.dispatch(PlayingChanged(_isPlaying));
    _playingSubscription = player.stream.playing.listen((isPlaying) {
      _handlePlaybackStateChanged(isPlaying);
      _introSkipController.dispatch(PlayingChanged(isPlaying));
    });
  }

  void _setupPlayerCompletedListener() {
    _completedSubscription?.cancel();
    final player = _player;
    if (player == null) return;

    _completedSubscription = player.stream.completed.listen((completed) {
      if (!completed || !mounted) return;
      _handlePlaybackCompleted();
    });
  }

  bool get _shouldTrackDirectLinkEmbeddedSubtitles {
    return _playingInfoCache?.isUseDirectLink == true;
  }

  void _clearPendingEmbeddedSubtitleSwitch({bool advanceToken = false}) {
    if (advanceToken) {
      _embeddedSubtitleSwitchToken++;
    }
    _pendingEmbeddedSubtitleGuid = null;
    _pendingEmbeddedSubtitlePrevious = null;
  }

  void _resetDirectLinkEmbeddedSubtitleState() {
    _audioSwitchToken++;
    _embeddedAudioTracks = const <AudioTrack>[];
    _tracksSubscription?.cancel();
    _tracksSubscription = null;
    _embeddedSubtitleTracks = const <SubtitleTrack>[];
    _clearPendingEmbeddedSubtitleSwitch(advanceToken: true);
  }

  void _syncEmbeddedSubtitleTracks(Tracks tracks) {
    _embeddedSubtitleTracks =
        _directLinkSubtitleTrackResolver.embeddedTracksOf(tracks.subtitle);
  }

  void _setupDirectLinkEmbeddedSubtitleTracking() {
    _tracksSubscription?.cancel();
    _tracksSubscription = null;

    if (!_shouldTrackDirectLinkEmbeddedSubtitles) {
      _embeddedSubtitleTracks = const <SubtitleTrack>[];
      return;
    }

    final player = _player;
    if (player == null) {
      return;
    }

    _syncEmbeddedSubtitleTracks(player.state.tracks);
    _tracksSubscription = player.stream.tracks.listen((tracks) {
      _syncEmbeddedSubtitleTracks(tracks);
      final pendingGuid = _pendingEmbeddedSubtitleGuid;
      final currentSubtitleGuid =
          _playingInfoCache?.currentSubtitleStream?.guid;
      if (pendingGuid == null || pendingGuid != currentSubtitleGuid) {
        return;
      }
      unawaited(_tryApplyPendingDirectLinkEmbeddedSubtitleSwitch(
        requestToken: _embeddedSubtitleSwitchToken,
      ));
    });
  }

  /// Waits until [player.stream.tracks] first reports at least one real
  /// embedded subtitle track. Returns [true] if tracks became available
  /// before the timeout; [false] on timeout, disposal, or request staleness.
  Future<bool> _waitForDirectLinkEmbeddedSubtitleTracks({
    required SubtitleStream? subtitleStream,
    required int loadToken,
  }) async {
    if (subtitleStream == null) return false;
    if (!_isDirectLinkEmbeddedSubtitle(subtitleStream)) return false;
    if (_embeddedSubtitleTracks.isNotEmpty) return true;

    final player = _player;
    if (player == null) return false;

    final completer = Completer<bool>();
    StreamSubscription<Tracks>? subscription;
    Timer? timeoutTimer;

    void cleanup() {
      subscription?.cancel();
      timeoutTimer?.cancel();
    }

    timeoutTimer = Timer(_directLinkEmbeddedSubtitleTracksTimeout, () {
      cleanup();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    subscription = player.stream.tracks.listen((tracks) {
      final embeddedTracks =
          _directLinkSubtitleTrackResolver.embeddedTracksOf(tracks.subtitle);
      if (embeddedTracks.isNotEmpty) {
        cleanup();
        if (!completer.isCompleted) {
          _syncEmbeddedSubtitleTracks(tracks);
          completer.complete(true);
        }
      }
    }, onError: (_) {
      cleanup();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    final result = await completer.future;

    // Verify the request hasn't been superseded during the wait.
    if (loadToken != _loadRequestToken || !mounted || player != _player) {
      cleanup();
      return false;
    }

    return result;
  }

  void _handlePlaybackCompleted() {
    _introSkipController.dispatch(const PlaybackCompleted());
    if (mounted) {
      setState(() {});
    }
  }

  void _restoreAutoPlaySetting() {
    final autoPlay = ref.read(playerSettingsManagerProvider).getAutoPlay();
    _overlayController.setAutoPlayEnabled(autoPlay);
  }

  void _onAutoPlayChanged(bool value) {
    _overlayController.setAutoPlayEnabled(value);
    _introSkipController.dispatch(AutoPlayChanged(value));
    unawaited(PlayerSettingsStore.setAutoPlay(value));
  }

  void _setupProviderListeners() {
    if (_hasSetupProviderListeners) return;
    _hasSetupProviderListeners = true;

    ref.listenManual<MediaPState>(
      mediaPViewModelProvider,
      (previous, next) {
        if (!mounted) return;

        final previousError = previous?.error;
        final nextError = next.error;
        if (nextError != null &&
            nextError.isNotEmpty &&
            nextError != previousError) {
          AppTalker.warning('Player', 'mediaP state error: $nextError');
        }

        final previousQuitReqId = previous?.quitResponse?.reqId;
        final nextQuitResponse = next.quitResponse;
        if (nextQuitResponse != null &&
            nextQuitResponse.reqId != previousQuitReqId) {
          unawaited(_handleQuitSuccess(nextQuitResponse));
        }

        final previousResetQualityReqId = previous?.resetQualityResponse?.reqId;
        final nextResetQualityResponse = next.resetQualityResponse;
        if (nextResetQualityResponse != null &&
            nextResetQualityResponse.reqId != previousResetQualityReqId) {
          _handleResetQualitySuccess(nextResetQualityResponse);
        }

        final previousResetAudioReqId = previous?.resetAudioResponse?.reqId;
        final nextResetAudioResponse = next.resetAudioResponse;
        if (nextResetAudioResponse != null &&
            nextResetAudioResponse.reqId != previousResetAudioReqId) {
          _handleResetAudioSuccess(nextResetAudioResponse);
        }

        final previousResetSubtitleReqId =
            previous?.resetSubtitleResponse?.reqId;
        final nextResetSubtitleResponse = next.resetSubtitleResponse;
        if (nextResetSubtitleResponse != null &&
            nextResetSubtitleResponse.reqId != previousResetSubtitleReqId) {
          unawaited(_handleResetSubtitleSuccess(nextResetSubtitleResponse));
        }
      },
    );

    ref.listenManual<SubtitleSettings>(
      subtitleSettingsProvider,
      (previous, next) {
        if (!mounted || _areSubtitleSettingsEqual(previous, next)) return;
        if (_isCurrentSubtitleMpvAdjustable) {
          unawaited(_applySubtitleSettingsToMpv(next));
          return;
        }
        if (previous?.offsetSeconds != next.offsetSeconds) {
          _syncSubtitleOffsetToHlsRepository(next);
        }
      },
    );

    ref.listenManual<SettingsState>(settingsProvider, (previous, next) {
      if (!mounted ||
          previous?.flyNarwhalServerEnabled == next.flyNarwhalServerEnabled) {
        return;
      }
      if (!next.flyNarwhalServerEnabled) {
        ref.read(episodeAnalysisControllerProvider.notifier).stopAndClear();
        _introSkipController.dispatch(const FeatureDisabled());
      }
      _updateEpisodeAnalysisContext();
      _resolveAndDispatchSkipSegments();
      setState(() {});
    });

    ref.listenManual<SmartSkipSettingsState>(
      smartSkipSettingsControllerProvider,
      (previous, next) {
        if (!mounted || previous?.enabled == next.enabled) return;
        _updateEpisodeAnalysisContext();
        _resolveAndDispatchSkipSegments();
        setState(() {});
      },
    );

    ref.listenManual<EpisodeAnalysisState>(
      episodeAnalysisControllerProvider,
      (previous, next) {
        if (!mounted || previous?.smartSegments == next.smartSegments) return;
        _resolveAndDispatchSkipSegments();
        setState(() {});
      },
    );
  }

  void _resolveAndDispatchSkipSegments() {
    final cache = _playingInfoCache;
    final playConfig = cache?.playConfig;
    final settings = ref.read(settingsProvider);
    final smartSkipSettings = ref.read(smartSkipSettingsControllerProvider);
    final smartSegments =
        settings.flyNarwhalServerEnabled && smartSkipSettings.enabled
            ? ref.read(episodeAnalysisControllerProvider).smartSegments
            : null;
    _resolvedSkipSegments = _skipSegmentResolver.resolve(
      episodeGuid: cache?.itemGuid ?? _currentItemGuid,
      smartSegments: smartSegments,
      manualSkipOpeningSeconds: playConfig?.skipOpening ?? 0,
      manualSkipEndingSeconds: playConfig?.skipEnding ?? 0,
      durationMilliseconds: _duration > 0 ? _duration : null,
    );
    _introSkipController.dispatch(SegmentsChanged(_resolvedSkipSegments));
  }

  void _updateEpisodeAnalysisContext() {
    final cache = _playingInfoCache;
    final settings = ref.read(settingsProvider);
    final smartSkipSettings = ref.read(smartSkipSettingsControllerProvider);
    unawaited(
      ref.read(episodeAnalysisControllerProvider.notifier).updateContext(
            isEpisode:
                cache?.isEpisode == true || cache?.item?.type == 'Episode',
            serviceEnabled: settings.flyNarwhalServerEnabled,
            smartSkipEnabled: smartSkipSettings.enabled,
            episodeGuid: cache?.itemGuid,
            mediaGuid: cache?.currentVideoStream?.mediaGuid,
          ),
    );
  }

  Future<void> _handleSkipAction(PlayerSkipAction action) async {
    if (action.sessionGeneration != _introSkipState.sessionGeneration) {
      return;
    }
    switch (action) {
      case SeekTo():
        await _seekExecutor.performSeek(
          targetMilliseconds: action.milliseconds,
          origin: action.origin,
        );
      case PlayNextEpisode():
        final nextEpisode = _nextEpisode;
        if (nextEpisode != null) {
          _openEpisode(nextEpisode);
        }
      case PausePlayback():
        await _player?.pause();
      case ShowPlaybackEnd():
        if (mounted) setState(() {});
      case AwaitNextEpisode():
        await _awaitNextEpisode(action);
    }
  }

  Future<void> _awaitNextEpisode(AwaitNextEpisode action) async {
    final deadline = DateTime.now().add(action.timeout);
    while (mounted &&
        action.sessionGeneration == _introSkipState.sessionGeneration &&
        _nextEpisodeLoadPhase == NextEpisodeLoadPhase.loading &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final phase = _nextEpisode != null
        ? NextEpisodeLoadPhase.available
        : _nextEpisodeLoadPhase == NextEpisodeLoadPhase.loading
            ? NextEpisodeLoadPhase.failed
            : _nextEpisodeLoadPhase;
    _introSkipController.dispatch(
      NextEpisodeWaitCompleted(
        sessionGeneration: action.sessionGeneration,
        phase: phase,
      ),
    );
  }

  Future<void> _ensureSubtitleLanguageMapsLoaded() async {
    if (_iso6391Map.isNotEmpty && _iso6392Map.isNotEmpty) {
      return;
    }
    try {
      final tagRepository = ref.read(iTagRepositoryProvider);
      final results = await Future.wait<ApiResult<Map<String, String>>>([
        tagRepository.getTag('iso6391'),
        tagRepository.getTag('iso6392'),
      ]);
      if (!mounted) return;
      setState(() {
        _iso6391Map = results[0].dataOrNull ?? const <String, String>{};
        _iso6392Map = results[1].dataOrNull ?? const <String, String>{};
      });
    } catch (error) {
      AppTalker.warning('Player', 'load subtitle language tags failed: $error');
    }
  }

  String _resolveCurrentFilePath() {
    return _playingInfoCache?.currentFileStream?.path ?? '';
  }

  Future<void> _refreshSubtitleStreams({String? targetTrimId}) async {
    final cache = _playingInfoCache;
    if (cache == null) return;

    final result = await _sessionCoordinator.refreshSubtitleStreams(
      cache: cache,
      selectedSubtitleGuid: _selectedSubtitleGuid,
      targetTrimId: targetTrimId,
    );
    _playingInfoCache = result.playingInfoCache;
    ref
        .read(playerViewModelProvider.notifier)
        .updatePlayingInfo(result.playingInfoCache);

    if (!mounted) return;
    setState(() {
      _streamInfo = result.streamInfo;
      _selectedSubtitleGuid = result.selectedSubtitle?.guid;
      _requestedSubtitleGuid = result.selectedSubtitle?.guid;
    });
  }

  Future<void> _openSubtitleSearchDialog() async {
    if (_showSubtitleSearchDialog) return;
    final currentFile = _playingInfoCache?.currentFileStream;
    if (currentFile == null || currentFile.guid.isEmpty) {
      ref.read(toastManagerProvider.notifier).showToast(
            '当前文件信息缺失，无法搜索字幕',
            type: ToastType.info,
            category: 'subtitle-search:${widget.guid}',
          );
      return;
    }

    setState(() => _showSubtitleSearchDialog = true);
    try {
      await showDialog<void>(
        context: context,
        barrierColor: subtitleSearchScrimColor,
        barrierDismissible: true,
        builder: (_) => SubtitleSearchDialog(
          mediaFileName: currentFile.fileName,
          initialSubtitleGuidByTrimId: {
            for (final subtitle
                in _playingInfoCache?.currentSubtitleStreamList ?? const [])
              if (subtitle.trimId.isNotEmpty && subtitle.guid.isNotEmpty)
                subtitle.trimId: subtitle.guid,
          },
          onSearch: (language) {
            return ref.read(fileRepositoryProvider).searchSubtitles(
                  mediaGuid: currentFile.guid,
                  language: language,
                );
          },
          onDownload: (item) async {
            try {
              final subtitleStream =
                  await ref.read(fileRepositoryProvider).downloadSubtitle(
                        mediaGuid: currentFile.guid,
                        trimId: item.trimId,
                      );
              if (!mounted) return subtitleStream.guid;
              ref.read(toastManagerProvider.notifier).showToast(
                    '下载成功',
                    type: ToastType.success,
                    category: 'subtitle-download:${item.trimId}',
                  );
              unawaited(_refreshSubtitleStreams(targetTrimId: item.trimId));
              return subtitleStream.guid;
            } catch (error) {
              if (mounted) {
                ref.read(toastManagerProvider.notifier).showToast(
                      '下载字幕失败: $error',
                      type: ToastType.failed,
                      category: 'subtitle-download:${item.trimId}',
                    );
              }
              rethrow;
            }
          },
          onDownloadSimilar: (item, subtitleGuid) async {
            try {
              await ref
                  .read(fileRepositoryProvider)
                  .predownloadSimilarSubtitle(
                    mediaGuid: currentFile.guid,
                    subtitleGuid: subtitleGuid,
                  );
              if (!mounted) return;
              ref.read(toastManagerProvider.notifier).showToast(
                    '已创建字幕下载任务',
                    type: ToastType.success,
                    category: 'subtitle-predownload:${item.trimId}',
                  );
            } catch (error) {
              if (mounted) {
                ref.read(toastManagerProvider.notifier).showToast(
                      '创建字幕下载任务失败，请重试',
                      type: ToastType.failed,
                      category: 'subtitle-predownload:${item.trimId}',
                    );
              }
            }
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _showSubtitleSearchDialog = false);
      }
    }
  }

  Future<void> _openAddNasSubtitleDialog() async {
    if (_showAddNasSubtitleDialog) return;
    final mediaGuid = _playingInfoCache?.currentFileStream?.guid ?? '';
    if (mediaGuid.isEmpty) {
      ref.read(toastManagerProvider.notifier).showToast(
            '当前文件信息缺失，无法添加 NAS 字幕',
            type: ToastType.info,
            category: 'nas-subtitle:${widget.guid}',
          );
      return;
    }

    setState(() => _showAddNasSubtitleDialog = true);
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => AddNasSubtitleDialog(
          title: '添加 NAS 字幕文件',
          currentPath: _resolveCurrentFilePath(),
          onConfirm: (paths) async {
            try {
              await ref
                  .read(fileRepositoryProvider)
                  .markSubtitle(mediaGuid, paths);
              if (!mounted) return;
              ref.read(toastManagerProvider.notifier).showToast(
                    'NAS 字幕添加成功',
                    type: ToastType.success,
                    category: 'nas-subtitle:$mediaGuid',
                  );
              unawaited(_refreshSubtitleStreams());
            } catch (error) {
              if (!mounted) return;
              ref.read(toastManagerProvider.notifier).showToast(
                    '添加 NAS 字幕失败: $error',
                    type: ToastType.failed,
                    category: 'nas-subtitle:$mediaGuid',
                  );
            }
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _showAddNasSubtitleDialog = false);
      }
    }
  }

  Future<void> _pickAndUploadLocalSubtitle() async {
    final currentFile = _playingInfoCache?.currentFileStream;
    if (_isUploadingLocalSubtitle) return;
    if (currentFile == null || currentFile.guid.isEmpty) {
      ref.read(toastManagerProvider.notifier).showToast(
            '当前文件信息缺失，无法上传字幕',
            type: ToastType.info,
            category: 'local-subtitle:${widget.guid}',
          );
      return;
    }

    const subtitleTypeGroup = XTypeGroup(
      label: '字幕文件',
      extensions: ['ass', 'srt', 'vtt', 'sub', 'ssa'],
    );

    try {
      final file = await openFile(
        acceptedTypeGroups: [subtitleTypeGroup],
        confirmButtonText: '选择',
      );
      if (file == null) return;

      setState(() => _isUploadingLocalSubtitle = true);
      final bytes = await file.readAsBytes();
      await ref.read(fileRepositoryProvider).uploadSubtitle(
            guid: currentFile.guid,
            bytes: bytes,
            fileName: file.name,
          );
      if (!mounted) return;
      ref.read(toastManagerProvider.notifier).showToast(
            '电脑字幕文件上传成功',
            type: ToastType.success,
            category: 'local-subtitle:${currentFile.guid}',
          );
      unawaited(_refreshSubtitleStreams());
    } catch (error) {
      if (mounted) {
        ref.read(toastManagerProvider.notifier).showToast(
              '上传字幕失败: $error',
              type: ToastType.failed,
              category: 'local-subtitle:${currentFile.guid}',
            );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingLocalSubtitle = false);
      }
    }
  }

  void _syncPlaybackTargetsFromWidget() {
    _currentItemGuid = widget.guid;
    _currentMediaGuid = widget.mediaGuid;
    _requestedAudioGuid = widget.audioGuid;
    _requestedSubtitleGuid = widget.subtitleGuid;
  }

  void _resetPlaybackStateForTargetChange() {
    ref.read(episodeAnalysisControllerProvider.notifier).stopAndClear();
    _introSkipController.dispatch(const SessionDisposed());
    _resolvedSkipSegments = ResolvedSkipSegments.empty();
    _nextEpisodeLoadPhase = NextEpisodeLoadPhase.idle;
    ref.read(danmakuControllerProvider.notifier).clear();
    _danmakuPosition.value = Duration.zero;
    _danmakuResetGeneration++;
    _disposeHlsSubtitleSession();
    _resetDirectLinkEmbeddedSubtitleState();
    _playRecordTimer?.cancel();
    _lastRecordedPosition = 0;
    _currentPosition = 0;
    _duration = 0;
    _selectedAudioGuid = null;
    _selectedSubtitleGuid = null;
    _qualities = [];
    _currentQuality = null;
    _currentResolution = '';
    _currentBitrate = null;
    _playInfo = null;
    _streamInfo = null;
    _playingInfoCache = null;
    _episodeList = [];
    _currentEpisode = null;
    _nextEpisode = null;
  }

  void _queueQuitPlayback() {
    final cache = _playingInfoCache;
    final playLink = cache?.playLink;
    if (cache == null ||
        cache.isUseDirectLink ||
        playLink == null ||
        playLink.isEmpty) {
      return;
    }

    unawaited(() async {
      try {
        await ref.read(mediaPViewModelProvider.notifier).quit(
              MediaPRequest(playLink: playLink),
              updateState: false,
            );
      } catch (e) {
        AppTalker.warning('Player', 'quit media failed: $e');
      }
    }());
  }

  Future<void> _switchPlaybackTarget({
    required String guid,
    String? mediaGuid,
    String? audioGuid,
    String? subtitleGuid,
  }) async {
    final isSameTarget = guid == _currentItemGuid &&
        mediaGuid == _currentMediaGuid &&
        audioGuid == _requestedAudioGuid &&
        subtitleGuid == _requestedSubtitleGuid;
    if (isSameTarget) return;

    _queueQuitPlayback();

    setState(() {
      _currentItemGuid = guid;
      _currentMediaGuid = mediaGuid;
      _requestedAudioGuid = audioGuid;
      _requestedSubtitleGuid = subtitleGuid;
      _resetPlaybackStateForTargetChange();
      _isLoading = true;
    });

    await _loadAndPlayMedia();
  }

  Future<void> _openMediaWithResume({
    required String playUri,
    required int startPositionMs,
    required SubtitleStream? currentSubtitleStream,
  }) async {
    final player = _player;
    if (player == null) return;
    _resetDirectLinkEmbeddedSubtitleState();
    await _applyDirectLinkCachePolicy(player);

    // Set mpv native start property so decoding positions from the desired
    // point. This is the most reliable way for history-progress resume.
    final platform = player.platform;
    if (platform is NativePlayer) {
      if (startPositionMs > 0) {
        final seconds = (startPositionMs / 1000).toStringAsFixed(3);
        await platform.setProperty('start', seconds);
      } else {
        // Clear any residual start property from a previous open.
        await platform.setProperty('start', 'none');
      }
    }

    final headers = _sessionCoordinator.buildPlayerHeaders();
    await player.open(
      Media(
        playUri,
        httpHeaders: headers.isEmpty ? null : headers,
      ),
    );
    _setupDirectLinkEmbeddedSubtitleTracking();
    if (_playingInfoCache?.isUseDirectLink == true) {
      await _applyInitialDirectLinkAudioTrack();
    }

    if (_isSupportedExternalSubtitle(currentSubtitleStream)) {
      _applyExternalSubtitleAsync(currentSubtitleStream!, _loadRequestToken);
    } else if (_isDirectLinkEmbeddedSubtitle(currentSubtitleStream)) {
      final tracksReady = await _waitForDirectLinkEmbeddedSubtitleTracks(
        subtitleStream: currentSubtitleStream,
        loadToken: _loadRequestToken,
      );
      if (tracksReady) {
        await _applyCurrentSubtitleTrack(currentSubtitleStream);
      } else {
        _pendingEmbeddedSubtitleGuid = currentSubtitleStream!.guid;
      }
    } else {
      await _applyCurrentSubtitleTrack(currentSubtitleStream);
    }

    // For non-native platforms or when mpv start didn't fully apply, verify
    // the position and issue a single correction seek as fallback.
    await _verifyAndCorrectResume(startPositionMs);
  }

  PlayRecordRequest? _buildPlayRecordRequest({
    required int positionSeconds,
    required String deviceId,
    required String deviceName,
    PlayingInfoCache? cacheOverride,
  }) {
    // Route play/record requests through a pure builder so direct-link and
    // HLS sessions pick the correct play_link source consistently.
    return buildPlayRecordRequest(
      positionSeconds: positionSeconds,
      fallbackItemGuid: _currentItemGuid,
      deviceId: deviceId,
      deviceName: deviceName,
      cache: cacheOverride ?? _playingInfoCache,
    );
  }

  void _queuePlayRecordUpdate(
      {int? positionMs, PlayingInfoCache? cacheOverride}) {
    if (!_isInitialized) return;

    final player = _player;
    final cache = cacheOverride ?? _playingInfoCache;
    if (player == null || cache == null) return;

    final targetMs = positionMs ?? player.state.position.inMilliseconds;
    if (targetMs < 0) return;

    unawaited(() async {
      try {
        // Resolve the current device metadata right before sending play/record.
        final deviceContext =
            await ref.read(playerDeviceContextServiceProvider).loadContext();
        final request = _buildPlayRecordRequest(
          positionSeconds: targetMs ~/ 1000,
          deviceId: deviceContext.deviceId,
          deviceName: deviceContext.deviceName,
          cacheOverride: cacheOverride,
        );
        if (request == null) return;
        await ref.read(playerServiceProvider).updatePlayRecord(request);
      } catch (_) {
        // PlayRecord failure must not affect the main playback flow.
      }
    }());
  }

  Future<void> _reopenPlaybackFromPlayLink({
    required String playLink,
    required int startPositionMs,
  }) async {
    final prefs = ref.read(preferencesManagerProvider);
    final baseUrl = prefs.getBaseUrl() ?? '';
    final cache = _playingInfoCache;
    if (baseUrl.isEmpty || cache == null) return;

    final playUri = _sessionCoordinator.absolutePlayUrl(baseUrl, playLink);
    final dio = ref.read(dioClientProvider).dio;
    final prepared = await _sessionCoordinator.preparePlaySourceForMediaKit(
      playUri: playUri,
      currentSubtitleStream: cache.currentSubtitleStream,
    );
    _prepareHlsSubtitleOverlayMode(
      subtitleStream: cache.currentSubtitleStream,
      subtitlePlaylistUrl: prepared.subtitlePlaylistUrl,
    );
    await _openMediaWithResume(
      playUri: prepared.playUri,
      startPositionMs: startPositionMs,
      currentSubtitleStream: cache.currentSubtitleStream,
    );
    _startHlsSubtitleSessionAsync(
      dio: dio,
      subtitleStream: cache.currentSubtitleStream,
      subtitlePlaylistUrl: prepared.subtitlePlaylistUrl,
      startPositionMs: startPositionMs,
      loadToken: _loadRequestToken,
    );
  }

  Future<void> _reopenPlaybackWithDirectLink({
    required int startPositionMs,
  }) async {
    final cache = _playingInfoCache;
    final videoStream = cache?.currentVideoStream;
    if (cache == null || videoStream == null) return;

    final directLink = await _sessionCoordinator.getDirectPlayLink(
      mediaGuid: videoStream.mediaGuid,
      startPositionMs: startPositionMs,
    );
    _playingInfoCache = cache.copyWith(
      playLink: null,
      playRecordLink:
          _sessionCoordinator.ensureDirectPlayRecordLink(cache.playRecordLink),
      isUseDirectLink: true,
    );
    ref
        .read(playerViewModelProvider.notifier)
        .updatePlayingInfo(_playingInfoCache);
    _disposeHlsSubtitleSession();
    await _openMediaWithResume(
      playUri: directLink.playUri,
      startPositionMs: directLink.effectiveStartMs,
      currentSubtitleStream: _playingInfoCache?.currentSubtitleStream,
    );
  }

  Future<void> _handlePlayPlaySuccess(
    PlayPlayResponse response, {
    required int startPositionMs,
  }) async {
    final cache = _playingInfoCache;
    if (cache == null) return;

    _playingInfoCache = cache.copyWith(
      playLink: response.playLink,
      playRecordLink: null,
      isUseDirectLink: false,
    );
    ref
        .read(playerViewModelProvider.notifier)
        .updatePlayingInfo(_playingInfoCache);
    await _reopenPlaybackFromPlayLink(
      playLink: response.playLink,
      startPositionMs: startPositionMs,
    );
  }

  Future<void> _handleQuitSuccess(
    MediaResetQualityResponse response,
  ) async {
    ref.read(mediaPViewModelProvider.notifier).clearQuitResponse();
    if (response.result != 'succ' || _player == null) {
      return;
    }

    try {
      final startPositionMs = _player!.state.position.inMilliseconds;
      await _reopenPlaybackWithDirectLink(startPositionMs: startPositionMs);

      final verified = await _verifyPlaybackStarted();
      if (!verified && mounted) {
        await _fallbackToHlsFromDirectLink(startPositionMs: startPositionMs);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentQuality = _playingInfoCache?.currentQuality;
          _currentResolution = _currentQuality?.resolution ?? '';
          _currentBitrate = _currentQuality?.bitrate;
        });
      }
    } catch (e) {
      AppTalker.warning('Player', 'handle quit success failed: $e');
      if (mounted) {
        ref.read(toastManagerProvider.notifier).showToast(
              '切换原画失败: $e',
              type: ToastType.failed,
              category: 'playback-source:${widget.guid}',
            );
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleResetQualitySuccess(MediaResetQualityResponse response) {
    ref.read(mediaPViewModelProvider.notifier).clearResetQualityResponse();
    if (response.result != 'succ' || !mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
      _currentQuality = _playingInfoCache?.currentQuality;
      _currentResolution = _currentQuality?.resolution ?? '';
      _currentBitrate = _currentQuality?.bitrate;
    });
  }

  void _handleResetAudioSuccess(MediaResetQualityResponse response) {
    ref.read(mediaPViewModelProvider.notifier).clearResetAudioResponse();
    if (response.result != 'succ' || !mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
      _selectedAudioGuid = _playingInfoCache?.currentAudioStream?.guid;
    });
  }

  Future<void> _handleResetSubtitleSuccess(
    MediaResetQualityResponse response,
  ) async {
    ref.read(mediaPViewModelProvider.notifier).clearResetSubtitleResponse();
    if (response.result != 'succ') {
      if (mounted) {
        setState(() {
          _isSubtitleSwitching = false;
          _isLoading = false;
        });
      }
      return;
    }

    final cache = _playingInfoCache;
    if (cache == null) {
      if (mounted) {
        setState(() {
          _isSubtitleSwitching = false;
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final dio = ref.read(dioClientProvider).dio;
      final baseUrl = ref.read(preferencesManagerProvider).getBaseUrl() ?? '';
      final subtitlePlaylistUrl = cache.playLink != null &&
              baseUrl.isNotEmpty &&
              _sessionCoordinator.looksLikeM3u8(cache.playLink!)
          ? (await _sessionCoordinator.preparePlaySourceForMediaKit(
              playUri:
                  _sessionCoordinator.absolutePlayUrl(baseUrl, cache.playLink!),
              currentSubtitleStream: cache.currentSubtitleStream,
            ))
              .subtitlePlaylistUrl
          : null;
      final startPositionMs = _player?.state.position.inMilliseconds ?? 0;
      _prepareHlsSubtitleOverlayMode(
        subtitleStream: cache.currentSubtitleStream,
        subtitlePlaylistUrl: subtitlePlaylistUrl,
      );

      if (_isSupportedExternalSubtitle(cache.currentSubtitleStream)) {
        _startHlsSubtitleSessionAsync(
          dio: dio,
          subtitleStream: cache.currentSubtitleStream,
          subtitlePlaylistUrl: subtitlePlaylistUrl,
          startPositionMs: startPositionMs,
          loadToken: _loadRequestToken,
        );
        _applyExternalSubtitleAsync(
            cache.currentSubtitleStream!, _loadRequestToken);
        if (mounted) {
          setState(() {
            _isSubtitleSwitching = false;
            _isLoading = false;
            _selectedSubtitleGuid = cache.currentSubtitleStream?.guid;
          });
        }
      } else {
        await _applyCurrentSubtitleTrack(cache.currentSubtitleStream);
        if (!mounted) {
          return;
        }
        _startHlsSubtitleSessionAsync(
          dio: dio,
          subtitleStream: cache.currentSubtitleStream,
          subtitlePlaylistUrl: subtitlePlaylistUrl,
          startPositionMs: startPositionMs,
          loadToken: _loadRequestToken,
        );
        if (mounted) {
          setState(() {
            _isSubtitleSwitching = false;
            _isLoading = false;
            _selectedSubtitleGuid = cache.currentSubtitleStream?.guid;
          });
        }
      }
    } catch (e) {
      AppTalker.warning(
        'Player',
        'handle reset subtitle success failed: $e',
      );
      if (mounted) {
        ref.read(toastManagerProvider.notifier).showToast(
              '切换字幕失败: $e',
              type: ToastType.failed,
              category: 'subtitle-switch:${widget.guid}',
            );
        setState(() {
          _isSubtitleSwitching = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyAndCorrectResume(int startPositionMs) async {
    final player = _player;
    if (player == null || startPositionMs <= 0) return;

    // Wait for the player to be in a playing/paused state and have some
    // duration so position reporting is meaningful.
    for (int attempt = 0; attempt < 5; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final state = player.state;
      if (state.position.inMilliseconds > 0 ||
          state.duration.inMilliseconds > 0) {
        break;
      }
    }

    final currentPosition = player.state.position.inMilliseconds;
    final deviation = (currentPosition - startPositionMs).abs();

    if (deviation <= 3000) return;

    // mpv start property didn't fully apply. Correct through the runtime seek
    // executor without classifying the correction as a user interaction.
    await _seekExecutor.performSeek(
      targetMilliseconds: startPositionMs,
      origin: PlayerSeekOrigin.resumeCorrection,
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  bool _isSupportedExternalSubtitle(SubtitleStream? subtitleStream) {
    if (subtitleStream == null || subtitleStream.isExternal != 1) {
      return false;
    }
    const supportedFormats = {'srt', 'ass', 'ssa', 'vtt'};
    return supportedFormats.contains(subtitleStream.format.toLowerCase());
  }

  bool _isDirectLinkEmbeddedSubtitle(SubtitleStream? subtitleStream) {
    final cache = _playingInfoCache;
    return subtitleStream != null &&
        subtitleStream.isExternal != 1 &&
        cache?.isUseDirectLink == true &&
        !_useHlsSubtitleOverlay;
  }

  // Detect subtitles that pin every event to absolute coordinates via
  // \pos/\move (e.g. danmaku). For those, the global sub-pos has no effect,
  // so the vertical-position control should be disabled in the UI.
  bool _detectPositionLockedSubtitle(String content, String format) {
    final normalizedFormat = format.toLowerCase();
    if (normalizedFormat != 'ass' && normalizedFormat != 'ssa') {
      return false;
    }
    final dialogueLines = content
        .split('\n')
        .where((line) => line.trimLeft().startsWith('Dialogue:'))
        .toList();
    if (dialogueLines.isEmpty) {
      return false;
    }
    final positionedCount = dialogueLines
        .where((line) => line.contains('\\pos') || line.contains('\\move'))
        .length;
    // Treat as position-locked when the vast majority of events are absolutely
    // positioned, which is the signature of danmaku / effect-only tracks.
    return positionedCount / dialogueLines.length >= 0.8;
  }

  void _updatePositionLockedSubtitle(String content, String format) {
    final locked = _detectPositionLockedSubtitle(content, format);
    if (locked == _isPositionLockedSubtitle) return;
    if (!mounted) {
      _isPositionLockedSubtitle = locked;
      return;
    }
    setState(() => _isPositionLockedSubtitle = locked);
  }

  void _clearPositionLockedSubtitle() {
    if (!_isPositionLockedSubtitle) {
      return;
    }
    if (!mounted) {
      _isPositionLockedSubtitle = false;
      return;
    }
    setState(() => _isPositionLockedSubtitle = false);
  }

  bool _areSubtitleSettingsEqual(
    SubtitleSettings? left,
    SubtitleSettings right,
  ) {
    return left != null &&
        left.offsetSeconds == right.offsetSeconds &&
        left.verticalPosition == right.verticalPosition &&
        left.fontScale == right.fontScale &&
        left.fontSize == right.fontSize &&
        left.fontColor == right.fontColor &&
        left.backgroundColor == right.backgroundColor;
  }

  bool get _isCurrentSubtitleMpvAdjustable {
    final subtitleStream = _playingInfoCache?.currentSubtitleStream;
    return _isSupportedExternalSubtitle(subtitleStream) ||
        _isDirectLinkEmbeddedSubtitle(subtitleStream);
  }

  Future<void> _applySubtitleSettingsToMpv(SubtitleSettings settings) async {
    final player = _player;
    if (player == null || !_isCurrentSubtitleMpvAdjustable) {
      return;
    }

    final platform = player.platform;
    if (platform is! NativePlayer) {
      return;
    }

    final subPos = ((1 - settings.verticalPosition.clamp(0.0, 1.0)) * 100)
        .round()
        .clamp(0, 100);
    try {
      await platform.setProperty(
        'sub-delay',
        (-settings.offsetSeconds).toStringAsFixed(3),
      );
      await platform.setProperty(
          'sub-scale', settings.fontScale.toStringAsFixed(3));
      await platform.setProperty('sub-font', AppFonts.primary);
      // Let sub-pos move ASS subtitles that rely on style margins. Has no
      // effect on absolutely-positioned (\pos/\move) danmaku tracks.
      await platform.setProperty('sub-ass-force-margins', 'yes');
      await platform.setProperty('sub-pos', subPos.toString());
      await platform.setProperty('sub-visibility', 'yes');
    } catch (e) {
      AppTalker.warning('Player', 'apply subtitle settings to mpv failed: $e');
    }
  }

  void _applyExternalSubtitleAsync(
    SubtitleStream subtitleStream,
    int loadToken,
  ) {
    unawaited(() async {
      try {
        final content = await ref
            .read(playerServiceProvider)
            .downloadExternalSubtitle(subtitleStream.guid);
        final player = _player;
        if (!mounted || player == null || loadToken != _loadRequestToken) {
          return;
        }

        final expectedSubtitleGuid =
            _requestedSubtitleGuid ?? _selectedSubtitleGuid;
        if (expectedSubtitleGuid != null &&
            expectedSubtitleGuid != subtitleStream.guid) {
          return;
        }

        _clearPositionLockedSubtitle();
        await player.setSubtitleTrack(SubtitleTrack.no());
        await player.setSubtitleTrack(
          SubtitleTrack.data(
            content,
            title:
                subtitleStream.title.isNotEmpty ? subtitleStream.title : null,
            language: subtitleStream.language.isNotEmpty
                ? subtitleStream.language
                : null,
          ),
        );
        _updatePositionLockedSubtitle(content, subtitleStream.format);
        await _applySubtitleSettingsToMpv(ref.read(subtitleSettingsProvider));
      } catch (e) {
        AppTalker.warning('Player', 'apply external subtitle async failed: $e');
      }
    }());
  }

  SubtitleTrack? _resolveDirectLinkSubtitleTrack(
      SubtitleStream subtitleStream) {
    final cache = _playingInfoCache;
    if (cache == null) {
      return null;
    }
    return _directLinkSubtitleTrackResolver.resolve(
      subtitleStreams: cache.currentSubtitleStreamList,
      subtitleTracks: _embeddedSubtitleTracks,
      targetSubtitle: subtitleStream,
    );
  }

  Future<bool> _applyDirectLinkEmbeddedSubtitleTrack(
    SubtitleStream subtitleStream,
  ) async {
    final player = _player;
    if (player == null) {
      return false;
    }

    final targetTrack = _resolveDirectLinkSubtitleTrack(subtitleStream);
    if (targetTrack == null) {
      _pendingEmbeddedSubtitleGuid = subtitleStream.guid;
      return false;
    }

    _clearPositionLockedSubtitle();
    final platform = player.platform;
    try {
      if (platform is NativePlayer) {
        // Use mpv sid directly to avoid the heavier synchronized track-switch
        // path on hot subtitle interactions.
        await platform.setProperty(
          'sid',
          targetTrack.id,
          waitForInitialization: false,
        );
      } else {
        await player.setSubtitleTrack(targetTrack);
      }
    } catch (error) {
      AppTalker.warning(
        'Player',
        'lightweight sid switch failed, fallback to setSubtitleTrack: $error',
      );
      await player.setSubtitleTrack(targetTrack);
    }

    _pendingEmbeddedSubtitleGuid = null;
    await _applySubtitleSettingsToMpv(ref.read(subtitleSettingsProvider));
    return true;
  }

  Future<void> _handleDirectLinkEmbeddedSubtitleSwitchFailure({
    required int requestToken,
    required SubtitleStream targetSubtitle,
    required Object error,
  }) async {
    if (requestToken != _embeddedSubtitleSwitchToken) {
      return;
    }

    final previousSubtitle = _pendingEmbeddedSubtitlePrevious;
    final cache = _playingInfoCache;
    if (cache != null &&
        cache.currentSubtitleStream?.guid == targetSubtitle.guid) {
      _playingInfoCache = cache.copyWith(
        currentSubtitleStream: previousSubtitle,
        previousSubtitle: previousSubtitle,
      );
      ref
          .read(playerViewModelProvider.notifier)
          .updatePlayingInfo(_playingInfoCache);
    }
    _pendingEmbeddedSubtitleGuid = null;
    _pendingEmbeddedSubtitlePrevious = null;
    AppTalker.warning(
      'Player',
      'direct-link embedded subtitle switch failed: $error',
    );
    if (!mounted) {
      _selectedSubtitleGuid = previousSubtitle?.guid;
      return;
    }
    ref.read(toastManagerProvider.notifier).showToast(
          '切换字幕失败: $error',
          type: ToastType.failed,
          category: 'subtitle-switch:${widget.guid}',
        );
    setState(() {
      _selectedSubtitleGuid = previousSubtitle?.guid;
    });
  }

  Future<void> _tryApplyPendingDirectLinkEmbeddedSubtitleSwitch({
    required int requestToken,
  }) async {
    if (requestToken != _embeddedSubtitleSwitchToken) {
      return;
    }
    final pendingGuid = _pendingEmbeddedSubtitleGuid;
    final cache = _playingInfoCache;
    final targetSubtitle = cache?.currentSubtitleStream;
    if (pendingGuid == null ||
        targetSubtitle == null ||
        targetSubtitle.guid != pendingGuid ||
        !_isDirectLinkEmbeddedSubtitle(targetSubtitle)) {
      return;
    }

    try {
      final applied =
          await _applyDirectLinkEmbeddedSubtitleTrack(targetSubtitle);
      if (!applied || requestToken != _embeddedSubtitleSwitchToken) {
        return;
      }
      _pendingEmbeddedSubtitlePrevious = null;
      if (!mounted) {
        _selectedSubtitleGuid = targetSubtitle.guid;
        return;
      }
      setState(() => _selectedSubtitleGuid = targetSubtitle.guid);
    } catch (error) {
      await _handleDirectLinkEmbeddedSubtitleSwitchFailure(
        requestToken: requestToken,
        targetSubtitle: targetSubtitle,
        error: error,
      );
    }
  }

  void _scheduleDirectLinkEmbeddedSubtitleSwitch({
    required SubtitleStream targetSubtitle,
    required SubtitleStream? previousSubtitle,
  }) {
    final requestToken = ++_embeddedSubtitleSwitchToken;
    _pendingEmbeddedSubtitleGuid = targetSubtitle.guid;
    _pendingEmbeddedSubtitlePrevious = previousSubtitle;
    unawaited(_tryApplyPendingDirectLinkEmbeddedSubtitleSwitch(
      requestToken: requestToken,
    ));
  }

  Future<void> _applyCurrentSubtitleTrack(
    SubtitleStream? subtitleStream, {
    bool strict = false,
  }) async {
    final player = _player;
    if (player == null) return;

    if (subtitleStream == null) {
      _clearPendingEmbeddedSubtitleSwitch();
      _clearPositionLockedSubtitle();
      await player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }

    if (_useHlsSubtitleOverlay && subtitleStream.isExternal != 1) {
      _clearPendingEmbeddedSubtitleSwitch();
      _clearPositionLockedSubtitle();
      await player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }

    if (!_isSupportedExternalSubtitle(subtitleStream)) {
      if (!_isDirectLinkEmbeddedSubtitle(subtitleStream)) {
        _clearPendingEmbeddedSubtitleSwitch();
        _clearPositionLockedSubtitle();
        return;
      }

      final applied =
          await _applyDirectLinkEmbeddedSubtitleTrack(subtitleStream);
      if (!applied) {
        final error = StateError(
          'Unable to resolve embedded subtitle track for ${subtitleStream.guid}',
        );
        AppTalker.warning('Player', 'apply embedded subtitle failed: $error');
        if (strict) {
          throw error;
        }
        return;
      }

      return;
    }

    try {
      _clearPendingEmbeddedSubtitleSwitch();
      _clearPositionLockedSubtitle();
      await player.setSubtitleTrack(SubtitleTrack.no());
      final content = await ref
          .read(playerServiceProvider)
          .downloadExternalSubtitle(subtitleStream.guid);
      if (!mounted || player != _player) {
        return;
      }

      final expectedSubtitleGuid =
          _requestedSubtitleGuid ?? _selectedSubtitleGuid;
      if (expectedSubtitleGuid != null &&
          expectedSubtitleGuid != subtitleStream.guid) {
        return;
      }

      await player.setSubtitleTrack(
        SubtitleTrack.data(
          content,
          title: subtitleStream.title.isNotEmpty ? subtitleStream.title : null,
          language: subtitleStream.language.isNotEmpty
              ? subtitleStream.language
              : null,
        ),
      );
      _updatePositionLockedSubtitle(content, subtitleStream.format);
      await _applySubtitleSettingsToMpv(ref.read(subtitleSettingsProvider));
    } catch (e) {
      AppTalker.warning('Player', 'apply external subtitle failed: $e');
      if (player == _player) {
        await player.setSubtitleTrack(SubtitleTrack.no());
      }
      if (strict) {
        rethrow;
      }
    }
  }

  void _disposeHlsSubtitleSession() {
    // Invalidate stale async subtitle startup work before clearing the session.
    _hlsSessionToken++;
    final repository = _hlsSubtitleRepository;
    final listener = _hlsSubtitleTextsListener;
    if (repository != null && listener != null) {
      repository.visibleTexts.removeListener(listener);
    }
    repository?.dispose();
    _hlsSubtitleRepository = null;
    _hlsSubtitleTextsListener = null;
    _hlsSubtitleTexts.value = const [];
    _useHlsSubtitleOverlay = false;
  }

  void _prepareHlsSubtitleOverlayMode({
    required SubtitleStream? subtitleStream,
    required String? subtitlePlaylistUrl,
  }) {
    _disposeHlsSubtitleSession();
    final shouldUseOverlay = subtitleStream != null &&
        subtitleStream.isExternal != 1 &&
        subtitlePlaylistUrl != null &&
        subtitlePlaylistUrl.isNotEmpty;
    _useHlsSubtitleOverlay = shouldUseOverlay;
    if (shouldUseOverlay) {
      AppTalker.info(
        'Player',
        'hls subtitle overlay prepared: playlist=$subtitlePlaylistUrl',
      );
    } else {
      // AppTalker.info('Player', 'hls subtitle overlay disabled');
    }
  }

  void _syncSubtitleOffsetToHlsRepository(SubtitleSettings settings) {
    _hlsSubtitleRepository?.updateSubtitleOffsetSeconds(settings.offsetSeconds);
  }

  void _startHlsSubtitleSessionAsync({
    required Dio dio,
    required SubtitleStream? subtitleStream,
    required String? subtitlePlaylistUrl,
    required int startPositionMs,
    int? loadToken,
  }) {
    if (!_useHlsSubtitleOverlay) {
      return;
    }
    final sessionToken = ++_hlsSessionToken;
    unawaited(_configureHlsSubtitleSession(
      dio: dio,
      subtitleStream: subtitleStream,
      subtitlePlaylistUrl: subtitlePlaylistUrl,
      startPositionMs: startPositionMs,
      sessionToken: sessionToken,
      loadToken: loadToken,
    ));
  }

  Future<void> _configureHlsSubtitleSession({
    required Dio dio,
    required SubtitleStream? subtitleStream,
    required String? subtitlePlaylistUrl,
    required int startPositionMs,
    required int sessionToken,
    int? loadToken,
  }) async {
    if (subtitleStream == null ||
        subtitleStream.isExternal == 1 ||
        subtitlePlaylistUrl == null ||
        subtitlePlaylistUrl.isEmpty) {
      _disposeHlsSubtitleSession();
      return;
    }

    final repository = HlsSubtitleRepository(
      dio: dio,
      headers: _sessionCoordinator.buildPlayerHeaders(),
      subtitlePlaylistUrl: subtitlePlaylistUrl,
    );
    repository.updateSubtitleOffsetSeconds(
      ref.read(subtitleSettingsProvider).offsetSeconds,
    );
    try {
      // Keep subtitle startup best-effort so video recovery is never blocked.
      await repository
          .initialize(startPositionMs: startPositionMs)
          .timeout(_hlsSubtitleInitTimeout);
      final isStaleSession = !mounted ||
          _hlsSessionToken != sessionToken ||
          (loadToken != null && loadToken != _loadRequestToken);
      if (isStaleSession) {
        repository.dispose();
        return;
      }

      void listener() {
        if (_hlsSessionToken != sessionToken) {
          return;
        }
        _hlsSubtitleTexts.value = repository.visibleTexts.value;
      }

      repository.visibleTexts.addListener(listener);
      _hlsSubtitleRepository = repository;
      _hlsSubtitleTextsListener = listener;
      _hlsSubtitleTexts.value = repository.visibleTexts.value;
      _useHlsSubtitleOverlay = true;
      AppTalker.info(
        'Player',
        'hls subtitle overlay enabled: playlist=$subtitlePlaylistUrl',
      );
    } catch (e) {
      repository.dispose();
      AppTalker.warning(
        'Player',
        'hls subtitle overlay init failed: $e',
      );
      if (_hlsSessionToken == sessionToken) {
        _hlsSubtitleTexts.value = const [];
        _useHlsSubtitleOverlay = false;
      }
    }
  }

  /// Attempts direct-link playback; if player.open fails, automatically
  /// falls back to HLS transcode playback.
  Future<void> _openDirectLinkWithHlsFallback({
    required PlayerSessionLoadResult result,
    required Dio dio,
    required int startPositionMs,
    required int requestToken,
  }) async {
    try {
      await _openMediaWithResume(
        playUri: result.preparedPlaySource.playUri,
        startPositionMs: startPositionMs,
        currentSubtitleStream: result.playingInfoCache.currentSubtitleStream,
      );
      if (!mounted || requestToken != _loadRequestToken) return;

      final verified = await _verifyPlaybackStarted();
      if (verified) return;
    } catch (e) {
      AppTalker.warning(
        'Player',
        'direct link playback failed, falling back to HLS: $e',
      );
    }

    if (!mounted || requestToken != _loadRequestToken) return;
    await _fallbackToHlsFromDirectLink(startPositionMs: startPositionMs);
  }

  /// Returns true if the player has started producing frames.
  /// Waits up to ~3 seconds for the player to report a non-zero duration,
  /// which indicates the container was successfully opened.
  Future<bool> _verifyPlaybackStarted() async {
    final player = _player;
    if (player == null) return false;

    for (int attempt = 0; attempt < 6; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return false;
      final state = player.state;
      if (state.duration.inMilliseconds > 0 && state.width != null) {
        return true;
      }
    }
    AppTalker.warning(
      'Player',
      'direct link verification failed: player reports no duration after 3s',
    );
    return false;
  }

  /// Switches from a failed direct-link session to HLS transcode playback.
  Future<void> _fallbackToHlsFromDirectLink({
    required int startPositionMs,
  }) async {
    final cache = _playingInfoCache;
    final videoStream = cache?.currentVideoStream;
    final fileStream = cache?.currentFileStream;
    if (cache == null || videoStream == null || fileStream == null) return;

    final audioGuid = cache.currentAudioStream?.guid ??
        _selectedAudioGuid ??
        _requestedAudioGuid ??
        _playInfo?.audioGuid ??
        '';
    final subtitleGuid = cache.currentSubtitleStream?.guid;

    AppTalker.info('Player', 'falling back to HLS transcode playback');
    final hlsResult = await _sessionCoordinator.requestHlsPlayLink(
      videoStream: videoStream,
      fileStream: fileStream,
      audioGuid: audioGuid,
      subtitleGuid: subtitleGuid,
      startPositionMs: startPositionMs,
    );
    if (!mounted) return;

    _playingInfoCache = cache.copyWith(
      playLink: hlsResult.playLinkRaw,
      playRecordLink: null,
      isUseDirectLink: false,
    );
    ref
        .read(playerViewModelProvider.notifier)
        .updatePlayingInfo(_playingInfoCache);

    await _reopenPlaybackFromPlayLink(
      playLink: hlsResult.playLinkRaw,
      startPositionMs: startPositionMs,
    );
  }

  DanmakuRequest _buildDanmakuRequest(PlayInfoResponse playInfo) {
    final item = playInfo.item;
    final isSeason = playInfo.type != 'Movie';
    final parentGuid =
        item.parentGuid.isNotEmpty ? item.parentGuid : playInfo.parentGuid;
    return DanmakuRequest(
      doubanId: item.imdbId ?? '',
      episodeNumber: item.episodeNumber,
      episodeTitle: item.title,
      title: isSeason && item.tvTitle.isNotEmpty ? item.tvTitle : item.title,
      seasonNumber: item.seasonNumber,
      season: isSeason,
      guid: item.guid,
      parentGuid: parentGuid,
    );
  }

  Future<void> _loadAndPlayMedia() async {
    final requestToken = ++_loadRequestToken;
    try {
      _suspendPlaybackTransitionFeedback = true;
      _hidePlaybackIndicator();
      setState(() => _isLoading = true);

      final dio = ref.read(dioClientProvider).dio;
      final result = await _sessionCoordinator.loadSession(
        PlayerRouteTarget(
          guid: _currentItemGuid,
          mediaGuid: _currentMediaGuid,
          audioGuid: _requestedAudioGuid,
          subtitleGuid: _requestedSubtitleGuid,
        ),
      );
      if (!mounted || requestToken != _loadRequestToken) {
        return;
      }

      _playInfo = result.playInfo;
      _streamInfo = result.streamInfo;
      _playingInfoCache = result.playingInfoCache;
      final flyNarwhalSettings = ref.read(settingsProvider);
      if (flyNarwhalSettings.flyNarwhalServerEnabled &&
          flyNarwhalSettings.flyNarwhalServerBaseUrl.isNotEmpty &&
          flyNarwhalSettings.hasFlyNarwhalAuthCode) {
        unawaited(
          ref
              .read(danmakuControllerProvider.notifier)
              .loadDanmaku(_buildDanmakuRequest(result.playInfo)),
        );
      } else {
        ref.read(danmakuControllerProvider.notifier).clear();
      }
      _currentItemGuid =
          result.playingInfoCache.itemGuid ?? result.playInfo.item.guid;
      _qualities = result.qualities;
      _currentQuality = result.currentQuality;
      ref
          .read(playerViewModelProvider.notifier)
          .updatePlayingInfo(result.playingInfoCache);
      _prepareHlsSubtitleOverlayMode(
        subtitleStream: result.playingInfoCache.currentSubtitleStream,
        subtitlePlaylistUrl: result.preparedPlaySource.subtitlePlaylistUrl,
      );

      final startMs =
          widget.initialPositionMs ?? result.effectiveStartPositionMs;

      if (result.playingInfoCache.isUseDirectLink) {
        await _openDirectLinkWithHlsFallback(
          result: result,
          dio: dio,
          startPositionMs: startMs,
          requestToken: requestToken,
        );
      } else {
        await _openMediaWithResume(
          playUri: result.preparedPlaySource.playUri,
          startPositionMs: startMs,
          currentSubtitleStream: result.playingInfoCache.currentSubtitleStream,
        );
      }
      if (!mounted || requestToken != _loadRequestToken) {
        return;
      }
      _startHlsSubtitleSessionAsync(
        dio: dio,
        subtitleStream: _playingInfoCache?.currentSubtitleStream ??
            result.playingInfoCache.currentSubtitleStream,
        subtitlePlaylistUrl: result.preparedPlaySource.subtitlePlaylistUrl,
        startPositionMs: startMs,
        loadToken: requestToken,
      );

      _volume = ref.read(playerSettingsManagerProvider).getVolume();
      await _player!.setVolume(_volume * 100);

      _speed = ref.read(playerSettingsManagerProvider).getSpeed();
      await _player!.setRate(_speed);

      setState(() {
        _isLoading = false;
        _isInitialized = true;
        _isPlaying = _player?.state.playing ?? false;
        final playerDuration = _player?.state.duration.inMilliseconds ?? 0;
        final serviceDuration =
            result.playingInfoCache.currentVideoStream!.duration > 0
                ? result.playingInfoCache.currentVideoStream!.duration * 1000
                : result.playInfo.item.duration * 1000;
        _duration = playerDuration > 0 ? playerDuration : serviceDuration;
        _currentResolution = _currentQuality?.resolution ?? '';
        _currentBitrate = _currentQuality?.bitrate;
        _selectedAudioGuid = result.audioGuid;
        _selectedSubtitleGuid = result.subtitleGuid;
        _episodeList = result.episodeList;
        _currentEpisode = result.currentEpisode;
        _nextEpisode = result.nextEpisode;
        _nextEpisodeLoadPhase = result.nextEpisode != null
            ? NextEpisodeLoadPhase.available
            : result.playInfo.item.type == 'Episode'
                ? NextEpisodeLoadPhase.loading
                : NextEpisodeLoadPhase.unavailable;
      });
      _resolveAndDispatchSkipSegments();
      _introSkipController.dispatch(
        EpisodeSessionStarted(
          episodeGuid: _currentItemGuid,
          effectiveStartPositionMilliseconds: startMs,
          segments: _resolvedSkipSegments,
          isAutoPlayEnabled:
              ref.read(playerOverlayControllerProvider).isAutoPlayEnabled,
          nextEpisodeLoadPhase: _nextEpisodeLoadPhase,
        ),
      );
      _introSkipController.dispatch(const MediaOpened());
      _introSkipController.dispatch(PlayingChanged(_isPlaying));
      _updateEpisodeAnalysisContext();
      _startPlayRecordTimer();
      // Immediately record playback start, using at least 1s to avoid zero-second record.
      final recordStartMs = startMs > 0 ? startMs : 1000;
      _queuePlayRecordUpdate(positionMs: recordStartMs);
      _lastRecordedPosition = recordStartMs;
      _suspendPlaybackTransitionFeedback = false;

      // Start the initial idle countdown after playback state is finalized.
      _showUi();

      _fetchEpisodeContextAsync(requestToken);
    } catch (e, st) {
      AppTalker.error(
        'Player',
        error: e,
        stackTrace: st,
        message: 'Error loading media',
      );
      ref.read(toastManagerProvider.notifier).showToast(
            '加载失败: $e',
            type: ToastType.failed,
            category: 'playback-load:${widget.guid}',
          );
      _suspendPlaybackTransitionFeedback = false;
    } finally {
      // Always clear the loading flag for the active request, covering the
      // early-return paths above where the request stays current but never
      // reached the success branch (e.g. a superseded or aborted load).
      if (mounted && requestToken == _loadRequestToken && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _fetchEpisodeContextAsync(int requestToken) {
    final info = _playInfo;
    if (info == null ||
        info.item.type != 'Episode' ||
        info.parentGuid.isEmpty) {
      return;
    }
    unawaited(() async {
      try {
        final context = await _sessionCoordinator.loadEpisodeContext(
          parentGuid: info.parentGuid,
          currentGuid: info.item.guid,
        );
        if (!mounted || requestToken != _loadRequestToken) return;
        if (context.currentEpisode?.guid != info.item.guid) return;

        setState(() {
          _episodeList = context.episodeList;
          _currentEpisode = context.currentEpisode;
          _nextEpisode = context.nextEpisode;
          _nextEpisodeLoadPhase = context.nextEpisode != null
              ? NextEpisodeLoadPhase.available
              : NextEpisodeLoadPhase.unavailable;
        });
        _introSkipController.dispatch(
          NextEpisodeLoadChanged(_nextEpisodeLoadPhase),
        );
      } catch (e) {
        _nextEpisodeLoadPhase = NextEpisodeLoadPhase.failed;
        _introSkipController.dispatch(
          const NextEpisodeLoadChanged(NextEpisodeLoadPhase.failed),
        );
        AppTalker.warning('Player', 'load episode context failed: $e');
      }
    }());
  }

  void _startPlayRecordTimer() {
    _playRecordTimer?.cancel();
    _playRecordTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final position = _player?.state.position.inMilliseconds ?? 0;
      if (position > 0 && position != _lastRecordedPosition) {
        _lastRecordedPosition = position;
        _queuePlayRecordUpdate(positionMs: position);
      }
    });
  }

  void _showUi() {
    _overlayController.showUi(isPlaying: _isPlaying);
  }

  Future<void> _syncMacOSWindowButtonsVisibility({
    required bool visible,
    bool force = false,
  }) async {
    if (!_isMacOS) {
      return;
    }
    final effectiveVisibility = _isPipMode ? false : visible;
    if (!force && _lastMacOSWindowButtonsVisibility == effectiveVisibility) {
      return;
    }
    try {
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: effectiveVisibility,
      );
      _lastMacOSWindowButtonsVisibility = effectiveVisibility;
    } catch (error, stackTrace) {
      AppTalker.error(
        'Player',
        error: error,
        stackTrace: stackTrace,
        message:
            'sync macOS window buttons visibility failed: $effectiveVisibility',
      );
    }
  }

  void _scheduleMacOSWindowButtonsSync({
    required bool visible,
    bool force = false,
  }) {
    if (!_isMacOS) {
      return;
    }
    final effectiveVisibility = _isPipMode ? false : visible;
    if (!force &&
        _lastMacOSWindowButtonsVisibility == effectiveVisibility &&
        _pendingMacOSWindowButtonsVisibility == null) {
      return;
    }
    _pendingMacOSWindowButtonsVisibility = effectiveVisibility;
    _pendingMacOSWindowButtonsForce = _pendingMacOSWindowButtonsForce || force;
    if (_macOSWindowButtonsSyncQueued) {
      return;
    }
    _macOSWindowButtonsSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _macOSWindowButtonsSyncQueued = false;
      final pendingVisibility = _pendingMacOSWindowButtonsVisibility;
      final pendingForce = _pendingMacOSWindowButtonsForce;
      _pendingMacOSWindowButtonsVisibility = null;
      _pendingMacOSWindowButtonsForce = false;
      if (!mounted || pendingVisibility == null) {
        return;
      }
      unawaited(_syncMacOSWindowButtonsVisibility(
        visible: pendingVisibility,
        force: pendingForce,
      ));
    });
  }

  // Reveals the PiP control overlay and (re)starts the idle hide timer.
  void _showPipControls() {
    if (!_isPipMode) {
      return;
    }
    if (!_isPipHovered) {
      setState(() => _isPipHovered = true);
    }
    _restartPipIdleTimer();
  }

  // Restarts the 3s idle timer. While paused the UI stays pinned, so no timer.
  void _restartPipIdleTimer() {
    _pipIdleTimer?.cancel();
    if (!_isPlaying) {
      return;
    }
    _pipIdleTimer = Timer(_pipIdleHideDuration, _hidePipControls);
  }

  // Hides the PiP control overlay unless playback is paused.
  void _hidePipControls() {
    _pipIdleTimer?.cancel();
    if (!_isPlaying) {
      return;
    }
    if (_isPipHovered && mounted) {
      setState(() => _isPipHovered = false);
    }
  }

  void _handlePlaybackStateChanged(bool isPlaying) {
    final wasPlaying = _isPlaying;
    if (mounted && wasPlaying != isPlaying) {
      setState(() => _isPlaying = isPlaying);
    } else {
      _isPlaying = isPlaying;
    }

    // In PiP, keep controls pinned while paused; resume the idle timer on play.
    if (_isPipMode && wasPlaying != isPlaying) {
      if (!isPlaying) {
        _showPipControls();
      } else {
        _restartPipIdleTimer();
      }
    }

    if (_suspendPlaybackTransitionFeedback ||
        wasPlaying == isPlaying ||
        _isPipMode) {
      return;
    }

    if (!isPlaying) {
      _showPlaybackIndicator(_PlaybackIndicatorType.pause);
    } else {
      _showPlaybackIndicator(_PlaybackIndicatorType.play);
    }
    _showUi();
    _queuePlayRecordUpdate();
  }

  void _showPlaybackIndicator(_PlaybackIndicatorType type) {
    _playbackIndicatorTimer?.cancel();
    _playbackIndicatorExitController.stop();
    _playbackIndicatorExitController.value = 0;

    if (mounted) {
      setState(() {
        _playbackIndicatorType = type;
        _isPlaybackIndicatorVisible = true;
      });
    } else {
      _playbackIndicatorType = type;
      _isPlaybackIndicatorVisible = true;
    }

    _playbackIndicatorTimer = Timer(_playbackIndicatorVisibleDuration, () {
      if (!mounted || !_isPlaybackIndicatorVisible) return;
      _playbackIndicatorExitController.forward(from: 0);
    });
  }

  void _hidePlaybackIndicator() {
    _playbackIndicatorTimer?.cancel();
    _playbackIndicatorExitController.stop();
    _playbackIndicatorExitController.value = 0;
    _playbackIndicatorType = null;
    _isPlaybackIndicatorVisible = false;
  }

  void _handleFlyoutHoverStateChanged(PlayerFlyoutType type, bool hovered) {
    _overlayController.setFlyoutHovered(type, hovered);
  }

  void _handleNextEpisodeHoverStateChanged(bool hovered) {
    _handleFlyoutHoverStateChanged(PlayerFlyoutType.nextEpisode, hovered);
  }

  void _togglePlayPause() {
    if (_player == null) return;
    if (_player!.state.playing) {
      _player!.pause();
    } else {
      _player!.play();
    }
  }

  void _handleVideoDoubleTap() {
    _playerFocusNode.requestFocus();

    if (_isPipMode || _pipController.isPipMode) {
      return;
    }

    // Toggle fullscreen when the primary mouse button is double-clicked.
    unawaited(_toggleFullscreen());
  }

  void _seekRelative(int milliseconds) {
    if (_player == null) return;
    final current = _player!.state.position.inMilliseconds;
    final target = (current + milliseconds).clamp(0, _duration).toInt();
    final origin =
        _isPipMode ? PlayerSeekOrigin.pipShortcut : PlayerSeekOrigin.keyboard;
    unawaited(_performSeek(target, origin));
  }

  void _seekTo(double progress) {
    if (_player == null) return;
    final target = (progress * _duration).toInt();
    final origin = _isPipMode
        ? PlayerSeekOrigin.pipProgressBar
        : PlayerSeekOrigin.progressBar;
    unawaited(_performSeek(target, origin));
  }

  Future<void> _performSeek(
    int targetMilliseconds,
    PlayerSeekOrigin origin,
  ) async {
    await _seekExecutor.performSeek(
      targetMilliseconds: targetMilliseconds,
      origin: origin,
    );
  }

  void _setVolume(double volume) {
    if (_player == null) return;
    setState(() => _volume = volume);
    _player!.setVolume(volume * 100);
    ref.read(playerSettingsManagerProvider).setVolume(volume);
  }

  void _setSpeed(double speed) {
    if (_player == null) return;
    setState(() => _speed = speed);
    _player!.setRate(speed);
    ref.read(playerSettingsManagerProvider).setSpeed(speed);
  }

  KeyEventResult _handlePlayerKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_isSystemVolumeShortcut(event)) {
      return KeyEventResult.ignored;
    }
    final shortcutStore = ref.read(shortcutSettingsStoreProvider);
    if (shortcutStore.matches(event, ShortcutActionId.mute)) {
      _toggleMute();
      return KeyEventResult.handled;
    }
    if (shortcutStore.matches(event, ShortcutActionId.seekBackward)) {
      _seekRelativeWithToast(-10000);
      return KeyEventResult.handled;
    }
    if (shortcutStore.matches(event, ShortcutActionId.seekForward)) {
      _seekRelativeWithToast(10000);
      return KeyEventResult.handled;
    }
    if (shortcutStore.matches(event, ShortcutActionId.volumeUp)) {
      _changeVolumeBy(0.1);
      return KeyEventResult.handled;
    }
    if (shortcutStore.matches(event, ShortcutActionId.volumeDown)) {
      _changeVolumeBy(-0.1);
      return KeyEventResult.handled;
    }
    if (shortcutStore.matches(event, ShortcutActionId.togglePlayPause)) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }
    if (shortcutStore.matches(event, ShortcutActionId.toggleFullscreen)) {
      if (!_isPipMode && !_pipController.isPipMode) {
        unawaited(_toggleFullscreen());
      }
      return KeyEventResult.handled;
    }
    if (shortcutStore.matches(event, ShortcutActionId.exitFullscreen)) {
      if (!_isPipMode && !_pipController.isPipMode && _isFullscreen) {
        unawaited(_toggleFullscreen());
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _isSystemVolumeShortcut(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.f2 ||
        event.logicalKey == LogicalKeyboardKey.f3 ||
        event.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
        event.logicalKey == LogicalKeyboardKey.audioVolumeDown ||
        event.logicalKey == LogicalKeyboardKey.audioVolumeMute;
  }

  void _seekRelativeWithToast(int milliseconds) {
    final player = _player;
    if (player == null) return;
    final current = player.state.position.inMilliseconds;
    final target = (current + milliseconds).clamp(0, _duration).toInt();
    final origin =
        _isPipMode ? PlayerSeekOrigin.pipShortcut : PlayerSeekOrigin.keyboard;
    unawaited(_performSeek(target, origin));
    final label = milliseconds < 0 ? '快退至' : '快进至';
    ref.read(toastManagerProvider.notifier).showToast(
          '$label：${formatDurationToDateTime(target)}',
          type: ToastType.info,
          category: 'seek',
        );
  }

  void _changeVolumeBy(double delta) {
    final newVolume = ((_volume + delta) * 10).round() / 10.0;
    final clampedVolume = newVolume.clamp(0.0, 1.0).toDouble();
    _setVolume(clampedVolume);
    _lastVolumeBeforeMute = 0.0;
    ref.read(toastManagerProvider.notifier).showToast(
          '当前音量：${(clampedVolume * 100).toInt()}%',
          type: ToastType.info,
          category: 'volume',
        );
  }

  void _toggleMute() {
    if (_player == null) return;
    if (_volume > 0) {
      _lastVolumeBeforeMute = _volume;
      _setVolume(0.0);
      ref.read(toastManagerProvider.notifier).showToast(
            '静音',
            type: ToastType.info,
            category: 'volume',
          );
    } else {
      final restoreVolume =
          _lastVolumeBeforeMute > 0 ? _lastVolumeBeforeMute : 0.05;
      _setVolume(restoreVolume);
      ref.read(toastManagerProvider.notifier).showToast(
            '解除静音：${(restoreVolume * 100).toInt()}%',
            type: ToastType.info,
            category: 'volume',
          );
    }
  }

  Future<void> _toggleFullscreen() async {
    try {
      final isFullscreen = await _fullscreenController.toggle();
      if (!mounted) {
        return;
      }

      setState(() => _isFullscreen = isFullscreen);
    } catch (error, stackTrace) {
      AppTalker.error(
        'Player',
        error: error,
        stackTrace: stackTrace,
        message: 'toggle fullscreen failed',
      );
      if (mounted) {
        ref
            .read(toastManagerProvider.notifier)
            .showToast('切换全屏失败: $error', type: ToastType.failed);
      }
    }
  }

  /// Resolves the playing video's aspect ratio (width / height). Prefers the
  /// live media_kit decode size, falling back to the negotiated stream info.
  double? _resolveVideoAspectRatio() {
    final state = _player?.state;
    final liveWidth = state?.width ?? 0;
    final liveHeight = state?.height ?? 0;
    if (liveWidth > 0 && liveHeight > 0) {
      return liveWidth / liveHeight;
    }
    final videoStream = _playingInfoCache?.currentVideoStream;
    if (videoStream != null &&
        videoStream.width > 0 &&
        videoStream.height > 0) {
      return videoStream.width / videoStream.height;
    }
    return null;
  }

  Future<void> _enterPipMode() async {
    AppTalker.info('PiP', 'PiP requested from player screen');
    if (!_isDesktopPlatform()) {
      _showFeatureComingSoon('画中画');
      return;
    }

    final player = _player;
    if (player == null || !_isInitialized) {
      ref
          .read(toastManagerProvider.notifier)
          .showToast('播放器尚未准备完成', type: ToastType.info);
      return;
    }

    try {
      _isPipTransitioning = true;
      if (!mounted) {
        return;
      }
      setState(() {
        _isPipMode = true;
        _isPipHovered = true;
      });
      // Reveal controls on entry, then let the idle timer hide them.
      _restartPipIdleTimer();
      _dismissTransientPlayerUiBeforeExit();

      // Persist playback progress in the background; do not block window shrink.
      _queuePlayRecordUpdate();

      // Reuse the same window and the same player by switching the window into
      // a compact, borderless, always-on-top form.
      await _pipController.enter(videoAspectRatio: _resolveVideoAspectRatio());

      if (!mounted) {
        return;
      }
      _pipTransitionController?.forward(from: 0);
    } catch (error, stackTrace) {
      AppTalker.error(
        'Player',
        error: error,
        stackTrace: stackTrace,
        message: 'enter PiP failed',
      );
      // Roll back to the normal window form on any failure.
      try {
        await _pipController.exit();
      } catch (_) {}
      if (mounted) {
        setState(() => _isPipMode = false);
        ref
            .read(toastManagerProvider.notifier)
            .showToast('进入画中画失败: $error', type: ToastType.failed);
      }
    } finally {
      _isPipTransitioning = false;
    }
  }

  Future<void> _exitPipMode() async {
    if (!_isPipMode || _isPipTransitioning) {
      return;
    }
    try {
      _isPipTransitioning = true;
      _pipBoundsSaveTimer?.cancel();
      _pipIdleTimer?.cancel();

      await _pipController.persistCurrentBounds();
      await _pipController.exit();

      if (!mounted) {
        return;
      }
      setState(() {
        _isPipMode = false;
        _isPipHovered = false;
      });
      _pipTransitionController?.reverse(from: 1);
      _scheduleMacOSWindowButtonsSync(
        visible: ref.read(playerOverlayControllerProvider).isUiVisible,
        force: true,
      );
    } catch (error, stackTrace) {
      AppTalker.error(
        'Player',
        error: error,
        stackTrace: stackTrace,
        message: 'exit PiP failed',
      );
      if (mounted) {
        ref
            .read(toastManagerProvider.notifier)
            .showToast('退出画中画失败: $error', type: ToastType.failed);
      }
    } finally {
      _isPipTransitioning = false;
    }
  }

  void _schedulePipBoundsSave() {
    if (!_isPipMode) {
      return;
    }
    _pipBoundsSaveTimer?.cancel();
    _pipBoundsSaveTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_pipController.persistCurrentBounds()),
    );
  }

  Future<void> _onQualitySelected(QualityResponse quality) async {
    await _switchQualityWithSessionFlow(quality);
  }

  Future<void> _onAudioSelected(AudioStream audio) async {
    await _switchAudioWithSessionFlow(audio);
  }

  Future<void> _onSubtitleSelected(String? subtitleGuid) async {
    final stream = _streamInfo?.subtitleStreams
        ?.where((item) => item.guid == subtitleGuid)
        .firstOrNull;
    await _switchSubtitleWithSessionFlow(stream);
  }

  Future<void> _switchQualityWithSessionFlow(QualityResponse quality) async {
    final cache = _playingInfoCache;
    final player = _player;
    if (cache == null || player == null) {
      return;
    }

    final videoStream = cache.currentVideoStream;
    final fileStream = cache.currentFileStream;
    final currentAudio = cache.currentAudioStream;
    if (videoStream == null || fileStream == null) return;

    try {
      setState(() => _isLoading = true);
      final currentPosition = player.state.position.inMilliseconds;
      final currentPlayLink = cache.playLink;
      final isTargetDirectLink = _sessionCoordinator.supportsDirectLink(
        videoStream,
        quality,
        cache.currentQualities,
      );
      _playingInfoCache = cache.copyWith(
        currentQuality: quality,
        isUseDirectLink: isTargetDirectLink,
        playLink: isTargetDirectLink ? null : cache.playLink,
        playRecordLink: isTargetDirectLink
            ? _sessionCoordinator.ensureDirectPlayRecordLink(
                cache.playRecordLink,
              )
            : cache.playRecordLink,
      );
      ref
          .read(playerViewModelProvider.notifier)
          .updatePlayingInfo(_playingInfoCache);
      _queuePlayRecordUpdate(positionMs: currentPosition);

      if (isTargetDirectLink &&
          !cache.isUseDirectLink &&
          currentPlayLink != null) {
        await ref.read(mediaPViewModelProvider.notifier).quit(
              MediaPRequest(playLink: currentPlayLink),
            );
      } else if (!cache.isUseDirectLink && currentPlayLink != null) {
        await ref.read(mediaPViewModelProvider.notifier).resetQuality(
              MediaPRequest(
                playLink: currentPlayLink,
                quality: MediaPQuality(
                  resolution: quality.resolution,
                  bitrate: quality.bitrate,
                ),
                startTimestamp: currentPosition ~/ 1000,
                clearCache: true,
              ),
            );
      } else {
        final audioGuid = currentAudio?.guid ??
            _selectedAudioGuid ??
            _requestedAudioGuid ??
            _playInfo?.audioGuid ??
            '';
        final playRequest = _sessionCoordinator.createPlayRequest(
          videoStream: videoStream,
          fileStream: fileStream,
          audioGuid: audioGuid,
          subtitleGuid: cache.currentSubtitleStream?.guid,
        );
        final playerService = ref.read(playerServiceProvider);
        final response = await playerService.playVideo(
          PlayPlayRequest(
            mediaGuid: playRequest.mediaGuid,
            videoGuid: playRequest.videoGuid,
            videoEncoder: playRequest.videoEncoder,
            resolution: quality.resolution,
            bitrate: quality.bitrate,
            startTimestamp: currentPosition ~/ 1000,
            audioEncoder: playRequest.audioEncoder,
            audioGuid: playRequest.audioGuid,
            subtitleGuid: playRequest.subtitleGuid,
            channels: playRequest.channels,
            forcedSdr: playRequest.forcedSdr,
          ),
        );
        await _handlePlayPlaySuccess(response,
            startPositionMs: currentPosition);
      }

      setState(() {
        _isLoading = false;
        _currentQuality = quality;
        _currentResolution = quality.resolution;
        _currentBitrate = quality.bitrate;
      });
    } catch (e) {
      AppTalker.warning('Player', 'switch quality failed: $e');
      ref
          .read(toastManagerProvider.notifier)
          .showToast('切换画质失败: $e', type: ToastType.failed);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _switchAudioWithSessionFlow(AudioStream audio) async {
    final cache = _playingInfoCache;
    final player = _player;
    if (cache == null || player == null) {
      return;
    }
    if (audio.guid.isNotEmpty && cache.currentAudioStream?.guid == audio.guid) {
      return;
    }

    final switchToken = ++_audioSwitchToken;
    final previousAudio = cache.currentAudioStream;
    _requestedAudioGuid = audio.guid;
    setState(() => _isLoading = true);

    try {
      if (cache.isUseDirectLink) {
        final audioTrack = await _resolveDirectLinkAudioTrack(
          audio,
          switchToken,
        );
        if (!_isCurrentAudioSwitch(switchToken)) {
          return;
        }
        await _applyDirectLinkAudioTrack(audioTrack);
      } else {
        final playLink = cache.playLink;
        if (playLink == null || playLink.isEmpty) {
          throw StateError('服务端播放会话链接缺失');
        }
        final response = await ref
            .read(mediaPViewModelProvider.notifier)
            .resetAudio(
              MediaPRequest(
                playLink: playLink,
                startTimestamp: player.state.position.inMilliseconds ~/ 1000,
                clearCache: true,
                audioEncoder: 'aac',
                channels: 2,
                audioIndex: audio.index,
              ),
            );
        if (!response.isSuccess) {
          throw StateError('服务端未能切换音频轨道');
        }
      }

      if (!_isCurrentAudioSwitch(switchToken)) {
        return;
      }
      final updatedCache = cache.copyWith(currentAudioStream: audio);
      _playingInfoCache = updatedCache;
      ref
          .read(playerViewModelProvider.notifier)
          .updatePlayingInfo(updatedCache);
      _queuePlayRecordUpdate(cacheOverride: updatedCache);
      setState(() {
        _selectedAudioGuid = audio.guid;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      if (_isCurrentAudioSwitch(switchToken)) {
        _requestedAudioGuid = null;
        ref.read(toastManagerProvider.notifier).showToast(
              '切换音频失败: $error',
              type: ToastType.failed,
              category: 'player-audio-switch',
            );
        setState(() {
          _selectedAudioGuid = previousAudio?.guid;
          _isLoading = false;
        });
      }
      AppTalker.error(
        'Player',
        error: error,
        stackTrace: stackTrace,
        message: 'audio switch failed',
      );
    }
  }

  Future<AudioTrack> _resolveDirectLinkAudioTrack(
    AudioStream audio,
    int switchToken,
  ) async {
    AudioTrack? resolveCurrentTracks() {
      return _directLinkAudioTrackResolver.resolve(
        audioStreams:
            _playingInfoCache?.currentAudioStreamList ?? const <AudioStream>[],
        audioTracks: _embeddedAudioTracks,
        targetAudio: audio,
      );
    }

    _embeddedAudioTracks = _directLinkAudioTrackResolver.embeddedTracksOf(
      _player!.state.tracks.audio,
    );
    final immediateTrack = resolveCurrentTracks();
    if (immediateTrack != null) {
      return immediateTrack;
    }

    final player = _player;
    if (player == null) {
      throw StateError('播放器尚未初始化');
    }
    final completer = Completer<AudioTrack>();
    late final StreamSubscription<Tracks> subscription;
    final timeoutTimer = Timer(_directLinkEmbeddedAudioTracksTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(StateError('等待音频轨道超时'));
      }
    });
    subscription = player.stream.tracks.listen((tracks) {
      _embeddedAudioTracks =
          _directLinkAudioTrackResolver.embeddedTracksOf(tracks.audio);
      final resolvedTrack = resolveCurrentTracks();
      if (resolvedTrack != null && !completer.isCompleted) {
        completer.complete(resolvedTrack);
      }
    }, onError: (Object error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    try {
      final resolvedTrack = await completer.future;
      if (!_isCurrentAudioSwitch(switchToken)) {
        throw StateError('音频切换请求已过期');
      }
      return resolvedTrack;
    } finally {
      timeoutTimer.cancel();
      await subscription.cancel();
    }
  }

  Future<void> _applyInitialDirectLinkAudioTrack() async {
    final targetAudio = _playingInfoCache?.currentAudioStream;
    if (targetAudio == null) {
      return;
    }

    final switchToken = ++_audioSwitchToken;
    try {
      final targetTrack = await _resolveDirectLinkAudioTrack(
        targetAudio,
        switchToken,
      );
      if (!_isCurrentAudioSwitch(switchToken)) {
        return;
      }
      await _applyDirectLinkAudioTrack(targetTrack);
    } catch (error, stackTrace) {
      AppTalker.error(
        'Player',
        error: error,
        stackTrace: stackTrace,
        message: 'initial direct-link audio alignment failed',
      );
    }
  }

  Future<void> _applyDirectLinkAudioTrack(AudioTrack audioTrack) async {
    final player = _player;
    if (player == null) {
      throw StateError('播放器尚未初始化');
    }
    final platform = player.platform;
    if (platform is NativePlayer) {
      try {
        await platform.setProperty(
          'aid',
          audioTrack.id,
          waitForInitialization: false,
        );
        return;
      } catch (error) {
        AppTalker.warning(
          'Player',
          'mpv aid switch failed, fallback to setAudioTrack: $error',
        );
      }
    }
    await player.setAudioTrack(audioTrack);
  }

  bool _isCurrentAudioSwitch(int switchToken) {
    return mounted && switchToken == _audioSwitchToken;
  }

  Future<void> _switchSubtitleWithSessionFlow(SubtitleStream? subtitle) async {
    final cache = _playingInfoCache;
    final player = _player;
    if (cache == null || player == null) {
      return;
    }

    final videoStream = cache.currentVideoStream;
    final fileStream = cache.currentFileStream;
    if (videoStream == null || fileStream == null) return;

    final previousSubtitle = cache.currentSubtitleStream;
    final isDirectLinkEmbeddedSwitch = subtitle != null &&
        subtitle.isExternal != 1 &&
        cache.isUseDirectLink &&
        !_useHlsSubtitleOverlay;
    if (!isDirectLinkEmbeddedSwitch) {
      _clearPendingEmbeddedSubtitleSwitch(advanceToken: true);
    }
    final subtitleIndex = subtitle == null
        ? null
        : subtitle.isExternal == 1
            ? -1
            : subtitle.index;

    try {
      setState(() {
        _isSubtitleSwitching = true;
        _isLoading = !isDirectLinkEmbeddedSwitch;
      });
      _requestedSubtitleGuid = subtitle?.guid;
      final currentPosition = player.state.position.inMilliseconds;
      final initialPlayLink = cache.playLink;
      final updatedCache = cache.copyWith(
        previousSubtitle: previousSubtitle,
        currentSubtitleStream: subtitle,
      );
      _playingInfoCache = updatedCache;
      ref
          .read(playerViewModelProvider.notifier)
          .updatePlayingInfo(updatedCache);

      // Persist the newly selected subtitle via /play/record so the server
      // remembers it for the next session.
      _queuePlayRecordUpdate(
        positionMs: currentPosition,
        cacheOverride: updatedCache,
      );

      final currentPlayLink = updatedCache.playLink;
      final resetPlayLink = currentPlayLink ?? initialPlayLink;
      if (resetPlayLink != null && resetPlayLink.isNotEmpty) {
        await ref.read(mediaPViewModelProvider.notifier).resetSubtitle(
              MediaPRequest(
                playLink: resetPlayLink,
                subtitleIndex: subtitleIndex,
                startTimestamp: currentPosition ~/ 1000,
              ),
            );
      } else if (isDirectLinkEmbeddedSwitch) {
        _scheduleDirectLinkEmbeddedSubtitleSwitch(
          targetSubtitle: subtitle,
          previousSubtitle: previousSubtitle,
        );
        if (mounted) {
          setState(() {
            _isSubtitleSwitching = false;
            _selectedSubtitleGuid = subtitle.guid;
            _isLoading = false;
          });
        }
      } else {
        // Direct-link playback (no server-side session): apply the chosen
        // subtitle track locally and clear the loading state immediately.
        await _applyCurrentSubtitleTrack(subtitle, strict: true);
        if (mounted) {
          setState(() {
            _isSubtitleSwitching = false;
            _selectedSubtitleGuid = subtitle?.guid;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      _playingInfoCache = cache.copyWith(
        currentSubtitleStream: previousSubtitle,
        previousSubtitle: previousSubtitle,
      );
      ref
          .read(playerViewModelProvider.notifier)
          .updatePlayingInfo(_playingInfoCache);
      AppTalker.warning('Player', 'switch subtitle failed: $e');
      ref
          .read(toastManagerProvider.notifier)
          .showToast('切换字幕失败: $e', type: ToastType.failed);
      if (mounted) {
        setState(() {
          _isSubtitleSwitching = false;
          _selectedSubtitleGuid = previousSubtitle?.guid;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleBack() async {
    await _leavePlayerRoute(() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    });
  }

  Future<void> _closeFromPip() async {
    await _exitPipMode();
    if (!mounted) return;
    await _handleBack();
  }

  // Dismiss transient overlays before leaving the player route.
  void _dismissTransientPlayerUiBeforeExit() {
    _playRecordTimer?.cancel();
    _playbackIndicatorTimer?.cancel();
    _hidePlaybackIndicator();
    Tooltip.dismissAllToolTips();
    _overlayController.dismissTransientUi();
  }

  Future<void> _leavePlayerRoute(VoidCallback onLeave) async {
    _dismissTransientPlayerUiBeforeExit();
    _episodeAnalysisController.stopAndClear();

    // Restore the host window before leaving the fullscreen player route.
    await _restoreWindowModeBeforeLeave();
    unawaited(_syncMacOSWindowButtonsVisibility(visible: true, force: true));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      onLeave();
    });
  }

  @override
  void dispose() {
    if (_isDesktopPlatform()) {
      windowManager.removeListener(this);
      unawaited(_fullscreenController.exitForRouteLeave());
      // Ensure the window is restored to its normal form when leaving while in
      // PiP mode so the next route is not stuck in a tiny borderless window.
      if (_pipController.isPipMode) {
        unawaited(_pipController.exit());
      }
    }
    if (!_pipController.isPipMode) {
      unawaited(_syncMacOSWindowButtonsVisibility(visible: true, force: true));
    }
    _pipBoundsSaveTimer?.cancel();
    _pipIdleTimer?.cancel();
    _positionSubscription?.cancel();
    _bufferSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _completedSubscription?.cancel();
    _tracksSubscription?.cancel();
    _skipActionSubscription?.cancel();
    _removeIntroSkipStateListener?.call();
    _introSkipController.dispose();
    _disposeHlsSubtitleSession();
    _playRecordTimer?.cancel();
    _playbackIndicatorTimer?.cancel();
    _playbackIndicatorExitController.dispose();
    _pipTransitionController?.dispose();
    _playerFocusNode.dispose();
    _player?.dispose();
    _hlsSubtitleTexts.dispose();
    _danmakuPosition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitleSettings = ref.watch(subtitleSettingsProvider);
    final danmakuState = ref.watch(danmakuControllerProvider);
    final overlayState = ref.watch(playerOverlayControllerProvider);
    _scheduleMacOSWindowButtonsSync(
      visible: overlayState.isUiVisible,
    );
    final pipTransition = _pipTransitionController;
    final playerCursor =
        _isInitialized && !_isPipMode && !overlayState.isUiVisible
            ? SystemMouseCursors.none
            : SystemMouseCursors.click;

    final playerStack = MouseRegion(
      cursor: playerCursor,
      onHover: (_) => _showUi(),
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _playerFocusNode.requestFocus();
              _togglePlayPause();
            },
            onDoubleTap: _handleVideoDoubleTap,
            child: Container(
              color: Colors.black,
              child: _isInitialized && _videoController != null
                  ? Video(
                      controller: _videoController!,
                      controls: NoVideoControls,
                      fit: _isPipMode ? BoxFit.cover : BoxFit.contain,
                    )
                  : const Center(child: AppLoadingProgressRing()),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<Duration>(
                valueListenable: _danmakuPosition,
                builder: (context, position, _) {
                  return PlayerDanmakuOverlay(
                    danmakuList: danmakuState.danmakuList,
                    position: position,
                    isPlaying: _isPlaying,
                    playbackRate: _speed,
                    isVisible: danmakuState.isVisible,
                    settings: danmakuState.settings,
                    loadStatus: danmakuState.loadStatus,
                    resetGeneration: _danmakuResetGeneration,
                  );
                },
              ),
            ),
          ),
          Positioned.fill(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _hlsSubtitleTexts,
              builder: (context, lines, _) {
                return PlayerSubtitleOverlay(
                  lines: lines,
                  visible: _useHlsSubtitleOverlay,
                  settings: subtitleSettings,
                );
              },
            ),
          ),
          // Keep subtitle switches visually lightweight and avoid blocking the
          // video.
          if (_isLoading && !_isSubtitleSwitching)
            const Center(child: AppLoadingProgressRing()),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: _buildPlaybackIndicator(),
              ),
            ),
          ),
          if (_isInitialized && !_isPipMode)
            AnimatedOpacity(
              opacity: overlayState.isUiVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 112,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopBar(),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 168,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: MouseRegion(
                      onEnter: (_) {
                        _overlayController.setHovered(
                          PlayerHoverZone.bottomControls,
                          true,
                        );
                        _showUi();
                      },
                      onExit: (_) => _overlayController.setHovered(
                        PlayerHoverZone.bottomControls,
                        false,
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildProgressBar(),
                              const SizedBox(height: 12),
                              _buildControlButtons(
                                overlayState: overlayState,
                                subtitleSettings: subtitleSettings,
                                danmakuState: danmakuState,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_isInitialized && _isPipMode) _buildPipOverlay(),
          ..._buildSkipAndEndOverlays(),
        ],
      ),
    );

    Widget focusedPlayer(Widget child) {
      return Focus(
        focusNode: _playerFocusNode,
        autofocus: true,
        onKeyEvent: _handlePlayerKeyEvent,
        child: child,
      );
    }

    if (pipTransition == null || _isPipMode) {
      return focusedPlayer(playerStack);
    }
    return focusedPlayer(
      AnimatedBuilder(
        animation: pipTransition,
        builder: (context, child) {
          final t = Curves.easeInOutCubic.transform(pipTransition.value);
          return Transform.scale(
            scale: 1.0 - t * 0.08,
            child: child,
          );
        },
        child: playerStack,
      ),
    );
  }

  List<Widget> _buildSkipAndEndOverlays() {
    final state = _introSkipState;
    final credits = state.segments.creditsSegment;
    final hasContentAfterCredits = credits != null &&
        state.durationMilliseconds != null &&
        credits.endMilliseconds < state.durationMilliseconds! - 1000;
    final item = _playInfo?.item ?? _playingInfoCache?.item;

    return [
      if (state.isIntroUndoVisible)
        SkipIntroPrompt(
          countdown: state.introUndoRemainingSeconds,
          isPip: _isPipMode,
          onHoverChanged: _handleSkipPromptHover,
          onUndo: () {
            _introSkipController.dispatch(const IntroUndoRequested());
          },
        ),
      if (state.isOutroPromptVisible)
        SkipOutroPrompt(
          countdown: state.outroRemainingSeconds,
          autoPlayEnabled: state.isAutoPlayEnabled,
          hasContentAfterCredits: hasContentAfterCredits,
          nextEpisodePhase: state.nextEpisodeLoadPhase,
          isPip: _isPipMode,
          onHoverChanged: _handleSkipPromptHover,
          onCancel: () {
            _introSkipController.dispatch(const OutroCancelRequested());
          },
        ),
      if (state.isPlaybackEndVisible)
        PlaybackEndOverlay(
          episodeNumber: item?.episodeNumber ?? 0,
          episodeTitle: item?.title ?? '',
          runtimeMinutes: _duration ~/ Duration.millisecondsPerMinute,
          isPip: _isPipMode,
          onReplay: _replayCurrentEpisode,
          onReturnHome: () => unawaited(_handleBack()),
        ),
    ];
  }

  void _handleSkipPromptHover(bool hovered) {
    if (!_isPipMode) return;
    if (hovered) {
      _showPipControls();
    } else {
      _restartPipIdleTimer();
    }
  }

  void _replayCurrentEpisode() {
    final smartSkipEnabled =
        ref.read(settingsProvider).flyNarwhalServerEnabled &&
            ref.read(smartSkipSettingsControllerProvider).enabled;
    final manualIntroEnd =
        _resolvedSkipSegments.introSource == SkipSegmentSource.manual
            ? _resolvedSkipSegments.introSegment?.endMilliseconds ?? 0
            : 0;
    final replayTarget = smartSkipEnabled ? 0 : manualIntroEnd;
    _introSkipController.dispatch(const SessionDisposed());
    _resolveAndDispatchSkipSegments();
    _introSkipController.dispatch(
      EpisodeSessionStarted(
        episodeGuid: _currentItemGuid,
        effectiveStartPositionMilliseconds: replayTarget,
        segments: _resolvedSkipSegments,
        isAutoPlayEnabled:
            ref.read(playerOverlayControllerProvider).isAutoPlayEnabled,
        nextEpisodeLoadPhase: _nextEpisodeLoadPhase,
      ),
    );
    _introSkipController.dispatch(const MediaOpened());
    unawaited(() async {
      await _performSeek(replayTarget, PlayerSeekOrigin.settings);
      await _player?.play();
    }());
  }

  Widget _buildPipDragLayer() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePlayPause,
        onDoubleTap: () {},
        onPanStart: (_) => unawaited(windowManager.startDragging()),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildPipOverlay() {
    // The hover driver must wrap the whole stack as an ancestor (not sit as a
    // sibling). As an ancestor it stays in the hit-test path regardless of
    // which child is on top, so toggling the controls' IgnorePointer never
    // forces a spurious onExit. A sibling region gets occluded by the opaque
    // controls layer, causing an enter/exit feedback loop that flickers the
    // cursor between click and arrow.
    return Positioned.fill(
      child: MouseRegion(
        opaque: false,
        hitTestBehavior: HitTestBehavior.translucent,
        onEnter: (_) => _showPipControls(),
        onHover: (_) => _showPipControls(),
        onExit: (_) => _hidePipControls(),
        child: Stack(
          children: [
            _buildPipDragLayer(),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isPipHovered,
                child: AnimatedOpacity(
                  opacity: _isPipHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: _buildPipControlsLayer(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipControlsLayer() {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.24),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.38),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: PlayerActionButton.icon(
            key: const ValueKey('pip-close'),
            iconData: FluentIcons.chrome_close,
            tooltip: '关闭',
            onPressed: () => unawaited(_closeFromPip()),
            size: 28,
            iconSize: 14,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        // Centered transport cluster: rewind / play-pause / forward.
        Positioned.fill(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlayerActionButton.svg(
                  key: const ValueKey('pip-seek-backward'),
                  svgAssetPath: 'assets/images/back10s.svg',
                  tooltip: '快退 10 秒',
                  onPressed: () => _seekRelative(-10000),
                  size: 38,
                  iconSize: 24,
                  borderRadius: BorderRadius.circular(19),
                ),
                const SizedBox(width: 28),
                PlayerActionButton.svg(
                  key: const ValueKey('pip-play-pause'),
                  svgAssetPath: _isPlaying
                      ? 'assets/images/pause.svg'
                      : 'assets/images/play.svg',
                  tooltip: '播放/暂停',
                  onPressed: _togglePlayPause,
                  size: 52,
                  iconSize: 34,
                  borderRadius: BorderRadius.circular(26),
                ),
                const SizedBox(width: 28),
                PlayerActionButton.svg(
                  key: const ValueKey('pip-seek-forward'),
                  svgAssetPath: 'assets/images/forward10s.svg',
                  tooltip: '快进 10 秒',
                  onPressed: () => _seekRelative(10000),
                  size: 38,
                  iconSize: 24,
                  borderRadius: BorderRadius.circular(19),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 44,
          child: _buildPipProgressBar(),
        ),
        Positioned(
          left: 8,
          bottom: 6,
          child: VolumeControl(
            volume: _volume,
            popupBottomOffset: 36,
            onVolumeChange: _setVolume,
          ),
        ),
        Positioned(
          right: 10,
          bottom: 8,
          child: PlayerActionButton.lottie(
            key: const ValueKey('pip-exit'),
            lottieAssetPath: 'assets/lottie/quit_pip.json',
            tooltip: '退出画中画',
            onPressed: () => unawaited(_exitPipMode()),
            size: 30,
            iconSize: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildPipProgressBar() {
    final bufferedProgressRatio = _bufferedProgressRatio;
    return VideoPlayerProgressBar(
      currentPosition: _currentPosition,
      totalDuration: _duration,
      buffered: bufferedProgressRatio,
      introSegment: _resolvedSkipSegments.introSegment,
      creditsSegment: _resolvedSkipSegments.creditsSegment,
      showHoverTimestamp: false,
      onSeek: _seekTo,
    );
  }

  Widget _buildProgressBar() {
    final bufferedProgressRatio = _bufferedProgressRatio;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) =>
          _overlayController.setHovered(PlayerHoverZone.progressBar, true),
      onExit: (_) =>
          _overlayController.setHovered(PlayerHoverZone.progressBar, false),
      child: VideoPlayerProgressBar(
        currentPosition: _currentPosition,
        totalDuration: _duration,
        buffered: bufferedProgressRatio,
        introSegment: _resolvedSkipSegments.introSegment,
        creditsSegment: _resolvedSkipSegments.creditsSegment,
        onSeek: _seekTo,
      ),
    );
  }

  Widget _buildPlaybackTimeText() {
    return Text(
      '${formatDurationToDateTime(_currentPosition)} / ${formatDurationToDateTime(_duration)}',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.92),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Future<void> _saveSkipConfig(int skipOpening, int skipEnding) async {
    if (_isSavingSkipConfig) return;
    final cache = _playingInfoCache;
    final configGuid = cache?.playConfig?.guid ?? cache?.itemGuid;
    if (cache == null || configGuid == null || configGuid.isEmpty) return;

    final previousConfig = cache.playConfig;
    final optimisticConfig = PlayConfig(
      guid: configGuid,
      skipOpening: skipOpening.clamp(0, 600),
      skipEnding: skipEnding.clamp(0, 600),
    );
    setState(() {
      _isSavingSkipConfig = true;
      _playingInfoCache = cache.copyWith(playConfig: optimisticConfig);
    });
    ref
        .read(playerViewModelProvider.notifier)
        .updatePlayingInfo(_playingInfoCache);
    _resolveAndDispatchSkipSegments();

    try {
      await ref.read(playerServiceProvider).setSkipConfig(
            guid: configGuid,
            skipOpening: optimisticConfig.skipOpening ?? 0,
            skipEnding: optimisticConfig.skipEnding ?? 0,
          );
      if (!mounted) return;
      ref.read(toastManagerProvider.notifier).showToast(
            '跳过设置已保存',
            type: ToastType.success,
            category: 'skip-config',
          );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _playingInfoCache = cache.copyWith(playConfig: previousConfig);
      });
      ref
          .read(playerViewModelProvider.notifier)
          .updatePlayingInfo(_playingInfoCache);
      _resolveAndDispatchSkipSegments();
      ref.read(toastManagerProvider.notifier).showToast(
            '保存跳过设置失败: $error',
            type: ToastType.failed,
            category: 'skip-config',
          );
    } finally {
      if (mounted) setState(() => _isSavingSkipConfig = false);
    }
  }

  Future<void> _setSmartSkipEnabled(bool enabled) async {
    // Guard: require full FlyNarwhal config before enabling smart skip
    if (enabled) {
      final fnSettings = ref.read(settingsProvider);
      if (!fnSettings.isFlyNarwhalServerAvailable) {
        if (!mounted) return;
        ref.read(toastManagerProvider.notifier).showToast(
          buildFlyNarwhalConfigWarning(
            missingUrl: fnSettings.flyNarwhalServerBaseUrl.isEmpty,
            missingAuthCode: !fnSettings.hasFlyNarwhalAuthCode,
          ),
          type: ToastType.warning,
          category: 'fly-narwhal-config',
        );
        return;
      }
    }
    try {
      await ref
          .read(smartSkipSettingsControllerProvider.notifier)
          .setEnabled(enabled);
    } catch (error) {
      if (!mounted) return;
      ref.read(toastManagerProvider.notifier).showToast(
            '保存智能跳过设置失败: $error',
            type: ToastType.failed,
            category: 'smart-skip-setting',
          );
    }
  }

  Widget _buildControlButtons({
    required PlayerOverlayState overlayState,
    required SubtitleSettings subtitleSettings,
    required DanmakuState danmakuState,
  }) {
    final prefs = ref.watch(preferencesManagerProvider);
    final settings = ref.watch(settingsProvider);
    final baseUrl = prefs.getBaseUrl() ?? '';
    final token = prefs.getToken();
    final cookie = prefs.getCookie();
    final httpHeaders = token != null || (cookie != null && cookie.isNotEmpty)
        ? {
            if (token != null) 'Authorization': token,
            if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
          }
        : null;
    final cacheManager = ref.watch(imageCacheManagerProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PlayerActionButton.svg(
          key: const ValueKey('player-play-pause'),
          svgAssetPath:
              _isPlaying ? 'assets/images/pause.svg' : 'assets/images/play.svg',
          onPressed: _togglePlayPause,
          tooltip: '播放/暂停',
          size: 34,
          iconSize: 22,
        ),
        const SizedBox(width: 16),
        PlayerActionButton.svg(
          svgAssetPath: 'assets/images/back10s.svg',
          onPressed: () => _seekRelative(-10000),
          tooltip: '快退 10 秒',
          size: 30,
          iconSize: 20,
        ),
        const SizedBox(width: 16),
        PlayerActionButton.svg(
          svgAssetPath: 'assets/images/forward10s.svg',
          onPressed: () => _seekRelative(10000),
          tooltip: '快进 10 秒',
          size: 30,
          iconSize: 20,
        ),
        if (_nextEpisode != null) ...[
          const SizedBox(width: 12),
          NextEpisodePreviewFlyout(
            nextEpisode: _nextEpisode!,
            baseUrl: baseUrl,
            httpHeaders: httpHeaders,
            cacheManager: cacheManager,
            isActiveControl:
                overlayState.activeFlyout == PlayerFlyoutType.nextEpisode,
            onClick: () => _openEpisode(_nextEpisode!),
            onHoverStateChanged: _handleNextEpisodeHoverStateChanged,
          ),
        ],
        const SizedBox(width: 16),
        _buildPlaybackTimeText(),
        const Spacer(),
        // Keep the trailing control cluster visually consistent.
        SpeedControlFlyout(
          key: const ValueKey('player-speed-control'),
          defaultSpeed: _speed,
          yOffset: _controlFlyoutOffset,
          isActiveControl: overlayState.activeFlyout == PlayerFlyoutType.speed,
          onHoverStateChanged: (hovered) =>
              _handleFlyoutHoverStateChanged(PlayerFlyoutType.speed, hovered),
          onSpeedSelected: (speed) => _setSpeed(speed.value),
        ),
        const SizedBox(width: _trailingControlSpacing),
        if (_episodeList.isNotEmpty && _displaySubhead.isNotEmpty) ...[
          EpisodeSelectionFlyout(
            episodes: _episodeList,
            currentEpisodeGuid: _currentItemGuid,
            parentTitle: _episodeFlyoutTitle,
            baseUrl: baseUrl,
            httpHeaders: httpHeaders,
            cacheManager: cacheManager,
            yOffset: _controlFlyoutOffset,
            isActiveControl:
                overlayState.activeFlyout == PlayerFlyoutType.episode,
            onHoverStateChanged: (hovered) => _handleFlyoutHoverStateChanged(
                PlayerFlyoutType.episode, hovered),
            onEpisodeSelected: _openEpisode,
          ),
          const SizedBox(width: _trailingControlSpacing),
        ],
        if (_qualities.isNotEmpty)
          QualityControlFlyout(
            qualities: _qualities,
            currentResolution: _currentResolution,
            currentBitrate: _currentBitrate,
            yOffset: _controlFlyoutOffset,
            isActiveControl:
                overlayState.activeFlyout == PlayerFlyoutType.quality,
            onHoverStateChanged: (hovered) => _handleFlyoutHoverStateChanged(
                PlayerFlyoutType.quality, hovered),
            onQualitySelected: _onQualitySelected,
          ),
        const SizedBox(width: _trailingControlSpacing),
        if (settings.flyNarwhalServerEnabled) ...[
          MouseRegion(
            onEnter: (_) => _overlayController.setHovered(
                PlayerHoverZone.danmakuControl, true),
            onExit: (_) => _overlayController.setHovered(
              PlayerHoverZone.danmakuControl,
              false,
            ),
            child: PlayerActionButton.svg(
              key: const ValueKey('player-danmaku-toggle'),
              svgAssetPath: danmakuState.isVisible
                  ? 'assets/images/danmu_close.svg'
                  : 'assets/images/danmu_open.svg',
              onPressed: () {
                final newVisibility = !danmakuState.isVisible;
                // Guard: require full FlyNarwhal config before enabling danmaku
                if (newVisibility) {
                  final fnSettings = ref.read(settingsProvider);
                  if (!fnSettings.isFlyNarwhalServerAvailable) {
                    ref.read(toastManagerProvider.notifier).showToast(
                      buildFlyNarwhalConfigWarning(
                        missingUrl:
                            fnSettings.flyNarwhalServerBaseUrl.isEmpty,
                        missingAuthCode: !fnSettings.hasFlyNarwhalAuthCode,
                      ),
                      type: ToastType.warning,
                      category: 'fly-narwhal-config',
                    );
                    return;
                  }
                }
                ref
                    .read(danmakuControllerProvider.notifier)
                    .setVisibility(newVisibility);
              },
              tooltip: danmakuState.isVisible ? '关闭弹幕' : '开启弹幕',
              size: 34,
              iconSize: 24,
            ),
          ),
          const SizedBox(width: _trailingControlSpacing),
          DanmakuSettingsFlyout(
            settings: danmakuState.settings,
            loadStatus: danmakuState.loadStatus,
            popupBottomOffset: _controlFlyoutOffset.toDouble(),
            isActiveControl:
                overlayState.activeFlyout == PlayerFlyoutType.danmaku,
            onAreaChanged:
                ref.read(danmakuControllerProvider.notifier).updateArea,
            onOpacityChanged:
                ref.read(danmakuControllerProvider.notifier).updateOpacity,
            onFontSizeScaleChanged: ref
                .read(danmakuControllerProvider.notifier)
                .updateFontSizeScale,
            onSpeedChanged:
                ref.read(danmakuControllerProvider.notifier).updateSpeed,
            onSyncPlaybackSpeedChanged: ref
                .read(danmakuControllerProvider.notifier)
                .updateSyncPlaybackSpeed,
            onDebugEnabledChanged:
                ref.read(danmakuControllerProvider.notifier).updateDebugEnabled,
            onHoverStateChanged: (hovered) => _handleFlyoutHoverStateChanged(
              PlayerFlyoutType.danmaku,
              hovered,
            ),
          ),
          const SizedBox(width: _trailingControlSpacing),
        ],
        SubtitleControlFlyout(
          subtitles: _playingInfoCache?.currentSubtitleStreamList ?? const [],
          selectedSubtitleGuid: _selectedSubtitleGuid,
          iso6391Map: _iso6391Map,
          iso6392Map: _iso6392Map,
          subtitleSettings: subtitleSettings,
          canAdjustSubtitle: _canAdjustSubtitle,
          isPositionLocked: _isPositionLockedSubtitle,
          yOffset: _controlFlyoutOffset,
          isActiveControl:
              overlayState.activeFlyout == PlayerFlyoutType.subtitle,
          onHoverStateChanged: (hovered) => _handleFlyoutHoverStateChanged(
              PlayerFlyoutType.subtitle, hovered),
          onSubtitleSettingsChanged: (settings) =>
              ref.read(subtitleSettingsProvider.notifier).state = settings,
          onSubtitleSelected: _onSubtitleSelected,
          onOpenSubtitleSearch: _openSubtitleSearchDialog,
          onOpenAddNasSubtitle: _openAddNasSubtitleDialog,
          onOpenAddLocalSubtitle: _pickAndUploadLocalSubtitle,
        ),
        const SizedBox(width: _trailingControlSpacing),
        PlayerSettingsMenu(
          playingInfoCache: _playingInfoCache,
          iso6391Map: _iso6391Map,
          iso6392Map: _iso6392Map,
          currentPositionMillis: _currentPosition,
          totalDurationMillis: _duration,
          popupBottomOffset: _controlFlyoutOffset.toDouble(),
          smartSkipEnabled:
              ref.watch(smartSkipSettingsControllerProvider).enabled,
          isSmartAnalysisGloballyEnabled: settings.flyNarwhalServerEnabled,
          isSavingSkipConfig: _isSavingSkipConfig,
          onSmartSkipEnabledChanged: (enabled) {
            unawaited(_setSmartSkipEnabled(enabled));
          },
          isFlyNarwhalServerAvailable: settings.isFlyNarwhalServerAvailable,
          onFlyNarwhalConfigMissing: () {
            ref.read(toastManagerProvider.notifier).showToast(
              buildFlyNarwhalConfigWarning(
                missingUrl: settings.flyNarwhalServerBaseUrl.isEmpty,
                missingAuthCode: !settings.hasFlyNarwhalAuthCode,
              ),
              type: ToastType.warning,
              category: 'fly-narwhal-config',
            );
          },
          isAutoPlay: overlayState.isAutoPlayEnabled,
          onAutoPlayChanged: _onAutoPlayChanged,
          onHoverStateChanged: (hovered) => _overlayController.setHovered(
            PlayerHoverZone.settingsMenu,
            hovered,
          ),
          onAudioSelected: _onAudioSelected,
          onWindowAspectRatioChanged: (_) {},
          onSkipConfigChanged: (skipOpening, skipEnding) {
            unawaited(_saveSkipConfig(skipOpening, skipEnding));
          },
        ),
        const SizedBox(width: _trailingControlSpacing),
        VolumeControl(
          key: const ValueKey('player-volume-control'),
          volume: _volume,
          popupBottomOffset: _controlFlyoutOffset.toDouble(),
          onHoverStateChanged: (hovered) => _overlayController.setHovered(
            PlayerHoverZone.volumeControl,
            hovered,
          ),
          onVolumeChange: _setVolume,
        ),
        const SizedBox(width: _trailingControlSpacing),
        MouseRegion(
          onEnter: (_) =>
              _overlayController.setHovered(PlayerHoverZone.pipControl, true),
          onExit: (_) =>
              _overlayController.setHovered(PlayerHoverZone.pipControl, false),
          child: PlayerActionButton.lottie(
            key: const ValueKey('player-enter-pip'),
            lottieAssetPath: 'assets/lottie/to_pip.json',
            onPressed: () => unawaited(_enterPipMode()),
            tooltip: '画中画',
            size: 30,
            iconSize: 22,
          ),
        ),
        const SizedBox(width: _trailingControlSpacing),
        FullScreenControl(
          isFullScreen: _isFullscreen,
          onClick: _toggleFullscreen,
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    final leftInset = _isMacOS ? 72.0 : 0.0;
    // Reduce the top inset on macOS so the custom caption content lines up
    // more closely with the native traffic-light buttons.
    final topPadding = _isMacOS ? 6.0 : 12.0;
    final topBarContentHeight = _isMacOS ? 30.0 : 36.0;
    final topBarDragHeight = topPadding + topBarContentHeight;

    return SafeArea(
      child: SizedBox(
        height: topBarDragHeight,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DragToMoveArea(
                child: SizedBox.expand(),
              ),
            ),
            Positioned(
              top: topPadding,
              left: 16,
              right: 16,
              height: topBarContentHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            text: _buildTitleSpan(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (leftInset > 0) SizedBox(width: leftInset),
                        _buildBackButton(),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: WindowCaptionPinButton(
                      key: const ValueKey(
                        'player-window-caption-pin-button',
                      ),
                      brightness: Brightness.dark,
                      buttonSize: _isMacOS ? 30 : 34,
                      iconSize: _isMacOS ? 16 : 18,
                      borderRadius: BorderRadius.circular(_isMacOS ? 15 : 17),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return PlayerActionButton.icon(
      iconData: FluentIcons.back,
      onPressed: _handleBack,
      tooltip: '返回',
      size: _isMacOS ? 30 : 34,
      iconSize: _isMacOS ? 15 : 18,
      borderRadius: BorderRadius.circular(_isMacOS ? 15 : 17),
    );
  }

  Widget _buildPlaybackIndicator() {
    if (!_isPlaybackIndicatorVisible || _playbackIndicatorType == null) {
      return const SizedBox.shrink();
    }

    final animation = CurvedAnimation(
      parent: _playbackIndicatorExitController,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(animation),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 1.18).animate(animation),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.5),
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            _playbackIndicatorType == _PlaybackIndicatorType.pause
                ? 'assets/images/pause.svg'
                : 'assets/images/play.svg',
            width: 34,
            height: 34,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  TextSpan _buildTitleSpan() {
    final baseFontSize = _isMacOS ? 16.0 : 20.0;
    final subhead = _displaySubhead;
    if (subhead.isEmpty) {
      return TextSpan(
        text: _displayTitle,
        style: TextStyle(
          color: Colors.white,
          fontSize: baseFontSize,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return TextSpan(
      children: [
        TextSpan(
          text: _displayTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: baseFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: _isMacOS ? ' / ' : ' | ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.84),
            fontSize: baseFontSize,
            fontWeight: FontWeight.w300,
          ),
        ),
        TextSpan(
          text: subhead,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.76),
            fontSize: _isMacOS ? 16 : 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> _syncFullscreenState() async {
    final isFullscreen = await _fullscreenController.syncState();
    if (!mounted || _isFullscreen == isFullscreen) {
      return;
    }

    setState(() => _isFullscreen = isFullscreen);
  }

  Future<void> _restoreWindowModeBeforeLeave() async {
    if (!_isDesktopPlatform()) {
      return;
    }

    final isFullscreen = await _fullscreenController.exitForRouteLeave();
    if (!mounted || _isFullscreen == isFullscreen) {
      return;
    }

    setState(() => _isFullscreen = isFullscreen);
  }

  bool _isDesktopPlatform() {
    // Use Flutter target platform checks to avoid relying on dart:io in UI code.
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);
  }

  @override
  void onWindowEnterFullScreen() {
    if (!mounted) {
      return;
    }

    setState(() => _isFullscreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (!mounted) {
      return;
    }

    setState(() => _isFullscreen = false);
  }

  @override
  void onWindowMoved() => _schedulePipBoundsSave();

  @override
  void onWindowResized() => _schedulePipBoundsSave();

  bool get _canAdjustSubtitle {
    final subtitleStream = _playingInfoCache?.currentSubtitleStream;
    if (_isSupportedExternalSubtitle(subtitleStream) ||
        _isDirectLinkEmbeddedSubtitle(subtitleStream)) {
      return true;
    }
    return _useHlsSubtitleOverlay &&
        (subtitleStream != null || _hlsSubtitleTexts.value.isNotEmpty);
  }

  String get _displayTitle {
    final item = _playInfo?.item ?? _playingInfoCache?.item;
    if (item == null) return '';
    if (item.type == 'Episode' && item.tvTitle.isNotEmpty) {
      return item.tvTitle;
    }
    return item.title;
  }

  String get _displaySubhead {
    final item = _playInfo?.item ?? _playingInfoCache?.item;
    if (item == null || item.type != 'Episode') {
      return '';
    }
    return _sessionCoordinator.buildDisplaySubhead(
      item,
      episodeNumber:
          _currentEpisode?.episodeNumber ?? _playInfo?.item.episodeNumber ?? 0,
    );
  }

  String get _episodeFlyoutTitle {
    final currentEpisode = _currentEpisode;
    if (currentEpisode != null) {
      final tvTitle = currentEpisode.tvTitle.trim();
      final seasonTitle = currentEpisode.parentTitle.trim();
      if (tvTitle.isNotEmpty && seasonTitle.isNotEmpty) {
        return '$tvTitle・$seasonTitle';
      }
      if (seasonTitle.isNotEmpty) {
        return seasonTitle;
      }
    }

    final item = _playInfo?.item ?? _playingInfoCache?.item;
    if (item != null && item.type == 'Episode') {
      final tvTitle = item.tvTitle.trim();
      final seasonTitle = item.parentTitle.trim();
      if (tvTitle.isNotEmpty && seasonTitle.isNotEmpty) {
        return '$tvTitle・$seasonTitle';
      }
      if (seasonTitle.isNotEmpty) {
        return seasonTitle;
      }
    }

    return _displaySubhead;
  }

  void _openEpisode(EpisodeListResponse episode) {
    if (episode.guid == _currentItemGuid) {
      return;
    }
    unawaited(_switchPlaybackTarget(guid: episode.guid));
  }

  void _showFeatureComingSoon(String feature) {
    ref
        .read(toastManagerProvider.notifier)
        .showToast('$feature 暂未接入', type: ToastType.info);
  }
}
