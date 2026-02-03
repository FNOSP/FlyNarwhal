import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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

final bridgeApiClientProvider = Provider<BridgeApiClient>((ref) => BridgeApiClient());
final introOutroProvider = ChangeNotifierProvider<IntroOutroProvider>((ref) => IntroOutroProvider());

class PlayerUiState {
  final bool isPlayerInitialized;
  final String? initError;
  final bool showControls;
  final bool isHovering;
  final bool isSettingsOpen;
  final String aspectRatio;
  final String windowRatio;
  final bool isSmallWindow;
  final AppSettings? appSettings;
  final bool isBuffering;
  final Duration duration;
  final Duration position;
  final double volume;
  final double playbackSpeed;
  final bool isPlaying;
  final Rect? lastWindowBounds;

  const PlayerUiState({
    this.isPlayerInitialized = false,
    this.initError,
    this.showControls = true,
    this.isHovering = false,
    this.isSettingsOpen = false,
    this.aspectRatio = "默认",
    this.windowRatio = "自动",
    this.isSmallWindow = false,
    this.appSettings,
    this.isBuffering = false,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.isPlaying = false,
    this.lastWindowBounds,
  });

  PlayerUiState copyWith({
    bool? isPlayerInitialized,
    String? initError,
    bool initErrorSet = false,
    bool? showControls,
    bool? isHovering,
    bool? isSettingsOpen,
    String? aspectRatio,
    String? windowRatio,
    bool? isSmallWindow,
    AppSettings? appSettings,
    bool? isBuffering,
    Duration? duration,
    Duration? position,
    double? volume,
    double? playbackSpeed,
    bool? isPlaying,
    Rect? lastWindowBounds,
    bool lastWindowBoundsSet = false,
  }) {
    return PlayerUiState(
      isPlayerInitialized: isPlayerInitialized ?? this.isPlayerInitialized,
      initError: initErrorSet ? initError : this.initError,
      showControls: showControls ?? this.showControls,
      isHovering: isHovering ?? this.isHovering,
      isSettingsOpen: isSettingsOpen ?? this.isSettingsOpen,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      windowRatio: windowRatio ?? this.windowRatio,
      isSmallWindow: isSmallWindow ?? this.isSmallWindow,
      appSettings: appSettings ?? this.appSettings,
      isBuffering: isBuffering ?? this.isBuffering,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isPlaying: isPlaying ?? this.isPlaying,
      lastWindowBounds: lastWindowBoundsSet ? lastWindowBounds : this.lastWindowBounds,
    );
  }
}

class PlayerUiController extends StateNotifier<PlayerUiState> {
  PlayerUiController() : super(const PlayerUiState());

  void setPlayerInitialized(bool value) {
    state = state.copyWith(isPlayerInitialized: value);
  }

  void setInitError(String? error) {
    state = state.copyWith(initError: error, initErrorSet: true);
  }

  void setShowControls(bool value) {
    state = state.copyWith(showControls: value);
  }

  void setHovering(bool value) {
    state = state.copyWith(isHovering: value);
  }

  void setSettingsOpen(bool value) {
    state = state.copyWith(isSettingsOpen: value);
  }

  void setAspectRatio(String value) {
    state = state.copyWith(aspectRatio: value);
  }

  void setWindowRatio(String value) {
    state = state.copyWith(windowRatio: value);
  }

  void setSmallWindow(bool value) {
    state = state.copyWith(isSmallWindow: value);
  }

  void setLastWindowBounds(Rect? bounds) {
    state = state.copyWith(lastWindowBounds: bounds, lastWindowBoundsSet: true);
  }

  void setAppSettings(AppSettings settings) {
    state = state.copyWith(appSettings: settings);
  }

  void updateIntroOutro(int introEndMs, int outroStartMs) {
    final current = state.appSettings;
    if (current == null) return;
    current.introEndMs = introEndMs;
    current.outroStartMs = outroStartMs;
    state = state.copyWith(appSettings: current);
  }

  void setBuffering(bool value) {
    state = state.copyWith(isBuffering: value);
  }

  void setDuration(Duration value) {
    state = state.copyWith(duration: value);
  }

  void setPosition(Duration value) {
    state = state.copyWith(position: value);
  }

  void setVolume(double value) {
    state = state.copyWith(volume: value);
  }

  void setPlaybackSpeed(double value) {
    state = state.copyWith(playbackSpeed: value);
  }

  void setPlaying(bool value) {
    state = state.copyWith(isPlaying: value);
  }
}

final playerUiProvider = StateNotifierProvider<PlayerUiController, PlayerUiState>(
  (ref) => PlayerUiController(),
);

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
    ProviderScope(
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

class _PlayerWindowListener extends WindowListener {}

class PlayerScreen extends HookConsumerWidget {
  final String? url;
  final String? title;
  final Duration startPosition;
  final bool enableWindowManager;
  final bool enablePlayerEngine;

  const PlayerScreen({
    super.key,
    this.url,
    this.title,
    this.startPosition = Duration.zero,
    this.enableWindowManager = true,
    this.enablePlayerEngine = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyboardFocusNode = useMemoized(() => FocusNode());
    final hideControlsTimer = useRef<Timer?>(null);
    final serverRef = useRef<HttpServer?>(null);
    final playerRef = useRef<Player?>(null);
    final controllerRef = useRef<VideoController?>(null);
    final playerInitialized = useRef(false);
    final subscriptionsRef = useRef<List<StreamSubscription>>([]);
    final windowListener = useMemoized(_PlayerWindowListener.new);

    Future<void> fetchBridgeSettings() async {
      if (!enablePlayerEngine) return;
      if (!playerInitialized.value) return;
      try {
        final client = ref.read(bridgeApiClientProvider);
        final appSettings = await client.getAppSettings();
        final playerSettings = await client.getPlayerSettings();
        ref.read(playerUiProvider.notifier).setAppSettings(appSettings);
        playerRef.value?.setVolume(playerSettings.volume * 100.0);
      } catch (e) {
        debugPrint("Failed to fetch settings from bridge: $e");
      }
    }

    Future<void> initWindow() async {
      if (!enableWindowManager) return;
      WindowOptions windowOptions = WindowOptions(
        size: const Size(1280, 720),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        title: title ?? 'FnTV Player',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    void startHideControlsTimer() {
      hideControlsTimer.value?.cancel();
      hideControlsTimer.value = Timer(const Duration(seconds: 3), () {
        final uiState = ref.read(playerUiProvider);
        if (context.mounted && !uiState.isHovering && uiState.isPlaying && !uiState.isSettingsOpen) {
          ref.read(playerUiProvider.notifier).setShowControls(false);
        }
      });
    }

    void onUserInteraction() {
      ref.read(playerUiProvider.notifier).setShowControls(true);
      startHideControlsTimer();
    }

    Future<void> playNewMedia(String url, Duration startPosition) async {
      if (!enablePlayerEngine) return;
      final player = playerRef.value;
      if (player == null) return;
      try {
        await player.open(Media(url), play: false);
        if (startPosition > Duration.zero) {
          await player.seek(startPosition);
        }
        await player.play();
      } catch (e) {
        debugPrint('Error during media change: $e');
      }
      
      onUserInteraction();
    }

    Future<void> initPlayer() async {
      if (url != null) {
        await playNewMedia(url!, startPosition);
      }
      startHideControlsTimer();
    }

    Future<void> startHttpServer() async {
      if (!enableWindowManager) return;
      final router = shelf_router.Router();

      router.post('/play', (Request request) async {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        
        final String url = data['url'];
        final String? title = data['title'];
        final int startPosMs = data['startPos'] ?? 0;

        if (context.mounted && ref.read(playerUiProvider).isPlayerInitialized) {
          if (title != null) {
            windowManager.setTitle(title);
          }
          windowManager.show();
          windowManager.focus();
          await playNewMedia(url, Duration(milliseconds: startPosMs));
        }
        return Response.ok(jsonEncode({'status': 'ok'}));
      });

      try {
        serverRef.value = await io.serve(router.call, InternetAddress.loopbackIPv4, kPlayerPort);
      } catch (e) {
        debugPrint('Failed to start HTTP server: $e');
      }
    }

    useEffect(() {
      if (enableWindowManager) {
        windowManager.addListener(windowListener);
      }

      if (enablePlayerEngine) {
        try {
          final player = Player();
          final controller = VideoController(
            player,
            configuration: const VideoControllerConfiguration(
              enableHardwareAcceleration: true,
            ),
          );
          playerRef.value = player;
          controllerRef.value = controller;
          playerInitialized.value = true;
          ref.read(playerUiProvider.notifier).setPlayerInitialized(true);
          
          subscriptionsRef.value = [
            player.stream.position.listen((p) => ref.read(playerUiProvider.notifier).setPosition(p)),
            player.stream.duration.listen((d) => ref.read(playerUiProvider.notifier).setDuration(d)),
            player.stream.playing.listen((playing) => ref.read(playerUiProvider.notifier).setPlaying(playing)),
            player.stream.buffering.listen((buffering) => ref.read(playerUiProvider.notifier).setBuffering(buffering)),
            player.stream.volume.listen((volume) => ref.read(playerUiProvider.notifier).setVolume(volume / 100.0)),
            player.stream.rate.listen((rate) => ref.read(playerUiProvider.notifier).setPlaybackSpeed(rate)),
            player.stream.error.listen((error) {
               debugPrint("Player Error: $error");
            }),
          ];

          initPlayer();
        } catch (e, stack) {
          ref.read(playerUiProvider.notifier).setInitError(e.toString());
          debugPrint("Error initializing player: $e");
          debugPrint(stack.toString());
        }
      }

      if (enableWindowManager) {
        startHttpServer();
        initWindow();
      }
      if (enablePlayerEngine) {
        fetchBridgeSettings();
      }

      return () {
        if (enableWindowManager) {
          windowManager.removeListener(windowListener);
        }
        hideControlsTimer.value?.cancel();
        keyboardFocusNode.dispose();
        for (var s in subscriptionsRef.value) {
          s.cancel();
        }
        if (playerInitialized.value) {
          playerRef.value?.dispose();
        }
        serverRef.value?.close();
      };
    }, const []);

    Future<void> toggleSmallWindow() async {
      if (!enableWindowManager) return;
      final current = ref.read(playerUiProvider).isSmallWindow;
      final nextValue = !current;
      ref.read(playerUiProvider.notifier).setSmallWindow(nextValue);
      if (nextValue) {
        final bounds = await windowManager.getBounds();
        ref.read(playerUiProvider.notifier).setLastWindowBounds(bounds);
        await windowManager.setMinimumSize(const Size(320, 180));
        await windowManager.setSize(const Size(480, 270));
        await windowManager.setAlwaysOnTop(true);
      } else {
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setMinimumSize(const Size(800, 600));
        final bounds = ref.read(playerUiProvider).lastWindowBounds;
        if (bounds != null) {
          await windowManager.setBounds(bounds);
        } else {
          await windowManager.setSize(const Size(1280, 720));
          await windowManager.center();
        }
      }
    }

    void toggleFullScreen() {
      if (!enableWindowManager) return;
      windowManager.isFullScreen().then((isFull) {
        windowManager.setFullScreen(!isFull);
      });
    }

    double? getAspectRatio() {
      final aspectRatio = ref.read(playerUiProvider).aspectRatio;
      if (aspectRatio == "4:3") return 4/3;
      if (aspectRatio == "16:9") return 16/9;
      if (aspectRatio == "21:9") return 21/9;
      return null;
    }

    String formatDuration(Duration duration) {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      if (duration.inHours > 0) {
        return "${twoDigits(duration.inHours)}:$minutes:$seconds";
      }
      return "$minutes:$seconds";
    }

    void showIntroOutroDialog() {
      final uiState = ref.read(playerUiProvider);
      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (context) => Center(
          child: IntroOutroDialog(
            duration: uiState.duration,
            currentPosition: uiState.position,
            initialIntroEndMs: uiState.appSettings?.introEndMs ?? 0,
            initialOutroStartMs: uiState.appSettings?.outroStartMs ?? 0,
            onSave: (intro, outro) async {
              final client = ref.read(bridgeApiClientProvider);
              await client.updateIntroOutroSettings(intro, outro);
              ref.read(playerUiProvider.notifier).updateIntroOutro(intro, outro);
            },
            onReset: () async {
              final client = ref.read(bridgeApiClientProvider);
              await client.updateIntroOutroSettings(0, 0);
              ref.read(playerUiProvider.notifier).updateIntroOutro(0, 0);
            },
          ),
        ),
      );
    }

    Widget buildSmallWindowUI(Player player, VideoController controller) {
      final uiState = ref.watch(playerUiProvider);
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: MouseRegion(
          onHover: (_) => onUserInteraction(),
          child: Stack(
            children: [
              GestureDetector(
                onPanStart: (_) => windowManager.startDragging(),
                onDoubleTap: toggleSmallWindow,
                child: Video(
                  controller: controller,
                  controls: (state) => const SizedBox.shrink(),
                ),
              ),
              if (uiState.showControls)
                Positioned(
                  top: 8, right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: toggleSmallWindow,
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget buildBottomControls(Player player) {
      final uiState = ref.watch(playerUiProvider);
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
                final progress = uiState.duration.inMilliseconds > 0 
                  ? uiState.position.inMilliseconds / uiState.duration.inMilliseconds 
                  : 0.0;
                final buffered = uiState.duration.inMilliseconds > 0 
                  ? player.state.buffer.inMilliseconds / uiState.duration.inMilliseconds 
                  : 0.0;

                return GestureDetector(
                  onTapDown: (details) {
                    final box = context.findRenderObject() as RenderBox;
                    final width = box.size.width - 32;
                    final tapPos = details.localPosition.dx;
                    final relative = tapPos / width;
                    final seekMs = relative * uiState.duration.inMilliseconds;
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
                    IconButton(
                      icon: Icon(uiState.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                      onPressed: () => player.playOrPause(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                      onPressed: () {
                         final seekTo = uiState.position - const Duration(seconds: 10);
                         player.seek(seekTo);
                         ToastManager.show(context, "快退 10s", category: "seek", icon: Icons.fast_rewind);
                      },
                      tooltip: "快退 10s",
                    ),
                    IconButton( 
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                      onPressed: () {
                         final seekTo = uiState.position + const Duration(seconds: 10);
                         player.seek(seekTo);
                         ToastManager.show(context, "快进 10s", category: "seek", icon: Icons.fast_forward);
                      },
                      tooltip: "快进 10s",
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${formatDuration(uiState.position)} / ${formatDuration(uiState.duration)}", 
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
                
                // Right Group
                Row(
                  children: [
                    // Speed
                    SpeedControlFlyout(
                      currentSpeed: uiState.playbackSpeed,
                      onSpeedChanged: (speed) {
                        player.setRate(speed);
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
                      onPressed: toggleSmallWindow,
                      tooltip: "小窗模式",
                    ),
                    
                    // Settings (Lottie)
                    FlyoutMenu(
                      isOpen: uiState.isSettingsOpen,
                      openOnHover: true,
                      onOpen: () => ref.read(playerUiProvider.notifier).setSettingsOpen(true),
                      onDismiss: () => ref.read(playerUiProvider.notifier).setSettingsOpen(false),
                      offset: const Offset(0, -10),
                      flyout: SettingsMenu(
                        player: player,
                        currentAspectRatio: uiState.aspectRatio,
                        currentWindowRatio: uiState.windowRatio,
                        onAspectRatioChanged: (val) {
                          ref.read(playerUiProvider.notifier).setAspectRatio(val);
                        },
                        onWindowRatioChanged: (val) {
                          ref.read(playerUiProvider.notifier).setWindowRatio(val);
                        },
                        onIntroOutroTap: () {
                          ref.read(playerUiProvider.notifier).setSettingsOpen(false);
                          showIntroOutroDialog();
                        },
                        onClose: () => ref.read(playerUiProvider.notifier).setSettingsOpen(false),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: LottieIconButton(
                          assetName: 'settings_lottie.json',
                          onTap: () {
                            if (!uiState.isSettingsOpen) {
                              ref.read(playerUiProvider.notifier).setSettingsOpen(true);
                            }
                          },
                          animate: uiState.isSettingsOpen,
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

    final uiState = ref.watch(playerUiProvider);
    final player = playerRef.value;
    final controller = controllerRef.value;

    if (!uiState.isPlayerInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (uiState.initError != null) ...[
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text("播放器初始化失败", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(uiState.initError!, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
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

    if (uiState.isSmallWindow) {
      if (player == null || controller == null) {
        return const SizedBox.shrink();
      }
      return buildSmallWindowUI(player, controller);
    }

    return KeyboardListener(
      focusNode: keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          onUserInteraction();
          if (player == null) return;
          if (event.logicalKey == LogicalKeyboardKey.space) {
            player.playOrPause();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
             final seekTo = (uiState.position + const Duration(seconds: 10));
             player.seek(seekTo);
             ToastManager.show(context, "快进至: ${formatDuration(seekTo)}", category: "seek", icon: Icons.fast_forward);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
             final seekTo = (uiState.position - const Duration(seconds: 10));
             player.seek(seekTo);
             ToastManager.show(context, "快退至: ${formatDuration(seekTo)}", category: "seek", icon: Icons.fast_rewind);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            final newVol = (uiState.volume * 100 + 10).clamp(0.0, 100.0);
            player.setVolume(newVol);
            ToastManager.show(context, "当前音量: ${newVol.toInt()}%", category: "volume", icon: Icons.volume_up);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            final newVol = (uiState.volume * 100 - 10).clamp(0.0, 100.0);
            player.setVolume(newVol);
             ToastManager.show(context, "当前音量: ${newVol.toInt()}%", category: "volume", icon: Icons.volume_down);
          } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
             final newVol = uiState.volume > 0 ? 0.0 : 100.0;
             player.setVolume(newVol);
             ToastManager.show(
               context, 
               newVol == 0 ? "静音" : "解除静音: 100%", 
               category: "volume", 
               icon: newVol == 0 ? Icons.volume_off : Icons.volume_up
             );
          } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
            toggleFullScreen();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
             if (uiState.isSettingsOpen) {
               ref.read(playerUiProvider.notifier).setSettingsOpen(false);
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
            ref.read(playerUiProvider.notifier).setHovering(true);
            onUserInteraction();
          },
          onExit: (_) {
            ref.read(playerUiProvider.notifier).setHovering(false);
            startHideControlsTimer();
          },
          child: Stack(
            children: [
              GestureDetector(
                onTap: () {
                  if (uiState.isSettingsOpen) {
                    ref.read(playerUiProvider.notifier).setSettingsOpen(false);
                  } else {
                    onUserInteraction();
                  }
                },
                onDoubleTap: toggleFullScreen,
                child: Center(
                  child: controller == null
                      ? const SizedBox.shrink()
                      : Video(
                          controller: controller,
                          aspectRatio: getAspectRatio(),
                          controls: (state) => const SizedBox.shrink(),
                        ),
                ),
              ),
              
              // Loading Indicator
              if (uiState.isBuffering)
                const Center(
                  child: CircularLoadingIndicator(),
                ),

              // UI Overlay
              if (uiState.showControls) ...[
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
                              title ?? 'FnTV Player',
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
                  child: player == null
                      ? const SizedBox.shrink()
                      : buildBottomControls(player),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
