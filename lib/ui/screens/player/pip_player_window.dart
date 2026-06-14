import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/utils/log/app_talker.dart';
import '../../../data/models/media_request_models.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../data/models/player_models.dart';
import '../../../providers/providers.dart';
import '../../player/hls_subtitle_repository.dart';
import '../../player/pip/pip_window_channel.dart';
import '../../player/pip/pip_window_payload.dart';
import '../../player/player_manager.dart';
import '../../player/player_service.dart';
import '../../player/player_session_coordinator.dart';
import '../../player/widgets/player_action_button.dart';
import '../../player/widgets/player_subtitle_overlay.dart';
import '../../player/widgets/video_player_progress_bar.dart';
import '../../player/widgets/volume_control.dart';

class PipPlayerWindowScreen extends ConsumerStatefulWidget {
  final PipWindowPayload payload;
  final String currentWindowId;

  const PipPlayerWindowScreen({
    super.key,
    required this.payload,
    required this.currentWindowId,
  });

  @override
  ConsumerState<PipPlayerWindowScreen> createState() =>
      _PipPlayerWindowScreenState();
}

class _PipPlayerWindowScreenState extends ConsumerState<PipPlayerWindowScreen>
    with WindowListener {
  static const Size _defaultWindowSize = Size(320, 180);
  static const Size _minimumWindowSize = Size(280, 158);
  static const Duration _hlsSubtitleInitTimeout = Duration(seconds: 5);

  Player? _player;
  VideoController? _videoController;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isHovered = false;
  bool _hasSentEnterAck = false;
  bool _isWindowConfigured = false;
  bool _isSavingWindowBounds = false;
  int _currentPosition = 0;
  int _duration = 0;
  double _volume = 1.0;
  double _speed = 1.0;
  PlayingInfoCache? _playingInfoCache;
  HlsSubtitleRepository? _hlsSubtitleRepository;
  VoidCallback? _hlsSubtitleTextsListener;
  final ValueNotifier<List<String>> _hlsSubtitleTexts =
      ValueNotifier<List<String>>(const []);
  bool _useHlsSubtitleOverlay = false;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
  Timer? _playRecordTimer;
  Timer? _saveBoundsTimer;
  int _playbackLoadToken = 0;
  int _hlsSessionToken = 0;

  PlayerSessionCoordinator get _sessionCoordinator =>
      ref.read(playerSessionCoordinatorProvider);

  @override
  void initState() {
    super.initState();
    _volume = widget.payload.volume;
    _speed = widget.payload.speed;
    AppTalker.info(
      'PiP',
      'PiP window bootstrap for ${widget.payload.guid} from ${widget.payload.mainWindowId}',
    );
    windowManager.addListener(this);
    unawaited(_configureWindow());
    unawaited(_initializePlayer());
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _playRecordTimer?.cancel();
    _saveBoundsTimer?.cancel();
    _disposeHlsSubtitleSession();
    _player?.dispose();
    _hlsSubtitleTexts.dispose();
    super.dispose();
  }

  @override
  void onWindowMove() => _scheduleSaveWindowBounds();

  @override
  void onWindowMoved() => _scheduleSaveWindowBounds();

  @override
  void onWindowResize() => _scheduleSaveWindowBounds();

  @override
  void onWindowResized() => _scheduleSaveWindowBounds();

  Future<void> _configureWindow() async {
    if (!_isDesktopPlatform()) {
      return;
    }

    final prefs = ref.read(playerSettingsManagerProvider);
    final savedBounds =
        widget.payload.bounds?.toRect() ?? prefs.getPipWindowBounds();
    final initialBounds = savedBounds ??
        Rect.fromLTWH(
          0,
          0,
          _defaultWindowSize.width,
          _defaultWindowSize.height,
        );

    // Apply PiP-specific window chrome and geometry before the first frame.
    final options = WindowOptions(
      title: widget.payload.title.isEmpty ? '飞鲸影视 - 画中画' : widget.payload.title,
      size: initialBounds.size,
      center: savedBounds == null,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      backgroundColor: Colors.black,
      alwaysOnTop: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setMinimumSize(_minimumWindowSize);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      if (savedBounds != null) {
        await windowManager.setBounds(savedBounds);
      }
      await windowManager.show();
      await windowManager.focus();
    });
    _isWindowConfigured = true;
    AppTalker.info('PiP', 'PiP window configured');
    await _trySendEnterAck();
  }

  Future<void> _initializePlayer() async {
    final player = Player();
    final controller = VideoController(player);
    _player = player;
    _videoController = controller;
    _setupPlayerPlaybackListener();
    _setupPlayerPositionListener();
    await _loadAndPlayMedia();
  }

  void _setupPlayerPositionListener() {
    _positionSubscription?.cancel();
    final player = _player;
    if (player == null) {
      return;
    }
    _positionSubscription = player.stream.position.listen((position) {
      _currentPosition = position.inMilliseconds;
      _hlsSubtitleRepository?.onPlaybackPosition(position.inMilliseconds);
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _setupPlayerPlaybackListener() {
    _playingSubscription?.cancel();
    final player = _player;
    if (player == null) {
      return;
    }
    _isPlaying = player.state.playing;
    _playingSubscription = player.stream.playing.listen((isPlaying) {
      _handlePlaybackStateChanged(isPlaying);
    });
  }

  Future<void> _loadAndPlayMedia() async {
    final loadToken = ++_playbackLoadToken;
    try {
      final result = await _sessionCoordinator.loadSession(
        PlayerRouteTarget(
          guid: widget.payload.guid,
          mediaGuid: widget.payload.mediaGuid,
          audioGuid: widget.payload.audioGuid,
          subtitleGuid: widget.payload.subtitleGuid,
        ),
      );
      if (!mounted || loadToken != _playbackLoadToken) {
        return;
      }

      _playingInfoCache = result.playingInfoCache;
      _prepareHlsSubtitleOverlayMode(
        subtitleStream: result.playingInfoCache.currentSubtitleStream,
        subtitlePlaylistUrl: result.preparedPlaySource.subtitlePlaylistUrl,
      );

      await _openMediaWithResume(
        playUri: result.preparedPlaySource.playUri,
        startPositionMs: widget.payload.startPositionMs > 0
            ? widget.payload.startPositionMs
            : result.effectiveStartPositionMs,
        currentSubtitleStream: result.playingInfoCache.currentSubtitleStream,
      );
      if (!mounted || loadToken != _playbackLoadToken) {
        return;
      }

      final dio = ref.read(dioClientProvider).dio;
      _startHlsSubtitleSessionAsync(
        dio: dio,
        subtitleStream: result.playingInfoCache.currentSubtitleStream,
        subtitlePlaylistUrl: result.preparedPlaySource.subtitlePlaylistUrl,
        startPositionMs: widget.payload.startPositionMs > 0
            ? widget.payload.startPositionMs
            : result.effectiveStartPositionMs,
        loadToken: loadToken,
      );

      await _player!.setVolume(_volume * 100);
      await _player!.setRate(_speed);

      final videoStream = result.playingInfoCache.currentVideoStream;
      if (videoStream != null && widget.payload.bounds == null) {
        await _applyDynamicWindowSize(videoStream);
      }

      if (!mounted || loadToken != _playbackLoadToken) {
        return;
      }
      setState(() {
        _isInitialized = true;
        _isLoading = false;
        _isPlaying = _player?.state.playing ?? false;
        _duration = videoStream != null && videoStream.duration > 0
            ? videoStream.duration * 1000
            : result.playInfo.item.duration * 1000;
      });
      _startPlayRecordTimer();
      await _trySendEnterAck();
    } catch (error, stackTrace) {
      AppTalker.error(
        'PiP',
        error: error,
        stackTrace: stackTrace,
        message: 'Failed to initialize PiP playback',
      );
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _trySendEnterAck() async {
    // Delay the handoff ack until both the window and playback are ready.
    if (_hasSentEnterAck || !_isWindowConfigured || !_isInitialized) {
      return;
    }
    _hasSentEnterAck = true;
    AppTalker.info('PiP', 'PiP window sending enter ack');
    await PipWindowChannel.sendEnterAck();
  }

  Future<void> _applyDynamicWindowSize(VideoStream videoStream) async {
    const fallbackWidth = 16.0;
    const fallbackHeight = 9.0;
    final width =
        videoStream.width > 0 ? videoStream.width.toDouble() : fallbackWidth;
    final height =
        videoStream.height > 0 ? videoStream.height.toDouble() : fallbackHeight;
    final ratio = width / height;
    const targetWidth = 360.0;
    final targetHeight = (targetWidth / ratio).clamp(
      _minimumWindowSize.height,
      360.0,
    );
    await windowManager.setSize(Size(targetWidth, targetHeight));
  }

  Future<void> _openMediaWithResume({
    required String playUri,
    required int startPositionMs,
    required SubtitleStream? currentSubtitleStream,
  }) async {
    final player = _player;
    if (player == null) {
      return;
    }

    final headers = _sessionCoordinator.buildPlayerHeaders();
    await player.open(
      Media(
        playUri,
        httpHeaders: headers.isEmpty ? null : headers,
      ),
    );
    await _applyCurrentSubtitleTrack(currentSubtitleStream);
    await _applyResumePosition(startPositionMs);
  }

  Future<void> _applyResumePosition(int startPositionMs) async {
    final player = _player;
    if (player == null || startPositionMs <= 0) {
      return;
    }

    // Retry a few times because media_kit may ignore the first early seek.
    final target = Duration(milliseconds: startPositionMs);
    const attemptDelays = <Duration>[
      Duration(milliseconds: 300),
      Duration(milliseconds: 650),
      Duration(milliseconds: 1000),
    ];
    for (final delay in attemptDelays) {
      await Future<void>.delayed(delay);
      await player.seek(target);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (player.state.position.inMilliseconds >= startPositionMs - 1500) {
        break;
      }
    }
  }

  bool _isSupportedExternalSubtitle(SubtitleStream? subtitleStream) {
    if (subtitleStream == null || subtitleStream.isExternal != 1) {
      return false;
    }
    const supportedFormats = {'srt', 'ass', 'ssa', 'vtt'};
    return supportedFormats.contains(subtitleStream.format.toLowerCase());
  }

  Future<void> _applyCurrentSubtitleTrack(
    SubtitleStream? subtitleStream,
  ) async {
    final player = _player;
    if (player == null) {
      return;
    }

    if (subtitleStream == null) {
      await player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }

    if (_useHlsSubtitleOverlay && subtitleStream.isExternal != 1) {
      await player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }

    if (!_isSupportedExternalSubtitle(subtitleStream)) {
      return;
    }

    try {
      final content = await ref
          .read(playerServiceProvider)
          .downloadExternalSubtitle(subtitleStream.guid);
      if (!mounted || player != _player) {
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
    } catch (error) {
      AppTalker.warning('PiP', 'apply external subtitle failed: $error');
      if (player == _player) {
        await player.setSubtitleTrack(SubtitleTrack.no());
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
    _useHlsSubtitleOverlay = subtitleStream != null &&
        subtitleStream.isExternal != 1 &&
        subtitlePlaylistUrl != null &&
        subtitlePlaylistUrl.isNotEmpty;
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
      // Keep subtitle startup best-effort so PiP playback stays responsive.
      await repository
          .initialize(startPositionMs: startPositionMs)
          .timeout(_hlsSubtitleInitTimeout);
      final isStaleSession = !mounted ||
          _hlsSessionToken != sessionToken ||
          (loadToken != null && loadToken != _playbackLoadToken);
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
    } catch (error) {
      repository.dispose();
      AppTalker.warning('PiP', 'hls subtitle overlay init failed: $error');
      if (_hlsSessionToken == sessionToken) {
        _hlsSubtitleTexts.value = const [];
        _useHlsSubtitleOverlay = false;
      }
    }
  }

  void _startPlayRecordTimer() {
    _playRecordTimer?.cancel();
    _playRecordTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _syncPlayRecordAtCurrentPosition();
    });
  }

  PlayRecordRequest? _buildPlayRecordRequest(int positionMs) {
    final cache = _playingInfoCache;
    final fileStream = cache?.currentFileStream;
    final videoStream = cache?.currentVideoStream;
    if (cache == null || fileStream == null || videoStream == null) {
      return null;
    }

    final quality = cache.currentQuality;
    return PlayRecordRequest(
      itemGuid: cache.itemGuid ?? widget.payload.guid,
      mediaGuid: fileStream.guid,
      videoGuid: videoStream.guid,
      audioGuid: cache.currentAudioStream?.guid ?? '',
      subtitleGuid: cache.currentSubtitleStream?.guid,
      resolution: quality?.resolution ?? videoStream.resolutionType,
      bitrate: quality?.bitrate ?? videoStream.bps,
      ts: positionMs ~/ 1000,
      duration: videoStream.duration,
      playLink: cache.playLink,
    );
  }

  Future<void> _syncPlayRecordAtCurrentPosition({int? positionMs}) async {
    final player = _player;
    if (player == null || !_isInitialized) {
      return;
    }
    final request = _buildPlayRecordRequest(
      positionMs ?? player.state.position.inMilliseconds,
    );
    if (request == null) {
      return;
    }
    try {
      await ref.read(playerServiceProvider).updatePlayRecord(request);
    } catch (_) {
      // Ignore PiP record failures because playback should stay responsive.
    }
  }

  void _handlePlaybackStateChanged(bool isPlaying) {
    final previous = _isPlaying;
    _isPlaying = isPlaying;
    if (mounted) {
      setState(() {});
    }
    if (previous != isPlaying) {
      unawaited(_syncPlayRecordAtCurrentPosition());
    }
  }

  void _togglePlayPause() {
    final player = _player;
    if (player == null) {
      return;
    }
    if (player.state.playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  Future<void> _seekRelative(int milliseconds) async {
    final player = _player;
    if (player == null || _duration <= 0) {
      return;
    }
    final target = (player.state.position.inMilliseconds + milliseconds)
        .clamp(0, _duration);
    await player.seek(Duration(milliseconds: target));
    await _syncPlayRecordAtCurrentPosition(positionMs: target);
  }

  Future<void> _seekTo(double progress) async {
    final player = _player;
    if (player == null || _duration <= 0) {
      return;
    }
    final target = (progress * _duration).round().clamp(0, _duration);
    await player.seek(Duration(milliseconds: target));
    await _syncPlayRecordAtCurrentPosition(positionMs: target);
  }

  Future<void> _setVolume(double volume) async {
    final player = _player;
    if (player == null) {
      return;
    }
    setState(() => _volume = volume);
    await player.setVolume(volume * 100);
    await ref.read(playerSettingsManagerProvider).setVolume(volume);
  }

  Future<void> _closeWindow() async {
    await _syncPlayRecordAtCurrentPosition();
    await PipWindowChannel.sendClosePip();
    if (!mounted) {
      return;
    }
    await windowManager.close();
  }

  Future<void> _exitPip() async {
    final positionMs = _player?.state.position.inMilliseconds ?? 0;
    await _syncPlayRecordAtCurrentPosition(positionMs: positionMs);
    final restorePayload = widget.payload.copyWith(
      startPositionMs: positionMs,
      volume: _volume,
      speed: _speed,
      bounds: await _readCurrentWindowBounds(),
    );
    await PipWindowChannel.sendRestoreMainPlayer(restorePayload);
    if (!mounted) {
      return;
    }
    await windowManager.close();
  }

  Future<PipWindowBounds?> _readCurrentWindowBounds() async {
    try {
      final bounds = await windowManager.getBounds();
      return PipWindowBounds.fromRect(bounds);
    } catch (_) {
      return null;
    }
  }

  void _scheduleSaveWindowBounds() {
    _saveBoundsTimer?.cancel();
    _saveBoundsTimer = Timer(const Duration(milliseconds: 250), () async {
      if (_isSavingWindowBounds || !mounted) {
        return;
      }
      _isSavingWindowBounds = true;
      try {
        final bounds = await windowManager.getBounds();
        await ref
            .read(playerSettingsManagerProvider)
            .setPipWindowBounds(bounds);
        await PipWindowChannel.sendSyncBounds(PipWindowBounds.fromRect(bounds));
      } catch (_) {
        // Ignore transient move/resize persistence failures.
      } finally {
        _isSavingWindowBounds = false;
      }
    });
  }

  bool _isDesktopPlatform() {
    return !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  }

  @override
  Widget build(BuildContext context) {
    final subtitleSettings = ref.watch(subtitleSettingsProvider);
    return NavigationView(
      content: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Stack(
          children: [
            DragToMoveArea(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlayPause,
                child: Container(
                  color: Colors.black,
                  child: _isInitialized && _videoController != null
                      ? Video(
                          controller: _videoController!,
                          controls: NoVideoControls,
                        )
                      : const Center(child: ProgressRing()),
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
            if (_isLoading) const Center(child: ProgressRing()),
            if (_isHovered) ...[
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
                  onPressed: () => unawaited(_closeWindow()),
                  size: 28,
                  iconSize: 14,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: PlayerActionButton.svg(
                    key: const ValueKey('pip-seek-backward'),
                    svgAssetPath: 'assets/images/back10s.svg',
                    tooltip: '快退 10 秒',
                    onPressed: () => unawaited(_seekRelative(-10000)),
                    size: 38,
                    iconSize: 24,
                    borderRadius: BorderRadius.circular(19),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: PlayerActionButton.svg(
                    key: const ValueKey('pip-seek-forward'),
                    svgAssetPath: 'assets/images/forward10s.svg',
                    tooltip: '快进 10 秒',
                    onPressed: () => unawaited(_seekRelative(10000)),
                    size: 38,
                    iconSize: 24,
                    borderRadius: BorderRadius.circular(19),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 44,
                child: VideoPlayerProgressBar(
                  currentPosition: _currentPosition,
                  totalDuration: _duration,
                  onSeek: (progress) => unawaited(_seekTo(progress)),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 6,
                child: VolumeControl(
                  volume: _volume,
                  popupBottomOffset: 36,
                  onVolumeChange: (value) => unawaited(_setVolume(value)),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: true,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${formatDurationToDateTime(_currentPosition)} / ${formatDurationToDateTime(_duration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 8,
                child: PlayerActionButton.lottie(
                  key: const ValueKey('pip-exit'),
                  lottieAssetPath: 'assets/lottie/quit_pip.json',
                  tooltip: '退出画中画',
                  onPressed: () => unawaited(_exitPip()),
                  size: 30,
                  iconSize: 22,
                ),
              ),
            ],
            if (!_isPlaying && !_isLoading)
              Positioned.fill(
                child: Center(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.48),
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        'assets/images/play.svg',
                        width: 28,
                        height: 28,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
