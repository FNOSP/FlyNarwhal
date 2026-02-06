import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/login_history.dart';

class PreferencesManager {
  static const String _keyLoginHistory = 'login_history';
  static const String _keyToken = 'auth_token';
  static const String _keyBaseUrl = 'base_url';
  static const String _keyCookie = 'cookie_state';
  static const String _keyAuthCode = 'auth_code';

  final SharedPreferences _prefs;

  PreferencesManager(this._prefs);

  List<LoginHistory> getLoginHistory() {
    final jsonString = _prefs.getString(_keyLoginHistory);
    if (jsonString == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((e) => LoginHistory.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveLoginHistory(List<LoginHistory> history) async {
    final jsonString = jsonEncode(history.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyLoginHistory, jsonString);
  }

  String? getToken() {
    return _prefs.getString(_keyToken);
  }

  Future<void> saveToken(String token) async {
    await _prefs.setString(_keyToken, token);
  }

  String? getCookie() {
    return _prefs.getString(_keyCookie);
  }

  Future<void> saveCookie(String cookie) async {
    await _prefs.setString(_keyCookie, cookie);
  }

  String? getAuthCode() {
    return _prefs.getString(_keyAuthCode);
  }

  Future<void> saveAuthCode(String authCode) async {
    await _prefs.setString(_keyAuthCode, authCode);
  }
  
  String? getBaseUrl() {
    return _prefs.getString(_keyBaseUrl);
  }

  Future<void> saveBaseUrl(String url) async {
    await _prefs.setString(_keyBaseUrl, url);
  }

  Future<void> clear() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyBaseUrl);
    await _prefs.remove(_keyCookie);
    await _prefs.remove(_keyAuthCode);
  }
}
