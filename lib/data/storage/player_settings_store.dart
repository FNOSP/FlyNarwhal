import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import 'centered_window_bounds_codec.dart';
import 'preferences_manager.dart';

class PlayerSettingsStore {
  static const String _keyVolume = 'player_volume';
  static const String _keySpeed = 'player_speed';
  static const String _keyQualityResolution = 'player_quality_resolution';
  static const String _keyQualityBitrate = 'player_quality_bitrate';
  // Cloud-storage (网盘) playback preferences:
  // 'direct' (网盘直连播放) | 'proxy' (NAS 代理播放), keyed per cloud type.
  static const String _keyCloudPlayMode = 'player_cloud_play_mode';
  // Last chosen netdisk direct-link resolution (原画/流畅 …), stored apart
  // from the transcode quality so the two lists never cross-match.
  static const String _keyNetdiskQualityResolution =
      'player_netdisk_quality_resolution';
  static const String _keyAutoPlay = 'player_auto_play';
  static const String _keyWindowAspectRatio = 'player_window_aspect_ratio';
  static const String _keyVideoFillModeCache = 'player_video_fill_mode_cache';
  static const String _keyForceH264 = 'player_force_h264';
  static const String _keyForceSdrColor = 'player_force_sdr_color';
  // mpv hwdec decode mode: 'auto' | 'no' | 'auto-copy' | 'auto-unsafe'.
  static const String _keyDecodeMode = 'player_decode_mode';
  // Window geometry is persisted as geometric center + size (see
  // CenteredWindowBoundsCodec); legacy top-left keys under the same prefixes
  // are mirrored on write for downgrade compatibility.
  static const String _playerWindowBoundsPrefix = 'player_window';
  static const String _pipWindowBoundsPrefix = 'pip_window';
  // Whether the player window was last left maximized. Separate from the app
  // main window's maximized flag: the player keeps its own window form, so a
  // maximized player is restored maximized when any video is opened.
  static const String _keyPlayerWindowMaximized = 'player_window_maximized';
  static const String _keyDanmakuArea = 'danmaku_area';
  static const String _keyDanmakuOpacity = 'danmaku_opacity';
  static const String _keyDanmakuFontSize = 'danmaku_font_size';
  static const String _keyDanmakuSpeed = 'danmaku_speed';
  static const String _keyDanmakuSyncPlaybackSpeed =
      'danmaku_sync_playback_speed';
  static const String _keyDanmakuDebug = 'danmaku_debug';

  static double getVolume() {
    return SharedPreferences.getInstance().then((prefs) {
      return prefs.getDouble(_keyVolume) ?? 1.0;
    }).catchError((_) => 1.0) as double;
  }

  static Future<void> setVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyVolume, volume);
  }

  static double getSpeed() {
    return SharedPreferences.getInstance().then((prefs) {
      return prefs.getDouble(_keySpeed) ?? 1.0;
    }).catchError((_) => 1.0) as double;
  }

  static Future<void> setSpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySpeed, speed);
  }

  static bool getAutoPlay() {
    return SharedPreferences.getInstance().then((prefs) {
      return prefs.getBool(_keyAutoPlay) ?? true;
    }).catchError((_) => true) as bool;
  }

  static Future<void> setAutoPlay(bool autoPlay) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoPlay, autoPlay);
  }

  static String getWindowAspectRatio() {
    return SharedPreferences.getInstance().then((prefs) {
      return prefs.getString(_keyWindowAspectRatio) ?? 'AUTO';
    }).catchError((_) => 'AUTO') as String;
  }

  static Future<void> setWindowAspectRatio(String ratio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWindowAspectRatio, ratio);
  }

  static Future<String> getDecodeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDecodeMode) ?? 'auto';
  }

  static Future<void> setDecodeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDecodeMode, mode);
  }

  /// The player route keeps its own window geometry (position and size),
  /// separate from the rest of the app (mirrors the KMP player window's
  /// saved position/size). The position is stored as the window's geometric
  /// center; keep in sync with [PlayerSettingsManager] below.
  static Future<Rect?> getPlayerWindowBounds() async {
    final prefs = await SharedPreferences.getInstance();
    return CenteredWindowBoundsCodec.read(prefs, _playerWindowBoundsPrefix);
  }

  static Future<void> setPlayerWindowBounds(Rect bounds) async {
    final prefs = await SharedPreferences.getInstance();
    await CenteredWindowBoundsCodec.write(
        prefs, _playerWindowBoundsPrefix, bounds);
  }

  static Future<Rect?> getPipWindowBounds() async {
    final prefs = await SharedPreferences.getInstance();
    return CenteredWindowBoundsCodec.read(prefs, _pipWindowBoundsPrefix);
  }

  static Future<void> setPipWindowBounds(Rect bounds) async {
    final prefs = await SharedPreferences.getInstance();
    await CenteredWindowBoundsCodec.write(
        prefs, _pipWindowBoundsPrefix, bounds);
  }
}

class PlayerSavedQuality {
  final String resolution;
  final int? bitrate;

  const PlayerSavedQuality({
    required this.resolution,
    required this.bitrate,
  });
}

// Async version for use with providers
class PlayerSettingsManager {
  final SharedPreferences _prefs;
  final String? _userGuid;

  PlayerSettingsManager(this._prefs, {String? userGuid})
      : _userGuid = PreferencesManager.normalizeGuid(userGuid);

  String _scopedKey(String rawKey, {String? userGuid}) {
    final effective =
        PreferencesManager.normalizeGuid(userGuid) ?? _userGuid;
    if (effective == null) {
      return rawKey;
    }
    return '$effective::$rawKey';
  }

  double getVolume() => _readDoubleScoped(PlayerSettingsStore._keyVolume, 1.0);
  Future<void> setVolume(double volume) =>
      _writeDoubleScoped(PlayerSettingsStore._keyVolume, volume);

  double getSpeed() => _readDoubleScoped(PlayerSettingsStore._keySpeed, 1.0);
  Future<void> setSpeed(double speed) =>
      _writeDoubleScoped(PlayerSettingsStore._keySpeed, speed);

  PlayerSavedQuality? getQuality({String? userGuid}) {
    final scopedResolutionKey = _scopedKey(
      PlayerSettingsStore._keyQualityResolution,
      userGuid: userGuid,
    );
    final scopedBitrateKey = _scopedKey(
      PlayerSettingsStore._keyQualityBitrate,
      userGuid: userGuid,
    );
    final resolution = _prefs.getString(scopedResolutionKey) ??
        _prefs.getString(PlayerSettingsStore._keyQualityResolution);
    if (resolution == null || resolution.isEmpty) {
      return null;
    }
    return PlayerSavedQuality(
      resolution: resolution,
      bitrate: _prefs.getInt(scopedBitrateKey) ??
          _prefs.getInt(PlayerSettingsStore._keyQualityBitrate),
    );
  }

  Future<void> setQuality(
    String resolution,
    int? bitrate, {
    String? userGuid,
  }) async {
    final resolutionKey = _scopedKey(
      PlayerSettingsStore._keyQualityResolution,
      userGuid: userGuid,
    );
    final bitrateKey = _scopedKey(
      PlayerSettingsStore._keyQualityBitrate,
      userGuid: userGuid,
    );
    await _prefs.setString(resolutionKey, resolution);
    if (bitrate != null) {
      await _prefs.setInt(bitrateKey, bitrate);
      return;
    }
    await _prefs.remove(bitrateKey);
  }

  /// Saved cloud play mode for a cloud storage type: null means the default
  /// (网盘直连播放). Persisted per user + cloud type like the web player.
  String? getCloudPlayMode(int? cloudStorageType, String? userGuid) {
    if (cloudStorageType == null) return null;
    final key = _scopedKey(
      '${PlayerSettingsStore._keyCloudPlayMode}_$cloudStorageType',
      userGuid: userGuid,
    );
    return _prefs.getString(key);
  }

  Future<void> setCloudPlayMode(
    int? cloudStorageType,
    String mode, {
    String? userGuid,
  }) async {
    if (cloudStorageType == null) return;
    final key = _scopedKey(
      '${PlayerSettingsStore._keyCloudPlayMode}_$cloudStorageType',
      userGuid: userGuid,
    );
    await _prefs.setString(key, mode);
  }

  PlayerSavedQuality? getNetdiskQuality({String? userGuid}) {
    final key = _scopedKey(
      PlayerSettingsStore._keyNetdiskQualityResolution,
      userGuid: userGuid,
    );
    final resolution = _prefs.getString(key);
    if (resolution == null || resolution.isEmpty) return null;
    return PlayerSavedQuality(resolution: resolution, bitrate: null);
  }

  Future<void> setNetdiskQuality(String resolution, {String? userGuid}) async {
    final key = _scopedKey(
      PlayerSettingsStore._keyNetdiskQualityResolution,
      userGuid: userGuid,
    );
    await _prefs.setString(key, resolution);
  }

  double getDanmakuArea() =>
      _readDoubleScoped(PlayerSettingsStore._keyDanmakuArea, 1.0);
  Future<void> setDanmakuArea(double area) =>
      _writeDoubleScoped(PlayerSettingsStore._keyDanmakuArea, area);

  double getDanmakuOpacity() =>
      _readDoubleScoped(PlayerSettingsStore._keyDanmakuOpacity, 1.0);
  Future<void> setDanmakuOpacity(double opacity) =>
      _writeDoubleScoped(PlayerSettingsStore._keyDanmakuOpacity, opacity);

  double getDanmakuFontSizeScale() =>
      _readDoubleScoped(PlayerSettingsStore._keyDanmakuFontSize, 1.0);
  Future<void> setDanmakuFontSizeScale(double fontSizeScale) =>
      _writeDoubleScoped(PlayerSettingsStore._keyDanmakuFontSize, fontSizeScale);

  double getDanmakuSpeed() =>
      _readDoubleScoped(PlayerSettingsStore._keyDanmakuSpeed, 1.0);
  Future<void> setDanmakuSpeed(double speed) =>
      _writeDoubleScoped(PlayerSettingsStore._keyDanmakuSpeed, speed);

  bool getDanmakuSyncPlaybackSpeed() => _readBoolScoped(
      PlayerSettingsStore._keyDanmakuSyncPlaybackSpeed, false);
  Future<void> setDanmakuSyncPlaybackSpeed(bool syncPlaybackSpeed) =>
      _writeBoolScoped(
        PlayerSettingsStore._keyDanmakuSyncPlaybackSpeed,
        syncPlaybackSpeed,
      );

  bool getDanmakuDebugEnabled() =>
      _readBoolScoped(PlayerSettingsStore._keyDanmakuDebug, false);
  Future<void> setDanmakuDebugEnabled(bool debugEnabled) =>
      _writeBoolScoped(PlayerSettingsStore._keyDanmakuDebug, debugEnabled);

  bool getAutoPlay() =>
      _readBoolScoped(PlayerSettingsStore._keyAutoPlay, true);
  Future<void> setAutoPlay(bool autoPlay) =>
      _writeBoolScoped(PlayerSettingsStore._keyAutoPlay, autoPlay);

  String getWindowAspectRatio() =>
      _readStringScoped(PlayerSettingsStore._keyWindowAspectRatio, 'AUTO');
  Future<void> setWindowAspectRatio(String ratio) =>
      _writeStringScoped(PlayerSettingsStore._keyWindowAspectRatio, ratio);

  // mpv hwdec decode mode: 'auto' | 'no' | 'auto-copy' | 'auto-unsafe'.
  String getDecodeMode() =>
      _readStringScoped(PlayerSettingsStore._keyDecodeMode, 'auto');
  Future<void> setDecodeMode(String mode) =>
      _writeStringScoped(PlayerSettingsStore._keyDecodeMode, mode);

  // Mirrors the web player: the video fill mode is remembered per media item.
  String getVideoFillMode(String itemGuid) {
    if (itemGuid.isEmpty) return 'default';
    return _readVideoFillModeCache()[itemGuid] ?? 'default';
  }

  Future<void> setVideoFillMode(String itemGuid, String mode) async {
    if (itemGuid.isEmpty) return;
    final cache = _readVideoFillModeCache();
    cache.remove(itemGuid);
    cache[itemGuid] = mode;
    while (cache.length > 100) {
      cache.remove(cache.keys.first);
    }
    await _prefs.setString(
      PlayerSettingsStore._keyVideoFillModeCache,
      jsonEncode(cache),
    );
  }

  Map<String, String> _readVideoFillModeCache() {
    final raw = _prefs.getString(PlayerSettingsStore._keyVideoFillModeCache);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      }
    } catch (_) {
      // Ignore corrupted cache and start over.
    }
    return {};
  }

  bool getForceH264() =>
      _readBoolScoped(PlayerSettingsStore._keyForceH264, false);
  Future<void> setForceH264(bool enabled) =>
      _writeBoolScoped(PlayerSettingsStore._keyForceH264, enabled);

  bool getForceSdrColor() =>
      _readBoolScoped(PlayerSettingsStore._keyForceSdrColor, false);
  Future<void> setForceSdrColor(bool enabled) =>
      _writeBoolScoped(PlayerSettingsStore._keyForceSdrColor, enabled);

  // Window geometry: center + size persistence, keep in sync with the static
  // [PlayerSettingsStore] counterparts above.
  Rect? getPlayerWindowBounds() {
    return CenteredWindowBoundsCodec.read(
      _prefs,
      PlayerSettingsStore._playerWindowBoundsPrefix,
    );
  }

  Future<void> setPlayerWindowBounds(Rect bounds) {
    return CenteredWindowBoundsCodec.write(
      _prefs,
      PlayerSettingsStore._playerWindowBoundsPrefix,
      bounds,
    );
  }

  bool getPlayerWindowMaximized() {
    return _prefs.getBool(PlayerSettingsStore._keyPlayerWindowMaximized) ??
        false;
  }

  Future<void> setPlayerWindowMaximized(bool maximized) {
    return _prefs.setBool(
      PlayerSettingsStore._keyPlayerWindowMaximized,
      maximized,
    );
  }

  Rect? getPipWindowBounds() {
    return CenteredWindowBoundsCodec.read(
      _prefs,
      PlayerSettingsStore._pipWindowBoundsPrefix,
    );
  }

  Future<void> setPipWindowBounds(Rect bounds) {
    return CenteredWindowBoundsCodec.write(
      _prefs,
      PlayerSettingsStore._pipWindowBoundsPrefix,
      bounds,
    );
  }

  // 作用域读取：未登录读全局键；登录态只读 <guid>::<key>，无命中返回默认值。
  // 不再做"懒迁移"复制：迁移由 UserSettingsMigrator 统一处理并删除全局值。
  double _readDoubleScoped(String rawKey, double defaultValue) {
    final guid = _userGuid;
    if (guid == null) {
      return _prefs.getDouble(rawKey) ?? defaultValue;
    }
    return _prefs.getDouble('$guid::$rawKey') ?? defaultValue;
  }

  bool _readBoolScoped(String rawKey, bool defaultValue) {
    final guid = _userGuid;
    if (guid == null) {
      return _prefs.getBool(rawKey) ?? defaultValue;
    }
    return _prefs.getBool('$guid::$rawKey') ?? defaultValue;
  }

  String _readStringScoped(String rawKey, String defaultValue) {
    final guid = _userGuid;
    if (guid == null) {
      return _prefs.getString(rawKey) ?? defaultValue;
    }
    return _prefs.getString('$guid::$rawKey') ?? defaultValue;
  }

  Future<void> _writeDoubleScoped(String rawKey, double value) {
    return _prefs.setDouble(_scopedKey(rawKey), value);
  }

  Future<void> _writeBoolScoped(String rawKey, bool value) {
    return _prefs.setBool(_scopedKey(rawKey), value);
  }

  Future<void> _writeStringScoped(String rawKey, String value) {
    return _prefs.setString(_scopedKey(rawKey), value);
  }
}
