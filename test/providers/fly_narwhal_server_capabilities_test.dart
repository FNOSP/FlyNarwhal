import 'package:fly_narwhal/providers/fly_narwhal_server_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlyNarwhalServerCapabilities.fromVersion', () {
    test('a newer server carries the modern contract', () {
      final capabilities = FlyNarwhalServerCapabilities.fromVersion('2.1.0');
      expect(capabilities.versionKnown, isTrue);
      expect(capabilities.rawVersion, '2.1.0');
      expect(capabilities.supportsModernContract, isTrue);
    });

    test('the threshold version itself counts as modern', () {
      final capabilities = FlyNarwhalServerCapabilities.fromVersion('2.0.0');
      expect(capabilities.supportsModernContract, isTrue);
    });

    test('an older server falls back to the legacy contract', () {
      for (final version in <String>['1.9.9', '0.11.0', '0.6.4']) {
        final capabilities = FlyNarwhalServerCapabilities.fromVersion(version);
        expect(capabilities.versionKnown, isTrue, reason: 'version="$version"');
        expect(capabilities.supportsModernContract, isFalse,
            reason: 'version="$version"');
      }
    });

    test('a build suffix does not lift an old version over the threshold', () {
      final capabilities =
          FlyNarwhalServerCapabilities.fromVersion('1.9.9-fnapp');
      expect(capabilities.supportsModernContract, isFalse);
    });

    test('a build suffix does not demote a modern version', () {
      final capabilities =
          FlyNarwhalServerCapabilities.fromVersion('2.0.0-fnapp');
      expect(capabilities.supportsModernContract, isTrue);
    });

    test('an empty or placeholder version is unknown, not modern', () {
      for (final version in <String>['', '   ', '0.0.0']) {
        final capabilities = FlyNarwhalServerCapabilities.fromVersion(version);
        expect(capabilities.versionKnown, isFalse,
            reason: 'version="$version"');
        expect(capabilities.supportsModernContract, isFalse,
            reason: 'version="$version"');
      }
    });

    test('the unknown constant carries no capabilities', () {
      const capabilities = FlyNarwhalServerCapabilities.unknown();
      expect(capabilities.versionKnown, isFalse);
      expect(capabilities.rawVersion, isEmpty);
      expect(capabilities.supportsModernContract, isFalse);
    });
  });
}
