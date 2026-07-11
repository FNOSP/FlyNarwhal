import 'dart:convert';
import 'dart:typed_data';

import 'runtime_configuration.dart';

/// Reads development configuration from compile-time dart-defines.
///
/// This bridge is intentionally only a fallback for local development and
/// tests. Release builds must provide values through the native bridge.
class DartDefineSecretBridge implements NativeSecretBridge {
  static const String _developmentApiSecret =
      '16CCEB3D-AB42-077D-36A1-F355324E4237';
  static const String _developmentSecret =
      'D3F4A1B2-C5E6-7890-ABCD-EF1234567890';

  @override
  Future<Uint8List> readSecret(RuntimeSecret secret) async {
    final value = switch (secret) {
      RuntimeSecret.flyNarwhalApiSecret => const String.fromEnvironment(
          'FLY_NARWHAL_API_SECRET',
          defaultValue: _developmentApiSecret,
        ),
      RuntimeSecret.flyNarwhalSecret => const String.fromEnvironment(
          'FLY_NARWHAL_SECRET',
          defaultValue: _developmentSecret,
        ),
      RuntimeSecret.reportUrl =>
        const String.fromEnvironment('REPORT_URL', defaultValue: ''),
      RuntimeSecret.reportApiSecret =>
        const String.fromEnvironment('REPORT_API_SECRET', defaultValue: ''),
    };
    return Uint8List.fromList(utf8.encode(value));
  }

  @override
  Future<void> zeroize(Uint8List bytes) async {
    bytes.fillRange(0, bytes.length, 0);
  }
}
