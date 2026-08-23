import 'package:shared_preferences/shared_preferences.dart';

import '../../core/version/semantic_version.dart';
import 'legacy_update_preferences_migrator.dart';
import 'preferences_manager.dart';

/// Immutable update preferences exposed after migration completes.
final class UpdateSettings {
  const UpdateSettings({
    required this.isInitialized,
    required this.isProxyEnabled,
    required this.proxyUrl,
    required this.includePrerelease,
    required this.autoDownload,
    required this.lastSuccessfulCheckAt,
    required this.skippedVersions,
  });

  final bool isInitialized;
  final bool isProxyEnabled;
  final String proxyUrl;
  final bool includePrerelease;
  final bool autoDownload;
  final DateTime? lastSuccessfulCheckAt;
  final Set<String> skippedVersions;
}

/// Persists settings dedicated to application update behavior.
class UpdateSettingsStore {
  UpdateSettingsStore(
    this.preferences, {
    String? userGuid,
    LegacyUpdatePreferencesReader? legacyPreferencesReader,
  })  : _userGuid = PreferencesManager.normalizeGuid(userGuid),
        _legacyPreferencesReader = legacyPreferencesReader ??
            SharedPreferencesLegacyUpdateReader(preferences);

  static const int currentSchemaVersion = 1;
  static const String defaultProxyUrl = 'https://ghfast.top/';

  final SharedPreferences preferences;
  final String? _userGuid;
  final LegacyUpdatePreferencesReader _legacyPreferencesReader;
  bool _isInitialized = false;

  String _scopedKey(String rawKey) {
    final guid = _userGuid;
    if (guid == null) return rawKey;
    return '$guid::$rawKey';
  }

  bool get isInitialized => _isInitialized;
  bool get isProxyEnabled {
    final value = _readScoped(UpdateSettingsKeys.proxyEnabled);
    return value is bool ? value : true;
  }

  String get proxyUrl {
    final value = _readScoped(UpdateSettingsKeys.proxyUrl);
    if (value is! String) {
      return defaultProxyUrl;
    }
    return normalizeProxyUrl(value) ?? defaultProxyUrl;
  }

  bool get includePrerelease {
    final value = _readScoped(UpdateSettingsKeys.includePrerelease);
    return value is bool ? value : false;
  }

  bool get autoDownload {
    final value = _readScoped(UpdateSettingsKeys.autoDownload);
    return value is bool ? value : false;
  }

  Set<String> get skippedVersions =>
      LegacyUpdatePreferencesMigrator.normalizeSkippedVersions(
        _readScoped(UpdateSettingsKeys.skippedVersions),
      ).toSet();

  DateTime? get lastSuccessfulCheckAt {
    final timestamp =
        _readScoped(UpdateSettingsKeys.lastSuccessfulCheckAt);
    if (timestamp is! int || timestamp < 0) {
      return null;
    }
    try {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } on RangeError {
      return null;
    }
  }

  UpdateSettings get settings => UpdateSettings(
        isInitialized: _isInitialized,
        isProxyEnabled: isProxyEnabled,
        proxyUrl: proxyUrl,
        includePrerelease: includePrerelease,
        autoDownload: autoDownload,
        lastSuccessfulCheckAt: lastSuccessfulCheckAt,
        skippedVersions: Set<String>.unmodifiable(skippedVersions),
      );

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    // Collect the bare `update.*` key names already present in the *scoped*
    // namespace (global when logged out, `<guid>::`-prefixed when logged in).
    // The migrator works with bare key names, so strip the guid prefix.
    final scopedPrefix = _userGuid == null ? '' : '$_userGuid::';
    final existingNewKeys = preferences
        .getKeys()
        .where((key) => key.startsWith('${scopedPrefix}update.'))
        .map((key) => key.substring(scopedPrefix.length))
        .toSet();

    // When logged in, the KMP-legacy → `update.*` migration is handled by
    // UserSettingsMigrator; here we only backfill defaults. When logged out
    // (first install), migrate KMP legacy into the global `update.*` keys so
    // the upcoming user-scoped migration has a global source to read from.
    final migrationBatch = _userGuid == null
        ? const LegacyUpdatePreferencesMigrator(
            defaultProxyUrl: defaultProxyUrl,
          ).createMigrationBatch(
            existingNewKeys: existingNewKeys,
            legacyReader: _legacyPreferencesReader,
            normalizeProxyUrl: normalizeProxyUrl,
          )
        : const <String, Object>{};

    // Persist validated values (and first-install defaults) into the scoped
    // namespace.
    final initializationBatch = <String, Object>{};
    for (final entry in migrationBatch.entries) {
      initializationBatch[_scopedKey(entry.key)] = entry.value;
    }
    final hasProxyEnabled =
        _hasKey(migrationBatch, UpdateSettingsKeys.proxyEnabled);
    if (!hasProxyEnabled) {
      initializationBatch[_scopedKey(UpdateSettingsKeys.proxyEnabled)] = true;
    }
    if (!_hasKey(migrationBatch, UpdateSettingsKeys.proxyUrl)) {
      initializationBatch[_scopedKey(UpdateSettingsKeys.proxyUrl)] =
          defaultProxyUrl;
    }
    if (!_hasKey(migrationBatch, UpdateSettingsKeys.includePrerelease)) {
      initializationBatch[_scopedKey(UpdateSettingsKeys.includePrerelease)] =
          false;
    }
    if (!_hasKey(migrationBatch, UpdateSettingsKeys.autoDownload)) {
      initializationBatch[_scopedKey(UpdateSettingsKeys.autoDownload)] = false;
    }
    if (!_hasKey(migrationBatch, UpdateSettingsKeys.skippedVersions)) {
      initializationBatch[_scopedKey(UpdateSettingsKeys.skippedVersions)] =
          <String>[];
    }
    initializationBatch[_scopedKey(UpdateSettingsKeys.schemaVersion)] =
        currentSchemaVersion;
    await _persistBatch(initializationBatch);
    _isInitialized = true;
  }

  bool _hasKey(Map<String, Object> batch, String rawKey) {
    return batch.containsKey(rawKey) ||
        preferences.containsKey(_scopedKey(rawKey));
  }

  Future<void> setProxyEnabled(bool value) =>
      preferences.setBool(_scopedKey(UpdateSettingsKeys.proxyEnabled), value);
  Future<void> setIncludePrerelease(bool value) =>
      preferences.setBool(_scopedKey(UpdateSettingsKeys.includePrerelease), value);
  Future<void> setAutoDownload(bool value) =>
      preferences.setBool(_scopedKey(UpdateSettingsKeys.autoDownload), value);

  Future<void> setProxyUrl(String value) async {
    final normalizedUrl = normalizeProxyUrl(value);
    if (normalizedUrl == null) {
      throw const FormatException('GitHub 资源代理地址必须是有效的 HTTPS 地址。');
    }
    await preferences.setString(
      _scopedKey(UpdateSettingsKeys.proxyUrl),
      normalizedUrl,
    );
  }

  Future<void> setLastSuccessfulCheckAt(DateTime value) {
    return preferences.setInt(
      _scopedKey(UpdateSettingsKeys.lastSuccessfulCheckAt),
      value.millisecondsSinceEpoch,
    );
  }

  Future<void> skipVersion(String version) async {
    final versionText = version.trim().startsWith('v')
        ? version.trim().substring(1)
        : version.trim();
    final semanticVersion = SemanticVersion.tryParse(versionText);
    if (semanticVersion == null) {
      throw const FormatException('Skipped version must be valid SemVer.');
    }
    final updatedVersions = <String>{
      ...skippedVersions,
      semanticVersion.skipKey,
    }.toList()
      ..sort();
    await preferences.setStringList(
      _scopedKey(UpdateSettingsKeys.skippedVersions),
      updatedVersions,
    );
  }

  static String? normalizeProxyUrl(String value) {
    final parsedUrl = Uri.tryParse(value.trim());
    if (parsedUrl == null ||
        parsedUrl.scheme != 'https' ||
        parsedUrl.host.isEmpty ||
        parsedUrl.userInfo.isNotEmpty ||
        parsedUrl.hasQuery ||
        parsedUrl.fragment.isNotEmpty) {
      return null;
    }
    final normalizedPath = parsedUrl.path.replaceAll(RegExp(r'/+$'), '');
    return parsedUrl.replace(path: '$normalizedPath/').toString();
  }

  Future<void> _persistBatch(Map<String, Object> values) async {
    for (final entry in values.entries) {
      final value = entry.value;
      final succeeded = switch (value) {
        bool booleanValue => await preferences.setBool(entry.key, booleanValue),
        int integerValue => await preferences.setInt(entry.key, integerValue),
        String stringValue =>
          await preferences.setString(entry.key, stringValue),
        List<String> stringList =>
          await preferences.setStringList(entry.key, stringList),
        _ => throw ArgumentError.value(value, entry.key),
      };
      if (!succeeded) {
        throw StateError('Failed to persist update setting ${entry.key}');
      }
    }
  }

  // 作用域读取：未登录走 legacy 链（KMP 兼容）；登录态只读 <guid>::update.*，
  // 无命中返回 null。迁移由 UserSettingsMigrator 统一处理并删除 legacy / 全局值。
  Object? _readScoped(String rawKey) {
    final guid = _userGuid;
    if (guid == null) {
      return preferences.get(rawKey);
    }
    return preferences.get('$guid::$rawKey');
  }
}

/// Reads legacy values from the same preferences database.
final class SharedPreferencesLegacyUpdateReader
    implements LegacyUpdatePreferencesReader {
  const SharedPreferencesLegacyUpdateReader(this._preferences);

  final SharedPreferences _preferences;

  @override
  Object? read(String key) {
    final directValue = _preferences.get(key);
    if (directValue != null) {
      return directValue;
    }
    final globalValue = _preferences.get('global.$key');
    if (globalValue != null) {
      return globalValue;
    }

    // Accept one account-scoped KMP migration value without guessing users.
    final accountSuffix = '.$key';
    final matchingKeys = _preferences
        .getKeys()
        .where(
          (candidate) =>
              candidate.startsWith('account.') &&
              candidate.endsWith(accountSuffix),
        )
        .toList();
    if (matchingKeys.length != 1) {
      return null;
    }
    return _preferences.get(matchingKeys.single);
  }
}
