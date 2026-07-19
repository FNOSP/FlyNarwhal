import 'dart:convert';

import '../../core/security/password_cipher.dart';
import '../models/login_history.dart';
import 'account_settings_store.dart';

/// Converts decoded KMP Java Preferences values into Flutter namespaces.
class KmpPreferencesMigrationService {
  KmpPreferencesMigrationService({
    required AccountSettingsStore accountSettingsStore,
    required PasswordCipher passwordCipher,
  })  : _accountSettingsStore = accountSettingsStore,
        _passwordCipher = passwordCipher;

  static const String migrationStatusKey = 'migration.kmp1.status';
  static const String migrationReportKey = 'migration.kmp1.report';

  final AccountSettingsStore _accountSettingsStore;
  final PasswordCipher _passwordCipher;

  Future<KmpMigrationReport> migrate(Map<String, String> rawValues) async {
    final completedStatus =
        _accountSettingsStore.readGlobal<String>(migrationStatusKey);
    if (completedStatus == 'completed') {
      return KmpMigrationReport(alreadyCompleted: true);
    }

    await _accountSettingsStore.initializeSchema();
    final report = KmpMigrationReport();
    final activeGuid = _findSingleAccountGuid(rawValues);
    await _migrateGlobalValues(rawValues, report);
    await _migrateLoginHistory(rawValues, report);
    await _migrateScopedValues(rawValues, activeGuid, report);

    await _accountSettingsStore.writeGlobal(
      migrationReportKey,
      jsonEncode(report.toJson()),
    );
    await _accountSettingsStore.writeGlobal(migrationStatusKey, 'completed');
    return report;
  }

  Future<void> _migrateGlobalValues(
    Map<String, String> rawValues,
    KmpMigrationReport report,
  ) async {
    const globalMappings = <String, String>{
      'window_width': 'window.width',
      'window_height': 'window.height',
      'window_x': 'window.x',
      'window_y': 'window.y',
      'isWindowMaximized': 'window.maximized',
      'fallbackDeviceId': 'fallbackDeviceId',
    };

    for (final mapping in globalMappings.entries) {
      final rawValue = rawValues[mapping.key];
      if (rawValue == null || rawValue == 'NaN') {
        continue;
      }
      final value = _parsePreferenceValue(rawValue);
      if (value == null) {
        report.skippedEntries++;
        continue;
      }
      await _accountSettingsStore.writeGlobal(mapping.value, value);
      report.migratedEntries++;
    }
  }

  Future<void> _migrateLoginHistory(
    Map<String, String> rawValues,
    KmpMigrationReport report,
  ) async {
    final historyJson = rawValues['loginHistory'];
    if (historyJson == null || historyJson.isEmpty) {
      return;
    }
    try {
      final decodedHistory = jsonDecode(historyJson) as List<dynamic>;
      final migratedHistory = <Map<String, dynamic>>[];
      for (final rawEntry in decodedHistory) {
        if (rawEntry is! Map) {
          report.skippedEntries++;
          continue;
        }
        final entry =
            _normalizeLegacyJsonMap(Map<String, dynamic>.from(rawEntry));
        final history = LoginHistory.fromJson(entry);
        final encryptedPassword =
            await _encryptHistoryPassword(history.password);
        final migratedEntry = history.toJson()
          ..['password'] = encryptedPassword
          ..['passwordEncrypted'] = encryptedPassword != null;
        migratedHistory.add(migratedEntry);
        report.migratedEntries++;
      }
      await _accountSettingsStore.writeGlobal(
        'loginHistory',
        jsonEncode(migratedHistory),
      );
    } catch (_) {
      report.skippedEntries++;
    }
  }

  Future<void> _migrateScopedValues(
    Map<String, String> rawValues,
    String? activeGuid,
    KmpMigrationReport report,
  ) async {
    const settingMappings = <String, String>{
      'github_resource_proxy_url': 'githubResourceProxyUrl',
      'isFollowingSystemTheme': 'followSystemTheme',
      'dark_mode': 'darkMode',
      'navigation_display_mode': 'navigationDisplayMode',
      'include_prerelease': 'updates.includePrerelease',
      'auto_download_updates': 'updates.autoDownload',
      'last_update_check_time': 'updates.lastCheckMillis',
      'skipped_versions': 'updates.skippedVersions',
      'ssl_ignore_host_whitelist': 'security.sslIgnoreHostWhitelist',
      'smart_analysis_enabled': 'flyNarwhal.enabled',
      'smart_analysis_base_url': 'flyNarwhal.baseUrl',
      'auth_code': 'flyNarwhal.authCode',
      'player_volume': 'player.volume',
      'auto_play': 'player.autoPlay',
      'player_window_aspect_ratio': 'player.aspectRatio',
      'danmaku_area': 'danmaku.area',
      'danmaku_opacity': 'danmaku.opacity',
      'danmaku_font_size': 'danmaku.fontSize',
      'danmaku_speed': 'danmaku.speed',
      'danmaku_sync_playback_speed': 'danmaku.syncPlaybackSpeed',
      'danmaku_debug': 'danmaku.debug',
    };

    for (final rawEntry in rawValues.entries) {
      final scopedKey = _parseScopedKey(rawEntry.key);
      final guid = scopedKey?.guid ?? activeGuid;
      final rawSetting = scopedKey?.setting ?? rawEntry.key;
      final targetSetting = settingMappings[rawSetting];
      if (guid == null || targetSetting == null) {
        continue;
      }
      if (scopedKey == null &&
          _hasScopedOverride(rawValues, guid, rawSetting)) {
        continue;
      }
      final value = _parsePreferenceValue(rawEntry.value);
      if (value == null) {
        report.skippedEntries++;
        continue;
      }
      await _accountSettingsStore.writeAccount(
        guid: guid,
        setting: targetSetting,
        value: value,
      );
      report.migratedEntries++;
    }
  }

  Future<String?> _encryptHistoryPassword(String? password) async {
    if (password == null || password.isEmpty) {
      return null;
    }
    return _passwordCipher.encrypt(password);
  }

  String? _findSingleAccountGuid(Map<String, String> rawValues) {
    final guids = rawValues.keys
        .map(_parseScopedKey)
        .whereType<_ScopedPreferenceKey>()
        .map((key) => key.guid)
        .toSet();
    return guids.length == 1 ? guids.single : null;
  }

  bool _hasScopedOverride(
    Map<String, String> rawValues,
    String guid,
    String setting,
  ) {
    return rawValues.containsKey('$guid::$setting');
  }

  _ScopedPreferenceKey? _parseScopedKey(String key) {
    final separatorIndex = key.indexOf('::');
    if (separatorIndex <= 0 || separatorIndex == key.length - 2) {
      return null;
    }
    return _ScopedPreferenceKey(
      guid: key.substring(0, separatorIndex),
      setting: key.substring(separatorIndex + 2),
    );
  }

  Object? _parsePreferenceValue(String value) {
    final normalizedUrl = _normalizeLegacyUrl(value);
    if (normalizedUrl != null) {
      return normalizedUrl;
    }
    if (value == 'true' || value == 'false') {
      return value == 'true';
    }
    final integerValue = int.tryParse(value);
    if (integerValue != null) {
      return integerValue;
    }
    final doubleValue = double.tryParse(value);
    if (doubleValue != null && doubleValue.isFinite) {
      return doubleValue;
    }
    return value;
  }

  Map<String, dynamic> _normalizeLegacyJsonMap(Map<String, dynamic> json) {
    return json.map((key, value) {
      return MapEntry(_decodeLegacyKey(key), _normalizeLegacyJsonValue(value));
    });
  }

  dynamic _normalizeLegacyJsonValue(dynamic value) {
    if (value is Map) {
      return _normalizeLegacyJsonMap(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      return value.map(_normalizeLegacyJsonValue).toList();
    }
    if (value is String) {
      return _normalizeLegacyUrl(value) ?? value;
    }
    return value;
  }

  String _decodeLegacyKey(String key) {
    final buffer = StringBuffer();
    var uppercaseNext = false;
    for (final codePoint in key.runes) {
      final character = String.fromCharCode(codePoint);
      if (character == '/') {
        uppercaseNext = true;
        continue;
      }
      if (uppercaseNext && codePoint >= 0x61 && codePoint <= 0x7A) {
        buffer.writeCharCode(codePoint - 0x20);
      } else {
        buffer.write(character);
      }
      uppercaseNext = false;
    }
    return buffer.toString();
  }

  String? _normalizeLegacyUrl(String value) {
    final match = RegExp(r'^(https?):\\+').firstMatch(value);
    if (match == null) {
      return null;
    }
    final scheme = match.group(1)!;
    final suffix = value.substring(match.end).replaceAll('\\', '/');
    return '$scheme://$suffix';
  }
}

class KmpMigrationReport {
  KmpMigrationReport({
    this.alreadyCompleted = false,
    this.migratedEntries = 0,
    this.skippedEntries = 0,
  });

  int migratedEntries;
  int skippedEntries;
  final bool alreadyCompleted;

  Map<String, Object> toJson() => <String, Object>{
        'alreadyCompleted': alreadyCompleted,
        'migratedEntries': migratedEntries,
        'skippedEntries': skippedEntries,
      };
}

class _ScopedPreferenceKey {
  const _ScopedPreferenceKey({required this.guid, required this.setting});

  final String guid;
  final String setting;
}
