
/// Authentication repository interface
abstract class IAuthRepository {
  /// Check if user is authenticated
  bool get isAuthenticated;

  /// Get current auth token
  String? get token;

  /// Get current cookie
  String? get cookie;

  /// Get base URL
  String? get baseUrl;

  /// Get auth code
  String? get authCode;

  /// Save token
  Future<void> saveToken(String token);

  /// Save cookie
  Future<void> saveCookie(String cookie);

  /// Save base URL
  Future<void> saveBaseUrl(String url);

  /// Save auth code
  Future<void> saveAuthCode(String code);

  /// Clear all auth data
  Future<void> clearAuth();

  /// Save login history
  Future<void> saveLoginHistory(String baseUrl, String? username);

  /// Get login history
  List<LoginHistoryEntry> getLoginHistory();

  /// Clear login history
  Future<void> clearLoginHistory();
}

/// Login history entry
class LoginHistoryEntry {
  final String baseUrl;
  final String? username;
  final DateTime lastUsed;

  const LoginHistoryEntry({
    required this.baseUrl,
    this.username,
    required this.lastUsed,
  });
}