import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fly_narwhal/data/storage/preferences_manager.dart';
import 'package:fly_narwhal/ui/settings/app_language.dart';

void main() {
  group('PreferencesManager.systemLanguageFromLocale', () {
    String map(String language, {String? script, String? country}) {
      return PreferencesManager.systemLanguageFromLocale(
        Locale.fromSubtags(
          languageCode: language,
          scriptCode: script,
          countryCode: country,
        ),
      );
    }

    test('non-Chinese systems map to English', () {
      expect(map('en'), AppLanguage.en);
      expect(map('ja'), AppLanguage.en);
      expect(map('de', country: 'DE'), AppLanguage.en);
    });

    test('Traditional script or TW/HK/MO regions map to Traditional Chinese', () {
      expect(map('zh', script: 'Hant'), AppLanguage.zhHant);
      expect(map('zh', country: 'TW'), AppLanguage.zhHant);
      expect(map('zh', country: 'HK'), AppLanguage.zhHant);
      expect(map('zh', country: 'MO'), AppLanguage.zhHant);
    });

    test('other Chinese systems map to Simplified Chinese', () {
      expect(map('zh'), AppLanguage.zhHans);
      expect(map('zh', script: 'Hans'), AppLanguage.zhHans);
      expect(map('zh', country: 'CN'), AppLanguage.zhHans);
      expect(map('zh', country: 'SG'), AppLanguage.zhHans);
    });
  });

  group('PreferencesManager.getLanguage', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<PreferencesManager> managerWith(String fallback) async {
      final prefs = await SharedPreferences.getInstance();
      return PreferencesManager(prefs, languageFallback: () => fallback);
    }

    test('derives from the fallback when nothing is stored', () async {
      final manager = await managerWith(AppLanguage.zhHant);
      expect(manager.getLanguage(), AppLanguage.zhHant);
      expect(manager.hasStoredLanguage(), isFalse);
    });

    test('an explicitly stored value wins over the fallback', () async {
      SharedPreferences.setMockInitialValues({'language': AppLanguage.en});
      final manager = await managerWith(AppLanguage.zhHant);
      expect(manager.getLanguage(), AppLanguage.en);
      expect(manager.hasStoredLanguage(), isTrue);
    });

    test('falls back to Simplified Chinese only when the system is Simplified',
        () async {
      final manager = await managerWith(AppLanguage.zhHans);
      expect(manager.getLanguage(), AppLanguage.zhHans);
    });

    test('user-scoped value wins over the global one', () async {
      SharedPreferences.setMockInitialValues({
        'language': AppLanguage.en,
        'user-1::language': AppLanguage.zhHant,
      });
      final manager = await managerWith(AppLanguage.zhHans);
      expect(manager.getLanguage(userGuid: 'user-1'), AppLanguage.zhHant);
      expect(manager.getLanguage(), AppLanguage.en);
    });

    test('a scoped user with no stored language derives from the fallback',
        () async {
      SharedPreferences.setMockInitialValues({'language': AppLanguage.en});
      final manager = await managerWith(AppLanguage.zhHant);
      expect(manager.getLanguage(userGuid: 'user-1'), AppLanguage.zhHant);
      expect(manager.hasStoredLanguage(userGuid: 'user-1'), isFalse);
    });
  });
}
