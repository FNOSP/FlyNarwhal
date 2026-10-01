import 'package:fly_narwhal/providers/fly_narwhal_server_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlyNarwhalServerCapabilities.fromVersion', () {
    test('a modern server keeps the whole-work key and config endpoint', () {
      final capabilities = FlyNarwhalServerCapabilities.fromVersion('0.9.0');
      expect(capabilities.versionKnown, isTrue);
      expect(capabilities.rawVersion, '0.9.0');
      expect(capabilities.supportsWholeWorkDanmakuKey, isTrue);
      expect(capabilities.supportsSmartSkipConfig, isTrue);
    });

    test('the threshold version itself is treated as modern', () {
      final capabilities = FlyNarwhalServerCapabilities.fromVersion('0.7.0');
      expect(capabilities.supportsWholeWorkDanmakuKey, isTrue);
      expect(capabilities.supportsSmartSkipConfig, isTrue);
    });

    test('an older server falls back to the legacy contract', () {
      final capabilities = FlyNarwhalServerCapabilities.fromVersion('0.6.4');
      expect(capabilities.versionKnown, isTrue);
      expect(capabilities.supportsWholeWorkDanmakuKey, isFalse);
      expect(capabilities.supportsSmartSkipConfig, isFalse);
    });

    test('a build suffix does not demote a modern version', () {
      final capabilities =
          FlyNarwhalServerCapabilities.fromVersion('0.7.0-fnapp');
      expect(capabilities.supportsWholeWorkDanmakuKey, isTrue);
      expect(capabilities.supportsSmartSkipConfig, isTrue);
    });

    test('an empty or placeholder version is unknown, not modern', () {
      for (final version in <String>['', '   ', '0.0.0']) {
        final capabilities = FlyNarwhalServerCapabilities.fromVersion(version);
        expect(capabilities.versionKnown, isFalse,
            reason: 'version="$version"');
        expect(capabilities.supportsWholeWorkDanmakuKey, isFalse);
        expect(capabilities.supportsSmartSkipConfig, isFalse);
      }
    });

    test('the unknown constant carries no capabilities', () {
      const capabilities = FlyNarwhalServerCapabilities.unknown();
      expect(capabilities.versionKnown, isFalse);
      expect(capabilities.rawVersion, isEmpty);
      expect(capabilities.supportsWholeWorkDanmakuKey, isFalse);
      expect(capabilities.supportsSmartSkipConfig, isFalse);
    });
  });
}
