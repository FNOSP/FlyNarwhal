import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/ui/settings/app_language.dart';

void main() {
  group('AppLanguage', () {
    test('defaults to Simplified Chinese for unknown values', () {
      expect(AppLanguage.normalize('nonsense'), AppLanguage.zhHans);
      expect(AppLanguage.normalize(null), AppLanguage.zhHans);
      expect(AppLanguage.normalize(''), AppLanguage.zhHans);
      expect(AppLanguage.labelFromValue('nonsense'), '简体中文');
    });

    test('every value round-trips through normalize', () {
      for (final value in AppLanguage.values) {
        expect(AppLanguage.normalize(value), value);
      }
    });

    test('maps to the locale Flutter needs for each variant', () {
      expect(AppLanguage.localeFromValue(AppLanguage.zhHans).languageCode, 'zh');
      expect(AppLanguage.localeFromValue(AppLanguage.zhHans).scriptCode, isNull);

      final hant = AppLanguage.localeFromValue(AppLanguage.zhHant);
      expect(hant.languageCode, 'zh');
      expect(hant.scriptCode, 'Hant');

      expect(AppLanguage.localeFromValue(AppLanguage.en).languageCode, 'en');
    });

    test('Simplified Chinese requests the zh-CN tag table', () {
      expect(AppLanguage.tagLanFromValue(AppLanguage.zhHans), 'zh-CN');
    });

    test('Traditional Chinese and English both use the en tag table', () {
      // The server exposes only zh-CN and en tag data; lan=zh-TW still returns
      // Simplified Chinese, so Traditional Chinese must request English.
      expect(AppLanguage.tagLanFromValue(AppLanguage.zhHant), 'en');
      expect(AppLanguage.tagLanFromValue(AppLanguage.en), 'en');
    });

    test('unknown values fall back to the zh-CN tag table', () {
      expect(AppLanguage.tagLanFromValue('nonsense'), 'zh-CN');
    });

    test('labels are native names and never localized', () {
      expect(AppLanguage.labelFromValue(AppLanguage.zhHans), '简体中文');
      expect(AppLanguage.labelFromValue(AppLanguage.zhHant), '繁體中文');
      expect(AppLanguage.labelFromValue(AppLanguage.en), 'English');
    });
  });
}
