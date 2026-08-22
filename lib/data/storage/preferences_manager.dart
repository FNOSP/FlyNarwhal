import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/login_history.dart';

class PreferencesManager {
  static const String _keyLoginHistory = 'login_history';
  static const String _keyToken = 'auth_token';
  static const String _keyBaseUrl = 'base_url';
  static const String _keyCookie = 'cookie_state';
  static const String _keyFollowSystemTheme = 'follow_system_theme';
  static const String _keyDarkMode = 'dark_mode';
  static const String _keyNavigationDisplayMode = 'navigation_display_mode';
  // 选集/剧集列表视图：'card' (卡片/海报) | 'button' (序号按钮网格)。
  // 镜像 Web 端 playlist setting 的 view_type，全局记忆。
  static const String _keyEpisodeListViewType = 'episode_list_view_type';
  static const String _keyFallbackDeviceId = 'fallback_device_id';
  static const String _keySmartSkipEnabled = 'smart_skip_enabled';

  final SharedPreferences _prefs;

  PreferencesManager(this._prefs);

  /// 规范化用户 guid：未登录（空/仅空白）返回 null，表示使用全局/legacy 键。
  static String? normalizeGuid(String? userGuid) {
    final normalized = userGuid?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

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

  String? getBaseUrl() {
    return _prefs.getString(_keyBaseUrl);
  }

  Future<void> saveBaseUrl(String url) async {
    await _prefs.setString(_keyBaseUrl, url);
  }

  bool getFollowSystemTheme({String? userGuid}) {
    return _readBoolScoped(
      _keyFollowSystemTheme,
      userGuid,
      defaultValue: false,
    );
  }

  Future<void> saveFollowSystemTheme(bool value, {String? userGuid}) {
    return _writeBoolScoped(_keyFollowSystemTheme, userGuid, value);
  }

  bool getDarkMode({String? userGuid}) {
    return _readBoolScoped(_keyDarkMode, userGuid, defaultValue: true);
  }

  Future<void> saveDarkMode(bool value, {String? userGuid}) {
    return _writeBoolScoped(_keyDarkMode, userGuid, value);
  }

  String getNavigationDisplayMode({String? userGuid}) {
    return _readStringScoped(
      _keyNavigationDisplayMode,
      userGuid,
      defaultValue: 'LeftCompact',
    );
  }

  Future<void> saveNavigationDisplayMode(String value, {String? userGuid}) {
    return _writeStringScoped(_keyNavigationDisplayMode, userGuid, value);
  }

  // 选集/剧集列表视图：'card' | 'button'，默认卡片视图。
  String getEpisodeListViewType({String? userGuid}) {
    return _readStringScoped(
      _keyEpisodeListViewType,
      userGuid,
      defaultValue: 'card',
    );
  }

  Future<void> saveEpisodeListViewType(String value, {String? userGuid}) {
    return _writeStringScoped(_keyEpisodeListViewType, userGuid, value);
  }

  String? getFallbackDeviceId() {
    return _prefs.getString(_keyFallbackDeviceId);
  }

  Future<void> saveFallbackDeviceId(String value) async {
    await _prefs.setString(_keyFallbackDeviceId, value);
  }

  bool? getSmartSkipEnabledForUser(String userGuid) {
    final normalizedUserGuid = userGuid.trim();
    if (normalizedUserGuid.isEmpty) return null;
    return _prefs.getBool('$normalizedUserGuid::$_keySmartSkipEnabled');
  }

  Future<void> saveSmartSkipEnabledForUser(
    String userGuid,
    bool enabled,
  ) async {
    final normalizedUserGuid = userGuid.trim();
    if (normalizedUserGuid.isEmpty) return;
    await _prefs.setBool(
      '$normalizedUserGuid::$_keySmartSkipEnabled',
      enabled,
    );
  }

  bool? getLegacySmartSkipEnabled() {
    return _prefs.getBool(_keySmartSkipEnabled);
  }

  Future<void> saveLegacySmartSkipEnabled(bool enabled) async {
    await _prefs.setBool(_keySmartSkipEnabled, enabled);
  }

  Future<bool> loadSmartSkipEnabled(String? userGuid) async {
    final normalizedUserGuid = userGuid?.trim() ?? '';
    if (normalizedUserGuid.isEmpty) {
      return getLegacySmartSkipEnabled() ?? true;
    }

    final userValue = getSmartSkipEnabledForUser(normalizedUserGuid);
    if (userValue != null) return userValue;

    final initialValue = getLegacySmartSkipEnabled() ?? true;
    await saveSmartSkipEnabledForUser(normalizedUserGuid, initialValue);
    return initialValue;
  }

  // 作用域读取：优先用户键，未命中则回退全局/legacy 键并异步写入用户键。
  bool _readBoolScoped(
    String rawKey,
    String? userGuid, {
    required bool defaultValue,
  }) {
    final normalized = normalizeGuid(userGuid);
    if (normalized == null) {
      return _prefs.getBool(rawKey) ?? defaultValue;
    }
    final scopedKey = '$normalized::$rawKey';
    final userValue = _prefs.getBool(scopedKey);
    if (userValue != null) return userValue;
    final legacy = _prefs.getBool(rawKey);
    if (legacy != null) {
      unawaited(_prefs.setBool(scopedKey, legacy));
      return legacy;
    }
    return defaultValue;
  }

  String _readStringScoped(
    String rawKey,
    String? userGuid, {
    required String defaultValue,
  }) {
    final normalized = normalizeGuid(userGuid);
    if (normalized == null) {
      return _prefs.getString(rawKey) ?? defaultValue;
    }
    final scopedKey = '$normalized::$rawKey';
    final userValue = _prefs.getString(scopedKey);
    if (userValue != null) return userValue;
    final legacy = _prefs.getString(rawKey);
    if (legacy != null) {
      unawaited(_prefs.setString(scopedKey, legacy));
      return legacy;
    }
    return defaultValue;
  }

  Future<void> _writeBoolScoped(String rawKey, String? userGuid, bool value) {
    final normalized = normalizeGuid(userGuid);
    final key = normalized == null ? rawKey : '$normalized::$rawKey';
    return _prefs.setBool(key, value);
  }

  Future<void> _writeStringScoped(
    String rawKey,
    String? userGuid,
    String value,
  ) {
    final normalized = normalizeGuid(userGuid);
    final key = normalized == null ? rawKey : '$normalized::$rawKey';
    return _prefs.setString(key, value);
  }

  Future<void> clear() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyBaseUrl);
    await _prefs.remove(_keyCookie);
  }
}
