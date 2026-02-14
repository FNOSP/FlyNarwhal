import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_info2/system_info2.dart';
import 'providers/providers.dart';
import 'ui/navigation/app_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    final freeMemoryBytes = SysInfo.getFreePhysicalMemory();
    if (freeMemoryBytes > 0) {
      PaintingBinding.instance.imageCache.maximumSizeBytes = (freeMemoryBytes * 0.05).round();
    }
    
    await acrylic.Window.initialize();
    
    if (Platform.isWindows) {
      await acrylic.Window.hideWindowControls();
    }
    
    await windowManager.ensureInitialized();

    const logicalWidth = 1280.0;
    const logicalHeight = 720.0;
    const windowOptions = WindowOptions(
      title: '飞鲸影视',
      size: Size(logicalWidth, logicalHeight),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setMinimumSize(const Size(logicalWidth, logicalHeight));
      await windowManager.show();
      await windowManager.focus();
    });
  }
  
  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);
    final platformBrightness = MediaQuery.of(context).platformBrightness;
    final isDark = settings.followSystemTheme
        ? platformBrightness == Brightness.dark
        : settings.darkMode;

    return FluentApp.router(
      title: '飞鲸影视',
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
