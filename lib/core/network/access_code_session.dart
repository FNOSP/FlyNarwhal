import 'dart:convert';

import 'package:dio/dio.dart';

/// Raised when the fnOS access-code gateway rejects the code or is unreachable.
class AccessCodeVerificationException implements Exception {
  AccessCodeVerificationException(this.reason, this.message);

  /// `rejected` when the gateway refuses the code, `network` otherwise.
  final String reason;
  final String message;

  bool get isRejected => reason == 'rejected';

  @override
  String toString() => 'AccessCodeVerificationException($reason): $message';
}

/// Outcome of a successful access-code verification.
class AccessCodeSessionResult {
  const AccessCodeSessionResult({required this.baseUrl, required this.cookie});

  /// Origin that actually served the verification (after redirects).
  final String baseUrl;

  /// Gateway session cookie derived from the verification response.
  final String cookie;
}

const Set<String> _excludedCookieNames = {'mode', 'trim-mc-token'};
const Set<int> _rejectedStatusCodes = {401, 403, 429};
const int _maxRedirects = 5;

/// Origin (`scheme://host:port`) -> gateway cookie string.
final Map<String, String> _accessGrants = {};

/// Encodes the plaintext code the way the fnOS gateway expects it:
/// UTF-8 bytes, Base64 encoded (`Buffer.from(code, 'utf8').toString('base64')`).
String encodeAccessCode(String accessCode) =>
    base64.encode(utf8.encode(accessCode));

String? _normalizeOrigin(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return null;
  final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
  if (scheme != 'http' && scheme != 'https') return null;
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '$scheme://${uri.host}$port';
}

String originOf(String value) => _normalizeOrigin(value) ?? '';

void setAccessGrant(String origin, String cookie) {
  final normalized = _normalizeOrigin(origin);
  if (normalized == null) return;
  if (cookie.isEmpty) {
    _accessGrants.remove(normalized);
  } else {
    _accessGrants[normalized] = cookie;
  }
}

void clearAccessGrants() => _accessGrants.clear();

String getAccessCookieHeader(String origin) =>
    _accessGrants[_normalizeOrigin(origin) ?? ''] ?? '';

/// Merges cookie strings, keeping the first value seen for each cookie name.
String mergeCookies(List<String?> values) {
  final seen = <String>{};
  final parts = <String>[];
  for (final value in values) {
    for (final rawPart in (value ?? '').split(';')) {
      final part = rawPart.trim();
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      final name = part.substring(0, separator).trim();
      final normalizedName = name.toLowerCase();
      if (name.isEmpty || seen.contains(normalizedName)) continue;
      seen.add(normalizedName);
      parts.add('$name=${part.substring(separator + 1).trim()}');
    }
  }
  return parts.join('; ');
}

/// Establishes a gateway session by calling `GET <base>/access_code_verify`
/// with the Base64-encoded code, mirroring the Electron client.
class AccessCodeSession {
  AccessCodeSession._();

  static Future<AccessCodeSessionResult> establish({
    required Dio dio,
    required String baseUrl,
    required String accessCode,
  }) async {
    final initial = Uri.tryParse(baseUrl);
    if (initial == null ||
        initial.host.isEmpty ||
        (initial.scheme != 'http' && initial.scheme != 'https')) {
      throw AccessCodeVerificationException('network', '访问码验证地址无效');
    }

    // A single active login: drop grants from previous attempts.
    clearAccessGrants();

    final code = accessCode.trim();
    if (code.isEmpty) {
      return AccessCodeSessionResult(
        baseUrl: _normalizeOrigin(baseUrl) ?? '',
        cookie: '',
      );
    }

    final setCookies = <String>[];
    var current = initial;
    var response = await _request(dio, current, code, setCookies);

    var redirects = 0;
    while (_isRedirect(response.statusCode) && redirects < _maxRedirects) {
      redirects++;
      final location = response.headers.value('location');
      if (location == null || location.isEmpty) break;
      final next = _resolveRedirect(current, location);
      if (next == null) {
        throw AccessCodeVerificationException('network', '访问码验证拒绝不安全的重定向');
      }
      current = next;
      response = await _request(dio, current, code, setCookies);
    }

    final status = response.statusCode ?? 0;
    if (_rejectedStatusCodes.contains(status)) {
      clearAccessGrants();
      throw AccessCodeVerificationException('rejected', '访问码错误');
    }
    if (status < 200 || status >= 300) {
      throw AccessCodeVerificationException(
        'network',
        '访问码验证服务返回 HTTP $status',
      );
    }

    final resolvedOrigin = _normalizeOrigin(current.toString()) ?? '';
    final cookie = _composeGrant(setCookies);
    if (cookie.isEmpty) {
      throw AccessCodeVerificationException('network', '访问码验证成功但未建立网关会话');
    }
    setAccessGrant(resolvedOrigin, cookie);
    return AccessCodeSessionResult(baseUrl: resolvedOrigin, cookie: cookie);
  }

  static Future<Response<dynamic>> _request(
    Dio dio,
    Uri uri,
    String code,
    List<String> setCookies,
  ) async {
    try {
      final response = await dio.getUri<dynamic>(
        uri,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (_) => true,
          headers: {
            'x-access-code': encodeAccessCode(code),
            'x-access-source': 'web',
          },
        ),
      );
      final setCookie = response.headers.map['set-cookie'];
      if (setCookie != null) {
        setCookies.addAll(setCookie);
      }
      return response;
    } on DioException catch (e) {
      throw AccessCodeVerificationException(
        'network',
        '无法连接到访问码验证服务: ${e.message ?? e.type.name}',
      );
    }
  }

  static bool _isRedirect(int? status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  static Uri? _resolveRedirect(Uri source, String location) {
    final target = source.resolve(location);
    final isWeb = target.scheme == 'http' || target.scheme == 'https';
    final isSameHost = source.host == target.host;
    final isSecureTransition =
        !(source.scheme == 'https' && target.scheme == 'http');
    if (!isWeb || !isSameHost || !isSecureTransition) return null;
    return target;
  }

  static String _composeGrant(List<String> setCookies) {
    final seen = <String>{};
    final parts = <String>[];
    for (final raw in setCookies) {
      final pair = raw.split(';').first.trim();
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      final name = pair.substring(0, separator).trim();
      final normalizedName = name.toLowerCase();
      if (name.isEmpty ||
          _excludedCookieNames.contains(normalizedName) ||
          seen.contains(normalizedName)) {
        continue;
      }
      seen.add(normalizedName);
      parts.add(pair);
    }
    return parts.join('; ');
  }
}
