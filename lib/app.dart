import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_info2/system_info2.dart';
import 'package:media_kit/media_kit.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'core/config/runtime_configuration.dart';
import 'core/config/secret_bridge_selector.dart';
import 'core/security/password_cipher.dart';
import 'core/window/desktop_display_service.dart';
import 'core/window/window_geometry.dart';
import 'data/storage/main_window_settings_store.dart';
import 'core/utils/index.dart';
import 'data/storage/account_settings_store.dart';
import 'data/storage/kmp_preferences_migration_service.dart';
import 'data/storage/kmp_windows_preferences_reader.dart';
import 'data/storage/update_settings_store.dart';
import 'providers/providers.dart';
import 'providers/reporting_providers.dart';
import 'providers/update_providers.dart';
import 'services/update/update_scheduler.dart';
import 'services/window/main_window_lifecycle_controller.dart';
import 'ui/navigation/app_router.dart';
import 'ui/shared/toast.dart';

MainWindowLifecycleController? mainWindowLifecycleController;

Future<void> bootstrapApp() async {
  // Keep the whole bootstrap chain inside one guarded zone.
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await LiquidGlassWidgets.initialize();
    final talker = await AppTalker.initialize();

    // Register global Flutter and platform error hooks before app startup.
    await setupErrorHooks(talker);

    AppTalker.info('Bootstrap', 'Bootstrap start');

    // Initialize MediaKit before any player widgets are built.
    MediaKit.ensureInitialized();
    AppTalker.info('Bootstrap', 'MediaKit initialized');

    // Preferences are needed before the desktop window is shown so its saved
    // geometry can be validated against the current display arrangement.
    final prefs = await SharedPreferences.getInstance();
    AppTalker.info('Prefs', 'SharedPreferences ready');

    // Apply desktop-only window initialization and cache tuning.
    if (_isDesktopPlatform()) {
      AppTalker.info('Window', 'Desktop initialization start');
      final freeMemoryBytes = SysInfo.getFreePhysicalMemory();
      if (freeMemoryBytes > 0) {
        PaintingBinding.instance.imageCache.maximumSizeBytes =
            (freeMemoryBytes * 0.05).round();
      }

      await acrylic.Window.initialize();

      if (Platform.isWindows) {
        await acrylic.Window.hideWindowControls();
      }

      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(true);

      const defaultWindowSize = Size(1280, 720);
      // Smallest size the user may shrink the main (non-player) window to.
      const mainWindowMinimumSize = Size(800, 450);
      final savedState = MainWindowSettingsStore(prefs).read();

      // Displays are resolved regardless of whether saved geometry exists:
      // they validate restored bounds and shrink the default size on screens
      // whose scaled work area is smaller than 1280x720 so the window never
      // overflows the visible area.
      List<DesktopDisplayGeometry> displays = const [];
      try {
        displays = await const DesktopDisplayService().getDisplays();
      } catch (error, stackTrace) {
        AppTalker.warning('Window', 'Display discovery failed: $error');
        AppTalker.instance.handle(error, stackTrace);
      }

      Rect? restoredBounds;
      if (savedState != null) {
        restoredBounds = WindowGeometry.normalizeMainWindowBounds(
          savedState.bounds,
          displays,
          fallbackSize: defaultWindowSize,
          minimumSize: mainWindowMinimumSize,
        );
      }

      // Startup size for launches without restorable geometry: the default
      // size with any axis exceeding the primary display's scaled work area
      // shrunk to fit it (e.g. a portrait 1080p screen starts at
      // 1080x720 instead of overflowing).
      final startupSize = WindowGeometry.fitSizeToWorkArea(
        defaultWindowSize,
        displays,
      );
      // The minimum follows the same rule so displays with a smaller scaled
      // work area never end up with a minimum larger than the visible area.
      final minimumSize = WindowGeometry.fitSizeToWorkArea(
        mainWindowMinimumSize,
        displays,
      );
      AppTalker.info(
        'Window',
        'Startup size ${startupSize.width.toStringAsFixed(0)}x'
            '${startupSize.height.toStringAsFixed(0)} '
            '(default ${defaultWindowSize.width.toStringAsFixed(0)}x'
            '${defaultWindowSize.height.toStringAsFixed(0)}, '
            'minimum ${minimumSize.width.toStringAsFixed(0)}x'
            '${minimumSize.height.toStringAsFixed(0)}, '
            'displays=${displays.length}, restored=$restoredBounds)',
      );

      final windowOptions = WindowOptions(
        title: '飞鲸影视',
        size: restoredBounds?.size ?? startupSize,
        center: restoredBounds == null,
        titleBarStyle: TitleBarStyle.hidden,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setMinimumSize(minimumSize);
        if (restoredBounds != null) {
          await windowManager.setBounds(restoredBounds);
        }
        if (savedState?.isMaximized == true) {
          await windowManager.maximize();
        }
        await windowManager.show();
        await windowManager.focus();
      });
      mainWindowLifecycleController = MainWindowLifecycleController(prefs)
        ..start();
      AppTalker.info('Window', 'Desktop initialization complete');
    }

    // Run the idempotent KMP migration before providers access preferences.
    if (!kIsWeb && Platform.isWindows) {
      await _runKmpMigration(prefs);
    }
    await UpdateSettingsStore(prefs).initialize();

    // Start the widget tree after all startup services are prepared.
    AppTalker.info('Bootstrap', 'runApp start');
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const _UpdateSchedulerHost(child: MyApp()),
      ),
    );
  }, (error, stackTrace) {
    AppTalker.instance.handle(error, stackTrace);
  });
}

/// Migrates KMP preferences without allowing a legacy-data issue to block UI.
Future<void> _runKmpMigration(SharedPreferences preferences) async {
  try {
    final accountSettingsStore = AccountSettingsStore(preferences);
    await accountSettingsStore.initializeSchema();
    final configuration = NativeRuntimeConfiguration(resolveSecretBridge());
    final rawValues = await KmpWindowsPreferencesReader().readAll();
    if (rawValues.isEmpty) {
      return;
    }

    final migrationService = KmpPreferencesMigrationService(
      accountSettingsStore: accountSettingsStore,
      passwordCipher: PasswordCipher(configuration),
    );
    final report = await migrationService.migrate(rawValues);
    AppTalker.info(
      'Migration',
      'KMP migration: alreadyCompleted=${report.alreadyCompleted} '
          'migrated=${report.migratedEntries} skipped=${report.skippedEntries}',
    );

    // Sync migrated login history to the key used by PreferencesManager.
    _syncMigratedLoginHistory(preferences, accountSettingsStore);
  } catch (error, stackTrace) {
    AppTalker.warning('Migration', 'KMP migration failed: $error');
    AppTalker.instance.handle(error, stackTrace);
  }
}

/// Copies migrated login history into the key consumed by PreferencesManager.
void _syncMigratedLoginHistory(
  SharedPreferences preferences,
  AccountSettingsStore accountSettingsStore,
) {
  const targetKey = 'login_history';
  if (preferences.getString(targetKey) != null) {
    return;
  }
  final migratedJson = accountSettingsStore.readGlobal<String>('loginHistory');
  if (migratedJson == null || migratedJson.isEmpty) {
    return;
  }
  preferences.setString(targetKey, migratedJson);
  AppTalker.info('Migration', 'Login history synced to PreferencesManager key');
}

bool _isDesktopPlatform() {
  return !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
}

class _UpdateSchedulerHost extends ConsumerStatefulWidget {
  const _UpdateSchedulerHost({required this.child});

  final Widget child;

  @override
  ConsumerState<_UpdateSchedulerHost> createState() =>
      _UpdateSchedulerHostState();
}

class _UpdateSchedulerHostState extends ConsumerState<_UpdateSchedulerHost>
    with WidgetsBindingObserver {
  UpdateScheduler? _scheduler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scheduler = ref.read(updateSchedulerProvider);
      // Instantiate the server-update notifier so its reactive triggers
      // (server enable, login change, manual check) are registered up front.
      ref.read(flyNarwhalServerUpdateProvider);
      // Register the one-shot per-user settings migration listener before any
      // UI reads settings, so the first successful login migrates + clears the
      // global namespace exactly once.
      ref.read(userGuidMigrationBootstrapperProvider);
      scheduler.start();
      _scheduler = scheduler;
      unawaited(_reportLaunch());
    });
  }

  Future<void> _reportLaunch() async {
    try {
      await ref.read(reportingServiceProvider).reportLaunch();
    } catch (error, stackTrace) {
      AppTalker.warning('Reporting', 'Launch reporting failed: $error');
      AppTalker.instance.handle(error, stackTrace);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final scheduler = _scheduler;
    if (scheduler == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        scheduler.handleLifecycleState(
          UpdateSchedulerLifecycleState.foreground,
        );
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        scheduler.handleLifecycleState(
          UpdateSchedulerLifecycleState.background,
        );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_scheduler?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

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
        fontFamily: AppFonts.primary,
      ),
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      routeInformationProvider: router.routeInformationProvider,
      builder: (context, child) {
        return _MouseBackNavigationListener(
          router: router,
          navigationStackNotifier: ref.read(navigationStackProvider.notifier),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (child != null) child,
              const ToastHost(),
            ],
          ),
        );
      },
    );
  }
}

class _MouseBackNavigationListener extends StatelessWidget {
  const _MouseBackNavigationListener({
    required this.router,
    required this.navigationStackNotifier,
    required this.child,
  });

  final GoRouter router;
  final NavigationStackNotifier navigationStackNotifier;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: child,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.buttons != kBackMouseButton) {
      return;
    }

    final previousPath = navigationStackNotifier.pop();
    if (previousPath != null && previousPath.isNotEmpty) {
      router.go(previousPath);
      return;
    }

    if (router.canPop()) {
      router.pop();
      return;
    }

    if (router.routeInformationProvider.value.uri.path != '/home') {
      router.go('/home');
    }
  }
}
