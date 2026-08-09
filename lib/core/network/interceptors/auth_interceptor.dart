import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';


/// Authentication interceptor for FnOfficial API requests.
/// Injects Authorization, Cookie, User-Agent and Authx (single layer sign).
class AuthInterceptor extends Interceptor {
  // Shared secret used to compute Authx. Mirrors KMP FnOfficialApiImpl.
  static const String _apiKey = "NDzZTVxnRKP8Z0jXg1VAMonaG8akvh";
  static const String _apiSecret = "16CCEB3D-AB42-077D-36A1-F355324E4237";
  static const String _userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36";
  // Trim media client identifiers. These mirror the FnOfficial web client.
  // The server gates library types (e.g. the IPTV/live-TV media library) on
  // the presence of x-trim-client-version, so omitting it hides live channels
  // from the media library list.
  static const String _trimClient = "web";
  static const String _trimClientVersion = "616";

  final String Function()? getToken;
  final String Function()? getCookie;
  final String Function()? getBaseUrl;

  AuthInterceptor({
    this.getToken,
    this.getCookie,
    this.getBaseUrl,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
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
    options.headers.putIfAbsent('User-Agent', () => _userAgent);

    // Add Trim media client identifiers so the server returns all library
    // types (e.g. the IPTV/live-TV media library), matching the web client.
    options.headers.putIfAbsent('x-trim-client', () => _trimClient);
    options.headers.putIfAbsent(
        'x-trim-client-version', () => _trimClientVersion);

    // Set base URL if not already set
    final baseUrl = getBaseUrl?.call();
    if (baseUrl != null && baseUrl.isNotEmpty && options.baseUrl.isEmpty) {
      options.baseUrl = baseUrl;
    }

    // Add Authx header for FnOfficial (single-layer sign, matches KMP).
    if (!options.headers.containsKey('Authx')) {
      final path = _resolvePath(options.path);
      final authx = _genAuthx(
        path,
        parameters:
            options.queryParameters.isEmpty ? null : options.queryParameters,
        data: options.data is Map<String, dynamic> ? options.data : null,
      );
      options.headers['Authx'] = authx;
    }

    handler.next(options);
  }

  String _resolvePath(String rawPath) {
    if (rawPath.startsWith('http')) {
      final uri = Uri.parse(rawPath);
      return uri.path;
    }
    return rawPath;
  }

  // Compute the FnOfficial Authx header value.
  // Equivalent to KMP FnApiHelper.genAuthxForOfficial.
  String _genAuthx(
    String url, {
    Map<String, dynamic>? parameters,
    dynamic data,
  }) {
    final nonce = _generateRandomDigits();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final dataJsonMd5 = _buildDataJsonMd5(parameters, data);

    final signList = [
      _apiKey,
      url,
      nonce,
      timestamp,
      dataJsonMd5,
      _apiSecret,
    ];

    final signStr = signList.join("_");
    final sign = _md5(signStr);
    return "nonce=$nonce&timestamp=$timestamp&sign=$sign";
  }

  String _generateRandomDigits({int start = 100000, int end = 1000000}) {
    final random = Random();
    return (start + random.nextInt(end - start)).toString();
  }

  String _buildDataJsonMd5(Map<String, dynamic>? parameters, dynamic data) {
    if (data != null) {
      final dataJson = jsonEncode(data);
      return _md5(dataJson);
    } else if (parameters != null) {
      final sortedKeys = parameters.keys.toList()..sort();
      final sortedParams = sortedKeys
          .where((key) => parameters[key] != null)
          .map((key) => "$key=${parameters[key]}")
          .join("&");
      return _md5(sortedParams);
    } else {
      return _md5("");
    }
  }

  String _md5(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }
}
