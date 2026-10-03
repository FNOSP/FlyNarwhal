import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/l10n/generated/app_localizations.dart';
import 'package:fly_narwhal/ui/settings/app_language.dart';

/// Loads [AppLocalizations] for a persisted language value the way the app does.
Future<AppLocalizations> _localizationsFor(String language) async {
  final locale = AppLanguage.localeFromValue(language);
  final loaded = await AppLocalizations.delegate.load(locale);
  return loaded;
}

void main() {
  group('AppLocalizations resolution', () {
    test('Simplified Chinese resolves to the zh messages', () async {
      final l10n = await _localizationsFor(AppLanguage.zhHans);
      expect(l10n.settingsTitle, '设置');
      expect(l10n.settingsSectionGeneral, '通用');
      expect(l10n.settingsLanguageTitle, '语言');
    });

    test('Traditional Chinese resolves to the zh_Hant messages', () async {
      final l10n = await _localizationsFor(AppLanguage.zhHant);
      expect(l10n.settingsTitle, '設定');
      expect(l10n.settingsSectionGeneral, '一般');
      expect(l10n.settingsLanguageTitle, '語言');
    });

    test('English resolves to the en messages', () async {
      final l10n = await _localizationsFor(AppLanguage.en);
      expect(l10n.settingsTitle, 'Settings');
      expect(l10n.settingsSectionGeneral, 'General');
      expect(l10n.settingsLanguageTitle, 'Language');
    });

    test('the delegate accepts every supported locale', () {
      for (final value in AppLanguage.values) {
        expect(
          AppLocalizations.delegate.isSupported(
            AppLanguage.localeFromValue(value),
          ),
          isTrue,
          reason: '$value should be a supported locale',
        );
      }
    });

    test('Traditional Chinese is not collapsed into Simplified', () async {
      final simplified = await _localizationsFor(AppLanguage.zhHans);
      final traditional = await _localizationsFor(AppLanguage.zhHant);
      expect(traditional.appTitle, isNot(simplified.appTitle));
      expect(traditional.localeName, isNot(simplified.localeName));
    });
  });
}
