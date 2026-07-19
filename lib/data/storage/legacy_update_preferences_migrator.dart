import 'dart:convert';

import '../../core/version/semantic_version.dart';

/// Defines the only persisted keys written by the update settings module.
abstract final class UpdateSettingsKeys {
  static const String schemaVersion = 'update.schema_version';
  static const String proxyEnabled = 'update.proxy_enabled';
  static const String proxyUrl = 'update.proxy_url';
  static const String includePrerelease = 'update.include_prerelease';
  static const String autoDownload = 'update.auto_download';
  static const String lastSuccessfulCheckAt = 'update.last_successful_check_at';
  static const String legacyLastCheckAt = 'update.legacy_last_check_at';
  static const String skippedVersions = 'update.skipped_versions';
}

/// Defines supported KMP and historical Flutter preference names.
abstract final class LegacyUpdatePreferenceKeys {
  static const String githubResourceProxyUrl = 'github_resource_proxy_url';
  static const String includePrerelease = 'include_prerelease';
  static const String autoDownloadUpdates = 'auto_download_updates';
  static const String lastUpdateCheckTime = 'last_update_check_time';
  static const String skippedVersions = 'skipped_versions';

  static const String historicalProxyUrl = 'githubResourceProxyUrl';
  static const String historicalIncludePrerelease = 'updates.includePrerelease';
  static const String historicalAutoDownload = 'updates.autoDownload';
  static const String historicalLastCheckMillis = 'updates.lastCheckMillis';
  static const String historicalSkippedVersions = 'updates.skippedVersions';
}

/// Reads legacy update values without allowing the migrator to mutate them.
abstract interface class LegacyUpdatePreferencesReader {
  Object? read(String key);
}

/// Migrates legacy update preferences into one validated write batch.
final class LegacyUpdatePreferencesMigrator {
  const LegacyUpdatePreferencesMigrator({required this.defaultProxyUrl});

  final String defaultProxyUrl;

  Map<String, Object> createMigrationBatch({
    required Set<String> existingNewKeys,
    required LegacyUpdatePreferencesReader legacyReader,
    required String? Function(String value) normalizeProxyUrl,
  }) {
    final migrationBatch = <String, Object>{};

    _migrateProxy(
      existingNewKeys: existingNewKeys,
      legacyReader: legacyReader,
      normalizeProxyUrl: normalizeProxyUrl,
      migrationBatch: migrationBatch,
    );
    _migrateBoolean(
      targetKey: UpdateSettingsKeys.includePrerelease,
      legacyKeys: const <String>[
        LegacyUpdatePreferenceKeys.includePrerelease,
        LegacyUpdatePreferenceKeys.historicalIncludePrerelease,
      ],
      existingNewKeys: existingNewKeys,
      legacyReader: legacyReader,
      migrationBatch: migrationBatch,
    );
    _migrateBoolean(
      targetKey: UpdateSettingsKeys.autoDownload,
      legacyKeys: const <String>[
        LegacyUpdatePreferenceKeys.autoDownloadUpdates,
        LegacyUpdatePreferenceKeys.historicalAutoDownload,
      ],
      existingNewKeys: existingNewKeys,
      legacyReader: legacyReader,
      migrationBatch: migrationBatch,
    );
    _migrateLastCheck(
      existingNewKeys: existingNewKeys,
      legacyReader: legacyReader,
      migrationBatch: migrationBatch,
    );
    _migrateSkippedVersions(
      existingNewKeys: existingNewKeys,
      legacyReader: legacyReader,
      migrationBatch: migrationBatch,
    );

    return migrationBatch;
  }

  void _migrateProxy({
    required Set<String> existingNewKeys,
    required LegacyUpdatePreferencesReader legacyReader,
    required String? Function(String value) normalizeProxyUrl,
    required Map<String, Object> migrationBatch,
  }) {
    final needsEnabled =
        !existingNewKeys.contains(UpdateSettingsKeys.proxyEnabled);
    final needsUrl = !existingNewKeys.contains(UpdateSettingsKeys.proxyUrl);
    if (!needsEnabled && !needsUrl) {
      return;
    }

    final rawProxy = _readFirst(legacyReader, const <String>[
      LegacyUpdatePreferenceKeys.githubResourceProxyUrl,
      LegacyUpdatePreferenceKeys.historicalProxyUrl,
    ]);
    if (rawProxy is! String) {
      return;
    }

    final trimmedProxy = rawProxy.trim();
    if (trimmedProxy.isEmpty) {
      if (needsEnabled) {
        migrationBatch[UpdateSettingsKeys.proxyEnabled] = false;
      }
      if (needsUrl) {
        migrationBatch[UpdateSettingsKeys.proxyUrl] = defaultProxyUrl;
      }
      return;
    }

    final normalizedProxy = normalizeProxyUrl(trimmedProxy);
    if (normalizedProxy == null) {
      return;
    }
    if (needsEnabled) {
      migrationBatch[UpdateSettingsKeys.proxyEnabled] = true;
    }
    if (needsUrl) {
      migrationBatch[UpdateSettingsKeys.proxyUrl] = normalizedProxy;
    }
  }

  void _migrateBoolean({
    required String targetKey,
    required List<String> legacyKeys,
    required Set<String> existingNewKeys,
    required LegacyUpdatePreferencesReader legacyReader,
    required Map<String, Object> migrationBatch,
  }) {
    if (existingNewKeys.contains(targetKey)) {
      return;
    }
    final rawValue = _readFirst(legacyReader, legacyKeys);
    final parsedValue = _parseBoolean(rawValue);
    if (parsedValue != null) {
      migrationBatch[targetKey] = parsedValue;
    }
  }

  void _migrateLastCheck({
    required Set<String> existingNewKeys,
    required LegacyUpdatePreferencesReader legacyReader,
    required Map<String, Object> migrationBatch,
  }) {
    if (existingNewKeys.contains(UpdateSettingsKeys.lastSuccessfulCheckAt) ||
        existingNewKeys.contains(UpdateSettingsKeys.legacyLastCheckAt)) {
      return;
    }
    final rawValue = _readFirst(legacyReader, const <String>[
      LegacyUpdatePreferenceKeys.lastUpdateCheckTime,
      LegacyUpdatePreferenceKeys.historicalLastCheckMillis,
    ]);
    final timestamp = _parseTimestamp(rawValue);
    if (timestamp != null) {
      migrationBatch[UpdateSettingsKeys.legacyLastCheckAt] = timestamp;
    }
  }

  void _migrateSkippedVersions({
    required Set<String> existingNewKeys,
    required LegacyUpdatePreferencesReader legacyReader,
    required Map<String, Object> migrationBatch,
  }) {
    if (existingNewKeys.contains(UpdateSettingsKeys.skippedVersions)) {
      return;
    }
    final rawValue = _readFirst(legacyReader, const <String>[
      LegacyUpdatePreferenceKeys.skippedVersions,
      LegacyUpdatePreferenceKeys.historicalSkippedVersions,
    ]);
    final normalizedVersions = normalizeSkippedVersions(rawValue);
    if (rawValue != null) {
      migrationBatch[UpdateSettingsKeys.skippedVersions] = normalizedVersions;
    }
  }

  Object? _readFirst(
    LegacyUpdatePreferencesReader legacyReader,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = legacyReader.read(key);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  bool? _parseBoolean(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      if (value.toLowerCase() == 'true') {
        return true;
      }
      if (value.toLowerCase() == 'false') {
        return false;
      }
    }
    return null;
  }

  int? _parseTimestamp(Object? value) {
    final timestamp = switch (value) {
      int integerValue => integerValue,
      String stringValue => int.tryParse(stringValue.trim()),
      _ => null,
    };
    if (timestamp == null || timestamp < 0) {
      return null;
    }
    try {
      DateTime.fromMillisecondsSinceEpoch(timestamp);
      return timestamp;
    } on RangeError {
      return null;
    }
  }

  /// Normalizes exact SemVer values for persisted skip matching.
  static List<String> normalizeSkippedVersions(Object? rawValue) {
    final values = _decodeVersionValues(rawValue);
    final normalizedVersions = <String>{};
    for (final value in values) {
      if (value is! String) {
        continue;
      }
      final trimmedValue = value.trim();
      final versionText = trimmedValue.startsWith('v')
          ? trimmedValue.substring(1)
          : trimmedValue;
      final semanticVersion = SemanticVersion.tryParse(versionText);
      if (semanticVersion != null) {
        normalizedVersions.add(semanticVersion.skipKey);
      }
    }
    return normalizedVersions.toList()..sort();
  }

  static Iterable<Object?> _decodeVersionValues(Object? rawValue) {
    if (rawValue is List) {
      return rawValue;
    }
    if (rawValue is String) {
      try {
        final decodedValue = jsonDecode(rawValue);
        if (decodedValue is List) {
          return decodedValue;
        }
      } on FormatException {
        return const <Object?>[];
      }
    }
    return const <Object?>[];
  }
}
