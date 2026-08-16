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
import 'services/player_service.dart';
import 'utils/player_volume_helper.dart';
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
  bool _isChannelFlyoutOpen = false;
  double _volume = 1.0;

  int _loadToken = 0;
  Timer? _playRecordTimer;
  Timer? _pipIdleTimer;

  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _bufferingSubscription;
  StreamSubscription<String>? _errorSubscription;

  final DesktopPseudoFullscreenController _fullscreenController =
      DesktopPseudoFullscreenController();
  final PipWindowModeController _pipController = PipWindowModeController();

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
    }
    _volume = ref.read(playerSettingsManagerProvider).getVolume();
    _initializePlayer();
  }

  @override
  void dispose() {
    _playRecordTimer?.cancel();
    _pipIdleTimer?.cancel();
    _playingSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _errorSubscription?.cancel();
    if (_isDesktop) {
      windowManager.removeListener(this);
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
      _isChannelFlyoutOpen = false;
    });
    _overlayController.setFlyoutHovered(PlayerFlyoutType.liveChannel, false);

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

      final headers =
          ref.read(playerSessionCoordinatorProvider).buildPlayerHeaders();
      await player.open(
        Media(playUri, httpHeaders: headers.isEmpty ? null : headers),
      );
      if (!mounted || token != _loadToken) return;

      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });
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
      _closeChannelFlyout();
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
    await _fullscreenController.exitForRouteLeave();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      // Return to the page the player was entered from. The player route
      // sits outside the ShellRoute, so it is never on the navigation
      // stack itself and the entry `go` replaced it.
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

  void _toggleChannelFlyout(bool open) {
    if (_isChannelFlyoutOpen == open) return;
    setState(() => _isChannelFlyoutOpen = open);
    _overlayController.setFlyoutHovered(PlayerFlyoutType.liveChannel, open);
    if (open) {
      _showUi();
    }
  }

  void _closeChannelFlyout() => _toggleChannelFlyout(false);

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
                      if (_isChannelFlyoutOpen)
                        Positioned(
                          right: 16,
                          bottom: 64,
                          child: _buildChannelFlyout(),
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
          _buildChannelSelector(overlayState, currentChannel),
          const SizedBox(width: _trailingControlSpacing),
        ],
        VolumeControl(
          key: const ValueKey('live-volume-control'),
          volume: _volume,
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
            key: const ValueKey('live-enter-pip'),
            lottieAssetPath: 'assets/lottie/to_pip.json',
            onPressed: () => unawaited(_enterPipMode()),
            tooltip: '画中画',
            size: 30,
            iconSize: 22,
          ),
        ),
        const SizedBox(width: _trailingControlSpacing),
        FullScreenControl(
          key: const ValueKey('live-fullscreen'),
          isFullScreen: _isFullscreen,
          onClick: () => unawaited(_toggleFullscreen()),
        ),
      ],
    );
  }

  Widget _buildChannelSelector(
    PlayerOverlayState overlayState,
    LiveChannelSource currentChannel,
  ) {
    return GestureDetector(
      key: const ValueKey('live-channel-button'),
      onTap: () => _toggleChannelFlyout(!_isChannelFlyoutOpen),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isChannelFlyoutOpen
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            currentChannel.fileName,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelFlyout() {
    return MouseRegion(
      onEnter: (_) => _overlayController.setFlyoutHovered(
          PlayerFlyoutType.liveChannel, true),
      onExit: (_) => _overlayController.setFlyoutHovered(
          PlayerFlyoutType.liveChannel, false),
      child: Container(
        width: 168,
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x80808080)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '线路',
                    style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
                  ),
                ),
              ),
              ...List.generate(_channels.length, (index) {
                final channel = _channels[index];
                final isSelected = index == _selectedChannelIndex;
                return _ChannelFlyoutItem(
                  key: ValueKey('live-channel-item-$index'),
                  label: channel.fileName,
                  isSelected: isSelected,
                  onTap: () => unawaited(_openChannel(index)),
                );
              }),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
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

  // ------------------------------------------------------- window listener

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _isFullscreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _isFullscreen = false);
  }
}

class _ChannelFlyoutItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChannelFlyoutItem({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ChannelFlyoutItem> createState() => _ChannelFlyoutItemState();
}

class _ChannelFlyoutItemState extends State<_ChannelFlyoutItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered || widget.isSelected
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isSelected
                        ? const Color(0xFF3B82F6)
                        : Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              if (widget.isSelected)
                const Icon(
                  FluentIcons.check_mark,
                  size: 14,
                  color: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
