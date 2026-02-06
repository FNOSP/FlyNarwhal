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
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final dioClient = ref.read(dioClientProvider);
      final prefs = ref.read(preferencesManagerProvider);
      
      final protocol = isHttps ? 'https' : 'http';
      final baseUrl = isNasLogin 
          ? (await _resolveNasUrl(fnId!)) 
          : '$protocol://$host:$port';
      
      dioClient.updateBaseUrl(baseUrl);
      prefs.saveBaseUrl(baseUrl);

      final response = await dioClient.dio.post(
        '/v/api/v1/login',
        data: LoginRequest(username: username, password: password).toJson(),
      );
      
      final baseResponse = FnBaseResponse<LoginResponse>.fromJson(
        response.data, 
        (json) => LoginResponse.fromJson(json as Map<String, dynamic>)
      );

      if (baseResponse.code != 0) {
        throw Exception(baseResponse.msg);
      }
      
      if (baseResponse.data == null) {
        throw Exception("Login failed: No data returned");
      }
      
      final token = baseResponse.data!.token;
      await prefs.saveToken(token);
      await prefs.saveCookie("Trim-MC-token=$token");
      
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
        displayHost: host, 
        displayPort: port,
      );
      
      final currentHistory = prefs.getLoginHistory();
      // Remove existing with same identity
      final updatedHistory = currentHistory.where((element) => element != history).toList();
      updatedHistory.insert(0, history);
      
      await prefs.saveLoginHistory(updatedHistory);
      ref.invalidate(loginHistoryNotifierProvider);
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
