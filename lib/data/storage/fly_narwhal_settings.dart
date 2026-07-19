import 'package:shared_preferences/shared_preferences.dart';

class FlyNarwhalSettings {
  static const String _enabledKey = 'fly_narwhal_server_enabled';
  static const String _baseUrlKey = 'fly_narwhal_server_base_url';
  static const String _authCodeKey = 'fly_narwhal_server_auth_code';

  final SharedPreferences _prefs;

  FlyNarwhalSettings(this._prefs);

  bool get enabled => _prefs.getBool(_enabledKey) ?? false;

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(_enabledKey, value);
  }

  String? get baseUrl => _prefs.getString(_baseUrlKey);

  Future<void> setBaseUrl(String value) async {
    await _prefs.setString(_baseUrlKey, value);
  }

  String? get authCode => _prefs.getString(_authCodeKey);

  Future<void> setAuthCode(String value) async {
    await _prefs.setString(_authCodeKey, value);
  }
}
