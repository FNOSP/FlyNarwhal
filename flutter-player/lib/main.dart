import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
import 'ui/components/speed_control_flyout.dart';

const int kPlayerPort = 47922;

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
  late final Player _player;
  late final VideoController _controller;
  bool _isPlayerInitialized = false;
  String? _initError;
  final FocusNode _keyboardFocusNode = FocusNode();
  
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

  // Player State
  bool _isBuffering = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  bool _isPlaying = false;

  // Small Window State
  Rect? _lastWindowBounds;

  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    
    try {
      _player = Player();
      _controller = VideoController(
        _player,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );
      _isPlayerInitialized = true;
      
      _subscriptions.addAll([
        _player.stream.position.listen((p) => setState(() => _position = p)),
        _player.stream.duration.listen((d) => setState(() => _duration = d)),
        _player.stream.playing.listen((playing) => setState(() => _isPlaying = playing)),
        _player.stream.buffering.listen((buffering) => setState(() => _isBuffering = buffering)),
        _player.stream.volume.listen((volume) => setState(() => _volume = volume / 100.0)),
        _player.stream.rate.listen((rate) => setState(() => _playbackSpeed = rate)),
        _player.stream.error.listen((error) {
           debugPrint("Player Error: $error");
           // Show error to user if needed
        }),
      ]);

      _initPlayer();
     } catch (e, stack) {
       setState(() {
         _initError = e.toString();
       });
       debugPrint("Error initializing player: $e");
       debugPrint(stack.toString());
     }

    _startHttpServer();
    _initWindow();
    _fetchBridgeSettings();
  }

  Future<void> _fetchBridgeSettings() async {
    try {
      final client = context.read<BridgeApiClient>();
      final appSettings = await client.getAppSettings();
      final playerSettings = await client.getPlayerSettings();
      setState(() {
        _appSettings = appSettings;
        // Apply volume (media_kit volume is 0.0 to 100.0)
        _player.setVolume(playerSettings.volume * 100.0);
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

      if (mounted && _isPlayerInitialized) {
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
      _server = await io.serve(router.call, InternetAddress.loopbackIPv4, kPlayerPort);
    } catch (e) {
      debugPrint('Failed to start HTTP server: $e');
    }
  }

  Future<void> _playNewMedia(String url, Duration startPosition) async {
    try {
      await _player.open(Media(url), play: false);
      if (startPosition > Duration.zero) {
        await _player.seek(startPosition);
      }
      await _player.play();
    } catch (e) {
      debugPrint('Error during media change: $e');
    }
    
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
      if (mounted && !_isHovering && _isPlaying && !_isSettingsOpen) {
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
    _keyboardFocusNode.dispose();
    for (var s in _subscriptions) {
      s.cancel();
    }
    if (_isPlayerInitialized) {
      _player.dispose();
    }
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

  double? _getAspectRatio() {
    if (_aspectRatio == "4:3") return 4/3;
    if (_aspectRatio == "16:9") return 16/9;
    if (_aspectRatio == "21:9") return 21/9;
    return null; // Default behavior
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  void _showIntroOutroDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Center(
        child: IntroOutroDialog(
          duration: _duration,
          currentPosition: _position,
          initialIntroEndMs: _appSettings?.introEndMs ?? 0,
          initialOutroStartMs: _appSettings?.outroStartMs ?? 0,
          onSave: (intro, outro) async {
            final client = context.read<BridgeApiClient>();
            await client.updateIntroOutroSettings(intro, outro);
            setState(() {
              _appSettings?.introEndMs = intro;
              _appSettings?.outroStartMs = outro;
            });
          },
          onReset: () async {
            final client = context.read<BridgeApiClient>();
            await client.updateIntroOutroSettings(0, 0);
            setState(() {
              _appSettings?.introEndMs = 0;
              _appSettings?.outroStartMs = 0;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSmallWindowUI() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onHover: (_) => _onUserInteraction(),
        child: Stack(
          children: [
            GestureDetector(
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: _toggleSmallWindow,
              child: Video(
                controller: _controller,
                controls: (state) => const SizedBox.shrink(),
              ),
            ),
            if (_showControls)
              Positioned(
                top: 8, right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: _toggleSmallWindow,
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlayerInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_initError != null) ...[
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text("播放器初始化失败", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(_initError!, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                ),
              ] else ...[
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                const Text("正在初始化播放器...", style: TextStyle(color: Colors.white)),
              ],
            ],
          ),
        ),
      );
    }

    if (_isSmallWindow) {
      return _buildSmallWindowUI();
    }

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          _onUserInteraction();
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _player.playOrPause();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
             final seekTo = (_position + const Duration(seconds: 10));
             _player.seek(seekTo);
             ToastManager.show(context, "快进至: ${_formatDuration(seekTo)}", category: "seek", icon: Icons.fast_forward);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
             final seekTo = (_position - const Duration(seconds: 10));
             _player.seek(seekTo);
             ToastManager.show(context, "快退至: ${_formatDuration(seekTo)}", category: "seek", icon: Icons.fast_rewind);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            final newVol = (_volume * 100 + 10).clamp(0.0, 100.0);
            _player.setVolume(newVol);
            ToastManager.show(context, "当前音量: ${newVol.toInt()}%", category: "volume", icon: Icons.volume_up);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            final newVol = (_volume * 100 - 10).clamp(0.0, 100.0);
            _player.setVolume(newVol);
             ToastManager.show(context, "当前音量: ${newVol.toInt()}%", category: "volume", icon: Icons.volume_down);
          } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
             final newVol = _volume > 0 ? 0.0 : 100.0;
             _player.setVolume(newVol);
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
                    controller: _controller,
                    aspectRatio: _getAspectRatio(),
                    controls: (state) => const SizedBox.shrink(),
                  ),
                ),
              ),
              
              // Loading Indicator
              if (_isBuffering)
                const Center(
                  child: CircularLoadingIndicator(),
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
                          colors: [Colors.black.withAlpha(204), Colors.transparent],
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withAlpha(230), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress Bar
          Builder(
            builder: (context) {
              final progress = _duration.inMilliseconds > 0 
                ? _position.inMilliseconds / _duration.inMilliseconds 
                : 0.0;
              final buffered = _duration.inMilliseconds > 0 
                ? _player.state.buffer.inMilliseconds / _duration.inMilliseconds 
                : 0.0;

              return GestureDetector(
                onTapDown: (details) {
                  final box = context.findRenderObject() as RenderBox;
                  final width = box.size.width - 32; // padding
                  final tapPos = details.localPosition.dx;
                  final relative = tapPos / width;
                  final seekMs = relative * _duration.inMilliseconds;
                  _player.seek(Duration(milliseconds: seekMs.toInt()));
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
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                    onPressed: () => _player.playOrPause(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay_10, color: Colors.white),
                    onPressed: () {
                       final seekTo = _position - const Duration(seconds: 10);
                       _player.seek(seekTo);
                       ToastManager.show(context, "快退 10s", category: "seek", icon: Icons.fast_rewind);
                    },
                    tooltip: "快退 10s",
                  ),
                  IconButton( 
                    icon: const Icon(Icons.forward_10, color: Colors.white),
                    onPressed: () {
                       final seekTo = _position + const Duration(seconds: 10);
                       _player.seek(seekTo);
                       ToastManager.show(context, "快进 10s", category: "seek", icon: Icons.fast_forward);
                    },
                    tooltip: "快进 10s",
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${_formatDuration(_position)} / ${_formatDuration(_duration)}", 
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
              
              // Right Group
              Row(
                children: [
                  // Speed
                  SpeedControlFlyout(
                    currentSpeed: _playbackSpeed,
                    onSpeedChanged: (speed) {
                      _player.setRate(speed);
                      ToastManager.show(context, "播放速度: ${speed}x", category: "speed");
                    },
                  ),
                  
                  // Quality (Placeholder)
                  TextButton(
                    onPressed: () => ToastManager.show(context, "暂不支持切换画质"),
                    child: const Text("原画质", style: TextStyle(color: Colors.white)),
                  ),
                  
                  // Subtitle (Placeholder)
                  IconButton(
                    icon: const Icon(Icons.subtitles, color: Colors.white),
                    onPressed: () => ToastManager.show(context, "暂不支持字幕设置"),
                  ),
                  
                  // PIP
                  IconButton(
                    icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
                    onPressed: _toggleSmallWindow,
                    tooltip: "小窗模式",
                  ),
                  
                  // Settings (Lottie)
                  FlyoutMenu(
                    isOpen: _isSettingsOpen,
                    openOnHover: true,
                    onOpen: () => setState(() => _isSettingsOpen = true),
                    onDismiss: () => setState(() => _isSettingsOpen = false),
                    offset: const Offset(0, -10),
                    flyout: SettingsMenu(
                      player: _player,
                      currentAspectRatio: _aspectRatio,
                      currentWindowRatio: _windowRatio,
                      onAspectRatioChanged: (val) {
                        setState(() => _aspectRatio = val);
                      },
                      onWindowRatioChanged: (val) {
                        setState(() => _windowRatio = val);
                      },
                      onIntroOutroTap: () {
                        setState(() => _isSettingsOpen = false);
                        _showIntroOutroDialog();
                      },
                      onClose: () => setState(() => _isSettingsOpen = false),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: LottieIconButton(
                        assetName: 'settings_lottie.json',
                        onTap: () {
                          if (!_isSettingsOpen) {
                            setState(() => _isSettingsOpen = true);
                          }
                        },
                        animate: _isSettingsOpen,
                        tooltip: "设置",
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
