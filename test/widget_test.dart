// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fly_narwhal/app.dart';
import 'package:fly_narwhal/providers/providers.dart';
import 'package:fly_narwhal/ui/player/pip/pip_window_payload.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App boots and shows login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MyApp(
        windowArgs: DesktopWindowBootstrapArgs.main(),
        currentWindowId: 'test',
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Fly Narwhal'), findsWidgets);
    await tester.binding.setSurfaceSize(null);
  });
}
