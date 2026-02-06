import 'package:dio/dio.dart';
import '../storage/preferences_manager.dart';
import '../../utils/fn_api_helper.dart';

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
        if (authCode != null && authCode.isNotEmpty) {
          final path = _resolvePath(options.path);
          final authx = FnApiHelper.genAuthxForFlyNarwhal(
            path,
            parameters: options.queryParameters,
            data: options.data is Map<String, dynamic> ? options.data : null,
          );
          options.headers['Authx'] = authx;
          final signx = FnApiHelper.genSignxForFlyNarwhal(
            url: path,
            authx: authx,
            parameters: options.queryParameters,
            data: options.data is Map<String, dynamic> ? options.data : null,
            publicKeyBase64: authCode,
          );
          options.headers['Signx'] = signx;
          if (authCode.startsWith('FN1_')) {
            final keyx = await FnApiHelper.clientKeyxBase64Url();
            options.headers['Keyx'] = keyx;
          }
        }

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
