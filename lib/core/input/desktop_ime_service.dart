import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/log/app_talker.dart';

/// Forces the OS input method into its English/ASCII state while a text field
/// is focused, restoring the previous state once it loses focus, so a CJK
/// input method cannot be used to type into that field.
///
/// Native support: Windows (IMM32) and macOS (input source switch). Everywhere
/// else the calls are a no-op.
class DesktopImeService {
  const DesktopImeService();

  static const MethodChannel _channel = MethodChannel('fly_narwhal/ime');

  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Turns English-only input on or off. The native side captures the current
  /// input state when enabling and restores it when disabling, so calls are
  /// idempotent rather than nesting.
  Future<void> setEnglishOnly(bool enabled) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<void>(
        'setEnglishOnly',
        <String, dynamic>{'enabled': enabled},
      );
    } catch (error) {
      // IME control is best effort: never let it break text input.
      AppTalker.warning('Ime', 'setEnglishOnly($enabled) failed: $error');
    }
  }
}
