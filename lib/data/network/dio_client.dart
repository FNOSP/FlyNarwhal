import 'package:dio/dio.dart';
import '../storage/preferences_manager.dart';
import '../../core/network/auth_signer.dart';
import '../../core/utils/log/app_talker.dart';

/// Legacy DioClient for backward compatibility
/// Consider migrating to core/network/dio_client.dart
class DioClient {
  final Dio _dio;
  final PreferencesManager _preferencesManager;
  static const String _userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36";

  DioClient(this._preferencesManager)
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          responseType: ResponseType.json,
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = _preferencesManager.getToken();
        if (token != null) {
          options.headers.putIfAbsent('Authorization', () => token);
        }
        final cookie = _preferencesManager.getCookie();
        if (cookie != null && cookie.isNotEmpty) {
          options.headers.putIfAbsent('Cookie', () => cookie);
        }
        options.headers.putIfAbsent('Accept', () => 'application/json');
        options.headers.putIfAbsent('User-Agent', () => _userAgent);
        final baseUrl = _preferencesManager.getBaseUrl();
        if (baseUrl != null && options.baseUrl.isEmpty) {
          options.baseUrl = baseUrl;
        }
        
        final authCode = _preferencesManager.getAuthCode();
        final hasAuthx = options.headers.containsKey('Authx');
        final hasSignx = options.headers.containsKey('Signx');
        if (authCode != null && authCode.isNotEmpty && !hasAuthx && !hasSignx) {
          final path = _resolvePath(options.path);
          final authx = AuthSigner.genAuthx(
            path,
            parameters: options.queryParameters,
            data: options.data is Map<String, dynamic> ? options.data : null,
          );
          options.headers['Authx'] = authx;
          final signx = AuthSigner.genSignx(
            url: path,
            authx: authx,
            parameters: options.queryParameters,
            data: options.data is Map<String, dynamic> ? options.data : null,
            publicKeyBase64: authCode,
          );
          options.headers['Signx'] = signx;
          if (authCode.startsWith('FN1_')) {
            final keyx = await AuthSigner.clientKeyxBase64Url();
            options.headers['Keyx'] = keyx;
          }
        }
        if (authCode != null && authCode.isNotEmpty && (hasAuthx || hasSignx)) {
          AppTalker.info(
            'Dio',
            'skip fly-narwhal auth headers: custom headers provided',
          );
        }

        final resolvedBaseUrl = options.baseUrl.isEmpty ? (baseUrl ?? '') : options.baseUrl;
        AppTalker.info(
          'Dio',
          'request: method=${options.method} path=${options.path} baseUrl="$resolvedBaseUrl" token=${token != null && token.isNotEmpty} tokenLength=${token?.length ?? 0} cookie=${cookie != null && cookie.isNotEmpty} authCode=${authCode != null && authCode.isNotEmpty}',
        );

        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Handle errors globally if needed
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
  
  void updateBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  String _resolvePath(String rawPath) {
    if (rawPath.startsWith('http')) {
      final uri = Uri.parse(rawPath);
      return uri.path;
    }
    return rawPath;
  }
}

