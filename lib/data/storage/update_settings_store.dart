import 'package:shared_preferences/shared_preferences.dart';

import '../../core/version/semantic_version.dart';
import 'legacy_update_preferences_migrator.dart';

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
    LegacyUpdatePreferencesReader? legacyPreferencesReader,
  }) : _legacyPreferencesReader = legacyPreferencesReader ??
            SharedPreferencesLegacyUpdateReader(preferences);

  static const int currentSchemaVersion = 1;
  static const String defaultProxyUrl = 'https://ghfast.top/';

  final SharedPreferences preferences;
  final LegacyUpdatePreferencesReader _legacyPreferencesReader;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get isProxyEnabled {
    final value = preferences.get(UpdateSettingsKeys.proxyEnabled);
    return value is bool ? value : true;
  }

  String get proxyUrl {
    final value = preferences.get(UpdateSettingsKeys.proxyUrl);
    if (value is! String) {
      return defaultProxyUrl;
    }
    return normalizeProxyUrl(value) ?? defaultProxyUrl;
  }

  bool get includePrerelease {
    final value = preferences.get(UpdateSettingsKeys.includePrerelease);
    return value is bool ? value : false;
  }

  bool get autoDownload {
    final value = preferences.get(UpdateSettingsKeys.autoDownload);
    return value is bool ? value : false;
  }

  Set<String> get skippedVersions =>
      LegacyUpdatePreferencesMigrator.normalizeSkippedVersions(
        preferences.get(UpdateSettingsKeys.skippedVersions),
      ).toSet();

  DateTime? get lastSuccessfulCheckAt {
    final timestamp = preferences.get(UpdateSettingsKeys.lastSuccessfulCheckAt);
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
    final existingNewKeys = preferences.getKeys().where(
          (key) => key.startsWith('update.'),
        );
    const migrator = LegacyUpdatePreferencesMigrator(
      defaultProxyUrl: defaultProxyUrl,
    );
    final migrationBatch = migrator.createMigrationBatch(
      existingNewKeys: existingNewKeys.toSet(),
      legacyReader: _legacyPreferencesReader,
      normalizeProxyUrl: normalizeProxyUrl,
    );

    // Persist validated values before publishing initialized state.
    final initializationBatch = <String, Object>{
      ...migrationBatch,
      if (!preferences.containsKey(UpdateSettingsKeys.proxyEnabled) &&
          !migrationBatch.containsKey(UpdateSettingsKeys.proxyEnabled))
        UpdateSettingsKeys.proxyEnabled: true,
      if (!preferences.containsKey(UpdateSettingsKeys.proxyUrl) &&
          !migrationBatch.containsKey(UpdateSettingsKeys.proxyUrl))
        UpdateSettingsKeys.proxyUrl: defaultProxyUrl,
      if (!preferences.containsKey(UpdateSettingsKeys.includePrerelease) &&
          !migrationBatch.containsKey(UpdateSettingsKeys.includePrerelease))
        UpdateSettingsKeys.includePrerelease: false,
      if (!preferences.containsKey(UpdateSettingsKeys.autoDownload) &&
          !migrationBatch.containsKey(UpdateSettingsKeys.autoDownload))
        UpdateSettingsKeys.autoDownload: false,
      if (!preferences.containsKey(UpdateSettingsKeys.skippedVersions) &&
          !migrationBatch.containsKey(UpdateSettingsKeys.skippedVersions))
        UpdateSettingsKeys.skippedVersions: <String>[],
      UpdateSettingsKeys.schemaVersion: currentSchemaVersion,
    };
    await _persistBatch(initializationBatch);
    _isInitialized = true;
  }

  Future<void> setProxyEnabled(bool value) =>
      preferences.setBool(UpdateSettingsKeys.proxyEnabled, value);
  Future<void> setIncludePrerelease(bool value) =>
      preferences.setBool(UpdateSettingsKeys.includePrerelease, value);
  Future<void> setAutoDownload(bool value) =>
      preferences.setBool(UpdateSettingsKeys.autoDownload, value);

  Future<void> setProxyUrl(String value) async {
    final normalizedUrl = normalizeProxyUrl(value);
    if (normalizedUrl == null) {
      throw const FormatException('GitHub 资源代理地址必须是有效的 HTTPS 地址。');
    }
    await preferences.setString(UpdateSettingsKeys.proxyUrl, normalizedUrl);
  }

  Future<void> setLastSuccessfulCheckAt(DateTime value) {
    return preferences.setInt(
      UpdateSettingsKeys.lastSuccessfulCheckAt,
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
      UpdateSettingsKeys.skippedVersions,
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
