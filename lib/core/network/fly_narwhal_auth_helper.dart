import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../constants/app_constants.dart';

class FlyNarwhalAuthHelper {
  static final Random _random = Random.secure();

  const FlyNarwhalAuthHelper._();

  /// Generates the Fnauth header for a per-client FNK2 code.
  ///
  /// `sig = HMAC-SHA256(signKey, "FNK2_method_url_ts_nonce_dataJsonMd5_deviceId")`.
  /// The code plaintext never appears in the header — only its SHA-256 keyid.
  static String generateFnauth({
    required String method,
    required String url,
    required String keyIdHex,
    required List<int> signKey,
    required String deviceId,
    Map<String, dynamic>? parameters,
    dynamic data,
  }) {
    final nonceBytes = Uint8List(16);
    for (var i = 0; i < nonceBytes.length; i++) {
      nonceBytes[i] = _random.nextInt(256);
    }
    final nonce = nonceBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final dataJsonMd5 = buildDataJsonMd5(parameters: parameters, data: data);
    final message =
        ['FNK2', method.toUpperCase(), url, ts, nonce, dataJsonMd5, deviceId]
            .join('_');
    final sig = Hmac(sha256, signKey).convert(utf8.encode(message)).toString();
    return 'keyid=$keyIdHex&ts=$ts&nonce=$nonce&sig=$sig';
  }

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
      final querySource =
          sortedEntries.map((entry) => '${entry.key}=${entry.value}').join('&');
      return _md5Hex(querySource);
    }
    return _md5Hex('');
  }

  static String _md5Hex(String value) {
    return md5.convert(utf8.encode(value)).toString();
  }
}
