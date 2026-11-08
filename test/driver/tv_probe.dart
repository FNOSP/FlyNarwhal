// ignore_for_file: avoid_print
// End-to-end probe: desktop title bar button -> TV mode -> back out.
// Also reports whether taps inside the scaled TV canvas are hit-testable.
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main() async {
  final driver = await FlutterDriver.connect();
  Future<void> tap(SerializableFinder finder,
          {Duration timeout = const Duration(seconds: 15)}) =>
      driver.runUnsynchronized(() => driver.tap(finder, timeout: timeout));
  try {
    print('S1: desktop home caption visible');
    await driver.waitFor(
      find.byValueKey('macos-window-caption-tv-mode-button'),
      timeout: const Duration(seconds: 30),
    );
    print('S1 OK');

    print('S2: tap title bar TV button');
    await tap(find.byValueKey('macos-window-caption-tv-mode-button'));
    await driver.waitFor(
      find.byValueKey('tv-rail-home'),
      timeout: const Duration(seconds: 20),
    );
    print('S2 OK: TV mode entered');

    print('S3: probe hit-testability inside scaled canvas');
    try {
      await driver.runUnsynchronized(
        () => driver.waitForTappable(
          find.byValueKey('tv-rail-exit'),
          timeout: const Duration(seconds: 8),
        ),
      );
      print('S3 TAPPABLE tv-rail-exit');
    } catch (_) {
      print('S3 NOT-TAPPABLE tv-rail-exit');
    }

    print('S4: tap rail exit back to desktop');
    try {
      await tap(find.byValueKey('tv-rail-exit'));
      await driver.waitFor(
        find.byValueKey('macos-window-caption-tv-mode-button'),
        timeout: const Duration(seconds: 15),
      );
      print('S4 OK: back on desktop');
    } catch (error) {
      print('S4 FAILED: $error');
    }
    print('PROBE DONE');
  } catch (error, stackTrace) {
    print('PROBE FAILED: $error');
    print(stackTrace);
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
