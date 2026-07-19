import 'dart_define_secret_bridge.dart';
import 'native_secret_bridge_ffi.dart';
import 'runtime_configuration.dart';

/// Resolves the most secure runtime configuration source available.
///
/// Native library loading and ABI validation occur in [FfiSecretBridge]'s
/// constructor. Any failure deliberately selects the compile-time fallback.
NativeSecretBridge resolveSecretBridge() {
  try {
    return FfiSecretBridge();
  } catch (_) {
    return DartDefineSecretBridge();
  }
}
