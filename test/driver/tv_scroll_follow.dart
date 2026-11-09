// ignore_for_file: avoid_print
// Verifies focus-driven scroll following in both axes on a running driver
// build (lib/driver_main.dart exposes simkey: requestData):
//   flutter drive -d macos --use-existing-app=ws://... \
//     --driver=test/driver/tv_scroll_follow.dart
//
// Regression: Scrollable.ensureVisible(keepVisibleAtEnd) only revealed
// toward the end edge, so focus moves up/left never scrolled the page/row.
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

const resumeGuid = '98189fe66d834dc88898f01288906c37';

Future<void> main() async {
  final driver = await FlutterDriver.connect();
  Future<void> tap(SerializableFinder finder) =>
      driver.runUnsynchronized(() => driver.tap(finder));
  Future<void> key(String name) async {
    final result = await driver.requestData('simkey:$name');
    if (!result.startsWith('ok')) {
      throw StateError('simkey $name -> $result');
    }
    print('KEY $name -> ${result.substring(3)}');
    await Future<void>.delayed(const Duration(milliseconds: 450));
  }

  Future<void> focusTrace(String tag) async {
    print('FOCUS $tag: ${await driver.requestData('focus')}');
  }

  final failures = <String>[];
  void check(String name, bool ok, String detail) {
    print('CHECK $name: ${ok ? "PASS" : "FAIL"} ($detail)');
    if (!ok) failures.add(name);
  }

  try {
    print('S0: ensure TV mode');
    try {
      await driver.waitFor(
        find.byValueKey('macos-window-caption-tv-mode-button'),
        timeout: const Duration(seconds: 5),
      );
      await tap(find.byValueKey('macos-window-caption-tv-mode-button'));
    } catch (_) {
      print('S0: already in TV mode');
    }
    final resume0 = find.byValueKey('tv-resume-card-$resumeGuid');
    await driver.waitFor(resume0, timeout: const Duration(seconds: 30));
    await Future<void>.delayed(const Duration(milliseconds: 600));

    await focusTrace('initial');
    final r0 = await driver.getTopLeft(resume0);
    print('R0 = ${r0.dx},${r0.dy}');

    print('H1: arrowRight x4 scrolls the row left');
    for (var i = 0; i < 4; i++) {
      await key('arrowRight');
    }
    await focusTrace('after-right');
    final r1 = await driver.getTopLeft(resume0);
    check('row-scroll-right', r1.dx < r0.dx - 150, 'dx ${r0.dx} -> ${r1.dx}');

    print('H2: arrowLeft x4 scrolls the row back');
    for (var i = 0; i < 4; i++) {
      await key('arrowLeft');
    }
    await focusTrace('after-left');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final r2 = await driver.getTopLeft(resume0);
    check(
      'row-scroll-left',
      (r2.dx - r0.dx).abs() < 8,
      'dx ${r0.dx} -> ${r2.dx}',
    );

    print('V1: arrowDown x2 scrolls the page down');
    final movie0 = find.byValueKey(
      'tv-poster-card-96dfc89bde7e4e35b63678570954629b',
    );
    final m0 = await driver.getTopLeft(movie0);
    await key('arrowDown');
    await key('arrowDown');
    final d = await driver.getTopLeft(movie0);
    check(
      'page-scroll-down',
      d.dy < m0.dy - 300,
      'movie0 dy ${m0.dy} -> ${d.dy}',
    );

    print('V2: arrowUp reveals the row above again');
    await key('arrowUp');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final u = await driver.getTopLeft(movie0);
    check(
      'page-scroll-up',
      u.dy > d.dy + 50 && u.dy > 60 && u.dy < 400,
      'movie0 dy ${d.dy} -> ${u.dy}',
    );

    if (failures.isEmpty) {
      print('SCROLL FOLLOW PASSED');
    } else {
      print('SCROLL FOLLOW FAILED: $failures');
      exitCode = 1;
    }
  } catch (error, stackTrace) {
    print('SCROLL FOLLOW ERROR: $error');
    print(stackTrace);
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
