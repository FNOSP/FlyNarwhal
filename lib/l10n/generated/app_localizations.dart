import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
  ];

  /// Application name shown in the window title and about pages.
  ///
  /// In zh, this message translates to:
  /// **'飞鲸影视'**
  String get appTitle;

  /// Title of the settings screen.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// Settings section header for account-related rows.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get settingsSectionAccount;

  /// Settings section header for appearance-related rows.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsSectionAppearance;

  /// Settings section header for general rows, including language.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get settingsSectionGeneral;

  /// Heading of the language selector row in the settings screen.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguageTitle;

  /// Caption under the language selector row.
  ///
  /// In zh, this message translates to:
  /// **'选择应用界面的显示语言'**
  String get settingsLanguageCaption;

  /// Settings section header for the server rows.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get settingsSectionServer;

  /// Settings section header for privacy rows.
  ///
  /// In zh, this message translates to:
  /// **'隐私与安全'**
  String get settingsSectionPrivacy;

  /// Settings section header for the about rows.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsSectionAbout;

  /// Account row heading shown before user info loads.
  ///
  /// In zh, this message translates to:
  /// **'未加载用户信息'**
  String get settingsAccountUnloaded;

  /// Caption for the unloaded account row.
  ///
  /// In zh, this message translates to:
  /// **'登录后将在首页自动完成用户信息校验'**
  String get settingsAccountUnloadedCaption;

  /// Badge shown next to an administrator's name.
  ///
  /// In zh, this message translates to:
  /// **'管理员'**
  String get settingsAccountAdminBadge;

  /// Row heading for signing out.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get settingsAccountSignOut;

  /// Caption for the sign-out row.
  ///
  /// In zh, this message translates to:
  /// **'退出当前账号'**
  String get settingsAccountSignOutCaption;

  /// Confirmation shown before signing out.
  ///
  /// In zh, this message translates to:
  /// **'确认退出当前帐号？'**
  String get settingsAccountSignOutConfirm;

  /// Row heading for the theme mode setting.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get settingsAppearanceThemeMode;

  /// Caption for the theme mode row.
  ///
  /// In zh, this message translates to:
  /// **'是否跟随系统主题'**
  String get settingsAppearanceThemeModeCaption;

  /// Theme switch label when following the system theme.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsAppearanceFollowSystem;

  /// Theme switch label when the theme is set manually.
  ///
  /// In zh, this message translates to:
  /// **'手动设置'**
  String get settingsAppearanceManual;

  /// Row heading for the light/dark toggle.
  ///
  /// In zh, this message translates to:
  /// **'颜色'**
  String get settingsAppearanceColor;

  /// Caption for the theme color row.
  ///
  /// In zh, this message translates to:
  /// **'请选择主题颜色'**
  String get settingsAppearanceColorCaption;

  /// Dark mode label.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get settingsAppearanceDark;

  /// Light mode label.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get settingsAppearanceLight;

  /// Row heading for the navigation pane style.
  ///
  /// In zh, this message translates to:
  /// **'导航栏样式'**
  String get settingsAppearanceNavStyle;

  /// Caption for the navigation style row.
  ///
  /// In zh, this message translates to:
  /// **'请选择导航视图布局'**
  String get settingsAppearanceNavStyleCaption;

  /// Row heading for the UI font size.
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get settingsGeneralFontSize;

  /// Caption for the font size row.
  ///
  /// In zh, this message translates to:
  /// **'调整应用整体文字大小'**
  String get settingsGeneralFontSizeCaption;

  /// Row heading for shortcut settings.
  ///
  /// In zh, this message translates to:
  /// **'快捷键设置'**
  String get settingsGeneralShortcuts;

  /// Caption for the shortcut settings row.
  ///
  /// In zh, this message translates to:
  /// **'自定义快捷键'**
  String get settingsGeneralShortcutsCaption;

  /// Button that opens the shortcut dialog.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get settingsGeneralCustomize;

  /// Toggle that enables the FlyNarwhal server features.
  ///
  /// In zh, this message translates to:
  /// **'启用飞鲸服务端'**
  String get settingsServerEnable;

  /// Caption for the server enable toggle.
  ///
  /// In zh, this message translates to:
  /// **'启用后可连接飞鲸服务端实现智能识别片头/片尾、弹幕等功能支持'**
  String get settingsServerEnableCaption;

  /// Row heading for the server base URL.
  ///
  /// In zh, this message translates to:
  /// **'飞鲸服务端地址'**
  String get settingsServerAddress;

  /// Validation message for the server address.
  ///
  /// In zh, this message translates to:
  /// **'必须使用 HTTPS 地址'**
  String get settingsServerAddressHttpsRequired;

  /// Validation message for an incomplete server URL.
  ///
  /// In zh, this message translates to:
  /// **'请填写完整的服务端 URL'**
  String get settingsServerAddressIncomplete;

  /// Row heading for the server auth code.
  ///
  /// In zh, this message translates to:
  /// **'授权码'**
  String get settingsServerAuthCode;

  /// Placeholder for the auth code field.
  ///
  /// In zh, this message translates to:
  /// **'填写授权码'**
  String get settingsServerAuthCodePlaceholder;

  /// Caption shown once an auth code is stored.
  ///
  /// In zh, this message translates to:
  /// **'已填写飞鲸服务端授权码'**
  String get settingsServerAuthCodeFilled;

  /// Heading for the auth code prompt.
  ///
  /// In zh, this message translates to:
  /// **'填写飞鲸服务端授权码'**
  String get settingsServerAuthCodePrompt;

  /// Label above the auth code input.
  ///
  /// In zh, this message translates to:
  /// **'请输入飞鲸服务端授权码：'**
  String get settingsServerAuthCodeLabel;

  /// Hint under the auth code input.
  ///
  /// In zh, this message translates to:
  /// **'请在飞鲸服务端页面点击“获取授权码”后粘贴到此处。'**
  String get settingsServerAuthCodeHint;

  /// Long help text explaining how to obtain the auth code.
  ///
  /// In zh, this message translates to:
  /// **'请在浏览器中访问部署在 NAS 中的飞鲸服务端地址（应用中心版请点击飞牛 OS 桌面中的「飞鲸影视」），点击右上角的「获取授权码」按钮，复制授权码后粘贴到填写授权码的文本框中。\\n需要服务端版本 >= 0.6.0，低于 0.6.0 版的服务端不支持自动更新到 0.6.0 或以上版本，请手动更新到 0.6.0 或以上版本'**
  String get settingsServerAuthCodeHelp;

  /// Button that tests the server connection.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get settingsServerTest;

  /// Label while the connection test runs.
  ///
  /// In zh, this message translates to:
  /// **'测试中'**
  String get settingsServerTesting;

  /// Success message after a connection test.
  ///
  /// In zh, this message translates to:
  /// **'飞鲸服务端连接成功，当前服务端版本号：{version}'**
  String settingsServerTestSuccess(String version);

  /// Failure message after a connection test.
  ///
  /// In zh, this message translates to:
  /// **'飞鲸服务端连接失败：{error}'**
  String settingsServerTestConnectFailed(String error);

  /// Message when the server cannot be reached.
  ///
  /// In zh, this message translates to:
  /// **'飞鲸服务端无法访问'**
  String get settingsServerUnreachable;

  /// Row heading for the trusted certificate list.
  ///
  /// In zh, this message translates to:
  /// **'SSL 证书信任列表'**
  String get settingsPrivacySslTitle;

  /// Caption for the SSL trust list row.
  ///
  /// In zh, this message translates to:
  /// **'服务器证书校验失败时可加入信任，在此管理'**
  String get settingsPrivacySslCaption;

  /// Shows how many certificates are trusted.
  ///
  /// In zh, this message translates to:
  /// **'已信任 {count} 张证书'**
  String settingsPrivacySslTrustedCount(String count);

  /// Button that opens the certificate management dialog.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get settingsPrivacyManage;

  /// Row heading for the privacy statement.
  ///
  /// In zh, this message translates to:
  /// **'隐私声明'**
  String get settingsPrivacyStatement;

  /// Body text of the privacy statement dialog.
  ///
  /// In zh, this message translates to:
  /// **'为了改进软件性能，我们会收集部分硬件信息（如 CPU、GPU 型号等）作为参考依据。这些信息将仅用于优化软件，不会涉及个人隐私。'**
  String get settingsPrivacyStatementBody;

  /// Row heading for the GitHub asset proxy.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 资源代理'**
  String get settingsPrivacyGitHubProxy;

  /// Caption for the GitHub proxy row.
  ///
  /// In zh, this message translates to:
  /// **'仅用于安装包下载，默认关闭'**
  String get settingsPrivacyGitHubProxyCaption;

  /// Label for the proxy address field.
  ///
  /// In zh, this message translates to:
  /// **'代理地址'**
  String get settingsPrivacyProxyAddress;

  /// Row heading showing the current app version.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get settingsAboutVersion;

  /// Row heading for checking updates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get settingsAboutCheckUpdate;

  /// Row heading for the changelog.
  ///
  /// In zh, this message translates to:
  /// **'更新日志'**
  String get settingsAboutChangelog;

  /// Caption for the changelog row.
  ///
  /// In zh, this message translates to:
  /// **'查看各版本的更新内容'**
  String get settingsAboutChangelogCaption;

  /// Toggle for opting into pre-release builds.
  ///
  /// In zh, this message translates to:
  /// **'接收预发布版本更新'**
  String get settingsAboutPrerelease;

  /// Label next to the pre-release toggle.
  ///
  /// In zh, this message translates to:
  /// **'抢先体验'**
  String get settingsAboutPrereleaseEarly;

  /// Toggle for automatic update downloads.
  ///
  /// In zh, this message translates to:
  /// **'自动下载更新'**
  String get settingsAboutAutoDownload;

  /// Caption for the automatic download toggle.
  ///
  /// In zh, this message translates to:
  /// **'发现更新后在后台下载并校验安装包'**
  String get settingsAboutAutoDownloadCaption;

  /// Toggle label for enabled.
  ///
  /// In zh, this message translates to:
  /// **'开启'**
  String get settingsAboutOpen;

  /// Toggle label for disabled.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get settingsAboutClose;

  /// Row heading for exporting error logs.
  ///
  /// In zh, this message translates to:
  /// **'导出报错日志'**
  String get settingsAboutExportLogs;

  /// Caption for the export logs row.
  ///
  /// In zh, this message translates to:
  /// **'支持导出近三天的报错日志，方便开发者排查问题'**
  String get settingsAboutExportLogsCaption;

  /// Button that exports the logs.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get settingsAboutExport;

  /// Title shown when exporting logs fails.
  ///
  /// In zh, this message translates to:
  /// **'导出错误'**
  String get settingsAboutExportError;

  /// Shown while the version is loading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取版本信息…'**
  String get settingsAboutVersionLoading;

  /// Shown when the version cannot be resolved.
  ///
  /// In zh, this message translates to:
  /// **'无法读取版本信息'**
  String get settingsAboutVersionUnavailable;

  /// Generic loading label.
  ///
  /// In zh, this message translates to:
  /// **'加载中'**
  String get commonLoading;

  /// Generic confirm button.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get commonConfirm;

  /// Generic cancel button.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// Button that dismisses an informational dialog.
  ///
  /// In zh, this message translates to:
  /// **'我知道了'**
  String get commonGotIt;

  /// Error message when user info cannot be loaded.
  ///
  /// In zh, this message translates to:
  /// **'加载用户信息失败'**
  String get commonUserInfoLoadFailed;

  /// Shown while user info is loading.
  ///
  /// In zh, this message translates to:
  /// **'正在加载用户信息…'**
  String get commonUserInfoLoading;

  /// Title of the shortcut settings dialog.
  ///
  /// In zh, this message translates to:
  /// **'快捷键设置'**
  String get shortcutsTitle;

  /// Tab label for keyboard shortcuts.
  ///
  /// In zh, this message translates to:
  /// **'快捷键'**
  String get shortcutsTabKeyboard;

  /// Tab label for playback shortcuts.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get shortcutsTabPlayback;

  /// Tab label for shortcut help.
  ///
  /// In zh, this message translates to:
  /// **'说明'**
  String get shortcutsTabHelp;

  /// Button that restores default shortcuts.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get shortcutsRestoreDefaults;

  /// Placeholder of the shortcut search box.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get shortcutsSearch;

  /// Prompt shown while recording a shortcut.
  ///
  /// In zh, this message translates to:
  /// **'请在键盘按下快捷键或组合'**
  String get shortcutsPrompt;

  /// Title of the certificate trust dialog.
  ///
  /// In zh, this message translates to:
  /// **'SSL 证书信任列表'**
  String get sslTrustedTitle;

  /// Empty state of the certificate trust list.
  ///
  /// In zh, this message translates to:
  /// **'暂无信任的证书。当服务器证书校验失败时，可以在提示中选择「信任此证书」。'**
  String get sslTrustedEmpty;

  /// Shows when a certificate was trusted.
  ///
  /// In zh, this message translates to:
  /// **'添加时间：{time}'**
  String sslTrustedAddedAt(String time);

  /// Button that removes a trusted certificate.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get sslTrustedRemove;

  /// Button that clears every trusted certificate.
  ///
  /// In zh, this message translates to:
  /// **'全部清除'**
  String get sslTrustedRemoveAll;

  /// Title of the remove-certificate confirmation.
  ///
  /// In zh, this message translates to:
  /// **'移除信任的证书'**
  String get sslTrustedRemoveTitle;

  /// Body of the remove-certificate confirmation.
  ///
  /// In zh, this message translates to:
  /// **'移除后，再次访问「{host}」时该证书会重新校验。'**
  String sslTrustedRemoveBody(String host);

  /// Title of the clear-all confirmation.
  ///
  /// In zh, this message translates to:
  /// **'清除全部信任的证书'**
  String get sslTrustedClearTitle;

  /// Body of the clear-all confirmation.
  ///
  /// In zh, this message translates to:
  /// **'清除后，所有服务器的证书都会重新校验。'**
  String get sslTrustedClearBody;

  /// Title of the support-the-author dialog.
  ///
  /// In zh, this message translates to:
  /// **'支持作者'**
  String get supportAuthorTitle;

  /// Body of the support-the-author dialog.
  ///
  /// In zh, this message translates to:
  /// **'您的支持就是我持续更新的动力，如果觉得好用的话，请给项目点一个 Star ⭐，谢谢！(^_−)☆'**
  String get supportAuthorBody;

  /// Body text inviting bug reports.
  ///
  /// In zh, this message translates to:
  /// **'项目诚然还有很多地方需要完善，如果遇到软件问题或者 Bug 欢迎提交 Issue 或者 PR。'**
  String get supportAuthorIssues;

  /// Button that opens the GitHub repository.
  ///
  /// In zh, this message translates to:
  /// **'打开 Github 仓库'**
  String get supportAuthorOpenRepo;

  /// Button that dismisses the dialog.
  ///
  /// In zh, this message translates to:
  /// **'稍后再说'**
  String get supportAuthorLater;

  /// Font size option: small.
  ///
  /// In zh, this message translates to:
  /// **'小'**
  String get fontScaleSmall;

  /// Font size option: medium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get fontScaleMedium;

  /// Font size option: large.
  ///
  /// In zh, this message translates to:
  /// **'大'**
  String get fontScaleLarge;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
