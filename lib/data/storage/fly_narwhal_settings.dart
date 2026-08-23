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

  // 作用域读取：未登录读全局键；登录态只读 <guid>::<key>，无命中返回 null/默认值。
  // 不再做"懒迁移"复制：迁移由 UserSettingsMigrator 统一处理并删除全局值。
  bool _readBoolScoped(String rawKey, {required bool defaultValue}) {
    final guid = _userGuid;
    if (guid == null) {
      return _prefs.getBool(rawKey) ?? defaultValue;
    }
    return _prefs.getBool('$guid::$rawKey') ?? defaultValue;
  }

  String? _readStringScoped(String rawKey) {
    final guid = _userGuid;
    if (guid == null) {
      return _prefs.getString(rawKey);
    }
    return _prefs.getString('$guid::$rawKey');
  }

  Future<void> _writeBoolScoped(String rawKey, bool value) {
    return _prefs.setBool(_scopedKey(rawKey), value);
  }

  Future<void> _writeStringScoped(String rawKey, String value) {
    return _prefs.setString(_scopedKey(rawKey), value);
  }
}
