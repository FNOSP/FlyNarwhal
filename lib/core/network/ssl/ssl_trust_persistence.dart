import '../../../data/storage/account_settings_store.dart';
import 'ssl_trust_manager.dart';
import 'ssl_trust_store.dart';

/// Write path for user-approved certificates.
///
/// The read path is [SslTrustManager], a synchronous singleton consulted during
/// the TLS handshake. Writes need `SharedPreferences`, which is not available
/// from the handshake or from any interceptor that lacks a `Ref` — so the store
/// is installed once at bootstrap and reached through here.
///
/// Entries are global (not per-account): the login screen can prompt before any
/// guid exists, and the same host carries the same risk for every account.
class SslTrustPersistence {
  SslTrustPersistence._();

  static SslTrustStore? _store;

  /// Installs the backing store. Called from bootstrap after preferences load.
  static void install(AccountSettingsStore accountSettingsStore) {
    _store = SslTrustStore(accountSettingsStore);
  }

  /// Reads the persisted whitelist. Falls back to empty when not installed, so
  /// a missing bootstrap degrades to "prompt again" rather than crashing.
  static Set<SslTrustEntry> read() => _store?.read() ?? <SslTrustEntry>{};

  /// Adds [entry] to the persisted whitelist and rewrites the store.
  static Future<void> persist(SslTrustEntry entry) async {
    final store = _store;
    if (store == null) return;
    final updated = store.read()..add(entry);
    await store.write(updated);
  }

  /// Removes [entry] and rewrites the store.
  static Future<void> remove(SslTrustEntry entry) async {
    final store = _store;
    if (store == null) return;
    final updated = store.read()..remove(entry);
    await store.write(updated);
  }

  /// Clears the persisted whitelist entirely.
  static Future<void> clear() async {
    await _store?.clear();
  }
}
