import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/ui/settings/app_language.dart';

/// The tag endpoints take a `lan` value; the app derives it from the UI
/// language. Traditional Chinese has no server-side table, so it falls back to
/// the English data, matching the web client.
void main() {
  group('tag API language routing', () {
    test('Simplified Chinese requests the zh-CN table', () {
      expect(AppLanguage.tagLanFromValue(AppLanguage.zhHans), 'zh-CN');
    });

    test('Traditional Chinese falls back to the en table', () {
      expect(AppLanguage.tagLanFromValue(AppLanguage.zhHant), 'en');
    });

    test('English requests the en table', () {
      expect(AppLanguage.tagLanFromValue(AppLanguage.en), 'en');
    });

    test('only the two server-supported values are ever produced', () {
      final produced = AppLanguage.values
          .map(AppLanguage.tagLanFromValue)
          .toSet();
      expect(produced, {'zh-CN', 'en'});
    });
  });
}
