import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/l10n/generated/app_localizations.dart';
import 'package:fly_narwhal/ui/settings/app_language.dart';

/// Guards the smart-skip strings added by the intro-skipper merge: they must
/// resolve in every supported language, and the segment-name connector must
/// differ between Chinese and English.
Future<AppLocalizations> _l10n(String language) =>
    AppLocalizations.delegate.load(AppLanguage.localeFromValue(language));

void main() {
  group('smart skip localization', () {
    test('the config dialog title resolves in all three languages', () async {
      expect((await _l10n(AppLanguage.zhHans)).smartSkipConfigTitle, '智能跳过配置');
      expect((await _l10n(AppLanguage.zhHant)).smartSkipConfigTitle, '智慧跳過設定');
      expect((await _l10n(AppLanguage.en)).smartSkipConfigTitle,
          'Smart skip settings');
    });

    test('segment kinds resolve per language', () async {
      final en = await _l10n(AppLanguage.en);
      expect(en.playerSkipSegmentIntro, 'intro');
      expect(en.playerSkipSegmentOutro, 'outro');
      expect(en.playerSkipSegmentCommercial, 'advertisement');
    });

    test('the countdown message keeps both placeholders', () async {
      final en = await _l10n(AppLanguage.en);
      final zh = await _l10n(AppLanguage.zhHans);
      expect(en.playerSkipSegmentInSeconds('5', en.playerSkipSegmentOutro),
          'Skipping outro in 5s');
      expect(zh.playerSkipSegmentInSeconds('5', zh.playerSkipSegmentOutro),
          '5 秒后跳过片尾');
    });

    test('the segment connector differs between Chinese and English', () async {
      final zh = await _l10n(AppLanguage.zhHans);
      final en = await _l10n(AppLanguage.en);
      expect(zh.playerSkipSegmentConnector, isNot(en.playerSkipSegmentConnector));
    });

    test('the auto-skipped toast takes the segment name', () async {
      final en = await _l10n(AppLanguage.en);
      expect(en.playerSkipAutoSkipped(en.playerSkipSegmentRecap),
          'Automatically skipped recap');
    });
  });
}
