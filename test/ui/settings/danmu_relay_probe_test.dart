import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/ui/features/settings/settings_screen.dart';

/// Guards the relay connectivity probe against the dio double-decode bug:
/// with the default json responseType the body arrives already parsed into a
/// Map, and re-serializing it via toString() is not valid JSON.
void main() {
  group('parseRelayProbe', () {
    test('accepts an already-decoded Map with animes', () {
      final raw = <String, dynamic>{
        'animes': <Map<String, dynamic>>[
          {'animeId': 17617, 'animeTitle': '葬送的芙莉莲'},
        ],
      };
      final (ok, detail) = SettingsScreen.parseRelayProbe(raw, 200);
      expect(ok, isTrue, reason: 'dio auto-decoded body must pass: $detail');
      expect(detail, isNull);
    });

    test('accepts a raw JSON string with errorCode 0', () {
      final (ok, _) = SettingsScreen.parseRelayProbe(
        '{"errorCode":0,"animes":[]}',
        200,
      );
      expect(ok, isTrue);
    });

    test('rejects an error envelope with its errorCode as detail', () {
      final (ok, detail) = SettingsScreen.parseRelayProbe(
        '{"errorCode":-412,"message":"banned"}',
        200,
      );
      expect(ok, isFalse);
      expect(detail, contains('-412'));
    });

    test('non-JSON bodies report the HTTP status', () {
      final (ok, detail) =
          SettingsScreen.parseRelayProbe('<html>oops</html>', 502);
      expect(ok, isFalse);
      expect(detail, 'HTTP 502');
    });
  });
}
