import 'dart:io';

import 'package:flutter/services.dart';

/// Reads the KMP Java Preferences root only on Windows.
class KmpWindowsPreferencesReader {
  KmpWindowsPreferencesReader({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'fly_narwhal/kmp_preferences';
  final MethodChannel _channel;

  /// Returns raw KMP preference values after the Windows runner decodes them.
  ///
  /// An absent Registry root is represented as an empty map. Callers should
  /// treat malformed entries as non-migratable rather than guessing a value.
  Future<Map<String, String>> readAll() async {
    if (!Platform.isWindows) {
      return const <String, String>{};
    }
    final rawValues = await _channel.invokeMapMethod<String, dynamic>(
      'readJavaPreferences',
    );
    if (rawValues == null) {
      return const <String, String>{};
    }
    return rawValues.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );
  }
}
