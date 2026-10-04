import 'dart:convert';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:shared_preferences/shared_preferences.dart';

import '../../ui/settings/app_language.dart';
import '../models/login_history.dart';

class PreferencesManager {
  static const String _keyLoginHistory = 'login_history';
  static const String _keyToken = 'auth_token';
  static const String _keyBaseUrl = 'base_url';
  static const String _keyCookie = 'cookie_state';
  static const String _keyFollowSystemTheme = 'follow_system_theme';
  static const String _keyDarkMode = 'dark_mode';
  static const String _keyNavigationDisplayMode = 'navigation_display_mode';
  // 界面整体文字大小：'small' | 'medium' | 'large'，默认 'medium'。
  static const String _keyUiFontScale = 'ui_font_scale';
  // 界面语言：'zh-Hans' | 'zh-Hant' | 'en'，默认 'zh-Hans'。
  static const String _keyLanguage = 'language';
  // 选集/剧集列表视图：'card' (卡片/海报) | 'button' (序号按钮网格)。
  // 镜像 Web 端 playlist setting 的 view_type，全局记忆。
  static const String _keyEpisodeListViewType = 'episode_list_view_type';
  static const String _keyFallbackDeviceId = 'fallback_device_id';
  static const String _keySmartSkipEnabled = 'smart_skip_enabled';
  static const String _keySkipIntro = 'skip_intro';
  static const String _keySkipCredits = 'skip_credits';
  static const String _keySkipRecap = 'skip_recap';
  static const String _keySkipPreview = 'skip_preview';
  static const String _keySkipCommercial = 'skip_commercial';
  // 播放详细信息面板样式：true = 带动画的液态玻璃面板，false = 静态毛玻璃面板。
  static const String _keyPlayerDetailsLiquidGlass = 'player_details_liquid_glass';

  final SharedPreferences _prefs;

  PreferencesManager(this._prefs, {String Function()? languageFallback})
      : _languageFallback = languageFallback ?? detectSystemLanguage;

  /// 首次运行（该作用域下从未存过语言）时用于推断界面语言。
  /// 测试可注入返回值，生产环境默认读系统语言。
  final String Function() _languageFallback;

  /// 规范化用户 guid：未登录（空/仅空白）返回 null，表示使用全局/legacy 键。
  static String? normalizeGuid(String? userGuid) {
    final normalized = userGuid?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  /// 读系统语言并映射到界面语言三档之一。
  static String detectSystemLanguage() =>
      systemLanguageFromLocale(PlatformDispatcher.instance.locale);

  /// 系统 [Locale] 到界面语言的映射：
  /// 非 zh 一律英文；zh 带 Hant 或台港澳地区为繁体；其余 zh 为简体。
  static String systemLanguageFromLocale(Locale locale) {
    if (locale.languageCode != 'zh') return AppLanguage.en;
    final isTraditional = locale.scriptCode == 'Hant' ||
        const {'TW', 'HK', 'MO'}.contains(locale.countryCode);
    return isTraditional ? AppLanguage.zhHant : AppLanguage.zhHans;
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

  // 播放详细信息面板是否使用带动画的液态玻璃样式，默认开启（保持现状）。
  bool getPlayerDetailsLiquidGlass({String? userGuid}) {
    return _readBoolScoped(
      _keyPlayerDetailsLiquidGlass,
      userGuid,
      defaultValue: true,
    );
  }

  Future<void> savePlayerDetailsLiquidGlass(bool value, {String? userGuid}) {
    return _writeBoolScoped(_keyPlayerDetailsLiquidGlass, userGuid, value);
  }

  String getUiFontScale({String? userGuid}) {
    return _readStringScoped(
      _keyUiFontScale,
      userGuid,
      defaultValue: 'medium',
    );
  }

  Future<void> saveUiFontScale(String value, {String? userGuid}) {
    return _writeStringScoped(_keyUiFontScale, userGuid, value);
  }

  // 界面语言：'zh-Hans' | 'zh-Hant' | 'en'。
  // 该作用域下未存过时按系统语言推断（仅首次运行）。
  String getLanguage({String? userGuid}) {
    final stored = _readStringScopedNullable(_keyLanguage, userGuid);
    return stored ?? _languageFallback();
  }

  /// 该作用域下是否已存过界面语言（用于区分首次运行与用户显式选择）。
  bool hasStoredLanguage({String? userGuid}) =>
      _readStringScopedNullable(_keyLanguage, userGuid) != null;

  Future<void> saveLanguage(String value, {String? userGuid}) {
    return _writeStringScoped(_keyLanguage, userGuid, value);
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
    return getSmartSkipEnabledForUser(normalizedUserGuid) ?? true;
  }

  bool getSkipIntro({String? userGuid}) =>
      _readBoolScoped(_keySkipIntro, userGuid, defaultValue: true);

  Future<void> saveSkipIntro(bool value, {String? userGuid}) =>
      _writeBoolScoped(_keySkipIntro, userGuid, value);

  bool getSkipCredits({String? userGuid}) =>
      _readBoolScoped(_keySkipCredits, userGuid, defaultValue: true);

  Future<void> saveSkipCredits(bool value, {String? userGuid}) =>
      _writeBoolScoped(_keySkipCredits, userGuid, value);

  bool getSkipRecap({String? userGuid}) =>
      _readBoolScoped(_keySkipRecap, userGuid, defaultValue: true);

  Future<void> saveSkipRecap(bool value, {String? userGuid}) =>
      _writeBoolScoped(_keySkipRecap, userGuid, value);

  bool getSkipPreview({String? userGuid}) =>
      _readBoolScoped(_keySkipPreview, userGuid, defaultValue: true);

  Future<void> saveSkipPreview(bool value, {String? userGuid}) =>
      _writeBoolScoped(_keySkipPreview, userGuid, value);

  // 广告跳过是选择性功能，未设置过即为关闭。
  bool getSkipCommercial({String? userGuid}) =>
      _readBoolScoped(_keySkipCommercial, userGuid, defaultValue: false);

  Future<void> saveSkipCommercial(bool value, {String? userGuid}) =>
      _writeBoolScoped(_keySkipCommercial, userGuid, value);

  // 作用域读取：未登录读全局键；登录态只读 <guid>::<key>，无命中返回默认值。
  // 不再做"懒迁移"复制：迁移由 UserSettingsMigrator 统一处理并删除全局值。
  bool _readBoolScoped(
    String rawKey,
    String? userGuid, {
    required bool defaultValue,
  }) {
    final normalized = normalizeGuid(userGuid);
    if (normalized == null) {
      return _prefs.getBool(rawKey) ?? defaultValue;
    }
    return _prefs.getBool('$normalized::$rawKey') ?? defaultValue;
  }

  String _readStringScoped(
    String rawKey,
    String? userGuid, {
    required String defaultValue,
  }) {
    return _readStringScopedNullable(rawKey, userGuid) ?? defaultValue;
  }

  /// 读作用域键，键不存在返回 null（用于区分「未设置」与「显式空值」）。
  String? _readStringScopedNullable(String rawKey, String? userGuid) {
    final normalized = normalizeGuid(userGuid);
    if (normalized == null) {
      return _prefs.getString(rawKey);
    }
    return _prefs.getString('$normalized::$rawKey');
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
