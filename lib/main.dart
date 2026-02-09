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
    await windowManager.ensureInitialized();

    final devicePixelRatio = windowManager.getDevicePixelRatio();
    final logicalWidth = 1280 / devicePixelRatio;
    final logicalHeight = 720 / devicePixelRatio;
    final windowOptions = WindowOptions(
      title: 'Fly Narwhal',
      size: Size(logicalWidth, logicalHeight),
      center: true,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setMinimumSize(Size(logicalWidth, logicalHeight));
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
      title: 'Fly Narwhal',
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
