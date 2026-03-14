import 'package:dio/dio.dart';
import '../auth_signer.dart';

/// Authentication interceptor for adding Authx/Signx/Keyx headers
class AuthInterceptor extends Interceptor {
  final String Function()? getToken;
  final String Function()? getCookie;
  final String Function()? getAuthCode;
  final String Function()? getBaseUrl;

  AuthInterceptor({
    this.getToken,
    this.getCookie,
    this.getAuthCode,
    this.getBaseUrl,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Add Authorization header
    final token = getToken?.call();
    if (token != null && token.isNotEmpty) {
      options.headers.putIfAbsent('Authorization', () => token);
    }

    // Add Cookie header
    final cookie = getCookie?.call();
    if (cookie != null && cookie.isNotEmpty) {
      options.headers.putIfAbsent('Cookie', () => cookie);
    }

    // Add Accept header
    options.headers.putIfAbsent('Accept', () => 'application/json');

    // Add User-Agent
    options.headers.putIfAbsent(
      'User-Agent',
      () => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36',
    );

    // Set base URL if not already set
    final baseUrl = getBaseUrl?.call();
    if (baseUrl != null && baseUrl.isNotEmpty && options.baseUrl.isEmpty) {
      options.baseUrl = baseUrl;
    }

    // Add Authx/Signx/Keyx headers if authCode is available
    final authCode = getAuthCode?.call();
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

      // Add Keyx for FN1_ prefix auth codes
      if (authCode.startsWith('FN1_')) {
        final keyx = await AuthSigner.clientKeyxBase64Url();
        options.headers['Keyx'] = keyx;
      }
    }

    super.onRequest(options, handler);
  }

  String _resolvePath(String rawPath) {
    if (rawPath.startsWith('http')) {
      final uri = Uri.parse(rawPath);
      return uri.path;
    }
    return rawPath;
  }
}