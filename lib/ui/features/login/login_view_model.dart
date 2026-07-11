import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/utils/log/app_talker.dart';
import '../../../data/models/base_response.dart';
import '../../../data/models/login_history.dart';
import '../../../data/models/login_request.dart';
import '../../../data/models/login_response.dart';
import '../../../providers/providers.dart';

part 'login_view_model.g.dart';

@riverpod
class LoginViewModel extends _$LoginViewModel {
  @override
  FutureOr<void> build() {}

  Future<void> login({
    required String host,
    required int port,
    required String username,
    required String password,
    required bool isHttps,
    required bool rememberPassword,
    required bool isNasLogin,
    String? fnId,
    String? displayHost,
    int? displayPort,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final dioClient = ref.read(dioClientProvider);
      final prefs = ref.read(preferencesManagerProvider);

      final protocol = isHttps ? 'https' : 'http';
      final baseUrl = isNasLogin
          ? (await _resolveNasUrl(fnId!))
          : (port == 0 ? '$protocol://$host' : '$protocol://$host:$port');

      dioClient.updateBaseUrl(baseUrl);
      await prefs.saveBaseUrl(baseUrl);

      final parsed = Uri.tryParse(baseUrl);
      final isRelay = (parsed?.host.contains('5ddd.com') ?? false) ||
          (parsed?.host.contains('fnos.net') ?? false) ||
          isNasLogin;
      if (isRelay) {
        await prefs.saveCookie('mode=relay');
        AppTalker.info(
          'Login',
          'relay mode enabled: cookie="mode=relay" baseUrl="$baseUrl"',
        );
      }

      AppTalker.info(
        'Login',
        'login request: baseUrl="$baseUrl" path="/v/api/v1/login" username="$username" passwordLength=${password.length} isNasLogin=$isNasLogin',
      );
      final requestData =
          LoginRequest(username: username, password: password).toJson();
      final maskedRequestData = Map<String, dynamic>.from(requestData);
      if (maskedRequestData.containsKey('password')) {
        maskedRequestData['password'] = password.isEmpty ? '' : '***';
      }
      AppTalker.info('Login', 'login request body: $maskedRequestData');

      Response response;
      try {
        response = await dioClient.dio.post(
          '/v/api/v1/login',
          data: requestData,
        );
        AppTalker.info(
          'Login',
          'login response: status=${response.statusCode} dataType=${response.data.runtimeType}',
        );
        if (response.data is Map) {
          final keys = (response.data as Map).keys.toList();
          AppTalker.info('Login', 'login response keys: $keys');
        }
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        final data = e.response?.data;
        AppTalker.warning(
          'Login',
          'login error response: status=$status dataType=${data?.runtimeType}',
        );
        if (data is Map) {
          AppTalker.warning(
            'Login',
            'login error response keys: ${data.keys.toList()}',
          );
        }
        rethrow;
      }

      final baseResponse = FnBaseResponse<LoginResponse>.fromJson(response.data,
          (json) => LoginResponse.fromJson(json as Map<String, dynamic>));
      AppTalker.info(
        'Login',
        'login parsed: code=${baseResponse.code} msg="${baseResponse.msg}" hasData=${baseResponse.data != null}',
      );

      if (baseResponse.code != 0) {
        throw Exception(baseResponse.msg);
      }

      if (baseResponse.data == null) {
        throw Exception("Login failed: No data returned");
      }

      final token = baseResponse.data!.token;
      AppTalker.info(
        'Login',
        'login token: empty=${token.isEmpty} length=${token.length}',
      );
      await prefs.saveToken(token);
      if (isRelay) {
        await prefs.saveCookie("Trim-MC-token=$token; mode=relay");
        AppTalker.info(
          'Login',
          'cookie saved for relay: hasToken=${token.isNotEmpty} cookie="Trim-MC-token=***; mode=relay"',
        );
      } else {
        await prefs.saveCookie("Trim-MC-token=$token");
        AppTalker.info(
          'Login',
          'cookie saved: hasToken=${token.isNotEmpty} cookie="Trim-MC-token=***"',
        );
      }
      final storedToken = prefs.getToken();
      AppTalker.info(
        'Login',
        'token saved: ${token.isNotEmpty} stored=${storedToken != null} storedLength=${storedToken?.length ?? 0}',
      );

      // Encrypt remembered credentials before they reach persistent storage.
      final passwordService = ref.read(loginHistoryPasswordServiceProvider);
      final storedPassword = rememberPassword
          ? await passwordService.encryptForStorage(password)
          : null;
      final history = LoginHistory(
        host: host,
        port: port,
        username: username,
        password: storedPassword,
        passwordEncrypted: rememberPassword && storedPassword != null,
        isHttps: isHttps,
        rememberPassword: rememberPassword,
        isNasLogin: isNasLogin,
        fnId: fnId ?? "",
        displayHost: displayHost ?? host,
        displayPort: displayPort ?? port,
      );

      final currentHistory = prefs.getLoginHistory();
      // Remove existing with same identity
      final updatedHistory =
          currentHistory.where((element) => element != history).toList();
      updatedHistory.insert(0, history);

      await prefs.saveLoginHistory(updatedHistory);
      ref.invalidate(loginHistoryNotifierProvider);

      // Clear cached user info so the next home entry always performs
      // a fresh user info validation for the new session.
      ref.read(userInfoProvider.notifier).clear();

      final refreshNotifier = ref.read(authRefreshProvider.notifier);
      refreshNotifier.state = refreshNotifier.state + 1;
      AppTalker.info('Login', 'auth refresh state=${refreshNotifier.state}');
    });
  }

  Future<String> _resolveNasUrl(String fnId) async {
    final raw = fnId.trim();
    if (raw.isEmpty) {
      throw Exception('FN ID 不能为空');
    }
    final hasScheme = raw.startsWith('http://') || raw.startsWith('https://');
    if (hasScheme) {
      return raw;
    }
    if (raw.contains('.')) {
      return 'https://$raw';
    }
    return 'https://5ddd.com/$raw';
  }

  void clearError() {
    state = const AsyncValue.data(null);
  }
}

@riverpod
class LoginHistoryNotifier extends _$LoginHistoryNotifier {
  @override
  List<LoginHistory> build() {
    final prefs = ref.watch(preferencesManagerProvider);
    return prefs.getLoginHistory();
  }

  Future<void> delete(LoginHistory item) async {
    final prefs = ref.read(preferencesManagerProvider);
    final current = state.where((entry) => entry != item).toList();
    await prefs.saveLoginHistory(current);
    state = current;
  }

  /// Removes a stale encrypted password while preserving the history identity.
  Future<void> clearPassword(LoginHistory item) async {
    final prefs = ref.read(preferencesManagerProvider);
    final updatedHistory = state.map((entry) {
      if (entry != item) {
        return entry;
      }
      return LoginHistory(
        host: entry.host,
        port: entry.port,
        username: entry.username,
        isHttps: entry.isHttps,
        rememberPassword: false,
        isNasLogin: entry.isNasLogin,
        fnConnectUrl: entry.fnConnectUrl,
        fnId: entry.fnId,
        lastLoginTimestamp: entry.lastLoginTimestamp,
        displayHost: entry.displayHost,
        displayPort: entry.displayPort,
      );
    }).toList();
    await prefs.saveLoginHistory(updatedHistory);
    state = updatedHistory;
  }
}
