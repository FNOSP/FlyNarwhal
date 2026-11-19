import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/fly_narwhal_auth_helper.dart';
import 'package:fly_narwhal/core/network/fly_narwhal_wb_helper.dart';

/// Fixed golden vector for the FNWB2 canonical message. The Go signer library
/// (fly-narwhal-whitebox) and the server-side verifier must reproduce this
/// exact string; keep the literal in sync across all three implementations.
void main() {
  group('buildFnwbMessage', () {
    test('matches the fixed cross-language golden vector', () {
      // dataJsonMd5 = MD5('title=hello&year=2026'), the sorted-query form
      // produced by FlyNarwhalAuthHelper.buildDataJsonMd5.
      final message = FlyNarwhalWbHelper.buildFnwbMessage(
        method: 'GET',
        url: '/api/danmu/get',
        ts: '1731000000000',
        nonce: '00112233445566778899aabbccddeeff',
        dataJsonMd5: 'bea65d55300ad20387d9fcf8b69d050a',
        instanceId: 'macos-arm64-FN-0123456789abcdef',
        fnauthSig:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      expect(
        message,
        'FNWB2_GET_/api/danmu/get_1731000000000_'
        '00112233445566778899aabbccddeeff_'
        'bea65d55300ad20387d9fcf8b69d050a_'
        'macos-arm64-FN-0123456789abcdef_'
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
    });

    test('uppercases the method like the FNK2 Fnauth signature', () {
      String messageFor(String method) => FlyNarwhalWbHelper.buildFnwbMessage(
            method: method,
            url: '/api/client/activate',
            ts: '1731000000000',
            nonce: '00112233445566778899aabbccddeeff',
            dataJsonMd5: 'd41d8cd98f00b204e9800998ecf8427e',
            instanceId: 'd',
            fnauthSig: 'abcd',
          );
      expect(messageFor('post'), messageFor('POST'));
      expect(messageFor('post'), startsWith('FNWB2_POST_'));
    });

    test('dataJsonMd5 golden values match buildDataJsonMd5', () {
      expect(
        FlyNarwhalAuthHelper.buildDataJsonMd5(
          parameters: <String, dynamic>{'year': 2026, 'title': 'hello'},
        ),
        'bea65d55300ad20387d9fcf8b69d050a',
      );
      expect(
        FlyNarwhalAuthHelper.buildDataJsonMd5(),
        'd41d8cd98f00b204e9800998ecf8427e',
      );
    });
  });

  group('parseFnauth', () {
    test('extracts keyid/ts/nonce/sig from a Fnauth header value', () {
      const sig =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final parts = FlyNarwhalWbHelper.parseFnauth(
        'keyid=deadbeef&ts=1731000000000&'
        'nonce=00112233445566778899aabbccddeeff&sig=$sig',
      );
      expect(parts['keyid'], 'deadbeef');
      expect(parts['ts'], '1731000000000');
      expect(parts['nonce'], '00112233445566778899aabbccddeeff');
      expect(parts['sig'], sig);
    });
  });
}