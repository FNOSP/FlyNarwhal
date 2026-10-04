import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/utils/log/talker_log_sanitizer.dart';

void main() {
  const sanitizer = TalkerLogSanitizer();

  group('TalkerLogSanitizer', () {
    test('masks the login form payload from the JS bridge', () {
      final sanitized = sanitizer.sanitize(
        'CaptureLoginInfo|{"username":"admin","password":"ecE4#<9pEA"}',
      );

      expect(sanitized, isNot(contains('ecE4#<9pEA')));
      expect(sanitized, contains('"password":"******"'));
    });

    test('masks a multi-line JSON request body', () {
      final sanitized = sanitizer.sanitize(
        'Data: {\n  "username": "admin",\n  "password": "ecE4#<9pEA",\n'
        '  "app_name": "trimemedia-web"\n}',
      );

      expect(sanitized, isNot(contains('ecE4#<9pEA')));
      expect(sanitized, contains('"password": "******"'));
      expect(sanitized, contains('trimemedia-web'));
    });

    test('masks the access code in both the header and JSON forms', () {
      // The access code is Base64 of the plaintext code, so it is trivially
      // decodable and must never reach the log.
      expect(sanitizer.sanitize('x-access-code: d3dnMTIz'), 'x-access-code: ******');
      expect(
        sanitizer.sanitize('"x-access-code": "d3dnMTIz"'),
        '"x-access-code": "******"',
      );
      expect(
        sanitizer.sanitize('"x-access-code":"QUJDREVG"'),
        '"x-access-code":"******"',
      );
    });

    test('masks the gateway cookie but keeps its attributes', () {
      final sanitized = sanitizer.sanitize(
        'set-cookie: os-access-code=abc.def; Path=/; HttpOnly',
      );

      expect(sanitized, isNot(contains('abc.def')));
      expect(sanitized, contains('Path=/'));
    });

    test('masks auth tokens and FN Connect host fragments', () {
      expect(
        sanitizer.sanitize('Data: {"code":0,"data":{"token":"abcdef123456"}}'),
        contains('"token":"******"'),
      );
      expect(
        sanitizer.sanitize('https://n6z8f2q1m8.5ddd.com/signin'),
        'https://***.5ddd.com/signin',
      );
    });

    test('is idempotent, since console and file sinks both sanitize', () {
      final once = sanitizer.sanitize('{"username":"admin","password":"sec"}');

      expect(sanitizer.sanitize(once), once);
    });
  });
}