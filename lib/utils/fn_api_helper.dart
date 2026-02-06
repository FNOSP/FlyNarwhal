import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

class FnApiHelper {
  static const String _apiKey = "NDzZTVxnRKP8Z0jXg1VAMonaG8akvh";
  static const String _apiSecret = "16CCEB3D-AB42-077D-36A1-F355324E4237";

  static String genAuthxForOfficial(
    String url, {
    Map<String, dynamic>? parameters,
    dynamic data,
  }) {
    return _genAuthxInternal(
      url: url,
      parameters: parameters,
      data: data,
      apiSecret: _apiSecret,
    );
  }

  static String genAuthxForFlyNarwhal(
    String url, {
    Map<String, dynamic>? parameters,
    dynamic data,
    String? apiSecret,
  }) {
    return _genAuthxInternal(
      url: url,
      parameters: parameters,
      data: data,
      apiSecret: (apiSecret ?? _apiSecret).trim().isEmpty ? _apiSecret : apiSecret!,
    );
  }

  static String genSignxForFlyNarwhal({
    required String url,
    required String authx,
    Map<String, dynamic>? parameters,
    dynamic data,
    required String publicKeyBase64,
  }) {
    final authxMap = _parseAuthxHeader(authx);
    final nonce = authxMap['nonce'] ?? '';
    final timestamp = authxMap['timestamp'] ?? '';
    final sign = authxMap['sign'] ?? '';
    final dataJsonMd5 = _buildDataJsonMd5(parameters, data);
    final signxStr = [
      timestamp,
      nonce,
      sign,
      dataJsonMd5,
      url,
      publicKeyBase64,
    ].join("_");
    return _sha256Hex(signxStr);
  }

  static Future<String> clientKeyxBase64Url() {
    return FlyNarwhalKeyExchange.clientKeyxBase64Url();
  }

  static String _genAuthxInternal({
    required String url,
    Map<String, dynamic>? parameters,
    dynamic data,
    required String apiSecret,
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
      apiSecret,
    ];

    final signStr = signList.join("_");
    final sign = _getMd5(signStr);
    return "nonce=$nonce&timestamp=$timestamp&sign=$sign";
  }

  static String _generateRandomDigits({int start = 100000, int end = 1000000}) {
    final random = Random();
    return (start + random.nextInt(end - start)).toString();
  }

  static String _buildDataJsonMd5(Map<String, dynamic>? parameters, dynamic data) {
    if (data != null) {
      final dataJson = jsonEncode(data);
      return _getMd5(dataJson);
    } else if (parameters != null) {
      final sortedKeys = parameters.keys.toList()..sort();
      final sortedParams = sortedKeys
          .where((key) => parameters[key] != null)
          .map((key) => "$key=${parameters[key]}")
          .join("&");
      return _getMd5(sortedParams);
    } else {
      return _getMd5("");
    }
  }

  static Map<String, String> _parseAuthxHeader(String authx) {
    final parts = authx.split("&");
    final map = <String, String>{};
    for (final part in parts) {
      final kv = part.split("=");
      if (kv.length == 2) {
        map[kv[0]] = kv[1];
      }
    }
    return map;
  }

  static String _getMd5(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  static String _sha256Hex(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}

class FlyNarwhalKeyExchange {
  static final X25519 _algorithm = X25519();
  static SimpleKeyPair? _keyPair;
  static SimplePublicKey? _publicKey;

  static Future<String> clientKeyxBase64Url() async {
    _keyPair ??= await _algorithm.newKeyPair();
    _publicKey ??= await _keyPair!.extractPublicKey();
    final raw = _publicKey!.bytes;
    final encoded = base64UrlEncode(raw);
    return encoded.replaceAll('=', '');
  }
}
