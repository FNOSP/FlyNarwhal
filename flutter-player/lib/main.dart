import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;

import 'api/bridge_client.dart';
import 'models/bridge_models.dart';
import 'providers/intro_outro_provider.dart';
import 'ui/components/custom_ui.dart';
import 'ui/components/settings_menu.dart';

const int kPlayerPort = 47920;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();

  String? url;
  String? title;
  Duration startPosition = Duration.zero;

  if (args.isNotEmpty) {
    url = args[0];
    if (args.length > 1) {
        title = args[1];
      }
    if (args.length > 2) {
      try {
        final posMs = int.parse(args[2]);
        startPosition = Duration(milliseconds: posMs);
      } catch (e) {
        debugPrint('Error parsing start position: $e');
      }
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IntroOutroProvider()),
        Provider(create: (_) => BridgeApiClient()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: Colors.black,
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            secondary: Colors.blueAccent,
          ),
        ),
        home: PlayerScreen(url: url, title: title, startPosition: startPosition),
      ),
    ),
  );
}

class PlayerScreen extends StatefulWidget {
  final String? url;
  final String? title;
  final Duration startPosition;

  const PlayerScreen({
    super.key,
    this.url,
    this.title,
    this.startPosition = Duration.zero,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WindowListener {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _isHovering = false;
  HttpServer? _server;
  
  // State for Settings
  bool _isSettingsOpen = false;
  String _aspectRatio = "默认";
  String _windowRatio = "自动";
  bool _isSmallWindow = false;
  
  // Bridge Data
  AppSettings? _appSettings;
  PlayerSettings? _playerSettings;

  // Player State
  bool _isBuffering = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Duration _buffer = Duration.zero;
  double _volume = 100.0;
  double _playbackSpeed = 1.0;
  
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _bufferSubscription;
  StreamSubscription? _bufferingSubscription;
  StreamSubscription? _volumeSubscription;
  StreamSubscription? _rateSubscription;

  // Small Window State
  Rect? _lastWindowBounds;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initPlayer();
    _initStreams();
    _startHttpServer();
    _initWindow();
    _fetchBridgeSettings();
  }

  void _initStreams() {
    _durationSubscription = player.stream.duration.listen((d) => setState(() => _duration = d));
    _positionSubscription = player.stream.position.listen((p) => setState(() => _position = p));
    _bufferSubscription = player.stream.buffer.listen((b) => setState(() => _buffer = b));
    _bufferingSubscription = player.stream.buffering.listen((b) => setState(() => _isBuffering = b));
    _volumeSubscription = player.stream.volume.listen((v) => setState(() => _volume = v));
    _rateSubscription = player.stream.rate.listen((r) => setState(() => _playbackSpeed = r));
  }


  Future<void> _fetchBridgeSettings() async {
    try {
      final client = context.read<BridgeApiClient>();
      final appSettings = await client.getAppSettings();
      final playerSettings = await client.getPlayerSettings();
      setState(() {
        _appSettings = appSettings;
        _playerSettings = playerSettings;
        // Apply volume
        player.setVolume(playerSettings.volume * 100);
      });
    } catch (e) {
      debugPrint("Failed to fetch settings from bridge: $e");
    }
  }

  Future<void> _initWindow() async {
    WindowOptions windowOptions = WindowOptions(
      size: const Size(1280, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: widget.title ?? 'FnTV Player',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  Future<void> _startHttpServer() async {
    final router = shelf_router.Router();

    router.post('/play', (Request request) async {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      
      final String url = data['url'];
      final String? title = data['title'];
      final int startPosMs = data['startPos'] ?? 0;

      if (mounted) {
        if (title != null) {
          windowManager.setTitle(title);
        }
        windowManager.show();
        windowManager.focus();
        await _playNewMedia(url, Duration(milliseconds: startPosMs));
      }
      return Response.ok(jsonEncode({'status': 'ok'}));
    });

    try {
      _server = await io.serve(router, InternetAddress.loopbackIPv4, kPlayerPort);
    } catch (e) {
      debugPrint('Failed to start HTTP server: $e');
    }
  }

  Future<void> _playNewMedia(String url, Duration startPosition) async {
    final Completer<void> readyToSeek = Completer<void>();
    final StreamSubscription<Duration> subscription = player.stream.duration.listen((Duration d) {
      if (d > Duration.zero && !readyToSeek.isCompleted) {
        readyToSeek.complete();
      }
    });

    try {
      await player.open(Media(url), play: false);

      if (startPosition > Duration.zero) {
        await readyToSeek.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        );
        await player.seek(startPosition);
      }
    } catch (e) {
      debugPrint('Error during media change: $e');
    } finally {
      await subscription.cancel();
    }

    await player.play();
    _onUserInteraction();
  }

  Future<void> _initPlayer() async {
    if (widget.url != null) {
      await _playNewMedia(widget.url!, widget.startPosition);
    }
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isHovering && player.state.playing && !_isSettingsOpen) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _onUserInteraction() {
    setState(() {
      _showControls = true;
    });
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _hideControlsTimer?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _bufferSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _volumeSubscription?.cancel();
    _rateSubscription?.cancel();
    player.dispose();
    _server?.close();
    super.dispose();
  }

  Future<void> _toggleSmallWindow() async {
    setState(() => _isSmallWindow = !_isSmallWindow);
    if (_isSmallWindow) {
      _lastWindowBounds = await windowManager.getBounds();
      // Load saved bounds from preferences/bridge if available (mock for now)
      // For now, use default small size
      await windowManager.setMinimumSize(const Size(320, 180));
      await windowManager.setSize(const Size(480, 270));
      await windowManager.setAlwaysOnTop(true);
      // Optional: Position bottom right
    } else {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setMinimumSize(const Size(800, 600)); // Restore min size
      if (_lastWindowBounds != null) {
        await windowManager.setBounds(_lastWindowBounds!);
      } else {
        await windowManager.setSize(const Size(1280, 720));
        await windowManager.center();
      }
    }
  }

  void _toggleFullScreen() {
    windowManager.isFullScreen().then((isFull) {
      windowManager.setFullScreen(!isFull);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isSmallWindow) {
      return _buildSmallWindowUI();
    }

    return RawKeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          _onUserInteraction();
          if (event.logicalKey == LogicalKeyboardKey.space) {
            player.playOrPause();
            // Optional: Toast for play/pause?
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
             final seekTo = (_position + const Duration(seconds: 10));
             player.seek(seekTo);
             ToastManager.show(context, "快进至: ${_formatDuration(seekTo)}", category: "seek", icon: Icons.fast_forward);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
             final seekTo = (_position - const Duration(seconds: 10));
             player.seek(seekTo);
             ToastManager.show(context, "快退至: ${_formatDuration(seekTo)}", category: "seek", icon: Icons.fast_rewind);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            final newVol = (_volume + 10).clamp(0.0, 100.0);
            player.setVolume(newVol);
            ToastManager.show(context, "当前音量: ${newVol.toInt()}%", category: "volume", icon: Icons.volume_up);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            final newVol = (_volume - 10).clamp(0.0, 100.0);
            player.setVolume(newVol);
             ToastManager.show(context, "当前音量: ${newVol.toInt()}%", category: "volume", icon: Icons.volume_down);
          } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
             final newVol = _volume > 0 ? 0.0 : 100.0;
             player.setVolume(newVol);
             ToastManager.show(
               context, 
               newVol == 0 ? "静音" : "解除静音: 100%", 
               category: "volume", 
               icon: newVol == 0 ? Icons.volume_off : Icons.volume_up
             );
          } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
            _toggleFullScreen();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
             if (_isSettingsOpen) {
               setState(() => _isSettingsOpen = false);
             } else {
               windowManager.setFullScreen(false);
             }
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onHover: (_) {
            _isHovering = true;
            _onUserInteraction();
          },
          onExit: (_) {
            _isHovering = false;
            _startHideControlsTimer();
          },
          child: Stack(
            children: [
              GestureDetector(
                onTap: () {
                  if (_isSettingsOpen) {
                    setState(() => _isSettingsOpen = false);
                  } else {
                    _onUserInteraction();
                  }
                },
                onDoubleTap: _toggleFullScreen,
                child: Center(
                  child: Video(
                    controller: controller,
                    controls: NoVideoControls,
                  ),
                ),
              ),
              
              // Loading Indicator
              Center(
                child: StreamBuilder<bool>(
                  stream: player.stream.buffering,
                  builder: (context, snapshot) {
                    if (snapshot.data == true) {
                      return const CircularLoadingIndicator();
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),

              // UI Overlay
              if (_showControls) ...[
                // Top Bar
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: DragToMoveArea(
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => exit(0),
                          ),
                          Expanded(
                            child: Text(
                              widget.title ?? 'FnTV Player',
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Bar
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _buildBottomControls(),
                ),
              ],

              // Settings Menu Overlay
              if (_isSettingsOpen)
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: SettingsMenu(
                    player: player,
                    currentAspectRatio: _aspectRatio,
                    currentWindowRatio: _windowRatio,
                    onAspectRatioChanged: (val) {
                      setState(() => _aspectRatio = val);
                      // Apply aspect ratio logic to player/window
                    },
                    onWindowRatioChanged: (val) {
                      setState(() => _windowRatio = val);
                      // Apply window ratio logic
                    },
                    onIntroOutroTap: () {
                      setState(() => _isSettingsOpen = false);
                      _showIntroOutroDialog();
                    },
                    onClose: () => setState(() => _isSettingsOpen = false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsMenu() {
    setState(() => _isSettingsOpen = !_isSettingsOpen);
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress Bar
          StreamBuilder<Duration>(
            stream: player.stream.position,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = player.state.duration;
              final buffer = player.state.buffer;
              
              double progress = 0.0;
              double buffered = 0.0;
              if (duration.inMilliseconds > 0) {
                progress = position.inMilliseconds / duration.inMilliseconds;
                buffered = buffer.inMilliseconds / duration.inMilliseconds;
              }

              return GestureDetector(
                onTapDown: (details) {
                  final box = context.findRenderObject() as RenderBox;
                  final width = box.size.width - 32; // padding
                  final tapPos = details.localPosition.dx;
                  final relative = tapPos / width;
                  final seekMs = relative * duration.inMilliseconds;
                  player.seek(Duration(milliseconds: seekMs.toInt()));
                },
                child: CustomProgressBar(
                  progress: progress,
                  buffered: buffered,
                  progressColor: Theme.of(context).colorScheme.secondary,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          
          // Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Group
              Row(
                children: [
                  StreamBuilder<bool>(
                    stream: player.stream.playing,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return IconButton(
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                        onPressed: player.playOrPause,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay_10, color: Colors.white),
                    onPressed: () {
                       player.seek(_position - const Duration(seconds: 10));
                       ToastManager.show(context, "快退 10s", category: "seek", icon: Icons.fast_rewind);
                    },
                    tooltip: "快退 10s",
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10, color: Colors.white),
                    onPressed: () {
                       player.seek(_position + const Duration(seconds: 10));
                       ToastManager.show(context, "快进 10s", category: "seek", icon: Icons.fast_forward);
                    },
                    tooltip: "快进 10s",
                  ),
                  const SizedBox(width: 8),
                  StreamBuilder<Duration>(
                    stream: player.stream.position,
                    builder: (context, snapshot) {
                      final pos = snapshot.data ?? Duration.zero;
                      final dur = player.state.duration;
                      return Text(
                        "${_formatDuration(pos)} / ${_formatDuration(dur)}", 
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      );
                    },
                  ),
                ],
              ),
              
              // Right Group
              Row(
                children: [
                  // Speed
                  TextButton(
                    onPressed: () {
                      // TODO: Open Speed Flyout
                    },
                    child: Text("${_playbackSpeed}x", style: const TextStyle(color: Colors.white)),
                  ),
                  
                  // Quality
                  TextButton(
                    onPressed: _showQualityMenu,
                    child: const Text("原画质", style: TextStyle(color: Colors.white)),
                  ),
                  
                  // Subtitle
                  IconButton(
                    icon: const Icon(Icons.subtitles, color: Colors.white),
                    onPressed: _showSubtitleMenu,
                  ),
                  
                  // PIP
                  IconButton(
                    icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
                    onPressed: _toggleSmallWindow,
                    tooltip: "小窗模式",
                  ),
                  
                  // Settings (Lottie)
                  LottieIconButton(
                    assetName: 'settings_lottie.json',
                    onTap: () => setState(() => _isSettingsOpen = !_isSettingsOpen),
                    tooltip: "设置",
                  ),
                  
                  // Volume (Lottie)
                  LottieIconButton(
                    assetName: _volume == 0 ? 'volume_off_lottie.json' : 'volume_lottie.json',
                    onTap: () {
                       final newVol = _volume == 0 ? 100.0 : 0.0;
                       player.setVolume(newVol);
                    },
                    tooltip: "音量",
                  ),
                  
                  // Fullscreen (Lottie)
                  LottieIconButton(
                    assetName: _playerSettings?.playerIsFullscreen == true 
                        ? 'quit_full_screen_lottie.json' 
                        : 'full_screen_lottie.json',
                    onTap: _toggleFullScreen,
                    tooltip: "全屏",
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallWindowUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Video(
              controller: controller,
              controls: NoVideoControls,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MouseRegion(
               cursor: SystemMouseCursors.move,
               child: GestureDetector(
                 onPanStart: (details) {
                   windowManager.startDragging();
                 },
                 child: Container(
                  color: Colors.transparent, // Invisible grip area
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.topRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       IconButton(
                         icon: const Icon(Icons.open_in_full, color: Colors.white, size: 20),
                         onPressed: _toggleSmallWindow, // Restore
                         tooltip: "恢复窗口",
                       ),
                       IconButton(
                         icon: const Icon(Icons.close, color: Colors.white, size: 20),
                         onPressed: () => exit(0),
                         tooltip: "关闭",
                       ),
                     ],
                   ),
                 ),
               ),
            ),
          ),
          // Resize handle (bottom right)
          Positioned(
            bottom: 0,
            right: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpLeftDownRight,
              child: GestureDetector(
                onPanStart: (_) => windowManager.startResizing(ResizeEdge.bottomRight),
                child: Container(
                  width: 20,
                  height: 20,
                  color: Colors.transparent,
                  child: const Icon(Icons.drag_handle, color: Colors.white54, size: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showIntroOutroDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Center(
        child: IntroOutroDialog(
          duration: player.state.duration,
          currentPosition: player.state.position,
          initialIntroEndMs: 0, // Load from provider
          initialOutroStartMs: 0, // Load from provider
          onSave: (intro, outro) {
            context.read<IntroOutroProvider>().saveIntroOutro("season_id_placeholder", intro, outro);
            Navigator.pop(ctx);
          },
          onReset: () {
            // Reset logic
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _showQualityMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("画质选择", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(color: Colors.white24, height: 1),
            if (player.state.tracks.video.isEmpty)
               const Padding(padding: EdgeInsets.all(16), child: Text("无可用画质信息", style: TextStyle(color: Colors.white70))),
            ...player.state.tracks.video.map((track) {
              return ListTile(
                title: Text(track.title ?? "${track.w}x${track.h}", style: const TextStyle(color: Colors.white)),
                trailing: player.state.track.video == track ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  player.setVideoTrack(track);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSubtitleMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("字幕选择", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(color: Colors.white24, height: 1),
             ListTile(
                title: const Text("无", style: TextStyle(color: Colors.white)),
                trailing: player.state.track.subtitle == SubtitleTrack.no() ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  player.setSubtitleTrack(SubtitleTrack.no());
                  Navigator.pop(ctx);
                },
              ),
            ...player.state.tracks.subtitle.map((track) {
              return ListTile(
                title: Text(track.title ?? track.language ?? "Unknown", style: const TextStyle(color: Colors.white)),
                trailing: player.state.track.subtitle == track ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  player.setSubtitleTrack(track);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showToast(String message, {IconData? icon}) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 20,
        child: Material(
          color: Colors.transparent,
          child: CustomToast(message: message, icon: icon),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }
}
