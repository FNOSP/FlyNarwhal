import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/fly_narwhal_auth_helper.dart';
import 'package:fly_narwhal/core/network/fly_narwhal_client_code.dart';
import 'package:fly_narwhal/core/network/fly_narwhal_response_crypto.dart';

/// Fixed vectors shared with the server's ClientCodeCryptoTest: both sides
/// must derive identical keyid/sign key/signature from the same code.
void main() {
  final secret = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final code = 'FNK2_${base64Url.encode(secret).replaceAll('=', '')}';

  group('FlyNarwhalClientCode', () {
    test('parses a valid code and rejects malformed ones', () {
      final parsed = FlyNarwhalClientCode.tryParse(code);
      expect(parsed, isNotNull);
      expect(parsed!.secret, secret);
      expect(FlyNarwhalClientCode.tryParse('FN1_abc'), isNull);
      expect(FlyNarwhalClientCode.tryParse('FNK2_!!!'), isNull);
      expect(FlyNarwhalClientCode.tryParse(null), isNull);
      expect(
        FlyNarwhalClientCode.tryParse(
          'FNK2_${base64Url.encode(Uint8List(16)).replaceAll('=', '')}',
        ),
        isNull,
      );
    });

    test('keyid is sha256 of the full code string', () {
      final parsed = FlyNarwhalClientCode.tryParse(code)!;
      expect(parsed.keyIdHex, crypto.sha256.convert(utf8.encode(code)).toString());
      expect(parsed.keyIdHex.length, 64);
    });

    test('sign key derivation matches the server HKDF vector', () async {
      final parsed = FlyNarwhalClientCode.tryParse(code)!;
      final key = await parsed.deriveSignKey();
      final bytes = await key.extractBytes();
      // Independent HKDF computation with the same parameters.
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
      final expected = await hkdf.deriveKey(
        secretKey: SecretKey(secret),
        nonce: utf8.encode('flynarwhal'),
        info: utf8.encode('flynarwhal_sign_v2'),
      );
      expect(bytes, await expected.extractBytes());
      expect(bytes.length, 32);
    });

    test('matches the fixed cross-language vectors (server ClientCodeCryptoTest)', () async {
      // Vectors produced by the Java implementation for secret 0x00..0x1f.
      expect(code, 'FNK2_AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8');
      final parsed = FlyNarwhalClientCode.tryParse(code)!;
      expect(parsed.keyIdHex,
          '37f6f553f9e85803c404acc6dcf7542ef336d9ff6154faaa5240ac2d9e238f8e');
      final bytes = await (await parsed.deriveSignKey()).extractBytes();
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(hex, '21cde7c1a2ace9e0c92c0d769fbcb2c484f03412016769710d50e73fea58fb0e');
    });

    test('prefix detection', () {
      expect(FlyNarwhalClientCode.isFnk2(code), isTrue);
      expect(FlyNarwhalClientCode.isFnk2('FN1_x'), isFalse);
      expect(FlyNarwhalClientCode.isLegacyFn1('FN1_x'), isTrue);
      expect(FlyNarwhalClientCode.isLegacyFn1(code), isFalse);
    });
  });

  group('generateFnauth', () {
    test('signature verifies against an independent HMAC computation', () async {
      final parsed = FlyNarwhalClientCode.tryParse(code)!;
      final signKey = await (await parsed.deriveSignKey()).extractBytes();
      final header = FlyNarwhalAuthHelper.generateFnauth(
        method: 'GET',
        url: '/api/danmu/get',
        keyIdHex: parsed.keyIdHex,
        signKey: signKey,
        instanceId: 'flutter_test-device',
      );
      final parts = Uri.splitQueryString(header);
      expect(parts['keyid'], parsed.keyIdHex);
      expect(parts['nonce']!.length, 32);
      final message = [
        'FNK2',
        'GET',
        '/api/danmu/get',
        parts['ts'],
        parts['nonce'],
        FlyNarwhalAuthHelper.buildDataJsonMd5(),
        'flutter_test-device',
      ].join('_');
      final expected =
          crypto.Hmac(crypto.sha256, signKey).convert(utf8.encode(message)).toString();
      expect(parts['sig'], expected);
    });

    test('method is uppercased in the signature', () async {
      final parsed = FlyNarwhalClientCode.tryParse(code)!;
      final signKey = await (await parsed.deriveSignKey()).extractBytes();
      final header = FlyNarwhalAuthHelper.generateFnauth(
        method: 'post',
        url: '/api/client/activate',
        keyIdHex: parsed.keyIdHex,
        signKey: signKey,
        instanceId: 'd',
        data: {'a': 1},
      );
      final parts = Uri.splitQueryString(header);
      final message = [
        'FNK2',
        'POST',
        '/api/client/activate',
        parts['ts'],
        parts['nonce'],
        FlyNarwhalAuthHelper.buildDataJsonMd5(data: {'a': 1}),
        'd',
      ].join('_');
      final expected =
          crypto.Hmac(crypto.sha256, signKey).convert(utf8.encode(message)).toString();
      expect(parts['sig'], expected);
    });
  });

  group('v2 response envelope', () {
    test('decrypts a payload encrypted with the derived response key', () async {
      final parsed = FlyNarwhalClientCode.tryParse(code)!;
      final cryptoInstance = FlyNarwhalResponseCrypto.instance;
      final keyx = cryptoInstance.fnk2KeyxBytes();
      final signKey = await parsed.deriveSignKey();
      final responseKey =
          await FlyNarwhalClientCode.deriveResponseKey(signKey, keyx);

      // Encrypt a known payload the way the server does: 0x02 || IV || GCM.
      final aes = AesGcm.with256bits();
      final plaintext = utf8.encode('{"hello":"world"}');
      final box = await aes.encrypt(plaintext, secretKey: responseKey);
      final payload = <int>[
        2,
        ...box.nonce,
        ...box.cipherText,
        ...box.mac.bytes,
      ];
      final encoded = base64Url.encode(payload).replaceAll('=', '');

      final decrypted =
          await cryptoInstance.decryptAesGcmBase64Url(encoded, code);
      expect(decrypted, '{"hello":"world"}');
    });

    test('rejects a v2 payload when the code is FN1', () async {
      final cryptoInstance = FlyNarwhalResponseCrypto.instance;
      final payload = <int>[2, ...List<int>.filled(40, 0)];
      final encoded = base64Url.encode(payload).replaceAll('=', '');
      expect(
        () => cryptoInstance.decryptAesGcmBase64Url(encoded, 'FN1_abc'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}