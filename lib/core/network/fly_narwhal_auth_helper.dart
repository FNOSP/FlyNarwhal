import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../constants/app_constants.dart';

class FlyNarwhalAuthHelper {
  static final Random _random = Random.secure();

  const FlyNarwhalAuthHelper._();

  // Generate the Authx header value.
  static String generateAuthx(
    String url, {
    Map<String, dynamic>? parameters,
    dynamic data,
    String? apiSecret,
  }) {
    final nonce = 100000 + _random.nextInt(900000);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dataJsonMd5 = buildDataJsonMd5(parameters: parameters, data: data);
    final resolvedApiSecret = (apiSecret == null || apiSecret.isEmpty)
        ? AppConstants.flyNarwhalApiSecret
        : apiSecret;
    final signSource = [
      AppConstants.defaultApiKey,
      url,
      nonce,
      timestamp,
      dataJsonMd5,
      resolvedApiSecret,
    ].join('_');
    final sign = _md5Hex(signSource);
    return 'nonce=$nonce&timestamp=$timestamp&sign=$sign';
  }

  // Generate the Signx header value from an existing Authx.
  static String generateSignx({
    required String url,
    required String authx,
    Map<String, dynamic>? parameters,
    dynamic data,
    required String authCode,
  }) {
    final authxParameters = Uri.splitQueryString(authx);
    final nonce = authxParameters['nonce'] ?? '';
    final timestamp = authxParameters['timestamp'] ?? '';
    final sign = authxParameters['sign'] ?? '';
    final dataJsonMd5 = buildDataJsonMd5(parameters: parameters, data: data);
    final signxSource = [
      timestamp,
      nonce,
      sign,
      dataJsonMd5,
      url,
      authCode,
    ].join('_');
    return sha256.convert(utf8.encode(signxSource)).toString();
  }

  // MD5 of json body / sorted query / empty string.
  static String buildDataJsonMd5({
    Map<String, dynamic>? parameters,
    dynamic data,
  }) {
    if (data != null) {
      return _md5Hex(jsonEncode(data));
    }
    if (parameters != null) {
      final sortedEntries = parameters.entries
          .where((entry) => entry.value != null)
          .toList()
        ..sort((first, second) => first.key.compareTo(second.key));
      final querySource = sortedEntries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('&');
      return _md5Hex(querySource.isEmpty ? '' : '$querySource&');
    }
    return _md5Hex('');
  }

  static String _md5Hex(String value) {
    return md5.convert(utf8.encode(value)).toString();
  }
}
