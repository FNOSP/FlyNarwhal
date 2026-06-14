import 'dart:async';
import 'dart:io' show Platform;
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_info2/system_info2.dart';
import 'package:media_kit/media_kit.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;

import 'core/utils/index.dart';
import 'providers/providers.dart';
import 'ui/navigation/app_router.dart';
import 'ui/player/pip/pip_window_payload.dart';

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
    );
  }
}
