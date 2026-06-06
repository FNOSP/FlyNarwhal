import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/index.dart';

/// Abstract storage interface for dependency injection
abstract class PreferencesStorage {
  String? getString(String key);
  Future<void> setString(String key, String value);
  bool? getBool(String key);
  Future<void> setBool(String key, bool value);
  List<String>? getStringList(String key);
  Future<void> setStringList(String key, List<String> value);
  Future<void> remove(String key);
}

/// Local data source for preferences storage
class PreferencesLocalDataSource {
  final PreferencesStorage _storage;

  PreferencesLocalDataSource(this._storage);

  // Auth related methods
  String? getToken() => _storage.getString(StorageKeys.authToken);

  Future<void> saveToken(String token) =>
      _storage.setString(StorageKeys.authToken, token);

  String? getCookie() => _storage.getString(StorageKeys.cookieState);

  Future<void> saveCookie(String cookie) =>
      _storage.setString(StorageKeys.cookieState, cookie);

  String? getBaseUrl() => _storage.getString(StorageKeys.baseUrl);

  Future<void> saveBaseUrl(String url) =>
      _storage.setString(StorageKeys.baseUrl, url);

  String? getAuthCode() => _storage.getString(StorageKeys.authCode);

  Future<void> saveAuthCode(String code) =>
      _storage.setString(StorageKeys.authCode, code);

  Future<void> clearAuth() async {
    await Future.wait([
      _storage.remove(StorageKeys.authToken),
      _storage.remove(StorageKeys.cookieState),
      _storage.remove(StorageKeys.authCode),
    ]);
  }

  // Login history methods
  Future<void> saveLoginHistory(String baseUrl, String? username) async {
    final history = getLoginHistory();
    final existingIndex = history.indexWhere((e) => e.baseUrl == baseUrl);

    final newEntry = LoginHistoryEntry(
      baseUrl: baseUrl,
      username: username,
      lastUsed: DateTime.now(),
    );

    if (existingIndex >= 0) {
      history[existingIndex] = newEntry;
    } else {
      history.add(newEntry);
    }

    // Keep only last 10 entries
    if (history.length > 10) {
      history.removeRange(0, history.length - 10);
    }

    await _saveLoginHistoryList(history);
  }

  List<LoginHistoryEntry> getLoginHistory() {
    final jsonList = _storage.getStringList(StorageKeys.loginHistory);
    if (jsonList == null) return [];

    return jsonList.map((json) {
      final parts = json.split('|');
      return LoginHistoryEntry(
        baseUrl: parts.isNotEmpty ? parts[0] : '',
        username: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
        lastUsed: parts.length > 2
            ? DateTime.tryParse(parts[2]) ?? DateTime.now()
            : DateTime.now(),
      );
    }).toList();
  }

  Future<void> clearLoginHistory() =>
      _storage.remove(StorageKeys.loginHistory);

  Future<void> _saveLoginHistoryList(List<LoginHistoryEntry> history) async {
    final jsonList = history.map((e) {
      final username = e.username ?? '';
      return '${e.baseUrl}|$username|${e.lastUsed.toIso8601String()}';
    }).toList();
    await _storage.setStringList(StorageKeys.loginHistory, jsonList);
  }

  // Theme settings
  bool getFollowSystemTheme() =>
      _storage.getBool(StorageKeys.followSystemTheme) ?? true;

  Future<void> saveFollowSystemTheme(bool value) =>
      _storage.setBool(StorageKeys.followSystemTheme, value);

  bool getDarkMode() => _storage.getBool(StorageKeys.darkMode) ?? false;

  Future<void> saveDarkMode(bool value) =>
      _storage.setBool(StorageKeys.darkMode, value);

  String getNavigationDisplayMode() =>
      _storage.getString(StorageKeys.navigationDisplayMode) ?? 'LeftCompact';

  Future<void> saveNavigationDisplayMode(String value) =>
      _storage.setString(StorageKeys.navigationDisplayMode, value);

  // Auth check
  bool get isAuthenticated {
    final token = getToken();
    return token != null && token.isNotEmpty;
  }
}
