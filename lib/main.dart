import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/providers.dart';
import 'ui/navigation/app_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    
    return FluentApp.router(
      title: 'Fly Narwhal',
      theme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: Colors.blue,
      ),
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      routeInformationProvider: router.routeInformationProvider,
    );
  }
}
