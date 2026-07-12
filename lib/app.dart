import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'core/utils/index.dart';
import 'data/storage/account_settings_store.dart';
import 'data/storage/kmp_preferences_migration_service.dart';
import 'data/storage/kmp_windows_preferences_reader.dart';
import 'providers/providers.dart';
import 'ui/navigation/app_router.dart';
import 'ui/shared/toast.dart';

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
      if (Platform.isMacOS) {
        // Keep the app alive when the main window close button is pressed.
        await windowManager.setPreventClose(true);
      }

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
      AppTalker.info('Window', 'Desktop initialization complete');
    }

    // Load persisted app preferences before creating providers.
    final prefs = await SharedPreferences.getInstance();
    AppTalker.info('Prefs', 'SharedPreferences ready');

    // Run the idempotent KMP migration before providers access preferences.
    if (!kIsWeb && Platform.isWindows) {
      await _runKmpMigration(prefs);
    }

    // Start the widget tree after all startup services are prepared.
    AppTalker.info('Bootstrap', 'runApp start');
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MyApp(),
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
  } catch (error, stackTrace) {
    AppTalker.warning('Migration', 'KMP migration failed: $error');
    AppTalker.instance.handle(error, stackTrace);
  }
}

bool _isDesktopPlatform() {
  return !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
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
        return Stack(
          fit: StackFit.expand,
          children: [
            if (child != null) child,
            const ToastHost(),
          ],
        );
      },
    );
  }
}
