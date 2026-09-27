import '../../../data/storage/account_settings_store.dart';
import 'ssl_trust_manager.dart';

/// Persists the SSL trust whitelist under the key the KMP migration already
/// reserves (`kmp_preferences_migration_service.dart` maps the legacy
/// `ssl_ignore_host_whitelist` setting onto it).
///
/// Scope is deliberately global, not per-account: the login screen can prompt
/// before any guid exists, and the same NAS host carries the same risk whoever
/// logs in. The KMP original scoped it per-guid only because its settings store
/// made that mechanical.
class SslTrustStore {
  SslTrustStore(this._store);

  /// Matches the migration's target key exactly.
  static const String settingKey = 'security.sslIgnoreHostWhitelist';

  /// Host/fingerprint separator inside one serialized entry.
  static const String _separator = '|';

  final AccountSettingsStore _store;

  /// Reads persisted entries.
  ///
  /// Tolerates the shape the KMP migration leaves behind: a comma-separated
  /// [String] of bare hostnames with no fingerprints. Those entries cannot be
  /// verified against a certificate, so they are dropped — silently trusting
  /// them would grant exactly the untargeted access the fingerprint is meant to
  /// prevent. The migration is cross-platform data, so this is the one place
  /// legacy tolerance is worth the complexity.
  Set<SslTrustEntry> read() {
    final raw = _store.readGlobal<Object>(settingKey);
    return switch (raw) {
      List<Object?> list => list
          .map((item) => _parseEntry(item?.toString()))
          .whereType<SslTrustEntry>()
          .toSet(),
      String value => value
          .split(',')
          .map(_parseEntry)
          .whereType<SslTrustEntry>()
          .toSet(),
      _ => <SslTrustEntry>{},
    };
  }

  /// Writes [entries] to disk, normalizing the stored shape to `List<String>`.
  ///
  /// Entries written before the timestamp existed have none, so the field is
  /// omitted rather than written empty.
  Future<void> write(Iterable<SslTrustEntry> entries) {
    final serialized = entries
        .map(
          (e) => e.addedAt == null
              ? '${e.host}$_separator${e.fingerprintSha256}'
              : '${e.host}$_separator${e.fingerprintSha256}'
                  '$_separator${e.addedAt!.toIso8601String()}',
        )
        .toList(growable: false);
    return _store.writeGlobal(settingKey, serialized);
  }

  Future<void> clear() => _store.removeGlobal(settingKey);

  /// Parses `host|fingerprint[|addedAt]`. Returns null for anything without a
  /// usable fingerprint, including the bare hostnames the legacy migration
  /// produces.
  static SslTrustEntry? _parseEntry(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split(_separator);
    if (parts.length < 2) return null;

    final host = SslTrustManager.normalizeHost(parts[0]);
    final fingerprint = parts[1].replaceAll(':', '').trim().toLowerCase();
    if (host.isEmpty || fingerprint.isEmpty) return null;

    // A missing or unparsable timestamp is not fatal; the entry still counts.
    final addedAt = parts.length > 2 ? DateTime.tryParse(parts[2].trim()) : null;

    return SslTrustEntry(
      host: host,
      fingerprintSha256: fingerprint,
      addedAt: addedAt,
    );
  }
}

