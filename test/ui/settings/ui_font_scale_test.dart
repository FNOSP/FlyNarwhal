import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/l10n/generated/app_localizations.dart';
import 'package:fly_narwhal/ui/settings/app_language.dart';
import 'package:fly_narwhal/ui/settings/ui_font_scale.dart';

Future<AppLocalizations> _l10n(String language) =>
    AppLocalizations.delegate.load(AppLanguage.localeFromValue(language));

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

    test('unknown values fall back to medium', () async {
      expect(UiFontScale.factorFromValue('nonsense'), 1.0);
      expect(UiFontScale.indexFromValue('nonsense'), 1);
      final l10n = await _l10n(AppLanguage.zhHans);
      expect(UiFontScale.labelFromValue('nonsense', l10n), '中');
    });

    test('labels follow the active locale', () async {
      final zh = await _l10n(AppLanguage.zhHans);
      final en = await _l10n(AppLanguage.en);
      expect(UiFontScale.labelFromValue(UiFontScale.small, zh), '小');
      expect(UiFontScale.labelFromValue(UiFontScale.large, zh), '大');
      expect(UiFontScale.labelFromValue(UiFontScale.small, en), 'Small');
      expect(UiFontScale.labelFromValue(UiFontScale.large, en), 'Large');
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
