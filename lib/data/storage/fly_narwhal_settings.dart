import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_manager.dart';

class FlyNarwhalSettings {
  static const String _enabledKey = 'fly_narwhal_server_enabled';
  static const String _baseUrlKey = 'fly_narwhal_server_base_url';
  static const String _authCodeKey = 'fly_narwhal_server_auth_code';

  final SharedPreferences _prefs;
  final String? _userGuid;

  FlyNarwhalSettings(this._prefs, {String? userGuid})
      : _userGuid = PreferencesManager.normalizeGuid(userGuid);

  bool get enabled {
    return _readBoolScoped(_enabledKey, defaultValue: false);
  }

  Future<void> setEnabled(bool value) {
    return _writeBoolScoped(_enabledKey, value);
  }

  String? get baseUrl => _readStringScoped(_baseUrlKey);

  Future<void> setBaseUrl(String value) {
    return _writeStringScoped(_baseUrlKey, value);
  }

  String? get authCode => _readStringScoped(_authCodeKey);

  Future<void> setAuthCode(String value) {
    return _writeStringScoped(_authCodeKey, value);
  }

  String _scopedKey(String rawKey) {
    final guid = _userGuid;
    if (guid == null) return rawKey;
    return '$guid::$rawKey';
  }

  bool _readBoolScoped(String rawKey, {required bool defaultValue}) {
    final guid = _userGuid;
    if (guid == null) {
      return _prefs.getBool(rawKey) ?? defaultValue;
    }
    final scopedKey = _scopedKey(rawKey);
    final userValue = _prefs.getBool(scopedKey);
    if (userValue != null) return userValue;
    final legacy = _prefs.getBool(rawKey);
    if (legacy != null) {
      unawaited(_prefs.setBool(scopedKey, legacy));
      return legacy;
    }
    return defaultValue;
  }

  String? _readStringScoped(String rawKey) {
    final guid = _userGuid;
    if (guid == null) {
      return _prefs.getString(rawKey);
    }
    final scopedKey = _scopedKey(rawKey);
    final userValue = _prefs.getString(scopedKey);
    if (userValue != null) return userValue;
    final legacy = _prefs.getString(rawKey);
    if (legacy != null) {
      unawaited(_prefs.setString(scopedKey, legacy));
    }
    return legacy;
  }

  Future<void> _writeBoolScoped(String rawKey, bool value) {
    return _prefs.setBool(_scopedKey(rawKey), value);
  }

  Future<void> _writeStringScoped(String rawKey, String value) {
    return _prefs.setString(_scopedKey(rawKey), value);
  }
}
