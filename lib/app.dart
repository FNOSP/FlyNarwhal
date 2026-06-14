import 'dart:async';
import 'dart:io' show Platform;
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_info2/system_info2.dart';
import 'package:media_kit/media_kit.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;

import 'core/utils/index.dart';
import 'providers/providers.dart';
import 'ui/navigation/app_router.dart';
import 'ui/player/pip/pip_window_channel.dart';
import 'ui/player/pip/pip_window_payload.dart';
import 'ui/player/player_manager.dart';
import 'ui/screens/player/pip_player_window.dart';

Future<void> bootstrapApp({
  DesktopWindowBootstrapArgs? windowArgs,
  String? currentWindowId,
}) async {
  // Keep the whole bootstrap chain inside one guarded zone.
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final bootstrapContext = await _resolveWindowBootstrapContext(
      windowArgs: windowArgs,
      currentWindowId: currentWindowId,
    );
    final talker = await AppTalker.initialize();

    // Register global Flutter and platform error hooks before app startup.
    await setupErrorHooks(talker);

    AppTalker.info('Bootstrap', 'Bootstrap start');

    // Initialize MediaKit before any player widgets are built.
    MediaKit.ensureInitialized();
    AppTalker.info('Bootstrap', 'MediaKit initialized');

    // Apply desktop-only window initialization and cache tuning.
    if (_isDesktopPlatform()) {
      AppTalker.info('Window', 'Desktop initialization start');
      final freeMemoryBytes = SysInfo.getFreePhysicalMemory();
      if (freeMemoryBytes > 0) {
        PaintingBinding.instance.imageCache.maximumSizeBytes =
            (freeMemoryBytes * 0.05).round();
      }

      await acrylic.Window.initialize();

      if (Platform.isWindows &&
          bootstrapContext.windowArgs.type == DesktopWindowType.main) {
        await acrylic.Window.hideWindowControls();
      }

      await windowManager.ensureInitialized();

      if (bootstrapContext.windowArgs.type == DesktopWindowType.main) {
        const logicalWidth = 1280.0;
        const logicalHeight = 720.0;
        const windowOptions = WindowOptions(
          title: '飞鲸影视',
          size: Size(logicalWidth, logicalHeight),
          center: true,
          titleBarStyle: TitleBarStyle.hidden,
        );

        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager
              .setMinimumSize(const Size(logicalWidth, logicalHeight));
          await windowManager.show();
          await windowManager.focus();
        });
      }
      AppTalker.info('Window', 'Desktop initialization complete');
    }

    // Load persisted app preferences before creating providers.
    final prefs = await SharedPreferences.getInstance();
    AppTalker.info('Prefs', 'SharedPreferences ready');

    // Start the widget tree after all startup services are prepared.
    AppTalker.info('Bootstrap', 'runApp start');
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MyApp(
          windowArgs: bootstrapContext.windowArgs,
          currentWindowId: bootstrapContext.currentWindowId,
        ),
      ),
    );
  }, (error, stackTrace) {
    AppTalker.instance.handle(error, stackTrace);
  });
}

class _WindowBootstrapContext {
  final DesktopWindowBootstrapArgs windowArgs;
  final String currentWindowId;

  const _WindowBootstrapContext({
    required this.windowArgs,
    required this.currentWindowId,
  });
}

Future<_WindowBootstrapContext> _resolveWindowBootstrapContext({
  DesktopWindowBootstrapArgs? windowArgs,
  String? currentWindowId,
}) async {
  // Resolve the current engine metadata inside the same zone as runApp.
  final windowController = await WindowController.fromCurrentEngine();
  return _WindowBootstrapContext(
    windowArgs: windowArgs ??
        DesktopWindowBootstrapArgs.tryParse(windowController.arguments),
    currentWindowId: currentWindowId ?? windowController.windowId,
  );
}

bool _isDesktopPlatform() {
  return !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
}

class MyApp extends ConsumerWidget {
  final DesktopWindowBootstrapArgs windowArgs;
  final String currentWindowId;

  const MyApp({
    super.key,
    required this.windowArgs,
    required this.currentWindowId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final platformBrightness = MediaQuery.of(context).platformBrightness;
    final isDark = settings.followSystemTheme
        ? platformBrightness == Brightness.dark
        : settings.darkMode;

    if (windowArgs.type == DesktopWindowType.pip &&
        windowArgs.pipPayload != null) {
      return FluentApp(
        title: '飞鲸影视 - 画中画',
        debugShowCheckedModeBanner: false,
        theme: FluentThemeData(
          brightness: isDark ? Brightness.dark : Brightness.light,
          accentColor: Colors.blue,
        ),
        home: PipPlayerWindowScreen(
          payload: windowArgs.pipPayload!,
          currentWindowId: currentWindowId,
        ),
      );
    }

    final router = ref.watch(routerProvider);
    return FluentApp.router(
      title: '飞鲸影视',
      debugShowCheckedModeBanner: false,
      theme: FluentThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        accentColor: Colors.blue,
      ),
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      routeInformationProvider: router.routeInformationProvider,
      builder: (context, child) {
        return _MainWindowBridgeHost(
          router: router,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _MainWindowBridgeHost extends ConsumerStatefulWidget {
  final GoRouter router;
  final Widget child;

  const _MainWindowBridgeHost({
    required this.router,
    required this.child,
  });

  @override
  ConsumerState<_MainWindowBridgeHost> createState() =>
      _MainWindowBridgeHostState();
}

class _MainWindowBridgeHostState extends ConsumerState<_MainWindowBridgeHost> {
  @override
  void initState() {
    super.initState();
    // Keep the main window ready to receive PiP lifecycle events.
    unawaited(PipWindowChannel.register(_handleWindowCall));
  }

  @override
  void dispose() {
    unawaited(PipWindowChannel.register(null));
    super.dispose();
  }

  Future<dynamic> _handleWindowCall(MethodCall call) async {
    AppTalker.info('PiP', 'Main window received ${call.method}');
    if (call.method == PipWindowChannelMethod.closePip) {
      final playerManager = ref.read(playerManagerProvider.notifier);
      playerManager.clearPendingRestorePayload();
      playerManager.clearPipState();
      // Restore the hidden main window when PiP closes without re-entering player.
      if (_isDesktopPlatform()) {
        await windowManager.show();
        await windowManager.focus();
      }
      return null;
    }
    if (call.method == PipWindowChannelMethod.enterPipAck) {
      ref.read(playerManagerProvider.notifier).markPipWindowReady();
      return null;
    }
    if (call.method == PipWindowChannelMethod.syncBounds) {
      final arguments = Map<String, dynamic>.from(
        call.arguments as Map<dynamic, dynamic>? ?? const <String, dynamic>{},
      );
      final bounds = PipWindowBounds.fromJson(arguments);
      await ref.read(playerSettingsManagerProvider).setPipWindowBounds(
            bounds.toRect(),
          );
      return null;
    }
    if (call.method != PipWindowChannelMethod.restoreMainPlayer) {
      return null;
    }
    final arguments = Map<String, dynamic>.from(
      call.arguments as Map<dynamic, dynamic>? ?? const <String, dynamic>{},
    );
    final payload = PipWindowPayload.fromJson(arguments);
    if (payload.guid.isEmpty) {
      return null;
    }
    final playerManager = ref.read(playerManagerProvider.notifier);
    playerManager.setPendingRestorePayload(payload);
    playerManager.clearPipState();

    // Restore the hidden main window before routing back into the player.
    if (_isDesktopPlatform()) {
      await windowManager.show();
      await windowManager.focus();
    }

    // Reopen the main player route with PiP progress as the resume source.
    final uri = Uri(
      path: '/player/${payload.guid}',
      queryParameters: <String, String>{
        if (payload.mediaGuid != null && payload.mediaGuid!.isNotEmpty)
          'media_guid': payload.mediaGuid!,
        if (payload.audioGuid != null && payload.audioGuid!.isNotEmpty)
          'audio_guid': payload.audioGuid!,
        if (payload.subtitleGuid != null && payload.subtitleGuid!.isNotEmpty)
          'subtitle_guid': payload.subtitleGuid!,
        'start_ms': payload.startPositionMs.toString(),
      },
    );
    widget.router.go(uri.toString());
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
