import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import '../../../data/models/player_models.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../providers/providers.dart';
import '../../player/mp4_parser.dart';
import '../../player/player_service.dart';
import '../../player/widgets/video_player_progress_bar.dart';
import '../../player/widgets/speed_control_flyout.dart';
import '../../player/widgets/quality_control_flyout.dart';
import '../../player/widgets/volume_control.dart';
import '../../player/widgets/fullscreen_control.dart';
import '../../player/widgets/player_settings_menu.dart';
import '../../widgets/toast.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String guid;
  final String? mediaGuid;
  final String? audioGuid;
  final String? subtitleGuid;

  const PlayerScreen({
    super.key,
    required this.guid,
    this.mediaGuid,
    this.audioGuid,
    this.subtitleGuid,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final ToastManager _toastManager;
  Player? _player;
  VideoController? _videoController;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isUiVisible = true;
  bool _isFullscreen = false;
  bool _isSeeking = false;
  int _currentPosition = 0;
  int _duration = 0;
  double _volume = 1.0;
  double _speed = 1.0;
  List<QualityResponse> _qualities = [];
  QualityResponse? _currentQuality;
  String _currentResolution = '';
  int? _currentBitrate;
  PlayingInfoCache? _playingInfoCache;
  PlayInfoResponse? _playInfo;
  StreamResponse? _streamInfo;
  Timer? _hideUiTimer;
  Timer? _playRecordTimer;
  int _lastRecordedPosition = 0;
  int _pendingInitialResumeMs = 0;
  bool _initialResumeApplied = false;

  // Hover states
  bool _isProgressBarHovered = false;
  bool _isSpeedControlHovered = false;
  bool _isVolumeControlHovered = false;
  bool _isQualityControlHovered = false;
  bool _isSettingsMenuHovered = false;

  @override
  void initState() {
    super.initState();
    _toastManager = ToastManager();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _player = Player();
    _videoController = VideoController(_player!);

    await _loadAndPlayMedia();
  }

  void _resetInitialResumeState(int positionMs) {
    _pendingInitialResumeMs = positionMs;
    _initialResumeApplied = positionMs <= 0;
  }

  Future<void> _openMediaWithResume({
    required String playUri,
    required int startPositionMs,
    bool isInitialPlayback = false,
  }) async {
    final player = _player;
    if (player == null) return;

    final headers = _buildPlayerHeaders();
    await player.open(
      Media(
        playUri,
        httpHeaders: headers.isEmpty ? null : headers,
      ),
    );

    if (isInitialPlayback) {
      _resetInitialResumeState(startPositionMs);
    }

    await _applyResumePosition(startPositionMs,
        isInitialPlayback: isInitialPlayback);
  }

  Future<void> _applyResumePosition(
    int startPositionMs, {
    bool isInitialPlayback = false,
  }) async {
    final player = _player;
    if (player == null || startPositionMs <= 0) {
      if (isInitialPlayback) {
        _pendingInitialResumeMs = 0;
        _initialResumeApplied = true;
      }
      return;
    }

    const attemptDelays = <Duration>[
      Duration(milliseconds: 300),
      Duration(milliseconds: 600),
      Duration(milliseconds: 900),
    ];
    final target = Duration(milliseconds: startPositionMs);

    for (final delay in attemptDelays) {
      await Future<void>.delayed(delay);
      await player.seek(target);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final currentPosition = player.state.position.inMilliseconds;
      final applied = currentPosition >= startPositionMs - 1500;
      if (applied) {
        if (isInitialPlayback) {
          _pendingInitialResumeMs = 0;
          _initialResumeApplied = true;
        }
        return;
      }
    }

    if (isInitialPlayback) {
      _pendingInitialResumeMs = startPositionMs;
      _initialResumeApplied = false;
    }
  }

  Future<void> _ensureInitialResumeApplied() async {
    if (_initialResumeApplied || _pendingInitialResumeMs <= 0) {
      return;
    }
    await _applyResumePosition(
      _pendingInitialResumeMs,
      isInitialPlayback: true,
    );
  }

  Map<String, String> _buildPlayerHeaders() {
    final prefs = ref.read(preferencesManagerProvider);
    final headers = <String, String>{};
    final cookie = prefs.getCookie();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    final token = prefs.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = token;
    }
    return headers;
  }

  String _absolutePlayUrl(String baseUrl, String playLink) {
    if (playLink.startsWith('http://') || playLink.startsWith('https://')) {
      return playLink;
    }
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final path = playLink.startsWith('/') ? playLink : '/$playLink';
    return '$base$path';
  }

  PlayPlayRequest _createPlayRequest({
    required VideoStream videoStream,
    required FileInfo fileStream,
    required String audioGuid,
    required String? subtitleGuid,
  }) {
    return PlayPlayRequest(
      mediaGuid: fileStream.guid,
      videoGuid: videoStream.guid,
      videoEncoder: videoStream.codecName,
      resolution: videoStream.resolutionType,
      bitrate: videoStream.bps,
      startTimestamp: 0,
      audioEncoder: 'aac',
      audioGuid: audioGuid,
      subtitleGuid: subtitleGuid ?? '',
      channels: 2,
      forcedSdr: 0,
    );
  }

  Future<
      ({
        String playUri,
        String? playLinkRaw,
        int effectiveStartMs,
        bool isDirectLink,
      })> _resolvePlayLink({
    required PlayInfoResponse playInfo,
    required VideoStream videoStream,
    required FileInfo fileStream,
    required String audioGuid,
    required String? subtitleGuid,
    required List<QualityResponse> qualities,
    required int startPositionMs,
    required String baseUrl,
    required PlayerService playerService,
    required Dio dio,
  }) async {
    final originalQuality = qualities.isNotEmpty ? qualities.first : null;
    final isOriginalQuality = _currentQuality != null &&
        originalQuality != null &&
        _currentQuality!.resolution == originalQuality.resolution &&
        _currentQuality!.bitrate == originalQuality.bitrate;

    final useDirectLink = videoStream.wrapper == 'MP4' && isOriginalQuality;

    if (useDirectLink) {
      final r = await _getDirectPlayLink(
        mediaGuid: videoStream.mediaGuid,
        startPositionMs: startPositionMs,
        baseUrl: baseUrl,
        dio: dio,
      );
      return (
        playUri: r.url,
        playLinkRaw: null,
        effectiveStartMs: r.effectiveStartMs,
        isDirectLink: true,
      );
    }

    try {
      final request = _createPlayRequest(
        videoStream: videoStream,
        fileStream: fileStream,
        audioGuid: audioGuid,
        subtitleGuid: subtitleGuid,
      );
      final resp = await playerService.playVideo(request);
      final raw = resp.playLink;
      final uri = _absolutePlayUrl(baseUrl, raw);
      return (
        playUri: uri,
        playLinkRaw: raw,
        effectiveStartMs: startPositionMs,
        isDirectLink: false,
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('8192')) {
        final r = await _getDirectPlayLink(
          mediaGuid: playInfo.mediaGuid,
          startPositionMs: startPositionMs,
          baseUrl: baseUrl,
          dio: dio,
        );
        return (
          playUri: r.url,
          playLinkRaw: null,
          effectiveStartMs: r.effectiveStartMs,
          isDirectLink: false,
        );
      }
      rethrow;
    }
  }

  Future<({String url, int effectiveStartMs})> _getDirectPlayLink({
    required String mediaGuid,
    required int startPositionMs,
    required String baseUrl,
    required Dio dio,
  }) async {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final fullUrl = '$base/v/api/v1/media/range/$mediaGuid';
    final ts = startPositionMs / 1000.0;
    try {
      final parser = Mp4Parser(dio);
      final offset = await parser.getOffset(fullUrl, ts);
      if (offset > 0) {
        final uri = '$fullUrl?range=bytes=$offset-';
        return (url: uri, effectiveStartMs: 0);
      }
      return (url: fullUrl, effectiveStartMs: startPositionMs);
    } catch (e) {
      debugPrint('[Player] getDirectPlayLink fallback: $e');
      return (url: fullUrl, effectiveStartMs: startPositionMs);
    }
  }

  Future<void> _loadAndPlayMedia() async {
    try {
      setState(() => _isLoading = true);

      final playerService = ref.read(playerServiceProvider);
      final prefs = ref.read(preferencesManagerProvider);
      final dio = ref.read(dioClientProvider).dio;
      final baseUrl = prefs.getBaseUrl() ?? '';

      final playInfo = await playerService.getPlayInfo(
        widget.guid,
        mediaGuid: widget.mediaGuid,
      );
      _playInfo = playInfo;
      debugPrint(
        '[Player] playInfo: guid=${playInfo.guid}, mediaGuid=${playInfo.mediaGuid}, videoGuid=${playInfo.videoGuid}, type=${playInfo.item.type}',
      );

      final targetMediaGuid = playInfo.mediaGuid;
      debugPrint('[Player] targetMediaGuid: $targetMediaGuid');

      final streamInfo = await playerService.getStreamInfo(
        targetMediaGuid,
        ip: playerService.getIpHash(prefs.getToken() ?? ''),
      );
      _streamInfo = streamInfo;
      debugPrint(
        '[Player] streamInfo: videoStream=${streamInfo.videoStream?.mediaGuid}, audioStreams=${streamInfo.audioStreams?.length ?? 0}',
      );

      final currentVideoStream = streamInfo.videoStream;
      final fileStream = streamInfo.fileStream;
      if (currentVideoStream == null || fileStream == null) {
        throw Exception('Missing video_stream or file_stream');
      }

      final audioStreams = streamInfo.audioStreams ?? [];
      final subtitleStreams = streamInfo.subtitleStreams ?? [];

      AudioStream? currentAudioStream;
      SubtitleStream? currentSubtitleStream;

      if (widget.audioGuid != null) {
        currentAudioStream =
            audioStreams.where((s) => s.guid == widget.audioGuid).firstOrNull;
      } else {
        currentAudioStream =
            audioStreams.where((s) => s.isDefault == 1).firstOrNull ??
                audioStreams.firstOrNull;
      }
      if (widget.subtitleGuid != null) {
        currentSubtitleStream = subtitleStreams
            .where((s) => s.guid == widget.subtitleGuid)
            .firstOrNull;
      } else {
        currentSubtitleStream =
            subtitleStreams.where((s) => s.isDefault == 1).firstOrNull;
      }

      final audioGuid =
          widget.audioGuid ?? currentAudioStream?.guid ?? playInfo.audioGuid;
      final subtitleGuid = widget.subtitleGuid ?? currentSubtitleStream?.guid;

      final qualities = streamInfo.qualities ?? [];
      _qualities = qualities;
      _currentQuality = qualities.isNotEmpty ? qualities.first : null;

      final historyMs = playInfo.ts * 1000;
      _resetInitialResumeState(historyMs);
      final resolved = await _resolvePlayLink(
        playInfo: playInfo,
        videoStream: currentVideoStream,
        fileStream: fileStream,
        audioGuid: audioGuid,
        subtitleGuid: subtitleGuid,
        qualities: qualities,
        startPositionMs: historyMs,
        baseUrl: baseUrl,
        playerService: playerService,
        dio: dio,
      );

      if (!resolved.isDirectLink && resolved.playLinkRaw != null) {
        try {
          _qualities = await playerService.getQualities(resolved.playLinkRaw!);
          if (_qualities.isNotEmpty) {
            _currentQuality = _qualities.first;
          }
        } catch (_) {
          // Ignore quality list errors
        }
      }

      _playingInfoCache = PlayingInfoCache(
        itemGuid: widget.guid,
        parentGuid: playInfo.parentGuid,
        item: playInfo.item,
        currentVideoStream: currentVideoStream,
        currentAudioStream: currentAudioStream,
        currentSubtitleStream: currentSubtitleStream,
        currentAudioStreamList: audioStreams,
        currentSubtitleStreamList: subtitleStreams,
        playLink: resolved.playLinkRaw ?? resolved.playUri,
        isUseDirectLink: resolved.isDirectLink,
        playConfig: playInfo.playConfig,
        streamInfo: streamInfo,
        isEpisode: playInfo.item.type == 'Episode',
      );

      await _openMediaWithResume(
        playUri: resolved.playUri,
        startPositionMs: resolved.effectiveStartMs,
        isInitialPlayback: true,
      );

      _volume = ref.read(playerSettingsManagerProvider).getVolume();
      await _player!.setVolume(_volume * 100);

      _speed = ref.read(playerSettingsManagerProvider).getSpeed();
      await _player!.setRate(_speed);

      setState(() {
        _isLoading = false;
        _isInitialized = true;
        _duration = currentVideoStream.duration > 0
            ? currentVideoStream.duration * 1000
            : playInfo.item.duration * 1000;
        _currentResolution = _currentQuality?.resolution ?? '';
        _currentBitrate = _currentQuality?.bitrate;
      });

      await _ensureInitialResumeApplied();
      _startPlayRecordTimer();
    } catch (e) {
      debugPrint('[Player] Error loading media: $e');
      _toastManager.showToast(
        '加载失败: $e',
        type: ToastType.failed,
      );
      setState(() => _isLoading = false);
    }
  }

  void _startPlayRecordTimer() {
    _playRecordTimer?.cancel();
    _playRecordTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isInitialized || _player == null) return;

      final position = _player!.state.position.inMilliseconds;
      if (position != _lastRecordedPosition && position > 0) {
        _lastRecordedPosition = position;
        try {
          final playerService = ref.read(playerServiceProvider);
          await playerService.updatePlayRecord(
            guid: widget.guid,
            ts: position ~/ 1000,
            duration: _duration > 0 ? _duration ~/ 1000 : null,
          );
        } catch (_) {
          // Ignore record errors
        }
      }
    });
  }

  void _showUi() {
    setState(() => _isUiVisible = true);
    _hideUiTimer?.cancel();
    _hideUiTimer = Timer(const Duration(seconds: 3), () {
      if (!_isProgressBarHovered &&
          !_isSpeedControlHovered &&
          !_isVolumeControlHovered &&
          !_isQualityControlHovered &&
          !_isSettingsMenuHovered &&
          mounted) {
        setState(() => _isUiVisible = false);
      }
    });
  }

  void _togglePlayPause() {
    if (_player == null) return;
    if (_player!.state.playing) {
      _player!.pause();
    } else {
      _player!.play();
    }
  }

  void _seekRelative(int milliseconds) {
    if (_player == null) return;
    final current = _player!.state.position.inMilliseconds;
    final target = (current + milliseconds).clamp(0, _duration);
    _player!.seek(Duration(milliseconds: target));
  }

  void _seekTo(double progress) {
    if (_player == null) return;
    final target = (progress * _duration).toInt();
    _player!.seek(Duration(milliseconds: target));
  }

  void _setVolume(double volume) {
    if (_player == null) return;
    _volume = volume;
    _player!.setVolume(volume * 100);
    ref.read(playerSettingsManagerProvider).setVolume(volume);
  }

  void _setSpeed(double speed) {
    if (_player == null) return;
    _speed = speed;
    _player!.setRate(speed);
    ref.read(playerSettingsManagerProvider).setSpeed(speed);
  }

  Future<void> _toggleFullscreen() async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final isFullscreen = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFullscreen);
    } else {
      // Windows/Linux pseudo fullscreen
      if (_isFullscreen) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    }
    setState(() => _isFullscreen = !_isFullscreen);
  }

  Future<void> _onQualitySelected(QualityResponse quality) async {
    final playInfo = _playInfo;
    final streamInfo = _streamInfo;
    final videoStream = streamInfo?.videoStream;
    final fileStream = streamInfo?.fileStream;
    if (playInfo == null ||
        streamInfo == null ||
        videoStream == null ||
        fileStream == null ||
        _player == null) {
      return;
    }

    try {
      setState(() => _isLoading = true);

      final prefs = ref.read(preferencesManagerProvider);
      final baseUrl = prefs.getBaseUrl() ?? '';
      final playerService = ref.read(playerServiceProvider);
      final dio = ref.read(dioClientProvider).dio;

      final audioStreams = streamInfo.audioStreams ?? [];
      final currentAudioStream = audioStreams
              .where((s) => s.guid == (widget.audioGuid ?? playInfo.audioGuid))
              .firstOrNull ??
          audioStreams.where((s) => s.isDefault == 1).firstOrNull ??
          audioStreams.firstOrNull;
      final audioGuid =
          widget.audioGuid ?? currentAudioStream?.guid ?? playInfo.audioGuid;

      final subtitleStreams = streamInfo.subtitleStreams ?? [];
      final currentSubtitleStream = widget.subtitleGuid != null
          ? subtitleStreams
              .where((s) => s.guid == widget.subtitleGuid)
              .firstOrNull
          : subtitleStreams.where((s) => s.isDefault == 1).firstOrNull;
      final subtitleGuid = widget.subtitleGuid ?? currentSubtitleStream?.guid;

      final currentPosition = _player!.state.position.inMilliseconds;
      _currentQuality = quality;

      final qualities = streamInfo.qualities ?? [];
      final resolved = await _resolvePlayLink(
        playInfo: playInfo,
        videoStream: videoStream,
        fileStream: fileStream,
        audioGuid: audioGuid,
        subtitleGuid: subtitleGuid,
        qualities: qualities,
        startPositionMs: currentPosition,
        baseUrl: baseUrl,
        playerService: playerService,
        dio: dio,
      );

      if (!resolved.isDirectLink && resolved.playLinkRaw != null) {
        try {
          _qualities = await playerService.getQualities(resolved.playLinkRaw!);
        } catch (_) {
          // Ignore quality list errors
        }
      }

      _playingInfoCache = _playingInfoCache?.copyWith(
        playLink: resolved.playLinkRaw ?? resolved.playUri,
        isUseDirectLink: resolved.isDirectLink,
      );

      await _openMediaWithResume(
        playUri: resolved.playUri,
        startPositionMs: resolved.effectiveStartMs,
      );

      setState(() {
        _isLoading = false;
        _currentResolution = quality.resolution;
        _currentBitrate = quality.bitrate;
      });
    } catch (e) {
      _toastManager.showToast('切换画质失败: $e', type: ToastType.failed);
      setState(() => _isLoading = false);
    }
  }

  void _handleBack() {
    _playRecordTimer?.cancel();
    _hideUiTimer?.cancel();
    // Check if there's a route to pop, otherwise navigate to home
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _playRecordTimer?.cancel();
    _hideUiTimer?.cancel();
    _player?.dispose();
    _toastManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        MouseRegion(
          onHover: (_) => _showUi(),
          child: GestureDetector(
            onTap: () => _showUi(),
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

        // Loading overlay
        if (_isLoading) const Center(child: ProgressRing()),

        // UI Overlay
        if (_isInitialized)
          AnimatedOpacity(
            opacity: _isUiVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Stack(
              children: [
                // Top gradient
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 80,
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

                // Top bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: _handleBack,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.3),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  FluentIcons.back,
                                  size: 24,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _playingInfoCache?.item?.title ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_playingInfoCache?.subhead.isNotEmpty ==
                                    true)
                                  Text(
                                    _playingInfoCache!.subhead,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Center play button
                Center(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _player?.state.playing == true
                            ? FluentIcons.pause
                            : FluentIcons.play,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Bottom gradient
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 120,
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

                // Bottom controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress bar
                          _buildProgressBar(),
                          const SizedBox(height: 12),
                          // Control buttons
                          _buildControlButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Toast overlay
        Positioned.fill(
          child: ToastHost(toastManager: _toastManager),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    // Update current position from player stream
    return StreamBuilder<Duration>(
      stream: _player?.stream.position,
      builder: (context, snapshot) {
        _currentPosition = snapshot.data?.inMilliseconds ?? _currentPosition;
        return MouseRegion(
          onEnter: (_) => setState(() => _isProgressBarHovered = true),
          onExit: (_) => setState(() => _isProgressBarHovered = false),
          child: Row(
            children: [
              Text(
                formatDurationToDateTime(_currentPosition),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VideoPlayerProgressBar(
                  currentPosition: _currentPosition,
                  totalDuration: _duration,
                  onSeek: _seekTo,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatDurationToDateTime(_duration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        // Play/Pause
        GestureDetector(
          onTap: _togglePlayPause,
          child: Icon(
            _player?.state.playing == true
                ? FluentIcons.pause
                : FluentIcons.play,
            size: 32,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        // Skip back 10s
        GestureDetector(
          onTap: () => _seekRelative(-10000),
          child: const Icon(
            FluentIcons.back,
            size: 24,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        // Skip forward 10s
        GestureDetector(
          onTap: () => _seekRelative(10000),
          child: const Icon(
            FluentIcons.forward,
            size: 24,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 24),
        // Volume
        MouseRegion(
          onEnter: (_) => setState(() => _isVolumeControlHovered = true),
          onExit: (_) => setState(() => _isVolumeControlHovered = false),
          child: VolumeControl(
            volume: _volume,
            onVolumeChange: _setVolume,
          ),
        ),
        const Spacer(),
        // Speed
        MouseRegion(
          onEnter: (_) => setState(() => _isSpeedControlHovered = true),
          onExit: (_) => setState(() => _isSpeedControlHovered = false),
          child: SpeedControlFlyout(
            defaultSpeed: _speed,
            onSpeedSelected: (speed) => _setSpeed(speed.value),
          ),
        ),
        const SizedBox(width: 16),
        // Quality
        if (_qualities.isNotEmpty)
          MouseRegion(
            onEnter: (_) => setState(() => _isQualityControlHovered = true),
            onExit: (_) => setState(() => _isQualityControlHovered = false),
            child: QualityControlFlyout(
              qualities: _qualities,
              currentResolution: _currentResolution,
              currentBitrate: _currentBitrate,
              onQualitySelected: _onQualitySelected,
            ),
          ),
        const SizedBox(width: 16),
        // Settings
        MouseRegion(
          onEnter: (_) => setState(() => _isSettingsMenuHovered = true),
          onExit: (_) => setState(() => _isSettingsMenuHovered = false),
          child: PlayerSettingsMenu(
            playingInfoCache: _playingInfoCache,
            currentPositionMillis: _currentPosition,
            totalDurationMillis: _duration,
            onAudioSelected: (audio) {
              // Handle audio selection
            },
            onWindowAspectRatioChanged: (ratio) {
              // Handle window aspect ratio
            },
            onSkipConfigChanged: (opening, ending) {
              // Handle skip config
            },
          ),
        ),
        const SizedBox(width: 16),
        // Fullscreen
        FullScreenControl(
          isFullScreen: _isFullscreen,
          onClick: _toggleFullscreen,
        ),
      ],
    );
  }
}
