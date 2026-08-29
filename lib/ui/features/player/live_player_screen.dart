import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart' hide DragToMoveArea;

import '../../../core/utils/log/app_talker.dart';
import '../../../core/window/desktop_display_service.dart';
import '../../../core/window/main_window_persistence_guard.dart';
import '../../../core/window/window_geometry.dart';
import '../../../data/models/media_request_models.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../providers/providers.dart';
import '../../shared/common/app_loading_progress_ring.dart';
import '../../shared/toast.dart';
import '../../shared/window_caption.dart';
import 'controllers/desktop_pseudo_fullscreen_controller.dart';
import 'controllers/pip_window_mode_controller.dart';
import 'controllers/player_overlay_controller.dart';
import 'controllers/player_session_coordinator.dart';
import 'controllers/player_window_aspect_ratio_controller.dart';
import 'services/player_service.dart';
import 'utils/player_volume_helper.dart';
import 'widgets/channel_select_flyout.dart';
import 'widgets/fullscreen_control.dart';
import 'widgets/player_action_button.dart';
import 'widgets/volume_control.dart';
import 'package:fly_narwhal/ui/shared/app_button.dart';

/// IPTV live-channel player, mirroring the web live player: top bar with
/// back button, title and a "直播中" badge; bottom bar with play/pause on the
/// left and channel-line selection, volume, PiP and fullscreen on the right.
/// No progress bar / seek controls — live streams are not seekable.
class LivePlayerScreen extends ConsumerStatefulWidget {
  final String guid;

  const LivePlayerScreen({super.key, required this.guid});

  @override
  ConsumerState<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends ConsumerState<LivePlayerScreen>
    with WindowListener {
  static const Duration _sessionRequestTimeout = Duration(seconds: 15);
  static const double _trailingControlSpacing = 12;
  static const Duration _pipIdleHideDuration = Duration(seconds: 3);

  final FocusNode _playerFocusNode = FocusNode(debugLabel: 'live-player');
  Player? _player;
  VideoController? _videoController;

  bool _isLoading = true;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isFullscreen = false;
  bool _isPipMode = false;
  bool _isPipHovered = false;
  String? _errorMessage;

  PlayInfoResponse? _playInfo;
  List<LiveChannelSource> _channels = const [];
  int _selectedChannelIndex = 0;
  double _volume = 1.0;

  int _loadToken = 0;
  Timer? _playRecordTimer;
  Timer? _pipIdleTimer;
  Timer? _pipBoundsSaveTimer;
  Timer? _playerWindowSizeSaveTimer;

  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _bufferingSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<VideoParams>? _videoParamsSubscription;

  final DesktopPseudoFullscreenController _fullscreenController =
      DesktopPseudoFullscreenController();
  final PipWindowModeController _pipController = PipWindowModeController();
  final PlayerWindowAspectRatioController _windowAspectRatioController =
      PlayerWindowAspectRatioController();
  String _windowAspectRatio = PlayerWindowAspectRatioController.autoSetting;
  // Window session separation: the player route keeps its own geometry and
  // must not leak resizes into the app window state used by other routes.
  Rect? _prePlayerWindowBounds;
  bool _prePlayerWasMaximized = false;
  bool _windowPersistenceSuspended = false;
  bool _windowSessionCaptured = false;
  // True while this screen is programmatically restoring window geometry
  // (player entry / route leave). Window-state events fired by our own
  // maximize/unmaximize calls must not overwrite the persisted player window
  // form, otherwise the exit-time unmaximize wipes the user's maximized
  // preference and the next video opens floating.
  bool _isRestoringWindowSession = false;
  // Monotonic id pairing every player screen with the window session it
  // captured, so a disposed screen never restores the app window over a newer
  // player screen that has already taken over (e.g. direct video switches).
  static int _windowSessionGeneration = 0;
  int _windowSessionId = 0;

  bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  bool get _isDesktop => !kIsWeb;

  PlayerOverlayController get _overlayController =>
      ref.read(playerOverlayControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      unawaited(_syncFullscreenState());
      unawaited(_captureWindowSession());
    }
    _volume = ref.read(playerSettingsManagerProvider).getVolume();
    _windowAspectRatio =
        ref.read(playerSettingsManagerProvider).getWindowAspectRatio();
    _initializePlayer();
  }

  @override
  void dispose() {
    _playRecordTimer?.cancel();
    _pipIdleTimer?.cancel();
    _pipBoundsSaveTimer?.cancel();
    _playerWindowSizeSaveTimer?.cancel();
    _playingSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _errorSubscription?.cancel();
    _videoParamsSubscription?.cancel();
    if (_isDesktop) {
      windowManager.removeListener(this);
      unawaited(_windowAspectRatioController.release());
      unawaited(_fullscreenController.exitForRouteLeave());
      // Ensure the window is restored to its normal form when leaving while in
      // PiP mode so the next route is not stuck in a tiny borderless window,
      // then hand the window back to the app routes at its pre-player size.
      unawaited(_tearDownWindowSession());
    }
    _player?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    _player = Player(configuration: const PlayerConfiguration(libass: true));
    _videoController = VideoController(_player!);
    final player = _player!;

    _playingSubscription = player.stream.playing.listen((isPlaying) {
      if (!mounted) return;
      setState(() => _isPlaying = isPlaying);
      // Keep the overlay pinned while paused, resume idle hiding on play.
      if (_isPipMode) {
        if (isPlaying) {
          _restartPipIdleTimer();
        } else {
          _showPipControls();
        }
      }
      _showUi();
    });
    _bufferingSubscription = player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      setState(() => _isBuffering = buffering);
    });
    _errorSubscription = player.stream.error.listen((error) {
      if (!mounted || error.isEmpty) return;
      AppTalker.warning('LivePlayer', 'mpv error: $error');
      if (_isInitialized) {
        setState(() => _errorMessage = '播放出错,请尝试切换线路');
      }
    });
    // Tracks live decode-size changes so the AUTO window ratio keeps the
    // window locked to the actual video aspect ratio, the same way PiP mode
    // keeps its window matched to the video.
    _videoParamsSubscription = player.stream.videoParams.listen((params) {
      if (!mounted) return;
      final width = params.w ?? 0;
      final height = params.h ?? 0;
      if (width <= 0 || height <= 0) return;
      if (_windowAspectRatio != PlayerWindowAspectRatioController.autoSetting) {
        return;
      }
      unawaited(_applyWindowAspectRatio());
    });

    await player.setVolume(uiVolumeToMpvVolume(_volume));
    unawaited(_loadPlayInfo());
    if (mounted) {
      _playerFocusNode.requestFocus();
    }
  }

  Future<void> _loadPlayInfo() async {
    final token = ++_loadToken;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final playInfo = await ref
          .read(playerServiceProvider)
          .getPlayInfo(widget.guid)
          .timeout(_sessionRequestTimeout);
      if (!mounted || token != _loadToken) return;

      final channels = (playInfo.liveChannels ?? const <LiveChannelSource>[])
          .where((channel) => channel.path.isNotEmpty)
          .toList()
        ..sort((a, b) => a.sortNum.compareTo(b.sortNum));
      if (channels.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '该频道没有可用的播放线路';
        });
        return;
      }

      _playInfo = playInfo;
      _channels = channels;
      await _openChannel(0);
    } catch (e, st) {
      AppTalker.error(
        'LivePlayer',
        error: e,
        stackTrace: st,
        message: 'load play info failed',
      );
      if (!mounted || token != _loadToken) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '加载失败,请返回重试';
      });
    }
  }

  Future<void> _openChannel(int index) async {
    if (index < 0 || index >= _channels.length) return;
    final token = ++_loadToken;
    final channel = _channels[index];
    setState(() {
      _selectedChannelIndex = index;
      _isLoading = true;
      _errorMessage = null;
    });

    final player = _player;
    if (player == null) return;

    try {
      // Resolve master playlists the same way the VOD player does; fall back
      // to the raw URL when the resolver cannot reach the external host.
      String playUri = channel.path;
      try {
        final prepared = await ref
            .read(playerSessionCoordinatorProvider)
            .preparePlaySourceForMediaKit(
              playUri: channel.path,
              currentSubtitleStream: null,
            );
        playUri = prepared.playUri;
      } catch (_) {
        playUri = channel.path;
      }
      if (!mounted || token != _loadToken) return;

      final headers = _buildPlaybackHttpHeaders(playUri);
      await player.open(
        Media(playUri, httpHeaders: headers.isEmpty ? null : headers),
      );
      if (!mounted || token != _loadToken) return;

      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });
      // Resize/lock the window per the window aspect ratio setting now that
      // the new stream is known.
      unawaited(_applyWindowAspectRatio());
      _startPlayRecordTimer();
      _queueLivePlayRecord();
      _showUi();
    } catch (e, st) {
      AppTalker.error(
        'LivePlayer',
        error: e,
        stackTrace: st,
        message: 'open channel failed: ${channel.fileName}',
      );
      if (!mounted || token != _loadToken) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '播放失败,请尝试切换线路';
      });
    }
  }

  /// Builds the HTTP headers for opening a live channel. NAS credentials
  /// (Cookie / Authorization) are only attached when the URL is served by the
  /// NAS itself; direct external IPTV URLs live on other hosts and must not
  /// receive NAS credentials.
  Map<String, String> _buildPlaybackHttpHeaders(String playUri) {
    final isNasProxy = playUri.contains('/v/api/v1/media/range') ||
        playUri.contains('/v/api/v1/wp/m3u8') ||
        _isNasHostedUrl(playUri);
    if (isNasProxy) {
      return ref.read(playerSessionCoordinatorProvider).buildPlayerHeaders();
    }
    return const <String, String>{};
  }

  /// Whether [playUri] is served by the NAS itself and therefore needs NAS
  /// auth. Covers links that live on the same host:port as the configured
  /// base URL. The browser-based web player gets this for free via
  /// same-origin cookies; mpv needs the headers attached explicitly. External
  /// IPTV hosts must not receive NAS credentials.
  bool _isNasHostedUrl(String playUri) {
    final baseUrl = ref.read(preferencesManagerProvider).getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) return false;
    final baseUri = Uri.tryParse(baseUrl);
    final targetUri = Uri.tryParse(playUri);
    if (baseUri == null || targetUri == null) return false;
    final baseHost = baseUri.host;
    if (baseHost.isEmpty) return false;
    return targetUri.host == baseHost && targetUri.port == baseUri.port;
  }

  // ---------------------------------------------------------------- records

  void _startPlayRecordTimer() {
    _playRecordTimer?.cancel();
    _playRecordTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _queueLivePlayRecord();
    });
  }

  /// Mirrors the web live player: play/record for LiveChannel only carries
  /// {item_guid, media_guid, ts: 0}.
  void _queueLivePlayRecord() {
    if (_channels.isEmpty) return;
    final channel = _channels[_selectedChannelIndex];
    unawaited(() async {
      try {
        await ref.read(playerServiceProvider).updateLivePlayRecord(
              LivePlayRecordRequest(
                itemGuid: widget.guid,
                mediaGuid: channel.guid,
                ts: 0,
              ),
            );
      } catch (_) {
        // Record failures must never affect playback.
      }
    }());
  }

  // ---------------------------------------------------------------- actions

  void _togglePlayPause() {
    final player = _player;
    if (player == null || !_isInitialized) return;
    if (player.state.playing) {
      unawaited(player.pause());
    } else {
      unawaited(player.play());
    }
  }

  void _setVolume(double volume) {
    setState(() => _volume = volume);
    _player?.setVolume(uiVolumeToMpvVolume(volume));
    ref.read(playerSettingsManagerProvider).setVolume(volume);
  }

  Future<void> _toggleFullscreen() async {
    if (!_isDesktop) return;
    if (_isPipMode) {
      await _exitPipMode();
    }
    try {
      final isFullscreen = await _fullscreenController.toggle();
      if (mounted) {
        setState(() => _isFullscreen = isFullscreen);
      }
      _syncWindowAspectRatioWithFullscreen(isFullscreen);
    } catch (e, st) {
      AppTalker.error(
        'LivePlayer',
        error: e,
        stackTrace: st,
        message: 'toggle fullscreen failed',
      );
    }
  }

  Future<void> _syncFullscreenState() async {
    final isFullscreen = await _fullscreenController.syncState();
    if (mounted) {
      setState(() => _isFullscreen = isFullscreen);
    }
  }

  Future<void> _enterPipMode() async {
    if (!_isDesktop || _player == null || !_isInitialized) return;
    try {
      setState(() {
        _isPipMode = true;
        _isPipHovered = true;
      });
      _overlayController.dismissTransientUi();
      // PiP manages its own aspect ratio lock; hand the window over cleanly.
      await _windowAspectRatioController.release();
      await _pipController.enter(videoAspectRatio: _resolveVideoAspectRatio());
      _restartPipIdleTimer();
    } catch (e, st) {
      AppTalker.error(
        'LivePlayer',
        error: e,
        stackTrace: st,
        message: 'enter PiP failed',
      );
      try {
        await _pipController.exit();
      } catch (_) {}
      if (mounted) {
        setState(() => _isPipMode = false);
        // PiP exit cleared the ratio lock; restore the player's setting.
        unawaited(_applyWindowAspectRatio());
        ref.read(toastManagerProvider.notifier).showToast(
              '进入画中画失败: $e',
              type: ToastType.failed,
            );
      }
    }
  }

  Future<void> _exitPipMode() async {
    if (!_isPipMode) return;
    _pipIdleTimer?.cancel();
    try {
      await _pipController.persistCurrentBounds();
      await _pipController.exit();
      if (mounted) {
        setState(() {
          _isPipMode = false;
          _isPipHovered = false;
        });
        _scheduleMacOSWindowButtonsSync(
          visible: ref.read(playerOverlayControllerProvider).isUiVisible,
          force: true,
        );
        // PiP cleared the aspect ratio lock; restore the player's setting.
        unawaited(_applyWindowAspectRatio());
      }
    } catch (e, st) {
      AppTalker.error(
        'LivePlayer',
        error: e,
        stackTrace: st,
        message: 'exit PiP failed',
      );
    }
  }

  double? _resolveVideoAspectRatio() {
    final state = _player?.state;
    final width = state?.width;
    final height = state?.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }

  void _showPipControls() {
    if (!_isPipMode) return;
    if (!_isPipHovered) {
      setState(() => _isPipHovered = true);
    }
    _restartPipIdleTimer();
  }

  void _restartPipIdleTimer() {
    _pipIdleTimer?.cancel();
    if (!_isPlaying) return;
    _pipIdleTimer = Timer(_pipIdleHideDuration, () {
      if (!_isPlaying) return;
      if (mounted && _isPipHovered) {
        setState(() => _isPipHovered = false);
      }
    });
  }

  Future<void> _handleBack() async {
    _playRecordTimer?.cancel();
    _overlayController.dismissTransientUi();
    if (_isPipMode) {
      await _exitPipMode();
    }
    if (!mounted) return;
    await _restoreWindowModeBeforeLeave();
    if (!mounted) return;
    if (context.canPop()) {
      // Normal entries push the player on top of the shell, so popping
      // restores the source page with its state (incl. scroll position).
      final stack = ref.read(navigationStackProvider.notifier);
      stack.playerSourcePath = null;
      context.pop();
    } else {
      // Fallback for deep links that land on the player directly: return
      // to the page the player was entered from (or home).
      final stack = ref.read(navigationStackProvider.notifier);
      final sourcePath = stack.playerSourcePath;
      stack.playerSourcePath = null;
      context.go(sourcePath ?? '/home');
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      unawaited(_handleBack());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------- overlay

  void _showUi() {
    _overlayController.showUi(isPlaying: _isPlaying);
  }

  bool _lastMacOSWindowButtonsVisibility = true;
  void _scheduleMacOSWindowButtonsSync({
    required bool visible,
    bool force = false,
  }) {
    if (!_isMacOS) return;
    final effectiveVisibility = _isPipMode ? false : visible;
    if (!force && _lastMacOSWindowButtonsVisibility == effectiveVisibility) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await windowManager.setTitleBarStyle(
          TitleBarStyle.hidden,
          windowButtonVisibility: effectiveVisibility,
        );
        _lastMacOSWindowButtonsVisibility = effectiveVisibility;
      } catch (error) {
        AppTalker.warning(
          'LivePlayer',
          'sync macOS window buttons failed: $error',
        );
      }
    });
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final overlayState = ref.watch(playerOverlayControllerProvider);
    _scheduleMacOSWindowButtonsSync(visible: overlayState.isUiVisible);
    final playerCursor =
        _isInitialized && !_isPipMode && !overlayState.isUiVisible
            ? SystemMouseCursors.none
            : SystemMouseCursors.click;

    return Focus(
      focusNode: _playerFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
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
              onDoubleTap: () {
                _playerFocusNode.requestFocus();
                if (!_isPipMode) {
                  unawaited(_toggleFullscreen());
                }
              },
              child: Container(
                key: const ValueKey('live-video'),
                color: Colors.black,
                child: _isInitialized && _videoController != null
                    ? Video(
                        controller: _videoController!,
                        controls: NoVideoControls,
                        fit: _isPipMode ? BoxFit.cover : BoxFit.contain,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            if ((_isLoading || (_isInitialized && _isBuffering)) &&
                _errorMessage == null)
              const Center(
                key: ValueKey('live-loading'),
                child: AppLoadingProgressRing(),
              ),
            if (!_isLoading && _errorMessage != null)
              Center(
                child: Container(
                  key: const ValueKey('live-error'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC000000),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        onPressed: () {
                          if (_channels.isEmpty) {
                            unawaited(_loadPlayInfo());
                          } else {
                            unawaited(_openChannel(_selectedChannelIndex));
                          }
                        },
                        child: const Align(
                          alignment: Alignment.center,
                          widthFactor: 1.0,
                          child: Text('重试'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_isInitialized && !_isPipMode)
              Positioned(
                top: _isMacOS && !_isFullscreen ? 12.0 : 6.0,
                left: 16 + (_isMacOS && !_isFullscreen ? 72.0 : 0.0),
                child: _buildBackButton(),
              ),
            if (_isInitialized && !_isPipMode)
              AnimatedOpacity(
                opacity: overlayState.isUiVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !overlayState.isUiVisible,
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
                          height: 96,
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
                              child: _buildBottomBar(overlayState),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_isInitialized && _isPipMode) _buildPipOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final leftInset = _isMacOS && !_isFullscreen ? 72.0 : 0.0;
    final topPadding = _isMacOS && !_isFullscreen ? 12.0 : 6.0;
    final topBarContentHeight = _isMacOS ? 30.0 : 36.0;
    final title = _playInfo?.item.title ?? '';

    return SafeArea(
      child: SizedBox(
        height: topPadding + topBarContentHeight,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DragToMoveArea(child: SizedBox.expand()),
            ),
            Positioned(
              top: topPadding,
              left: 16,
              right: 16,
              height: topBarContentHeight,
              child: Row(
                children: [
                  if (leftInset > 0) SizedBox(width: leftInset),
                  _buildBackButton(),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '直播中',
                      style: TextStyle(color: Colors.white, fontSize: 12),
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
      key: const ValueKey('live-back-button'),
      iconData: FluentIcons.back,
      onPressed: () => unawaited(_handleBack()),
      tooltip: '返回',
      size: _isMacOS ? 30 : 34,
      iconSize: _isMacOS ? 15 : 18,
      borderRadius: BorderRadius.circular(_isMacOS ? 15 : 17),
    );
  }

  Widget _buildBottomBar(PlayerOverlayState overlayState) {
    final currentChannel =
        _channels.isEmpty ? null : _channels[_selectedChannelIndex];
    return Row(
      children: [
        PlayerActionButton.svg(
          key: const ValueKey('live-play-pause'),
          svgAssetPath:
              _isPlaying ? 'assets/images/pause.svg' : 'assets/images/play.svg',
          onPressed: _togglePlayPause,
          tooltip: _isPlaying ? '暂停' : '播放',
          size: 34,
          iconSize: 24,
        ),
        const Spacer(),
        if (currentChannel != null) ...[
          _buildChannelSelector(overlayState),
          const SizedBox(width: _trailingControlSpacing),
        ],
        VolumeControl(
          key: const ValueKey('live-volume-control'),
          volume: _volume,
          isActiveControl:
              overlayState.activeFlyout != PlayerFlyoutType.liveChannel,
          onHoverStateChanged: (hovered) {
            if (hovered) _dismissChannelFlyout();
            _overlayController.setHovered(
              PlayerHoverZone.volumeControl,
              hovered,
            );
          },
          onVolumeChange: _setVolume,
        ),
        const SizedBox(width: _trailingControlSpacing),
        MouseRegion(
          onEnter: (_) {
            _dismissChannelFlyout();
            _overlayController.setHovered(PlayerHoverZone.pipControl, true);
          },
          onExit: (_) =>
              _overlayController.setHovered(PlayerHoverZone.pipControl, false),
          child: PlayerActionButton.lottie(
            key: const ValueKey('live-enter-pip'),
            lottieAssetPath: 'assets/lottie/to_pip.json',
            onPressed: () => unawaited(_enterPipMode()),
            tooltip: '画中画',
            size: 30,
            iconSize: 22,
          ),
        ),
        const SizedBox(width: _trailingControlSpacing),
        MouseRegion(
          onEnter: (_) => _dismissChannelFlyout(),
          child: FullScreenControl(
            key: const ValueKey('live-fullscreen'),
            isFullScreen: _isFullscreen,
            onClick: () => unawaited(_toggleFullscreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelSelector(
    PlayerOverlayState overlayState,
  ) {
    return ChannelSelectFlyout(
      key: const ValueKey('live-channel-button'),
      channels: _channels,
      selectedIndex: _selectedChannelIndex,
      isActiveControl:
          overlayState.activeFlyout == PlayerFlyoutType.liveChannel,
      onHoverStateChanged: (hovered) => _handleFlyoutHoverStateChanged(
        PlayerFlyoutType.liveChannel,
        hovered,
      ),
      onChannelSelected: (index) => unawaited(_openChannel(index)),
    );
  }

  void _handleFlyoutHoverStateChanged(PlayerFlyoutType type, bool hovered) {
    _overlayController.setFlyoutHovered(type, hovered);
    if (hovered) {
      _showUi();
    }
  }

  /// Synchronously closes the channel flyout by clearing its active state in
  /// the overlay controller. When the cursor moves onto a non-menu trailing
  /// control (volume / PiP / fullscreen), this flips the flyout's
  /// `isActiveControl` to false, which triggers its `didUpdateWidget` and
  /// `_forceCloseFlyout` — the same cross-menu sync-close used elsewhere.
  void _dismissChannelFlyout() {
    _overlayController.setFlyoutHovered(PlayerFlyoutType.liveChannel, false);
  }

  Widget _buildPipOverlay() {
    return MouseRegion(
      onHover: (_) => _showPipControls(),
      child: Stack(
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
          AnimatedOpacity(
            opacity: _isPipHovered ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_isPipHovered,
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    right: 8,
                    child: PlayerActionButton.icon(
                      key: const ValueKey('live-pip-close'),
                      iconData: FluentIcons.chrome_close,
                      tooltip: '关闭',
                      onPressed: () => unawaited(_handleBack()),
                      size: 28,
                      iconSize: 14,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: PlayerActionButton.svg(
                        key: const ValueKey('live-pip-play-pause'),
                        svgAssetPath: _isPlaying
                            ? 'assets/images/pause.svg'
                            : 'assets/images/play.svg',
                        tooltip: '播放/暂停',
                        onPressed: _togglePlayPause,
                        size: 52,
                        iconSize: 34,
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
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
                      key: const ValueKey('live-pip-exit'),
                      lottieAssetPath: 'assets/lottie/quit_pip.json',
                      tooltip: '退出画中画',
                      onPressed: () => unawaited(_exitPipMode()),
                      size: 30,
                      iconSize: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------- window session / ratio

  /// Applies the current window aspect ratio setting to the main window,
  /// mirroring the VOD player: AUTO mode locks the window to the video's own
  /// ratio so the video frame and the window stay perfectly matched.
  Future<void> _applyWindowAspectRatio() async {
    if (!_isDesktop) return;
    if (!_windowSessionCaptured) return;
    if (_isPipMode || _pipController.isPipMode) return;
    if (_isFullscreen || !_isInitialized) return;
    // A maximized player window owns its shape. The persisted flag is checked
    // in addition to the controller's own isMaximized() probe because macOS
    // can transiently report a zoomed window as not maximized; the flag keeps
    // the maximized window intact in that window of instability.
    if (ref.read(playerSettingsManagerProvider).getPlayerWindowMaximized()) {
      // The maximized window will be restored by the OS on un-maximize; keep
      // the small ratio-aware minimum so that restore is not clamped.
      unawaited(
        _windowAspectRatioController.release(restoreNormalMinimumSize: false),
      );
      return;
    }

    // Delay slightly so the window state has settled, matching the VOD
    // player's behavior right after window creation or state transitions.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    if (_isPipMode || _pipController.isPipMode) return;
    if (_isFullscreen) return;
    if (ref.read(playerSettingsManagerProvider).getPlayerWindowMaximized()) {
      unawaited(
        _windowAspectRatioController.release(restoreNormalMinimumSize: false),
      );
      return;
    }

    await _windowAspectRatioController.apply(
      setting: _windowAspectRatio,
      videoAspectRatio: _resolveVideoAspectRatio(),
    );
  }

  /// Fullscreen owns the window shape: release the ratio lock while in it,
  /// re-apply the setting once back in windowed mode.
  void _syncWindowAspectRatioWithFullscreen(bool isFullscreen) {
    if (!_isDesktop) return;
    if (_isPipMode || _pipController.isPipMode) return;
    if (isFullscreen) {
      // Keep the ratio-aware (small) window minimum in place while
      // fullscreen: the OS restores the pre-fullscreen frame on exit, and a
      // raised minimum would clamp that restore, shifting small windows.
      unawaited(
        _windowAspectRatioController.release(restoreNormalMinimumSize: false),
      );
    } else {
      unawaited(_applyWindowAspectRatio());
    }
  }

  Future<void> _restoreWindowModeBeforeLeave() async {
    if (!_isDesktop) {
      return;
    }

    // Window-state events fired by the restore sequence below are our own,
    // not user gestures; keep them from overwriting the persisted form.
    _isRestoringWindowSession = true;
    try {
      // The player route owns the window ratio lock; release it so other
      // routes can resize the window freely again.
      await _windowAspectRatioController.release();
      final isFullscreen = await _fullscreenController.exitForRouteLeave();
      await _restoreAppWindowSession();
      if (!mounted || _isFullscreen == isFullscreen) {
        return;
      }

      setState(() => _isFullscreen = isFullscreen);
    } finally {
      _isRestoringWindowSession = false;
    }
  }

  /// The player route keeps its own window geometry, separate from the rest
  /// of the app (the KMP player window stores its size independently too).
  /// While the player is open, main-window persistence is suspended and
  /// player resizes are recorded into the player-geometry store instead, so
  /// leaving the player no longer drags the other routes along.
  Future<void> _captureWindowSession() async {
    if (!_isDesktop) {
      return;
    }
    // Claim the window session synchronously before any await so a disposed
    // predecessor can see the takeover and skip its own window restore.
    _windowSessionId = ++_windowSessionGeneration;
    Rect? bounds;
    var wasMaximized = false;
    try {
      bounds = await windowManager.getBounds();
      wasMaximized = await windowManager.isMaximized();
    } catch (error, stackTrace) {
      AppTalker.error(
        'LivePlayer',
        error: error,
        stackTrace: stackTrace,
        message: 'capture window session failed',
      );
    }
    if (!mounted) {
      return;
    }
    _prePlayerWindowBounds = bounds;
    _prePlayerWasMaximized = wasMaximized;
    _windowSessionCaptured = true;
    AppTalker.info(
      'WindowSession',
      'captured app bounds=$bounds maximized=$wasMaximized',
    );
    MainWindowPersistenceGuard.suspend();
    _windowPersistenceSuspended = true;
    unawaited(_restorePlayerWindowBounds());
  }

  /// Restores the player window's own remembered geometry (position and
  /// size), mirroring the KMP player window restoring its saved position and
  /// size on open.
  Future<void> _restorePlayerWindowBounds() async {
    _isRestoringWindowSession = true;
    try {
      if (await windowManager.isFullScreen()) {
        return;
      }
      // The player keeps its own window form: if it was last left maximized,
      // re-enter maximize for this (possibly different) video instead of
      // restoring the floating geometry. The pre-player maximized state seeds
      // the player form too, so entering the player from a maximized app
      // window keeps the window maximized across video switches.
      final settingsManager = ref.read(playerSettingsManagerProvider);
      final playerWindowMaximized =
          settingsManager.getPlayerWindowMaximized() || _prePlayerWasMaximized;
      if (playerWindowMaximized) {
        if (!settingsManager.getPlayerWindowMaximized()) {
          unawaited(settingsManager.setPlayerWindowMaximized(true));
        }
        if (!await windowManager.isMaximized()) {
          await windowManager.maximize();
        }
        return;
      }
      final savedBounds = settingsManager.getPlayerWindowBounds();
      if (savedBounds == null) {
        return;
      }
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      final displays = await _tryGetDisplays();
      // The player follows the main window's display when they diverge
      // (e.g. the app moved to another screen since the player last ran);
      // on the same display it keeps its own remembered position.
      final restored = WindowGeometry.normalizePlayerBounds(
        savedBounds,
        displays: displays,
        anchorBounds: _prePlayerWindowBounds,
        minimumSize: const Size(640, 360),
      );
      await windowManager.setBounds(restored);
    } catch (error, stackTrace) {
      AppTalker.error(
        'LivePlayer',
        error: error,
        stackTrace: stackTrace,
        message: 'restore player window bounds failed',
      );
    } finally {
      _isRestoringWindowSession = false;
    }
  }

  void _schedulePlayerWindowBoundsSave() {
    if (!_isDesktop) return;
    if (_isPipMode || _pipController.isPipMode) return;
    _playerWindowSizeSaveTimer?.cancel();
    _playerWindowSizeSaveTimer =
        Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      if (_isPipMode || _pipController.isPipMode) return;
      try {
        if (await windowManager.isMaximized() ||
            await windowManager.isFullScreen()) {
          return;
        }
        // isMaximized() can transiently report false for a maximized window on
        // macOS (e.g. right after the ratio lock is released); the persisted
        // maximized flag is the authoritative source, so never record the
        // zoomed geometry as the player's floating bounds while it is set.
        if (ref
            .read(playerSettingsManagerProvider)
            .getPlayerWindowMaximized()) {
          return;
        }
        final bounds = await windowManager.getBounds();
        if (!mounted) return;
        // User resizes under the ratio lock update the window-ratio
        // baseline; programmatic setBounds echoes are ignored there.
        _windowAspectRatioController.observeSettledBounds(bounds);
        await ref
            .read(playerSettingsManagerProvider)
            .setPlayerWindowBounds(bounds);
      } catch (_) {
        // Persistence is best-effort; never fail a window event on it.
      }
    });
  }

  /// Restores the app window to its pre-player geometry and re-enables
  /// main-window persistence, so player-driven resizes never leak into the
  /// other routes.
  Future<void> _restoreAppWindowSession() async {
    if (!_windowPersistenceSuspended) {
      return;
    }
    _windowPersistenceSuspended = false;

    if (!_isDesktop) {
      MainWindowPersistenceGuard.resume();
      return;
    }

    // A newer player screen (direct video switch) has already captured the
    // window session: hand over without restoring app geometry over it.
    final superseded = _windowSessionId != _windowSessionGeneration;
    if (superseded) {
      MainWindowPersistenceGuard.resume();
      return;
    }

    _isRestoringWindowSession = true;

    // Remember the player's final floating geometry for the next session.
    if (!_isPipMode && !_pipController.isPipMode) {
      try {
        // The persisted maximized flag guards against isMaximized() briefly
        // reporting false for a zoomed window; a zoomed geometry must never
        // be recorded as the floating bounds.
        if (!await windowManager.isMaximized() &&
            !await windowManager.isFullScreen() &&
            !ref
                .read(playerSettingsManagerProvider)
                .getPlayerWindowMaximized()) {
          final bounds = await windowManager.getBounds();
          await ref
              .read(playerSettingsManagerProvider)
              .setPlayerWindowBounds(bounds);
        }
      } catch (_) {
        // Best-effort, same as the debounced saves.
      }
    }

    final appBounds = _prePlayerWindowBounds;
    final wasMaximized = _prePlayerWasMaximized;
    _prePlayerWindowBounds = null;

    try {
      await _fullscreenController.exitForRouteLeave();
      // Native fullscreen exits animate; wait for the window to settle
      // before restoring the captured bounds.
      for (var attempt = 0;
          attempt < 15 && await windowManager.isFullScreen();
          attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (appBounds != null && !await windowManager.isFullScreen()) {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }
        final displays = await _tryGetDisplays();
        final restored = WindowGeometry.normalizeMainWindowBounds(
          appBounds,
          displays,
          fallbackSize: appBounds.size,
          minimumSize: const Size(640, 360),
        );
        await windowManager.setBounds(restored);
        if (wasMaximized) {
          await Future<void>.delayed(const Duration(milliseconds: 16));
          await windowManager.maximize();
        }
      }
    } catch (error, stackTrace) {
      AppTalker.error(
        'LivePlayer',
        error: error,
        stackTrace: stackTrace,
        message: 'restore app window session failed',
      );
    } finally {
      _isRestoringWindowSession = false;
      MainWindowPersistenceGuard.resume();
    }
  }

  Future<void> _tearDownWindowSession() async {
    if (_pipController.isPipMode) {
      await _pipController.exit();
    }
    await _restoreAppWindowSession();
  }

  Future<List<DesktopDisplayGeometry>> _tryGetDisplays() async {
    try {
      return await const DesktopDisplayService().getDisplays();
    } catch (_) {
      return const [];
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

  // ------------------------------------------------------- window listener

  @override
  void onWindowEnterFullScreen() {
    if (!mounted) {
      return;
    }

    setState(() => _isFullscreen = true);
    _syncWindowAspectRatioWithFullscreen(true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (!mounted) {
      return;
    }

    setState(() => _isFullscreen = false);
    _syncWindowAspectRatioWithFullscreen(false);
  }

  @override
  void onWindowMoved() {
    _schedulePipBoundsSave();
    _schedulePlayerWindowBoundsSave();
  }

  @override
  void onWindowResized() {
    _schedulePipBoundsSave();
    _schedulePlayerWindowBoundsSave();
  }

  @override
  void onWindowMaximize() {
    if (!mounted || !_isDesktop) return;
    if (_isPipMode || _pipController.isPipMode) return;
    if (_isRestoringWindowSession) return;
    // Maximize owns the window shape (like fullscreen/PiP): drop the ratio
    // lock so the maximized window is left intact, and persist the player's
    // maximized form so other videos also open maximized.
    unawaited(
      ref.read(playerSettingsManagerProvider).setPlayerWindowMaximized(true),
    );
    // Keep the ratio-aware (small) window minimum while maximized: un-
    // maximizing restores the pre-maximize frame, and a raised minimum
    // would clamp that restore, shifting small windows.
    unawaited(
      _windowAspectRatioController.release(restoreNormalMinimumSize: false),
    );
  }

  @override
  void onWindowUnmaximize() {
    if (!mounted || !_isDesktop) return;
    if (_isPipMode || _pipController.isPipMode) return;
    if (_isRestoringWindowSession) return;
    // The user returned to a floating window; persist that and re-apply the
    // ratio lock.
    unawaited(
      ref.read(playerSettingsManagerProvider).setPlayerWindowMaximized(false),
    );
    unawaited(_applyWindowAspectRatio());
  }
}
