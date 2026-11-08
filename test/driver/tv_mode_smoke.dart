// ignore_for_file: avoid_print
// Smoke check for the TV big-screen mode against a running driver build:
//   flutter drive -d macos --use-existing-app=ws://127.0.0.1:<port>/<token>/ws \
//     --driver=test/driver/tv_mode_smoke.dart
//
// The app must be launched from lib/driver_main.dart with
// --dart-define=DRIVER_INITIAL_ROUTE=/bigscreen and a logged-in profile.
// Runs without package:test: prints each step and exits non-zero on failure.
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main() async {
  // Continue-watching item of the verification account; override with
  // TV_RESUME_GUID when running against another library.
  const resumeGuid = '98189fe66d834dc88898f01288906c37';
  final driver = await FlutterDriver.connect();
  // This project's driver taps deadlock while frame sync waits for settle on
  // continuously-animating pages (see project memory); run taps unsynchronized
  // and rely on explicit waitFor checks instead.
  Future<void> tap(SerializableFinder finder) =>
      driver.runUnsynchronized(() => driver.tap(finder));
  try {
    print('STEP 0: enter TV mode if starting from the desktop home');
    try {
      await driver.waitFor(
        find.byValueKey('macos-window-caption-tv-mode-button'),
        timeout: const Duration(seconds: 5),
      );
      await tap(find.byValueKey('macos-window-caption-tv-mode-button'));
      await driver.waitFor(
        find.byValueKey('tv-rail-home'),
        timeout: const Duration(seconds: 20),
      );
      print('STEP 0 OK: entered from desktop');
    } catch (_) {
      print('STEP 0 SKIPPED: already in TV mode');
    }

    print('STEP 1: wait for TV home with live resume data');
    await driver.waitFor(
      find.byValueKey('tv-resume-card-$resumeGuid'),
      timeout: const Duration(seconds: 30),
    );
    await driver.waitFor(find.byValueKey('tv-hero-play'));
    await driver.waitFor(find.byValueKey('tv-rail-exit'));
    print('STEP 1 OK: TV home, hero button and rail exit present');

    print('STEP 2: tap rail exit -> desktop home caption returns');
    await tap(find.byValueKey('tv-rail-exit'));
    await driver.waitFor(
      find.byValueKey('macos-window-caption-tv-mode-button'),
      timeout: const Duration(seconds: 20),
    );
    print('STEP 2 OK: back on desktop home');

    print('STEP 3: tap title bar TV button -> TV mode again');
    await tap(find.byValueKey('macos-window-caption-tv-mode-button'));
    await driver.waitFor(
      find.byValueKey('tv-rail-home'),
      timeout: const Duration(seconds: 20),
    );
    print('STEP 3 OK: re-entered TV mode');
    print('HOLD: 8s window for fullscreen evidence');
    await Future<void>.delayed(const Duration(seconds: 8));

    if (Platform.environment['TV_SMOKE_SKIP_PLAYER'] != '1') {
      print('STEP 4: hero play opens the fullscreen player');
      await tap(find.byValueKey('tv-hero-play'));
      await driver.waitFor(
        find.byType('PlayerScreen'),
        timeout: const Duration(seconds: 40),
      );
      print('STEP 4 OK: player route opened');
    } else {
      print('STEP 4 SKIPPED: app left in TV mode for window evidence');
    }
    print('TV SMOKE PASSED');
  } catch (error, stackTrace) {
    print('TV SMOKE FAILED: $error');
    print(stackTrace);
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
