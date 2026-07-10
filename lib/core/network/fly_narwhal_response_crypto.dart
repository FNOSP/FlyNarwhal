import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class FlyNarwhalResponseCrypto {
  static final FlyNarwhalResponseCrypto instance = FlyNarwhalResponseCrypto._();

  final X25519 _x25519 = X25519();
  final AesGcm _aesGcm = AesGcm.with256bits();
  Future<SimpleKeyPair>? _clientKeyPairFuture;

  FlyNarwhalResponseCrypto._();

  // Client X25519 public key, base64url without padding.
  Future<String> clientKeyxBase64Url() async {
    final publicKey = await _clientPublicKey();
    return _encodeBase64UrlNoPadding(publicKey.bytes);
  }

  // Decrypt an encrypted response payload using the FN1 auth code.
  Future<String> decryptAesGcmBase64Url(
    String ciphertextBase64Url,
    String authCode,
  ) async {
    final serverPublicKeyBytes = _decodeAuthCodeServerPublicKey(authCode);
    final payload = _decodeBase64UrlNoPadding(ciphertextBase64Url);
    if (payload.length < 14 || payload.first != 1) {
      throw const FormatException('Invalid FlyNarwhal encrypted payload');
    }

    final nonce = payload.sublist(1, 13);
    final encryptedBytesWithMac = payload.sublist(13);
    if (encryptedBytesWithMac.length < 16) {
      throw const FormatException('Invalid FlyNarwhal encrypted payload mac');
    }

    final cipherText = encryptedBytesWithMac.sublist(
      0,
      encryptedBytesWithMac.length - 16,
    );
    final macBytes = encryptedBytesWithMac.sublist(
      encryptedBytesWithMac.length - 16,
    );
    final secretKey = await _deriveResponseSecretKey(serverPublicKeyBytes);
    final decryptedBytes = await _aesGcm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
      secretKey: secretKey,
    );
    return utf8.decode(decryptedBytes);
  }

  Future<SimpleKeyPair> _clientKeyPair() {
    return _clientKeyPairFuture ??= _x25519.newKeyPair();
  }

  Future<SimplePublicKey> _clientPublicKey() async {
    final keyPair = await _clientKeyPair();
    return keyPair.extractPublicKey();
  }

  Future<SecretKey> _deriveResponseSecretKey(List<int> serverPublicKeyBytes) async {
    final clientKeyPair = await _clientKeyPair();
    final clientPublicKey = await _clientPublicKey();
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: clientKeyPair,
      remotePublicKey: SimplePublicKey(
        serverPublicKeyBytes,
        type: KeyPairType.x25519,
      ),
    );
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode('flynarwhal'),
      info: <int>[
        ...utf8.encode('flynarwhal_resp_v1'),
        ...serverPublicKeyBytes,
        ...clientPublicKey.bytes,
      ],
    );
  }

  List<int> _decodeAuthCodeServerPublicKey(String authCode) {
    if (!authCode.startsWith('FN1_')) {
      throw const FormatException('FlyNarwhal auth code must start with FN1_');
    }
    final payload = _decodeBase64UrlNoPadding(authCode.substring(4));
    if (payload.length != 33 || payload.first != 1) {
      throw const FormatException('Invalid FlyNarwhal auth code payload');
    }
    return payload.sublist(1, 33);
  }

  static String _encodeBase64UrlNoPadding(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Uint8List _decodeBase64UrlNoPadding(String value) {
    final normalizedLength = value.length + ((4 - value.length % 4) % 4);
    final normalized = value.padRight(normalizedLength, '=');
    return base64Url.decode(normalized);
  }
}
