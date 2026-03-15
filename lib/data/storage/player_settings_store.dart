import 'package:shared_preferences/shared_preferences.dart';

class PlayerSettingsStore {
  static const String _keyVolume = 'player_volume';
  static const String _keySpeed = 'player_speed';
  static const String _keyAutoPlay = 'player_auto_play';
  static const String _keyWindowAspectRatio = 'player_window_aspect_ratio';

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

  bool getAutoPlay() =>
      _prefs.getBool(PlayerSettingsStore._keyAutoPlay) ?? true;
  Future<void> setAutoPlay(bool autoPlay) =>
      _prefs.setBool(PlayerSettingsStore._keyAutoPlay, autoPlay);

  String getWindowAspectRatio() =>
      _prefs.getString(PlayerSettingsStore._keyWindowAspectRatio) ?? 'AUTO';
  Future<void> setWindowAspectRatio(String ratio) =>
      _prefs.setString(PlayerSettingsStore._keyWindowAspectRatio, ratio);
}