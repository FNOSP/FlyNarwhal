import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/local/preferences_local_data_source.dart';

/// Implementation of IAuthRepository
class AuthRepositoryImpl implements IAuthRepository {
  final PreferencesLocalDataSource _localDataSource;

  AuthRepositoryImpl(this._localDataSource);

  @override
  bool get isAuthenticated => _localDataSource.isAuthenticated;

  @override
  String? get token => _localDataSource.getToken();

  @override
  String? get cookie => _localDataSource.getCookie();

  @override
  String? get baseUrl => _localDataSource.getBaseUrl();

  @override
  Future<void> saveToken(String token) => _localDataSource.saveToken(token);

  @override
  Future<void> saveCookie(String cookie) => _localDataSource.saveCookie(cookie);

  @override
  Future<void> saveBaseUrl(String url) => _localDataSource.saveBaseUrl(url);

  @override
  Future<void> clearAuth() => _localDataSource.clearAuth();

  @override
  Future<void> saveLoginHistory(String baseUrl, String? username) =>
      _localDataSource.saveLoginHistory(baseUrl, username);

  @override
  List<LoginHistoryEntry> getLoginHistory() =>
      _localDataSource.getLoginHistory();

  @override
  Future<void> clearLoginHistory() => _localDataSource.clearLoginHistory();
}