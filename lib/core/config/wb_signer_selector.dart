import 'wb_signer_bridge_ffi.dart';

WbSigner? _cachedSigner;
bool _loadAttempted = false;

/// Loads the white-box signer once per process, caching failures too.
///
/// Release bundles ship libfly_narwhal_wb next to the executable; development
/// builds do not, so the load fails and stays null for the process lifetime
/// (no per-request retry). There is deliberately no dart-define fallback: the
/// V2 secret must never exist in Dart.
WbSigner? tryLoadWbSigner() {
  if (!_loadAttempted) {
    _loadAttempted = true;
    try {
      _cachedSigner = FfiWbSigner();
    } catch (_) {
      _cachedSigner = null;
    }
  }
  return _cachedSigner;
}