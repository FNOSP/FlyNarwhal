import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/ui/settings/ui_font_scale.dart';

void main() {
  group('UiFontScale', () {
    test('medium is the default and leaves text unscaled', () {
      expect(UiFontScale.mediumFactor, 1.0);
      expect(UiFontScale.factorFromValue(UiFontScale.medium), 1.0);
    });

    test('small and large sit either side of medium', () {
      expect(UiFontScale.factorFromValue(UiFontScale.small), lessThan(1.0));
      expect(UiFontScale.factorFromValue(UiFontScale.large), greaterThan(1.0));
    });

    test('unknown values fall back to medium', () {
      expect(UiFontScale.factorFromValue('nonsense'), 1.0);
      expect(UiFontScale.labelFromValue('nonsense'), '中');
      expect(UiFontScale.indexFromValue('nonsense'), 1);
    });

    test('slider index round-trips through every value', () {
      for (final value in UiFontScale.values) {
        final index = UiFontScale.indexFromValue(value);
        expect(UiFontScale.valueFromIndex(index), value);
      }
    });

    test('slider index is clamped to the valid range', () {
      expect(UiFontScale.valueFromIndex(-3), UiFontScale.small);
      expect(UiFontScale.valueFromIndex(99), UiFontScale.large);
    });
  });
}
