import 'dart:async';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/log/app_talker.dart';
import 'centered_window_bounds_codec.dart';
import 'legacy_update_preferences_migrator.dart';
import 'preferences_manager.dart';
import 'shortcut_settings_store.dart';
import 'update_settings_store.dart';

/// Result returned by [UserSettingsMigrator.migrateForUser].
class MigrationReport {
  MigrationReport({
    required this.alreadyCompleted,
    required final List<String> migratedKeys,
    required final List<String> skippedKeys,
    required final List<String> failedKeys,
  })  : migratedKeys = List.unmodifiable(migratedKeys),
        skippedKeys = List.unmodifiable(skippedKeys),
        failedKeys = List.unmodifiable(failedKeys);

  factory MigrationReport.empty({bool alreadyCompleted = false}) =>
      MigrationReport(
        alreadyCompleted: alreadyCompleted,
        migratedKeys: const [],
        skippedKeys: const [],
        failedKeys: const [],
      );

  /// True when the global `global_settings_migrated` flag was already set on
  /// entry; in that case no read/write is performed.
  final bool alreadyCompleted;

  /// Keys that had a legacy value copied into the user namespace.
  final List<String> migratedKeys;

  /// Keys that did not exist globally and therefore were skipped.
  final List<String> skippedKeys;

  /// Keys whose copy or removal failed; failures are logged but do not throw.
  final List<String> failedKeys;
}

/// One-shot migrator that copies globally-stored settings into the current
/// user's `<guid>::<key>` namespace and removes the global values.
///
/// Migration runs at most once per install: a `global_settings_migrated` flag
/// is set as soon as the pass finishes (regardless of partial failures) so
/// that subsequent logins on the same machine fall back to per-user defaults
/// instead of re-reading the (already emptied) global keys.
class UserSettingsMigrator {
  UserSettingsMigrator(
    this._prefs, {
    LegacyUpdatePreferencesReader? legacyReader,
  }) : _legacyReader = legacyReader ??
            SharedPreferencesLegacyUpdateReader(_prefs);

  /// Key persisted in the global namespace to record that the one-shot
  /// migration has already been attempted.
  static const String migrationFlagKey = 'global_settings_migrated';

  final SharedPreferences _prefs;
  final LegacyUpdatePreferencesReader _legacyReader;

  Future<MigrationReport> migrateForUser(String userGuid) async {
    if (_prefs.getBool(migrationFlagKey) == true) {
      AppTalker.info(
        'UserSettingsMigrator',
        'skipped (already migrated)',
      );
      return MigrationReport.empty(alreadyCompleted: true);
    }

    final normalizedGuid = PreferencesManager.normalizeGuid(userGuid);
    if (normalizedGuid == null) {
      AppTalker.warning(
        'UserSettingsMigrator',
        'migrateForUser called with empty guid; skipping',
      );
      return MigrationReport.empty();
    }

    final migrated = <String>[];
    final skipped = <String>[];
    final failed = <String>[];

    await _migratePreferencesManager(normalizedGuid, migrated, skipped, failed);
    await _migrateFlyNarwhalSettings(normalizedGuid, migrated, skipped, failed);
    await _migratePlayerSettings(normalizedGuid, migrated, skipped, failed);
    await _migrateShortcutSettings(normalizedGuid, migrated, skipped, failed);
    await _migrateUpdateSettings(normalizedGuid, migrated, skipped, failed);

    // Set the flag regardless of partial failures: subsequent users should
    // never re-read the global namespace. A failure here is logged and the
    // next launch will retry the whole pass.
    try {
      await _prefs.setBool(migrationFlagKey, true);
    } catch (error, stackTrace) {
      AppTalker.instance.handle(error, stackTrace);
      failed.add(migrationFlagKey);
    }

    AppTalker.info(
      'UserSettingsMigrator',
      'migrated=${migrated.length} skipped=${skipped.length} '
          'failed=${failed.length} guid=$normalizedGuid',
    );
    if (failed.isNotEmpty) {
      AppTalker.warning(
        'UserSettingsMigrator',
        'failed keys: ${failed.join(", ")}',
      );
    }

    return MigrationReport(
      alreadyCompleted: false,
      migratedKeys: migrated,
      skippedKeys: skipped,
      failedKeys: failed,
    );
  }

  // ---- PreferencesManager ------------------------------------------------

  static const String _kFollowSystemTheme = 'follow_system_theme';
  static const String _kDarkMode = 'dark_mode';
  static const String _kNavigationDisplayMode = 'navigation_display_mode';
  static const String _kEpisodeListViewType = 'episode_list_view_type';
  static const String _kSmartSkipEnabled = 'smart_skip_enabled';

  Future<void> _migratePreferencesManager(
    String guid,
    List<String> migrated,
    List<String> skipped,
    List<String> failed,
  ) async {
    await _migrateBool(guid, _kFollowSystemTheme, migrated, skipped, failed);
    await _migrateBool(guid, _kDarkMode, migrated, skipped, failed);
    await _migrateString(
      guid,
      _kNavigationDisplayMode,
      migrated,
      skipped,
      failed,
    );
    await _migrateString(
      guid,
      _kEpisodeListViewType,
      migrated,
      skipped,
      failed,
    );
    await _migrateBool(guid, _kSmartSkipEnabled, migrated, skipped, failed);
  }

  // ---- FlyNarwhalSettings ------------------------------------------------

  static const String _kFlyNarwhalEnabled = 'fly_narwhal_server_enabled';
  static const String _kFlyNarwhalBaseUrl = 'fly_narwhal_server_base_url';
  static const String _kFlyNarwhalAuthCode = 'fly_narwhal_server_auth_code';

  Future<void> _migrateFlyNarwhalSettings(
    String guid,
    List<String> migrated,
    List<String> skipped,
    List<String> failed,
  ) async {
    await _migrateBool(guid, _kFlyNarwhalEnabled, migrated, skipped, failed);
    await _migrateString(guid, _kFlyNarwhalBaseUrl, migrated, skipped, failed);
    await _migrateString(
      guid,
      _kFlyNarwhalAuthCode,
      migrated,
      skipped,
      failed,
    );
  }

  // ---- PlayerSettingsManager --------------------------------------------

  static const String _kPlayerVolume = 'player_volume';
  static const String _kPlayerSpeed = 'player_speed';
  static const String _kPlayerQualityResolution = 'player_quality_resolution';
  static const String _kPlayerQualityBitrate = 'player_quality_bitrate';
  static const String _kPlayerAutoPlay = 'player_auto_play';
  static const String _kPlayerWindowAspectRatio = 'player_window_aspect_ratio';
  static const String _kPlayerVideoFillModeCache =
      'player_video_fill_mode_cache';
  static const String _kPlayerForceH264 = 'player_force_h264';
  static const String _kPlayerForceSdrColor = 'player_force_sdr_color';
  static const String _kPlayerDecodeMode = 'player_decode_mode';
  static const String _kDanmakuArea = 'danmaku_area';
  static const String _kDanmakuOpacity = 'danmaku_opacity';
  static const String _kDanmakuFontSize = 'danmaku_font_size';
  static const String _kDanmakuSpeed = 'danmaku_speed';
  static const String _kDanmakuSyncPlaybackSpeed = 'danmaku_sync_playback_speed';
  static const String _kDanmakuDebug = 'danmaku_debug';
  static const String _kPlayerWindowBoundsPrefix = 'player_window';
  static const String _kPipWindowBoundsPrefix = 'pip_window';

  Future<void> _migratePlayerSettings(
    String guid,
    List<String> migrated,
    List<String> skipped,
    List<String> failed,
  ) async {
    await _migrateDouble(guid, _kPlayerVolume, migrated, skipped, failed);
    await _migrateDouble(guid, _kPlayerSpeed, migrated, skipped, failed);
    await _migrateString(
      guid,
      _kPlayerQualityResolution,
      migrated,
      skipped,
      failed,
    );
    await _migrateInt(guid, _kPlayerQualityBitrate, migrated, skipped, failed);
    await _migrateBool(guid, _kPlayerAutoPlay, migrated, skipped, failed);
    await _migrateString(
      guid,
      _kPlayerWindowAspectRatio,
      migrated,
      skipped,
      failed,
    );
    await _migrateVideoFillModeCache(guid, migrated, skipped, failed);
    await _migrateBool(guid, _kPlayerForceH264, migrated, skipped, failed);
    await _migrateBool(
      guid,
      _kPlayerForceSdrColor,
      migrated,
      skipped,
      failed,
    );
    await _migrateString(guid, _kPlayerDecodeMode, migrated, skipped, failed);
    await _migrateDouble(guid, _kDanmakuArea, migrated, skipped, failed);
    await _migrateDouble(guid, _kDanmakuOpacity, migrated, skipped, failed);
    await _migrateDouble(guid, _kDanmakuFontSize, migrated, skipped, failed);
    await _migrateDouble(guid, _kDanmakuSpeed, migrated, skipped, failed);
    await _migrateBool(
      guid,
      _kDanmakuSyncPlaybackSpeed,
      migrated,
      skipped,
      failed,
    );
    await _migrateBool(guid, _kDanmakuDebug, migrated, skipped, failed);
    await _migrateWindowBounds(
      guid,
      _kPlayerWindowBoundsPrefix,
      migrated,
      skipped,
      failed,
    );
    await _migrateWindowBounds(
      guid,
      _kPipWindowBoundsPrefix,
      migrated,
      skipped,
      failed,
    );
  }

  Future<void> _migrateVideoFillModeCache(
    String guid,
    List<String> migrated,
    List<String> skipped,
    List<String> failed,
  ) async {
    final raw = _prefs.getString(_kPlayerVideoFillModeCache);
    if (raw == null) {
      skipped.add(_kPlayerVideoFillModeCache);
      return;
    }
    try {
      await _prefs.setString('$guid::$_kPlayerVideoFillModeCache', raw);
      await _prefs.remove(_kPlayerVideoFillModeCache);
      migrated.add(_kPlayerVideoFillModeCache);
    } catch (error, stackTrace) {
      AppTalker.instance.handle(error, stackTrace);
      failed.add(_kPlayerVideoFillModeCache);
    }
  }

  Future<void> _migrateWindowBounds(
    String guid,
    String prefix,
    List<String> migrated,
    List<String> skipped,
    List<String> failed,
  ) async {
    final Rect? bounds = CenteredWindowBoundsCodec.read(_prefs, prefix);
    if (bounds == null) {
      skipped.add(prefix);
      return;
    }
    try {
      await CenteredWindowBoundsCodec.write(_prefs, '$guid::$prefix', bounds);
      await _removeAllKeysWithPrefix(prefix);
      migrated.add(prefix);
    } catch (error, stackTrace) {
      AppTalker.instance.handle(error, stackTrace);
      failed.add(prefix);
    }
  }

  Future<void> _removeAllKeysWithPrefix(String prefix) async {
    final candidates = <String>[];
    for (final key in _prefs.getKeys()) {
      if (key == prefix ||
          key.startsWith('${prefix}_') ||
          key.startsWith('$prefix.')) {
        candidates.add(key);
      }
    }
    for (final key in candidates) {
      await _prefs.remove(key);
    }
  }

  // ---- ShortcutSettingsStore --------------------------------------------

  Future<void> _migrateShortcutSettings(
    String guid,
    List<String> migrated,
    List<String> skipped,
    List<String> failed,
  ) async {
    for (final definition in ShortcutSettingsStore.definitions) {
      for (final slot in const ['primary', 'secondary']) {
        final rawKey = 'shortcut.${definition.id.name}.$slot';
        await _migrateString(guid, rawKey, migrated, skipped, failed);
      }
    }
  }

  // ---- UpdateSettingsStore ----------------------------------------------

  Future<void> _migrateUpdateSettings(
    String guid,
    List<String> migrated,
    List<String> skipped,
    List<String> failed,
  ) async {
    // Pass 1: migrate KMP legacy values (github_resource_proxy_url, ...) into
    // `<guid>::update.*`, using the legacy reader which only reads global
    // legacy keys — it never consults global `update.*`.
    // No scoped keys exist yet on first login, so pass an empty existing-set
    // to force the migrator to read every legacy source.
    const migrator = LegacyUpdatePreferencesMigrator(
      defaultProxyUrl: UpdateSettingsStore.defaultProxyUrl,
    );
    final Map<String, Object> legacyBatch = migrator.createMigrationBatch(
      existingNewKeys: const <String>{},
      legacyReader: _legacyReader,
      normalizeProxyUrl: UpdateSettingsStore.normalizeProxyUrl,
    );
    for (final entry in legacyBatch.entries) {
      final scopedKey = '$guid::${entry.key}';
      try {
        await _writeBatchEntry(scopedKey, entry.value);
        migrated.add('${entry.key} (from KMP legacy)');
      } catch (error, stackTrace) {
        AppTalker.instance.handle(error, stackTrace);
        failed.add('${entry.key} (from KMP legacy)');
      }
    }

    // Pass 2: migrate global Flutter `update.*` values (first-install
    // defaults or lazy-migration leftovers) into `<guid>::update.*`, then
    // remove the global keys. Preserve any user-edited value over the KMP
    // legacy value by writing it last.
    final globalUpdateKeys = _prefs
        .getKeys()
        .where((key) => key.startsWith('update.'))
        .toList();
    for (final rawKey in globalUpdateKeys) {
      if (rawKey == UpdateSettingsKeys.schemaVersion) continue;
      final Object? value = _prefs.get(rawKey);
      if (value == null) {
        skipped.add(rawKey);
        continue;
      }
      final scopedKey = '$guid::$rawKey';
      try {
        await _writeBatchEntry(scopedKey, value);
        await _prefs.remove(rawKey);
        migrated.add(rawKey);
      } catch (error, stackTrace) {
        AppTalker.instance.handle(error, stackTrace);
        failed.add(rawKey);
      }
    }

    // Remove the global schema version marker too (it is regenerated per-user
    // by UpdateSettingsStore.initialize).
    if (_prefs.getKeys().contains(UpdateSettingsKeys.schemaVersion)) {
      try {
        await _prefs.remove(UpdateSettingsKeys.schemaVersion);
      } catch (error, stackTrace) {
        AppTalker.instance.handle(error, stackTrace);
        failed.add(UpdateSettingsKeys.schemaVersion);
      }
    }

    // Also remove KMP legacy keys the migrator may have read from, so the
    // global namespace stays clean for the rest of the migration pass.
    const legacyKeys = <String>[
      LegacyUpdatePreferenceKeys.githubResourceProxyUrl,
      LegacyUpdatePreferenceKeys.includePrerelease,
      LegacyUpdatePreferenceKeys.autoDownloadUpdates,
      LegacyUpdatePreferenceKeys.lastUpdateCheckTime,
      LegacyUpdatePreferenceKeys.skippedVersions,
      LegacyUpdatePreferenceKeys.historicalProxyUrl,
      LegacyUpdatePreferenceKeys.historicalIncludePrerelease,
      LegacyUpdatePreferenceKeys.historicalAutoDownload,
      LegacyUpdatePreferenceKeys.historicalLastCheckMillis,
      LegacyUpdatePreferenceKeys.historicalSkippedVersions,
    ];
    for (final key in legacyKeys) {
      if (_prefs.getKeys().contains(key)) {
        try {
          await _prefs.remove(key);
        } catch (error, stackTrace) {
          AppTalker.instance.handle(error, stackTrace);
          failed.add(key);
        }
      }
    }
  }

  // ---- Helpers ----------------------------------------------------------

  Future<void> _writeBatchEntry(String scopedKey, Object value) async {
    if (value is bool) {
      await _prefs.setBool(scopedKey, value);
    } else if (value is int) {
      await _prefs.setInt(scopedKey, value);
    } else if (value is String) {
      await _prefs.setString(scopedKey, value);
    } else if (value is List) {
      // SharedPreferences.get may return a raw List<dynamic>; normalise each
      // element to String before persisting as a string list.
      await _prefs.setStringList(
        scopedKey,
        value.map((e) => e.toString()).toList(),
      );
    } else {
      throw ArgumentError.value(value, scopedKey);
    }
  }

  Future<void> _migrateBool(
    String guid,
    String rawKey,
    List<String> migrated,
    List<String> skipped,
    List<String> failed,
  ) async {
    final value = _prefs.getBool(rawKey);
    if (value == null) {
      skipped.add(rawKey);
      return;
    }
    try {
      await _prefs.setBool('$guid::$rawKey', value);
      await _prefs.remove(rawKey);
      migrated.add(rawKey);
    } catch (error, stackTrace) {
      AppTalker.instance.handle(error, stackTrace);
      failed.add(rawKey);
    }
  }

  Future<void> _migrateString(
    String guid,
    String rawKey,
    List<String> migrated,
    List<String> skipped,
    List<String> failed,
  ) async {
    final value = _prefs.getString(rawKey);
    if (value == null) {
      skipped.add(rawKey);
      return;
    }
    try {
      await _prefs.setString('$guid::$rawKey', value);
      await _prefs.remove(rawKey);
      migrated.add(rawKey);
    } catch (error, stackTrace) {
      AppTalker.instance.handle(error, stackTrace);
      failed.add(rawKey);
    }
  }

  Future<void> _migrateDouble(
    String guid,
    String rawKey,
    List<String> migrated,
    List<String> skipped,
    List<String> failed,
  ) async {
    final value = _prefs.getDouble(rawKey);
    if (value == null) {
      skipped.add(rawKey);
      return;
    }
    try {
      await _prefs.setDouble('$guid::$rawKey', value);
      await _prefs.remove(rawKey);
      migrated.add(rawKey);
    } catch (error, stackTrace) {
      AppTalker.instance.handle(error, stackTrace);
      failed.add(rawKey);
    }
  }

  Future<void> _migrateInt(
    String guid,
    String rawKey,
    List<String> migrated,
    List<String> skipped,
    List<String> failed,
  ) async {
    final value = _prefs.getInt(rawKey);
    if (value == null) {
      skipped.add(rawKey);
      return;
    }
    try {
      await _prefs.setInt('$guid::$rawKey', value);
      await _prefs.remove(rawKey);
      migrated.add(rawKey);
    } catch (error, stackTrace) {
      AppTalker.instance.handle(error, stackTrace);
      failed.add(rawKey);
    }
  }
}
