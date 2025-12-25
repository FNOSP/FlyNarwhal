import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'dart:io';
import 'dart:async';
import 'dart:convert';

const int kPlayerPort = 47920;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();

  String? url;
  String? title;
  Duration startPosition = Duration.zero;

  if (args.isNotEmpty) {
    print('Arguments received: $args');
    url = args[0];
    if (args.length > 1) {
      title = args[1];
    }
    if (args.length > 2) {
      try {
        final posMs = int.parse(args[2]);
        startPosition = Duration(milliseconds: posMs);
        print('Parsed start position: $startPosition ($posMs ms)');
      } catch (e) {
        print('Error parsing start position: $e');
      }
    }
  }

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PlayerScreen(url: url, title: title, startPosition: startPosition),
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.blueAccent,
        ),
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

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initPlayer();
    _startHttpServer();
    _initWindow();
  }

  Future<void> _initWindow() async {
    // Window configuration
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

      print('Received play request via HTTP: $url, title: $title, startPos: $startPosMs');

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
      print('HTTP server listening on port ${_server!.port}');
    } catch (e) {
      print('Failed to start HTTP server: $e');
    }
  }

  Future<void> _playNewMedia(String url, Duration startPosition) async {
    // Set up a subscription to wait for the player to be ready to seek
    final Completer<void> readyToSeek = Completer<void>();
    final StreamSubscription<Duration> subscription = player.stream.duration.listen((Duration d) {
      if (d > Duration.zero && !readyToSeek.isCompleted) {
        readyToSeek.complete();
      }
    });

    try {
      await player.open(Media(url), play: false);

      if (startPosition > Duration.zero) {
        print('Waiting for metadata/duration to be ready for seeking...');
        await readyToSeek.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('Timeout waiting for duration metadata, proceeding with seek');
          },
        );
        
        print('Seeking to $startPosition');
        await player.seek(startPosition);
      }
    } catch (e) {
      print('Error during media change: $e');
    } finally {
      await subscription.cancel();
    }

    await player.play();
    _onUserInteraction();
  }

  Future<void> _initPlayer() async {
    print('Initializing player with URL: ${widget.url} at ${widget.startPosition}');
    if (widget.url != null) {
      await _playNewMedia(widget.url!, widget.startPosition);
    }
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isHovering && player.state.playing) {
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
    player.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() {
    player.dispose();
    super.onWindowClose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      _onUserInteraction();
      if (event.logicalKey == LogicalKeyboardKey.space) {
        player.playOrPause();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        player.seek(player.state.position - const Duration(seconds: 10));
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        player.seek(player.state.position + const Duration(seconds: 10));
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
         windowManager.isFullScreen().then((isFull) {
           if (isFull) {
             windowManager.setFullScreen(false);
           } else {
             // Maybe minimize or close?
             // windowManager.close(); 
           }
         });
      } else if (event.logicalKey == LogicalKeyboardKey.f11 || 
                 (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.enter)) {
        _toggleFullScreen();
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
    return RawKeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKey: _handleKeyEvent,
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
                onTap: _onUserInteraction,
                onDoubleTap: _toggleFullScreen,
                child: Center(
                  child: Video(
                    controller: controller,
                    controls: NoVideoControls,
                  ),
                ),
              ),
              // Draggable area at the top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: DragToMoveArea(
                  child: Container(
                    height: 50,
                    color: Colors.transparent,
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: !_showControls,
                child: _buildControlsOverlay(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Stack(
        children: [
          // Title Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => exit(0),
                    ),
                    Expanded(
                      child: Text(
                        widget.title ?? 'FnTV Player',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 100), // Space for window controls if needed
                  ],
                ),
              ),
            ),
          ),

          // Center Play Button (only when paused)
          Center(
            child: StreamBuilder<bool>(
              stream: player.stream.playing,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? false;
                if (isPlaying) return const SizedBox.shrink();
                return IconButton(
                  iconSize: 80,
                  icon: Icon(
                    Icons.play_circle_filled,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  onPressed: player.play,
                );
              },
            ),
          ),
          
          // Buffering Indicator
          Center(
            child: StreamBuilder<bool>(
              stream: player.stream.buffering,
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return const CircularProgressIndicator(color: Colors.white);
                }
                return const SizedBox.shrink();
              },
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
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
                      return Row(
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(color: Colors.white),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                activeTrackColor: Colors.blueAccent,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                                min: 0,
                                max: duration.inMilliseconds.toDouble(),
                                onChanged: (value) {
                                  _onUserInteraction();
                                  player.seek(Duration(milliseconds: value.toInt()));
                                },
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      );
                    },
                  ),
                  
                  // Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          StreamBuilder<bool>(
                            stream: player.stream.playing,
                            builder: (context, snapshot) {
                              final isPlaying = snapshot.data ?? false;
                              return IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                onPressed: player.playOrPause,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          // Volume Control
                          StreamBuilder<double>(
                            stream: player.stream.volume,
                            builder: (context, snapshot) {
                              final volume = snapshot.data ?? 100.0;
                              return Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      volume == 0 ? Icons.volume_off : Icons.volume_up,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                       if (volume > 0) {
                                         player.setVolume(0);
                                       } else {
                                         player.setVolume(100);
                                       }
                                    },
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                        trackHeight: 2,
                                      ),
                                      child: Slider(
                                        value: volume,
                                        min: 0,
                                        max: 100,
                                        onChanged: (v) {
                                          player.setVolume(v);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.fullscreen, color: Colors.white),
                            onPressed: _toggleFullScreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
