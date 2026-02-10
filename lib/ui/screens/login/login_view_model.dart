import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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
      final isRelay = (parsed?.host.contains('5ddd.com') ?? false) || (parsed?.host.contains('fnos.net') ?? false) || isNasLogin;
      if (isRelay) {
        await prefs.saveCookie('mode=relay');
        debugPrint('[Login] relay mode enabled: cookie="mode=relay" baseUrl="$baseUrl"');
      }

      debugPrint(
        '[Login] login request: baseUrl="$baseUrl" path="/v/api/v1/login" username="$username" passwordLength=${password.length} isNasLogin=$isNasLogin',
      );
      final requestData = LoginRequest(username: username, password: password).toJson();
      final maskedRequestData = Map<String, dynamic>.from(requestData);
      if (maskedRequestData.containsKey('password')) {
        maskedRequestData['password'] = password.isEmpty ? '' : '***';
      }
      debugPrint('[Login] login request body: $maskedRequestData');

      Response response;
      try {
        response = await dioClient.dio.post(
          '/v/api/v1/login',
          data: requestData,
        );
        debugPrint(
          '[Login] login response: status=${response.statusCode} dataType=${response.data.runtimeType}',
        );
        if (response.data is Map) {
          final keys = (response.data as Map).keys.toList();
          debugPrint('[Login] login response keys: $keys');
        }
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        final data = e.response?.data;
        debugPrint(
          '[Login] login error response: status=$status dataType=${data?.runtimeType}',
        );
        if (data is Map) {
          debugPrint('[Login] login error response keys: ${data.keys.toList()}');
        }
        rethrow;
      }
      
      final baseResponse = FnBaseResponse<LoginResponse>.fromJson(
        response.data, 
        (json) => LoginResponse.fromJson(json as Map<String, dynamic>)
      );
      debugPrint(
        '[Login] login parsed: code=${baseResponse.code} msg="${baseResponse.msg}" hasData=${baseResponse.data != null}',
      );

      if (baseResponse.code != 0) {
        throw Exception(baseResponse.msg);
      }
      
      if (baseResponse.data == null) {
        throw Exception("Login failed: No data returned");
      }
      
      final token = baseResponse.data!.token;
      debugPrint(
        '[Login] login token: empty=${token.isEmpty} length=${token.length}',
      );
      await prefs.saveToken(token);
      if (isRelay) {
        await prefs.saveCookie("Trim-MC-token=$token; mode=relay");
        debugPrint('[Login] cookie saved for relay: hasToken=${token.isNotEmpty} cookie="Trim-MC-token=***; mode=relay"');
      } else {
        await prefs.saveCookie("Trim-MC-token=$token");
        debugPrint('[Login] cookie saved: hasToken=${token.isNotEmpty} cookie="Trim-MC-token=***"');
      }
      final storedToken = prefs.getToken();
      debugPrint(
        '[Login] token saved: ${token.isNotEmpty} stored=${storedToken != null} storedLength=${storedToken?.length ?? 0}',
      );
      
      // Save History
      final history = LoginHistory(
        host: host,
        port: port,
        username: username,
        password: rememberPassword ? password : null,
        isHttps: isHttps,
        rememberPassword: rememberPassword,
        isNasLogin: isNasLogin,
        fnId: fnId ?? "",
        displayHost: displayHost ?? host, 
        displayPort: displayPort ?? port,
      );
      
      final currentHistory = prefs.getLoginHistory();
      // Remove existing with same identity
      final updatedHistory = currentHistory.where((element) => element != history).toList();
      updatedHistory.insert(0, history);
      
      await prefs.saveLoginHistory(updatedHistory);
      ref.invalidate(loginHistoryNotifierProvider);
      final refreshNotifier = ref.read(authRefreshProvider.notifier);
      refreshNotifier.state = refreshNotifier.state + 1;
      debugPrint('[Login] auth refresh state=${refreshNotifier.state}');
    });
  }
  
  Future<String> _resolveNasUrl(String fnId) async {
    // TODO: Implement FN Connect resolution
    throw UnimplementedError("FN Connect not implemented yet");
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
    final current = state.where((e) => e != item).toList();
    await prefs.saveLoginHistory(current);
    state = current;
  }
}
