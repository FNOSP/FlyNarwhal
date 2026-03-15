import 'dart:async';
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
import '../../player/player_manager.dart';
import '../../player/player_service.dart';
import '../../player/player_view_model.dart';
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
  String _currentResolution = '';
  int? _currentBitrate;
  PlayingInfoCache? _playingInfoCache;
  Timer? _hideUiTimer;
  Timer? _playRecordTimer;
  int _lastRecordedPosition = 0;

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

  Future<void> _loadAndPlayMedia() async {
    try {
      setState(() => _isLoading = true);

      final playerService = ref.read(playerServiceProvider);
      final prefs = ref.read(preferencesManagerProvider);
      final baseUrl = prefs.getBaseUrl() ?? '';

      // Get play info
      final playInfo = await playerService.getPlayInfo(widget.guid);
      debugPrint('[Player] playInfo: guid=${playInfo.guid}, mediaGuid=${playInfo.mediaGuid}, videoGuid=${playInfo.videoGuid}, type=${playInfo.item.type}');

      // Use playInfo.mediaGuid directly (same as Kotlin implementation)
      final targetMediaGuid = playInfo.mediaGuid;
      debugPrint('[Player] targetMediaGuid: $targetMediaGuid');

      // Get stream info (Kotlin always calls stream API with playInfo.mediaGuid)
      final streamInfo = await playerService.getStreamInfo(
        targetMediaGuid,
        ip: playerService.getIpHash(prefs.getToken() ?? ''),
      );
      debugPrint('[Player] streamInfo: videoStream=${streamInfo.videoStream?.mediaGuid}, audioStreams=${streamInfo.audioStreams?.length ?? 0}');

      // Build play URL - use direct link
      String playUrl;
      bool isUseDirectLink = true;

      playUrl = playerService.buildDirectPlayUrl(
        baseUrl: baseUrl,
        mediaGuid: targetMediaGuid,
        audioGuid: widget.audioGuid ?? playInfo.audioGuid,
        subtitleGuid: widget.subtitleGuid ?? playInfo.subtitleGuid,
      );
      debugPrint('[Player] Direct play URL: $playUrl');

      // Find current video stream
      VideoStream? currentVideoStream;
      AudioStream? currentAudioStream;
      SubtitleStream? currentSubtitleStream;

      currentVideoStream = streamInfo.videoStream;
      final audioStreams = streamInfo.audioStreams ?? [];
      final subtitleStreams = streamInfo.subtitleStreams ?? [];
      
      if (widget.audioGuid != null) {
        currentAudioStream = audioStreams.where((s) => s.guid == widget.audioGuid).firstOrNull;
      } else {
        currentAudioStream = audioStreams.where((s) => s.isDefault == 1).firstOrNull ??
            audioStreams.firstOrNull;
      }
      if (widget.subtitleGuid != null) {
        currentSubtitleStream = subtitleStreams.where((s) => s.guid == widget.subtitleGuid).firstOrNull;
      } else {
        currentSubtitleStream = subtitleStreams.where((s) => s.isDefault == 1).firstOrNull;
      }

      // Update playing info cache
      _playingInfoCache = PlayingInfoCache(
        itemGuid: widget.guid,
        parentGuid: playInfo.parentGuid,
        item: playInfo.item,
        currentVideoStream: currentVideoStream,
        currentAudioStream: currentAudioStream,
        currentSubtitleStream: currentSubtitleStream,
        currentAudioStreamList: audioStreams,
        currentSubtitleStreamList: subtitleStreams,
        playLink: isUseDirectLink ? null : playUrl,
        isUseDirectLink: isUseDirectLink,
        playConfig: playInfo.playConfig,
        streamInfo: streamInfo,
        isEpisode: playInfo.item.type == 'Episode',
      );

      // Open media
      await _player!.open(Media(playUrl));

      // Resume from last position
      if (playInfo.ts > 0) {
        await _player!.seek(Duration(milliseconds: playInfo.ts));
      }

      // Set initial volume
      _volume = ref.read(playerSettingsManagerProvider).getVolume();
      await _player!.setVolume(_volume * 100);

      // Set initial speed
      _speed = ref.read(playerSettingsManagerProvider).getSpeed();
      await _player!.setRate(_speed);

      // Get qualities if using HLS
      if (!isUseDirectLink) {
        try {
          _qualities = await playerService.getQualities(playUrl);
          if (_qualities.isNotEmpty) {
            _currentResolution = _qualities.first.resolution;
            _currentBitrate = _qualities.first.bitrate;
          }
        } catch (_) {
          // Ignore quality errors
        }
      }

      setState(() {
        _isLoading = false;
        _isInitialized = true;
        _duration = currentVideoStream?.duration ?? playInfo.item.duration * 1000;
      });

      // Start play record timer
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
    if (_playingInfoCache?.playLink == null) return;

    try {
      final playerService = ref.read(playerServiceProvider);
      final newPlayLink = await playerService.setQuality(
        playLink: _playingInfoCache!.playLink!,
        resolution: quality.resolution,
        bitrate: quality.bitrate,
      );

      // Store current position
      final currentPosition = _player?.state.position.inMilliseconds ?? 0;

      // Open new quality stream
      await _player!.open(Media(newPlayLink));

      // Seek to stored position
      if (currentPosition > 0) {
        await _player!.seek(Duration(milliseconds: currentPosition));
      }

      setState(() {
        _currentResolution = quality.resolution;
        _currentBitrate = quality.bitrate;
      });
    } catch (e) {
      _toastManager.showToast('切换画质失败: $e', type: ToastType.failed);
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
                  ? Video(controller: _videoController!)
                  : const Center(child: ProgressRing()),
            ),
          ),
        ),

        // Loading overlay
        if (_isLoading)
          const Center(child: ProgressRing()),

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
                                if (_playingInfoCache?.subhead.isNotEmpty == true)
                                  Text(
                                    _playingInfoCache!.subhead,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
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
                        _player?.state.playing == true ? FluentIcons.pause : FluentIcons.play,
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
            _player?.state.playing == true ? FluentIcons.pause : FluentIcons.play,
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