// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '飞鲸影视';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionAccount => '账号';

  @override
  String get settingsSectionAppearance => '外观';

  @override
  String get settingsSectionGeneral => '通用';

  @override
  String get settingsLanguageTitle => '语言';

  @override
  String get settingsLanguageCaption => '选择应用界面的显示语言';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => '飛鯨影視';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSectionAccount => '帳號';

  @override
  String get settingsSectionAppearance => '外觀';

  @override
  String get settingsSectionGeneral => '一般';

  @override
  String get settingsLanguageTitle => '語言';

  @override
  String get settingsLanguageCaption => '選擇應用介面的顯示語言';
}
