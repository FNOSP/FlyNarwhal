// ignore: depend_on_referenced_packages
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;

import 'app.dart';
import 'tooling/driver_test_mode.dart';

/// Driver-only keyboard injection: flutter_driver has no raw key events, so
/// verification scripts ask for arrows/enter/escape through
/// `driver.requestData('simkey:<name>')` and this feeds them to the real
/// [HardwareKeyboard] pipeline (the same path user presses take).
const Map<String, (LogicalKeyboardKey, PhysicalKeyboardKey)> _simulatedKeys = {
  'arrowUp': (LogicalKeyboardKey.arrowUp, PhysicalKeyboardKey.arrowUp),
  'arrowDown': (LogicalKeyboardKey.arrowDown, PhysicalKeyboardKey.arrowDown),
  'arrowLeft': (LogicalKeyboardKey.arrowLeft, PhysicalKeyboardKey.arrowLeft),
  'arrowRight': (
    LogicalKeyboardKey.arrowRight,
    PhysicalKeyboardKey.arrowRight,
  ),
  'enter': (LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter),
  'escape': (LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
};

int _simulatedKeyTimestampMicros = 0;

Future<String> _handleDriverData(String? message) async {
  if (message == 'focus') {
    return FocusManager.instance.primaryFocus?.debugLabel ?? 'none';
  }
  const prefix = 'simkey:';
  if (message == null || !message.startsWith(prefix)) {
    return 'ignored';
  }
  final keys = _simulatedKeys[message.substring(prefix.length)];
  if (keys == null) {
    return 'unknown-key';
  }
  _simulatedKeyTimestampMicros += 16000;
  final timestamp = Duration(microseconds: _simulatedKeyTimestampMicros);
  // Focus.onKeyEvent is fed through KeyEventManager.keyMessageHandler, which
  // only receives events via handleKeyData (the platform onKeyData entry);
  // HardwareKeyboard.handleKeyEvent alone would bypass the focus chain.
  // synthesized: true dispatches immediately without waiting for a raw event.
  // ignore: deprecated_member_use
  ServicesBinding.instance.keyEventManager.handleKeyData(
    ui.KeyData(
      timeStamp: timestamp,
      type: ui.KeyEventType.down,
      physical: keys.$2.usbHidUsage,
      logical: keys.$1.keyId,
      character: null,
      synthesized: true,
    ),
  );
  // ignore: deprecated_member_use
  ServicesBinding.instance.keyEventManager.handleKeyData(
    ui.KeyData(
      timeStamp: timestamp + const Duration(milliseconds: 1),
      type: ui.KeyEventType.up,
      physical: keys.$2.usbHidUsage,
      logical: keys.$1.keyId,
      character: null,
      synthesized: true,
    ),
  );
  // Report the post-dispatch focus so runs can trace navigation; focus
  // changes apply in a microtask, so let it run first.
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return 'ok focus=${FocusManager.instance.primaryFocus?.debugLabel ?? 'none'}';
}

Future<void> main(List<String> args) async {
  kDriverTestMode = true;
  enableFlutterDriverExtension(handler: _handleDriverData);
  await bootstrapApp();
}
