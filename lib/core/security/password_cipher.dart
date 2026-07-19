import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../config/runtime_configuration.dart';

/// Encrypts saved login passwords using the versioned FNPW envelope format.
class PasswordCipher {
  PasswordCipher(this._configuration) : _keyFactory = SecretKey.new;

  static const List<int> _magic = <int>[0x46, 0x4E, 0x50, 0x57];
  static const int _version = 0x01;
  static const int _algorithm = 0x01;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _authenticationTagLength = 16;
  static const int _maximumCiphertextLength = 16 * 1024;
  static const List<int> _hkdfInfo = <int>[
    0x66,
    0x6C,
    0x79,
    0x6E,
    0x61,
    0x72,
    0x77,
    0x68,
    0x61,
    0x6C,
    0x2D,
    0x70,
    0x61,
    0x73,
    0x73,
    0x77,
    0x6F,
    0x72,
    0x64,
    0x2D,
    0x76,
    0x31,
  ];

  final RuntimeConfiguration _configuration;
  final SecretKey Function(List<int>) _keyFactory;
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Encrypts [password] and returns a Base64URL envelope without padding.
  Future<String> encrypt(String password) async {
    final secretBytes = await _configuration.resolveRequiredSecret(
      RuntimeSecret.flyNarwhalSecret,
    );
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final plaintextBytes = Uint8List.fromList(utf8.encode(password));

    try {
      final encryptionKey = await _deriveEncryptionKey(secretBytes, salt);
      final secretBox = await _aesGcm.encrypt(
        plaintextBytes,
        secretKey: encryptionKey,
        nonce: nonce,
        aad: const <int>[],
      );
      final envelope = BytesBuilder(copy: false)
        ..add(_magic)
        ..addByte(_version)
        ..addByte(_algorithm)
        ..addByte(_saltLength)
        ..addByte(_nonceLength)
        ..add(salt)
        ..add(nonce)
        ..add(_encodeUint32(secretBox.cipherText.length))
        ..add(secretBox.cipherText)
        ..add(secretBox.mac.bytes);
      return base64Url.encode(envelope.takeBytes()).replaceAll('=', '');
    } finally {
      await _zeroize(secretBytes);
      _zeroizeLocally(salt);
      _zeroizeLocally(nonce);
      _zeroizeLocally(plaintextBytes);
    }
  }

  /// Decrypts one FNPW envelope.
  ///
  /// Invalid envelopes, a rotated secret, and modified tags throw
  /// [PasswordCipherException]. Callers must clear the stored password.
  Future<String> decrypt(String encodedEnvelope) async {
    final envelope = _decodeEnvelope(encodedEnvelope);
    Uint8List? secretBytes;
    Uint8List? salt;
    Uint8List? nonce;
    Uint8List? ciphertext;
    Uint8List? tag;

    try {
      _validateEnvelope(envelope);
      var cursor = 8;
      salt = Uint8List.fromList(envelope.sublist(cursor, cursor + _saltLength));
      cursor += _saltLength;
      nonce =
          Uint8List.fromList(envelope.sublist(cursor, cursor + _nonceLength));
      cursor += _nonceLength;
      final ciphertextLength = _decodeUint32(envelope, cursor);
      cursor += 4;
      ciphertext = Uint8List.fromList(
        envelope.sublist(cursor, cursor + ciphertextLength),
      );
      cursor += ciphertextLength;
      tag = Uint8List.fromList(
        envelope.sublist(cursor, cursor + _authenticationTagLength),
      );
      secretBytes = await _configuration.resolveRequiredSecret(
        RuntimeSecret.flyNarwhalSecret,
      );
      final encryptionKey = await _deriveEncryptionKey(secretBytes, salt);
      final plaintextBytes = await _aesGcm.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
        secretKey: encryptionKey,
        aad: const <int>[],
      );
      try {
        return utf8.decode(plaintextBytes, allowMalformed: false);
      } finally {
        _zeroizeLocally(plaintextBytes);
      }
    } on PasswordCipherException {
      rethrow;
    } catch (_) {
      throw const PasswordCipherException('Unable to decrypt saved password');
    } finally {
      await _zeroize(secretBytes);
      _zeroizeLocally(salt);
      _zeroizeLocally(nonce);
      _zeroizeLocally(ciphertext);
      _zeroizeLocally(tag);
      _zeroizeLocally(envelope);
    }
  }

  Future<SecretKey> _deriveEncryptionKey(
    List<int> secretBytes,
    List<int> salt,
  ) {
    return _hkdf.deriveKey(
      secretKey: _keyFactory(secretBytes),
      nonce: salt,
      info: _hkdfInfo,
    );
  }

  Uint8List _decodeEnvelope(String value) {
    try {
      final paddingLength = (4 - value.length % 4) % 4;
      final normalizedValue = value.padRight(value.length + paddingLength, '=');
      return Uint8List.fromList(base64Url.decode(normalizedValue));
    } catch (_) {
      throw const PasswordCipherException('Invalid saved password envelope');
    }
  }

  void _validateEnvelope(Uint8List envelope) {
    const headerLength = 8;
    const minimumLength = headerLength +
        _saltLength +
        _nonceLength +
        4 +
        _authenticationTagLength;
    if (envelope.length < minimumLength ||
        !_matchesMagic(envelope) ||
        envelope[4] != _version ||
        envelope[5] != _algorithm ||
        envelope[6] != _saltLength ||
        envelope[7] != _nonceLength) {
      throw const PasswordCipherException(
          'Unsupported saved password envelope');
    }

    final ciphertextLength = _decodeUint32(
      envelope,
      headerLength + _saltLength + _nonceLength,
    );
    if (ciphertextLength > _maximumCiphertextLength ||
        envelope.length != minimumLength + ciphertextLength) {
      throw const PasswordCipherException(
          'Invalid saved password envelope length');
    }
  }

  bool _matchesMagic(Uint8List envelope) {
    for (var index = 0; index < _magic.length; index++) {
      if (envelope[index] != _magic[index]) {
        return false;
      }
    }
    return true;
  }

  Uint8List _randomBytes(int length) {
    final secureRandom = Random.secure();
    final bytes = Uint8List(length);
    for (var index = 0; index < length; index++) {
      bytes[index] = secureRandom.nextInt(256);
    }
    return bytes;
  }

  Uint8List _encodeUint32(int value) {
    return Uint8List.fromList(<int>[
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }

  int _decodeUint32(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) {
      throw const PasswordCipherException('Invalid saved password envelope');
    }
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  Future<void> _zeroize(Uint8List? bytes) async {
    if (bytes == null) {
      return;
    }
    _zeroizeLocally(bytes);
    await _configuration.zeroize(bytes);
  }

  void _zeroizeLocally(List<int>? bytes) {
    if (bytes == null) {
      return;
    }
    for (var index = 0; index < bytes.length; index++) {
      bytes[index] = 0;
    }
  }
}

class PasswordCipherException implements Exception {
  const PasswordCipherException(this.message);

  final String message;

  @override
  String toString() => message;
}
