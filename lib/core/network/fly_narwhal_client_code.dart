import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

/// Per-client authorization code (FNK2) parsing and key derivation.
///
/// The code is `FNK2_<base64url(32 random bytes)>`. Two one-way derivations
/// matter to the client: the lookup key `SHA-256(full code string)` and the
/// HMAC signing key `HKDF-SHA256(secret, "flynarwhal", "flynarwhal_sign_v2")`.
/// The plaintext code never travels over the network — the Fnauth header
/// proves possession.
class FlyNarwhalClientCode {
  static const String prefix = 'FNK2_';
  static const String legacyPrefix = 'FN1_';
  static const int secretLength = 32;
  static const String _hkdfSalt = 'flynarwhal';
  static const String _signInfo = 'flynarwhal_sign_v2';
  static const String _respInfoPrefix = 'flynarwhal_resp_v2';

  final String fullCode;
  final Uint8List secret;

  FlyNarwhalClientCode._(this.fullCode, this.secret);

  static bool isFnk2(String? code) => code != null && code.startsWith(prefix);

  static bool isLegacyFn1(String? code) =>
      code != null && code.startsWith(legacyPrefix);

  /// Parses a full FNK2 code; returns null when malformed.
  static FlyNarwhalClientCode? tryParse(String? code) {
    if (!isFnk2(code)) return null;
    try {
      final payload = base64Url.decode(
        base64Url.normalize(code!.substring(prefix.length)),
      );
      if (payload.length != secretLength) return null;
      return FlyNarwhalClientCode._(code, Uint8List.fromList(payload));
    } catch (_) {
      return null;
    }
  }

  /// Lookup key sent as `keyid` in the Fnauth header.
  String get keyIdHex =>
      crypto.sha256.convert(utf8.encode(fullCode)).toString();

  Future<SecretKey> deriveSignKey() async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: SecretKey(secret),
      nonce: utf8.encode(_hkdfSalt),
      info: utf8.encode(_signInfo),
    );
  }

  /// AES-256 key for the v2 response envelope, derived from the sign key and
  /// this process's random Keyx.
  static Future<SecretKey> deriveResponseKey(
    SecretKey signKey,
    List<int> keyx32,
  ) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: signKey,
      nonce: utf8.encode(_hkdfSalt),
      info: <int>[...utf8.encode(_respInfoPrefix), ...keyx32],
    );
  }
}