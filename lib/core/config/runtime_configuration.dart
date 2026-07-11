import 'dart:typed_data';

/// Enumerates build-time values recovered by the private runtime bridge.
enum RuntimeSecret {
  flyNarwhalApiSecret,
  flyNarwhalSecret,
  reportUrl,
  reportApiSecret,
}

/// Provides short-lived byte buffers for build-time configuration values.
///
/// Production release builds replace the development implementation with the
/// Rust-backed generated binding produced by the private obfuscator repository.
abstract interface class RuntimeConfiguration {
  Future<Uint8List> resolveRequiredSecret(RuntimeSecret secret);

  Future<Uint8List?> resolveOptionalValue(RuntimeSecret secret);

  Future<void> zeroize(Uint8List bytes);
}

/// Defines a stable contract for a generated private-obfuscator binding.
///
/// The checked-in application code must not contain any secret values. The
/// release build script supplies the generated implementation under this API.
abstract interface class NativeSecretBridge {
  Future<Uint8List> readSecret(RuntimeSecret secret);

  Future<void> zeroize(Uint8List bytes);
}

/// Runtime configuration backed by a native secret bridge.
class NativeRuntimeConfiguration implements RuntimeConfiguration {
  NativeRuntimeConfiguration(this._bridge);

  final NativeSecretBridge _bridge;

  @override
  Future<Uint8List> resolveRequiredSecret(RuntimeSecret secret) {
    return _bridge.readSecret(secret);
  }

  @override
  Future<Uint8List?> resolveOptionalValue(RuntimeSecret secret) async {
    final value = await _bridge.readSecret(secret);
    return value.isEmpty ? null : value;
  }

  @override
  Future<void> zeroize(Uint8List bytes) => _bridge.zeroize(bytes);
}

/// Test-only bridge with caller-owned fixture values.
///
/// It exists to make crypto and Authx tests deterministic. It must never be
/// selected by a release bootstrap path.
class MemorySecretBridge implements NativeSecretBridge {
  MemorySecretBridge(Map<RuntimeSecret, List<int>> values)
      : _values = values.map(
          (secret, value) => MapEntry(secret, Uint8List.fromList(value)),
        );

  final Map<RuntimeSecret, Uint8List> _values;

  @override
  Future<Uint8List> readSecret(RuntimeSecret secret) async {
    final value = _values[secret];
    if (value == null) {
      throw StateError('Missing test value for $secret');
    }
    return Uint8List.fromList(value);
  }

  @override
  Future<void> zeroize(Uint8List bytes) async {
    bytes.fillRange(0, bytes.length, 0);
  }
}
