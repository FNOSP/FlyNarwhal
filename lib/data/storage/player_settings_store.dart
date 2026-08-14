import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import 'centered_window_bounds_codec.dart';

class PlayerSettingsStore {
  static const String _keyVolume = 'player_volume';
  static const String _keySpeed = 'player_speed';
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
    await CenteredWindowBoundsCodec.write(prefs, _playerWindowBoundsPrefix, bounds);
  }

  static Future<Rect?> getPipWindowBounds() async {
    final prefs = await SharedPreferences.getInstance();
    return CenteredWindowBoundsCodec.read(prefs, _pipWindowBoundsPrefix);
  }

  static Future<void> setPipWindowBounds(Rect bounds) async {
    final prefs = await SharedPreferences.getInstance();
    await CenteredWindowBoundsCodec.write(prefs, _pipWindowBoundsPrefix, bounds);
  }
}

// Async version for use with providers
class PlayerSettingsManager {
  final SharedPreferences _prefs;

  PlayerSettingsManager(this._prefs);

  double getVolume() => _prefs.getDouble(PlayerSettingsStore._keyVolume) ?? 1.0;
  Future<void> setVolume(double volume) =>
      _prefs.setDouble(PlayerSettingsStore._keyVolume, volume);

  double getSpeed() => _prefs.getDouble(PlayerSettingsStore._keySpeed) ?? 1.0;
  Future<void> setSpeed(double speed) =>
      _prefs.setDouble(PlayerSettingsStore._keySpeed, speed);

  double getDanmakuArea() =>
      _prefs.getDouble(PlayerSettingsStore._keyDanmakuArea) ?? 1.0;
  Future<void> setDanmakuArea(double area) =>
      _prefs.setDouble(PlayerSettingsStore._keyDanmakuArea, area);

  double getDanmakuOpacity() =>
      _prefs.getDouble(PlayerSettingsStore._keyDanmakuOpacity) ?? 1.0;
  Future<void> setDanmakuOpacity(double opacity) =>
      _prefs.setDouble(PlayerSettingsStore._keyDanmakuOpacity, opacity);

  double getDanmakuFontSizeScale() =>
      _prefs.getDouble(PlayerSettingsStore._keyDanmakuFontSize) ?? 1.0;
  Future<void> setDanmakuFontSizeScale(double fontSizeScale) =>
      _prefs.setDouble(PlayerSettingsStore._keyDanmakuFontSize, fontSizeScale);

  double getDanmakuSpeed() =>
      _prefs.getDouble(PlayerSettingsStore._keyDanmakuSpeed) ?? 1.0;
  Future<void> setDanmakuSpeed(double speed) =>
      _prefs.setDouble(PlayerSettingsStore._keyDanmakuSpeed, speed);

  bool getDanmakuSyncPlaybackSpeed() =>
      _prefs.getBool(PlayerSettingsStore._keyDanmakuSyncPlaybackSpeed) ?? false;
  Future<void> setDanmakuSyncPlaybackSpeed(bool syncPlaybackSpeed) =>
      _prefs.setBool(
        PlayerSettingsStore._keyDanmakuSyncPlaybackSpeed,
        syncPlaybackSpeed,
      );

  bool getDanmakuDebugEnabled() =>
      _prefs.getBool(PlayerSettingsStore._keyDanmakuDebug) ?? false;
  Future<void> setDanmakuDebugEnabled(bool debugEnabled) =>
      _prefs.setBool(PlayerSettingsStore._keyDanmakuDebug, debugEnabled);

  bool getAutoPlay() =>
      _prefs.getBool(PlayerSettingsStore._keyAutoPlay) ?? true;
  Future<void> setAutoPlay(bool autoPlay) =>
      _prefs.setBool(PlayerSettingsStore._keyAutoPlay, autoPlay);

  String getWindowAspectRatio() =>
      _prefs.getString(PlayerSettingsStore._keyWindowAspectRatio) ?? 'AUTO';
  Future<void> setWindowAspectRatio(String ratio) =>
      _prefs.setString(PlayerSettingsStore._keyWindowAspectRatio, ratio);

  // mpv hwdec decode mode: 'auto' | 'no' | 'auto-copy' | 'auto-unsafe'.
  String getDecodeMode() =>
      _prefs.getString(PlayerSettingsStore._keyDecodeMode) ?? 'auto';
  Future<void> setDecodeMode(String mode) =>
      _prefs.setString(PlayerSettingsStore._keyDecodeMode, mode);

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
      _prefs.getBool(PlayerSettingsStore._keyForceH264) ?? false;
  Future<void> setForceH264(bool enabled) =>
      _prefs.setBool(PlayerSettingsStore._keyForceH264, enabled);

  bool getForceSdrColor() =>
      _prefs.getBool(PlayerSettingsStore._keyForceSdrColor) ?? false;
  Future<void> setForceSdrColor(bool enabled) =>
      _prefs.setBool(PlayerSettingsStore._keyForceSdrColor, enabled);

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
}
