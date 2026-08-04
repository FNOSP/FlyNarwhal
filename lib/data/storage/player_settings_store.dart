import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

class PlayerSettingsStore {
  static const String _keyVolume = 'player_volume';
  static const String _keySpeed = 'player_speed';
  static const String _keyAutoPlay = 'player_auto_play';
  static const String _keyWindowAspectRatio = 'player_window_aspect_ratio';
  static const String _keyPlayerWindowLeft = 'player_window_left';
  static const String _keyPlayerWindowTop = 'player_window_top';
  static const String _keyPlayerWindowWidth = 'player_window_width';
  static const String _keyPlayerWindowHeight = 'player_window_height';
  static const String _keyPipWindowLeft = 'pip_window_left';
  static const String _keyPipWindowTop = 'pip_window_top';
  static const String _keyPipWindowWidth = 'pip_window_width';
  static const String _keyPipWindowHeight = 'pip_window_height';
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

  /// The player route keeps its own window geometry (position and size),
  /// separate from the rest of the app (mirrors the KMP player window's
  /// saved position/size).
  static Future<Rect?> getPlayerWindowBounds() async {
    final prefs = await SharedPreferences.getInstance();
    final left = prefs.getDouble(_keyPlayerWindowLeft);
    final top = prefs.getDouble(_keyPlayerWindowTop);
    final width = prefs.getDouble(_keyPlayerWindowWidth);
    final height = prefs.getDouble(_keyPlayerWindowHeight);
    if (left == null ||
        top == null ||
        width == null ||
        height == null ||
        width <= 0 ||
        height <= 0) {
      return null;
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  static Future<void> setPlayerWindowBounds(Rect bounds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPlayerWindowLeft, bounds.left);
    await prefs.setDouble(_keyPlayerWindowTop, bounds.top);
    await prefs.setDouble(_keyPlayerWindowWidth, bounds.width);
    await prefs.setDouble(_keyPlayerWindowHeight, bounds.height);
  }

  static Future<Rect?> getPipWindowBounds() async {
    final prefs = await SharedPreferences.getInstance();
    final left = prefs.getDouble(_keyPipWindowLeft);
    final top = prefs.getDouble(_keyPipWindowTop);
    final width = prefs.getDouble(_keyPipWindowWidth);
    final height = prefs.getDouble(_keyPipWindowHeight);
    if (left == null || top == null || width == null || height == null) {
      return null;
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  static Future<void> setPipWindowBounds(Rect bounds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPipWindowLeft, bounds.left);
    await prefs.setDouble(_keyPipWindowTop, bounds.top);
    await prefs.setDouble(_keyPipWindowWidth, bounds.width);
    await prefs.setDouble(_keyPipWindowHeight, bounds.height);
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

  Rect? getPlayerWindowBounds() {
    final left = _prefs.getDouble(PlayerSettingsStore._keyPlayerWindowLeft);
    final top = _prefs.getDouble(PlayerSettingsStore._keyPlayerWindowTop);
    final width = _prefs.getDouble(PlayerSettingsStore._keyPlayerWindowWidth);
    final height = _prefs.getDouble(PlayerSettingsStore._keyPlayerWindowHeight);
    if (left == null ||
        top == null ||
        width == null ||
        height == null ||
        width <= 0 ||
        height <= 0) {
      return null;
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  Future<void> setPlayerWindowBounds(Rect bounds) async {
    await _prefs.setDouble(PlayerSettingsStore._keyPlayerWindowLeft, bounds.left);
    await _prefs.setDouble(PlayerSettingsStore._keyPlayerWindowTop, bounds.top);
    await _prefs.setDouble(
      PlayerSettingsStore._keyPlayerWindowWidth,
      bounds.width,
    );
    await _prefs.setDouble(
      PlayerSettingsStore._keyPlayerWindowHeight,
      bounds.height,
    );
  }

  Rect? getPipWindowBounds() {
    final left = _prefs.getDouble(PlayerSettingsStore._keyPipWindowLeft);
    final top = _prefs.getDouble(PlayerSettingsStore._keyPipWindowTop);
    final width = _prefs.getDouble(PlayerSettingsStore._keyPipWindowWidth);
    final height = _prefs.getDouble(PlayerSettingsStore._keyPipWindowHeight);
    if (left == null || top == null || width == null || height == null) {
      return null;
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  Future<void> setPipWindowBounds(Rect bounds) async {
    await _prefs.setDouble(PlayerSettingsStore._keyPipWindowLeft, bounds.left);
    await _prefs.setDouble(PlayerSettingsStore._keyPipWindowTop, bounds.top);
    await _prefs.setDouble(PlayerSettingsStore._keyPipWindowWidth, bounds.width);
    await _prefs.setDouble(
      PlayerSettingsStore._keyPipWindowHeight,
      bounds.height,
    );
  }
}
