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

  /// Row heading for the playback details panel animation style.
  ///
  /// In zh, this message translates to:
  /// **'播放详细信息面板启用液态玻璃效果'**
  String get settingsAppearanceDetailsLiquidGlass;

  /// Caption for the playback details panel animation style row.
  ///
  /// In zh, this message translates to:
  /// **'开启后播放详细信息面板使用带动画的液态玻璃样式，关闭则使用静态毛玻璃样式'**
  String get settingsAppearanceDetailsLiquidGlassCaption;

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
  /// **'仅用于安装包下载'**
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

  /// Label of the filter toggle button.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get filterTitle;

  /// Chip that clears every selected filter.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get filterReset;

  /// Link that collapses the filter panel.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get filterCollapse;

  /// Generic 'all' option in a filter row.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get filterOptionAll;

  /// Media type option: movie.
  ///
  /// In zh, this message translates to:
  /// **'电影'**
  String get filterOptionMovie;

  /// Media type option: TV series.
  ///
  /// In zh, this message translates to:
  /// **'电视剧'**
  String get filterOptionTv;

  /// Watched-state option.
  ///
  /// In zh, this message translates to:
  /// **'已观看'**
  String get filterOptionWatched;

  /// Watched-state option.
  ///
  /// In zh, this message translates to:
  /// **'未观看'**
  String get filterOptionUnwatched;

  /// Recognition-status option.
  ///
  /// In zh, this message translates to:
  /// **'已匹配'**
  String get filterOptionMatched;

  /// Recognition-status option.
  ///
  /// In zh, this message translates to:
  /// **'未匹配'**
  String get filterOptionUnmatched;

  /// Recognition-status option.
  ///
  /// In zh, this message translates to:
  /// **'NFO匹配'**
  String get filterOptionNfoMatched;

  /// Catch-all option.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get filterOptionOthers;

  /// Decade option for recent releases.
  ///
  /// In zh, this message translates to:
  /// **'今年'**
  String get filterOptionThisYear;

  /// Decade option, e.g. 1990s.
  ///
  /// In zh, this message translates to:
  /// **'{decade}年代'**
  String filterOptionDecade(String decade);

  /// Dynamic-range option.
  ///
  /// In zh, this message translates to:
  /// **'杜比视界'**
  String get filterOptionDolbyVision;

  /// Audio option.
  ///
  /// In zh, this message translates to:
  /// **'杜比环绕'**
  String get filterOptionDolbySurround;

  /// Audio option.
  ///
  /// In zh, this message translates to:
  /// **'杜比全景声'**
  String get filterOptionDolbyAtmos;

  /// Audio option.
  ///
  /// In zh, this message translates to:
  /// **'立体声'**
  String get filterOptionStereo;

  /// Filter row label.
  ///
  /// In zh, this message translates to:
  /// **'影视类型'**
  String get filterRowMediaType;

  /// Filter row label.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get filterRowGenre;

  /// Filter row label.
  ///
  /// In zh, this message translates to:
  /// **'分辨率'**
  String get filterRowResolution;

  /// Filter row label.
  ///
  /// In zh, this message translates to:
  /// **'视频动态范围'**
  String get filterRowColorRange;

  /// Filter row label.
  ///
  /// In zh, this message translates to:
  /// **'音频规格'**
  String get filterRowAudioType;

  /// Filter row label.
  ///
  /// In zh, this message translates to:
  /// **'国家和地区'**
  String get filterRowLocation;

  /// Filter row label.
  ///
  /// In zh, this message translates to:
  /// **'发行年份'**
  String get filterRowDecade;

  /// Filter row label.
  ///
  /// In zh, this message translates to:
  /// **'匹配状态'**
  String get filterRowRecognitionStatus;

  /// Filter row label.
  ///
  /// In zh, this message translates to:
  /// **'是否已观看'**
  String get filterRowWatched;

  /// Title of the file media info dialog.
  ///
  /// In zh, this message translates to:
  /// **'文件媒体信息'**
  String get mediaInfoTitle;

  /// Shown when there is no media information.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get mediaInfoEmpty;

  /// Section heading for video streams.
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get mediaInfoSectionVideo;

  /// Section heading for audio streams.
  ///
  /// In zh, this message translates to:
  /// **'音频'**
  String get mediaInfoSectionAudio;

  /// Section heading for subtitle streams.
  ///
  /// In zh, this message translates to:
  /// **'字幕'**
  String get mediaInfoSectionSubtitle;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'分辨率'**
  String get mediaInfoFieldResolution;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'视频动态范围'**
  String get mediaInfoFieldDynamicRange;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'编码器'**
  String get mediaInfoFieldCodec;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get mediaInfoFieldProfile;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'等级'**
  String get mediaInfoFieldLevel;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'帧率'**
  String get mediaInfoFieldFrameRate;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'码率'**
  String get mediaInfoFieldBitRate;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'宽高比'**
  String get mediaInfoFieldAspectRatio;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'像素格式'**
  String get mediaInfoFieldPixelFormat;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'位深度'**
  String get mediaInfoFieldBitDepth;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'色彩空间'**
  String get mediaInfoFieldColorSpace;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'色彩原色'**
  String get mediaInfoFieldColorPrimaries;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'色彩转换'**
  String get mediaInfoFieldColorTransfer;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'参考帧'**
  String get mediaInfoFieldReferenceFrames;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'隔行扫描'**
  String get mediaInfoFieldInterlaced;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'布局'**
  String get mediaInfoFieldLayout;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'声道'**
  String get mediaInfoFieldChannels;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'采样率'**
  String get mediaInfoFieldSampleRate;

  /// Media info field.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get mediaInfoFieldLanguage;

  /// Media info field flag.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get mediaInfoFieldDefault;

  /// Media info field flag.
  ///
  /// In zh, this message translates to:
  /// **'强制'**
  String get mediaInfoFieldForced;

  /// Media info field flag.
  ///
  /// In zh, this message translates to:
  /// **'外部'**
  String get mediaInfoFieldExternal;

  /// Boolean media info value.
  ///
  /// In zh, this message translates to:
  /// **'是'**
  String get mediaInfoYes;

  /// Boolean media info value.
  ///
  /// In zh, this message translates to:
  /// **'否'**
  String get mediaInfoNo;

  /// File-picker dialog title for choosing subtitle files.
  ///
  /// In zh, this message translates to:
  /// **'字幕文件'**
  String get subtitleUploadFileTypeName;

  /// Button that opens the file picker.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get subtitleUploadSelect;

  /// Toast after subtitles were added.
  ///
  /// In zh, this message translates to:
  /// **'添加字幕成功'**
  String get subtitleUploadAdded;

  /// Toast when adding subtitles fails.
  ///
  /// In zh, this message translates to:
  /// **'添加字幕失败，请重试'**
  String get subtitleUploadFailed;

  /// Toast when only some subtitles were added.
  ///
  /// In zh, this message translates to:
  /// **'部分字幕添加成功，其中 {count} 个失败'**
  String subtitleUploadPartial(String count);

  /// Toast when too many files are chosen.
  ///
  /// In zh, this message translates to:
  /// **'最多选择 {count} 个文件'**
  String subtitleUploadTooMany(String count);

  /// Error when the file picker state cannot be restored.
  ///
  /// In zh, this message translates to:
  /// **'当前用户信息缺失，无法恢复文件选择器状态'**
  String get subtitleUploadMissingUser;

  /// Error when the file picker fails.
  ///
  /// In zh, this message translates to:
  /// **'选择字幕文件失败: {error}'**
  String subtitleUploadPickerFailed(String error);

  /// Description of the accepted subtitle formats.
  ///
  /// In zh, this message translates to:
  /// **'{formats} 格式的文件'**
  String subtitleUploadFormatSuffix(String formats);

  /// Window caption back button tooltip.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get captionBack;

  /// Window caption refresh button tooltip.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get captionRefresh;

  /// Window caption button tooltip.
  ///
  /// In zh, this message translates to:
  /// **'切换导航栏'**
  String get captionToggleNav;

  /// Window caption pin button tooltip.
  ///
  /// In zh, this message translates to:
  /// **'窗口置顶'**
  String get captionAlwaysOnTop;

  /// Window caption unpin button tooltip.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get captionUnpin;

  /// Toast title for informational messages.
  ///
  /// In zh, this message translates to:
  /// **'信息'**
  String get toastInfo;

  /// Toast title for successes.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get toastSuccess;

  /// Toast title for warnings.
  ///
  /// In zh, this message translates to:
  /// **'警告'**
  String get toastWarning;

  /// Toast title for errors.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get toastError;

  /// Validation toast.
  ///
  /// In zh, this message translates to:
  /// **'请填写飞鲸服务端 URL'**
  String get toastServerUrlRequired;

  /// Validation toast.
  ///
  /// In zh, this message translates to:
  /// **'请填写飞鲸服务端授权码'**
  String get toastServerAuthCodeRequired;

  /// Validation toast.
  ///
  /// In zh, this message translates to:
  /// **'请填写飞鲸服务端 URL 和授权码'**
  String get toastServerCredentialsRequired;

  /// Title of the certificate trust prompt.
  ///
  /// In zh, this message translates to:
  /// **'证书校验失败'**
  String get sslPromptTitle;

  /// Body of the certificate trust prompt.
  ///
  /// In zh, this message translates to:
  /// **'「{host}」的证书校验不通过，可能是证书过期、域名不匹配或自签名证书。'**
  String sslPromptBody(String host);

  /// Fingerprint line in the certificate prompt.
  ///
  /// In zh, this message translates to:
  /// **'证书指纹 SHA-256：{fingerprint}'**
  String sslPromptFingerprint(String fingerprint);

  /// Question shown in the certificate prompt.
  ///
  /// In zh, this message translates to:
  /// **'继续访问将绕过安全保护，是否继续访问？'**
  String get sslPromptQuestion;

  /// Button that trusts the certificate permanently.
  ///
  /// In zh, this message translates to:
  /// **'信任此证书'**
  String get sslPromptTrustPersistent;

  /// Button that trusts the certificate for this session only.
  ///
  /// In zh, this message translates to:
  /// **'仅本次信任'**
  String get sslPromptTrustOnce;

  /// Button that cancels the connection.
  ///
  /// In zh, this message translates to:
  /// **'取消访问'**
  String get sslPromptCancel;

  /// Heading of the layout chooser.
  ///
  /// In zh, this message translates to:
  /// **'布局'**
  String get layoutTitle;

  /// Layout option.
  ///
  /// In zh, this message translates to:
  /// **'海报墙'**
  String get layoutPosterWall;

  /// Layout option.
  ///
  /// In zh, this message translates to:
  /// **'竖幅海报'**
  String get layoutVerticalPoster;

  /// Layout option.
  ///
  /// In zh, this message translates to:
  /// **'横幅海报'**
  String get layoutBannerPoster;

  /// Layout option.
  ///
  /// In zh, this message translates to:
  /// **'列表'**
  String get layoutList;

  /// Heading of the cast row.
  ///
  /// In zh, this message translates to:
  /// **'演职人员'**
  String get castTitle;

  /// Cast role label.
  ///
  /// In zh, this message translates to:
  /// **'导演'**
  String get castRoleDirector;

  /// Cast role label.
  ///
  /// In zh, this message translates to:
  /// **'演员'**
  String get castRoleActor;

  /// Cast role label.
  ///
  /// In zh, this message translates to:
  /// **'编剧'**
  String get castRoleWriter;

  /// Cast role label.
  ///
  /// In zh, this message translates to:
  /// **'制片人'**
  String get castRoleProducer;

  /// Shows the character an actor plays.
  ///
  /// In zh, this message translates to:
  /// **'饰 {role}'**
  String castCharacter(String role);

  /// Sort option.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get sortTitle;

  /// Sort option.
  ///
  /// In zh, this message translates to:
  /// **'添加日期'**
  String get sortAddedDate;

  /// Sort option.
  ///
  /// In zh, this message translates to:
  /// **'发行年份'**
  String get sortReleaseYear;

  /// Sort option.
  ///
  /// In zh, this message translates to:
  /// **'评分'**
  String get sortScore;

  /// Sort direction.
  ///
  /// In zh, this message translates to:
  /// **'升序'**
  String get sortAscending;

  /// Sort direction.
  ///
  /// In zh, this message translates to:
  /// **'降序'**
  String get sortDescending;

  /// Label for the storage location picker.
  ///
  /// In zh, this message translates to:
  /// **'视频所在位置'**
  String get nasSubtitleStorageLocation;

  /// Placeholder of the storage picker.
  ///
  /// In zh, this message translates to:
  /// **'请选择存储空间'**
  String get nasSubtitleSelectStorage;

  /// Toast when too many files are chosen.
  ///
  /// In zh, this message translates to:
  /// **'最多选择 {count} 个文件'**
  String nasSubtitleTooMany(String count);

  /// Error view title.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailedTitle;

  /// Fallback error message.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get loadFailedUnknown;

  /// Button that retries loading.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get loadFailedRetry;

  /// Tooltip of the episode view toggle.
  ///
  /// In zh, this message translates to:
  /// **'切换为卡片视图'**
  String get episodeViewCard;

  /// Tooltip of the episode view toggle.
  ///
  /// In zh, this message translates to:
  /// **'切换为序号视图'**
  String get episodeViewButton;

  /// Empty state of the NAS file browser.
  ///
  /// In zh, this message translates to:
  /// **'空空如也'**
  String get nasBrowserEmpty;

  /// Play button label.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get actionPlay;

  /// Play button label when resuming playback.
  ///
  /// In zh, this message translates to:
  /// **'继续播放'**
  String get actionContinuePlay;

  /// Tooltip that adds the item to favorites.
  ///
  /// In zh, this message translates to:
  /// **'加入收藏'**
  String get actionFavoriteAdd;

  /// Tooltip that removes the item from favorites.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get actionFavoriteRemove;

  /// Tooltip or menu item that marks the item watched.
  ///
  /// In zh, this message translates to:
  /// **'标记为已看'**
  String get actionMarkWatched;

  /// Tooltip or menu item that marks the item unwatched.
  ///
  /// In zh, this message translates to:
  /// **'标记为未看'**
  String get actionMarkUnwatched;

  /// Tooltip of the more-actions button.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get actionMore;

  /// Inline link that expands a truncated description.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get actionMore2;

  /// Toast shown after adding to favorites.
  ///
  /// In zh, this message translates to:
  /// **'已收藏'**
  String get toastFavoriteAdded;

  /// Toast shown after removing from favorites.
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏'**
  String get toastFavoriteRemoved;

  /// Toast shown after marking unwatched.
  ///
  /// In zh, this message translates to:
  /// **'标记为未观看'**
  String get toastMarkedUnwatched;

  /// Toast shown after marking watched.
  ///
  /// In zh, this message translates to:
  /// **'标记为已观看'**
  String get toastMarkedWatched;

  /// Generic failure message when an action fails.
  ///
  /// In zh, this message translates to:
  /// **'操作失败'**
  String get toastOperationFailed;

  /// Failure toast that appends the underlying error.
  ///
  /// In zh, this message translates to:
  /// **'操作失败，{message}'**
  String toastOperationFailedReason(String message);

  /// Fallback text when an overview is missing.
  ///
  /// In zh, this message translates to:
  /// **'暂无介绍'**
  String get mediaInfoNoOverview;

  /// Fallback text when media details are empty.
  ///
  /// In zh, this message translates to:
  /// **'暂无信息'**
  String get mediaInfoNoInfo;

  /// Empty state of a stream selector flyout.
  ///
  /// In zh, this message translates to:
  /// **'无内容'**
  String get mediaInfoNoContent;

  /// Heading of the file info section.
  ///
  /// In zh, this message translates to:
  /// **'文件信息'**
  String get mediaInfoFileInfo;

  /// Label of the file location row.
  ///
  /// In zh, this message translates to:
  /// **'文件位置'**
  String get mediaInfoFileLocation;

  /// Label of the file size row.
  ///
  /// In zh, this message translates to:
  /// **'文件大小'**
  String get mediaInfoFileSize;

  /// Label of the file creation date.
  ///
  /// In zh, this message translates to:
  /// **'创建日期'**
  String get mediaInfoCreatedDate;

  /// Label of the date the file was added.
  ///
  /// In zh, this message translates to:
  /// **'添加日期'**
  String get mediaInfoAddedDate;

  /// Heading of the video and audio info section.
  ///
  /// In zh, this message translates to:
  /// **'视频/音频信息'**
  String get mediaInfoStreamSection;

  /// Prefix label before the IMDB link.
  ///
  /// In zh, this message translates to:
  /// **'链接:  '**
  String get linkLabel;

  /// Text of the IMDB link.
  ///
  /// In zh, this message translates to:
  /// **'IMDB链接'**
  String get imdbLinkLabel;

  /// Appends a default marker to a track name.
  ///
  /// In zh, this message translates to:
  /// **'{title} - 默认'**
  String defaultSuffix(String title);

  /// Link that opens the full media info dialog.
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get actionViewAll;

  /// Error shown when the movie cannot be found.
  ///
  /// In zh, this message translates to:
  /// **'未找到电影信息'**
  String get movieDetailNotFound;

  /// Title of the movie overview dialog.
  ///
  /// In zh, this message translates to:
  /// **'电影简介'**
  String get movieDetailDescriptionTitle;

  /// Title of the episode overview dialog.
  ///
  /// In zh, this message translates to:
  /// **'剧集简介'**
  String get movieDetailEpisodeDescriptionTitle;

  /// Title of the add-subtitle dialog.
  ///
  /// In zh, this message translates to:
  /// **'添加字幕'**
  String get movieDetailSubtitleAddTitle;

  /// Toast shown when the file is already a subtitle.
  ///
  /// In zh, this message translates to:
  /// **'该文件已被添加为字幕'**
  String get movieDetailSubtitleAlreadyAdded;

  /// Title of the add-subtitle failure dialog.
  ///
  /// In zh, this message translates to:
  /// **'添加字幕失败'**
  String get movieDetailSubtitleAddFailed;

  /// Add-subtitle failure message.
  ///
  /// In zh, this message translates to:
  /// **'请稍后重试：{error}'**
  String movieDetailSubtitleRetry(String error);

  /// Toast shown when the current file info is missing.
  ///
  /// In zh, this message translates to:
  /// **'当前文件信息缺失，无法搜索字幕'**
  String get movieDetailSubtitleSearchMissingFile;

  /// Toast shown when the current file info is missing.
  ///
  /// In zh, this message translates to:
  /// **'当前文件信息缺失，无法上传字幕'**
  String get movieDetailSubtitleUploadMissingFile;

  /// Toast shown after a subtitle downloads successfully.
  ///
  /// In zh, this message translates to:
  /// **'下载成功'**
  String get movieDetailSubtitleDownloadSuccess;

  /// Toast shown when a subtitle download fails.
  ///
  /// In zh, this message translates to:
  /// **'下载字幕失败: {error}'**
  String movieDetailSubtitleDownloadFailed(String error);

  /// Toast shown after a subtitle download task is created.
  ///
  /// In zh, this message translates to:
  /// **'已创建字幕下载任务'**
  String get movieDetailSubtitleTaskCreated;

  /// Toast shown when creating a subtitle download task fails.
  ///
  /// In zh, this message translates to:
  /// **'创建字幕下载任务失败，请重试'**
  String get movieDetailSubtitleTaskFailed;

  /// Appends an external marker to a subtitle display name.
  ///
  /// In zh, this message translates to:
  /// **' - 外挂'**
  String get movieDetailSubtitleExternalSuffix;

  /// Title of the delete-subtitle dialog.
  ///
  /// In zh, this message translates to:
  /// **'删除外挂字幕'**
  String get movieDetailSubtitleDeleteTitle;

  /// Confirmation body of the delete-subtitle dialog.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除 {name} 外挂字幕吗？'**
  String movieDetailSubtitleDeleteConfirm(String name);

  /// Toast shown after a subtitle is deleted.
  ///
  /// In zh, this message translates to:
  /// **'删除字幕成功'**
  String get movieDetailSubtitleDeleteSuccess;

  /// Toast shown when deleting a subtitle fails.
  ///
  /// In zh, this message translates to:
  /// **'删除字幕失败: {error}'**
  String movieDetailSubtitleDeleteFailed(String error);

  /// Subtitle selector label when subtitles are off.
  ///
  /// In zh, this message translates to:
  /// **'无字幕'**
  String get movieDetailSubtitleNone;

  /// Subtitle selector label that appends a language name.
  ///
  /// In zh, this message translates to:
  /// **'{language}字幕'**
  String movieDetailSubtitleLanguageLabel(String language);

  /// Audio selector label.
  ///
  /// In zh, this message translates to:
  /// **'音频'**
  String get movieDetailAudioLabel;

  /// Audio selector label that appends a language name.
  ///
  /// In zh, this message translates to:
  /// **'{language}音频'**
  String movieDetailAudioLanguageLabel(String language);

  /// Audio type label for stereo.
  ///
  /// In zh, this message translates to:
  /// **'立体声'**
  String get movieDetailAudioStereo;

  /// Remaining playback time under the progress bar.
  ///
  /// In zh, this message translates to:
  /// **'剩余 {time}'**
  String movieDetailRemaining(String time);

  /// Tag showing the smart analysis status.
  ///
  /// In zh, this message translates to:
  /// **'智能片头/片尾检测状态：{status}'**
  String movieDetailSmartAnalysisStatus(String status);

  /// Color range label for Dolby Vision.
  ///
  /// In zh, this message translates to:
  /// **'杜比视界'**
  String get movieDetailDolbyVision;

  /// Default label of the subtitle selector.
  ///
  /// In zh, this message translates to:
  /// **'字幕'**
  String get movieDetailSubtitleLabel;

  /// Error shown when the TV series cannot be found.
  ///
  /// In zh, this message translates to:
  /// **'未找到剧集信息'**
  String get tvDetailNotFound;

  /// Error shown when the season cannot be found.
  ///
  /// In zh, this message translates to:
  /// **'未找到分季信息'**
  String get tvDetailSeasonNotFound;

  /// Title of the series overview dialog.
  ///
  /// In zh, this message translates to:
  /// **'剧集简介'**
  String get tvDetailDescriptionTitle;

  /// Menu item that triggers smart intro/outro analysis.
  ///
  /// In zh, this message translates to:
  /// **'智能分析片头/片尾'**
  String get tvDetailSmartAnalysis;

  /// Heading of the season list section.
  ///
  /// In zh, this message translates to:
  /// **'剧季列表'**
  String get tvDetailSeasonListTitle;

  /// Episode number label.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 集'**
  String tvDetailEpisodeNumber(String number);

  /// Season number label.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 季'**
  String tvDetailSeasonNumber(String number);

  /// Combined season and episode label.
  ///
  /// In zh, this message translates to:
  /// **'第 {season} 季 第 {episode} 集'**
  String tvDetailSeasonEpisodeNumbers(String season, String episode);

  /// Season subtitle showing the episode count.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 集'**
  String tvDetailEpisodeCount(String count);

  /// Heading of the episode selection section.
  ///
  /// In zh, this message translates to:
  /// **'选集'**
  String get tvDetailEpisodeSectionTitle;

  /// Fallback season label.
  ///
  /// In zh, this message translates to:
  /// **'未知季'**
  String get tvDetailUnknownSeason;

  /// Title of the season selection dialog.
  ///
  /// In zh, this message translates to:
  /// **'《{title}》共 {count} 季'**
  String tvDetailSeasonTitleSummary(String title, String count);

  /// Fallback text when an episode overview is missing.
  ///
  /// In zh, this message translates to:
  /// **'暂无剧集简介'**
  String get tvDetailEpisodeNoneOverview;

  /// Episode runtime in minutes.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟'**
  String tvDetailEpisodeRuntime(String minutes);

  /// Fallback when the runtime is unknown.
  ///
  /// In zh, this message translates to:
  /// **'时长未知'**
  String get tvDetailRuntimeUnknown;

  /// Rating score tag.
  ///
  /// In zh, this message translates to:
  /// **'{score} 分'**
  String tvDetailScore(String score);

  /// Menu item that plays the current episode.
  ///
  /// In zh, this message translates to:
  /// **'播放本集'**
  String get tvDetailPlayEpisode;

  /// Label showing the season analysis status.
  ///
  /// In zh, this message translates to:
  /// **'智能分析：{status}'**
  String tvDetailSmartAnalysisStatus(String status);

  /// Season analysis status while loading.
  ///
  /// In zh, this message translates to:
  /// **'获取中'**
  String get tvDetailAnalysisFetching;

  /// Season analysis status when not detected.
  ///
  /// In zh, this message translates to:
  /// **'未检测'**
  String get tvDetailAnalysisNotDetected;

  /// Season analysis status when fetching fails.
  ///
  /// In zh, this message translates to:
  /// **'获取失败'**
  String get tvDetailAnalysisFailed;

  /// Season analysis status while preparing.
  ///
  /// In zh, this message translates to:
  /// **'准备中'**
  String get tvDetailAnalysisPreparing;

  /// Season analysis status while pending.
  ///
  /// In zh, this message translates to:
  /// **'等待中'**
  String get tvDetailAnalysisPending;

  /// Season analysis status while running.
  ///
  /// In zh, this message translates to:
  /// **'分析中'**
  String get tvDetailAnalysisInProgress;

  /// Season analysis status on partial success.
  ///
  /// In zh, this message translates to:
  /// **'部分成功'**
  String get tvDetailAnalysisPartialSuccess;

  /// Season analysis status when completed.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get tvDetailAnalysisCompleted;

  /// Season analysis status when failed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get tvDetailAnalysisStatusFailed;

  /// Media type label.
  ///
  /// In zh, this message translates to:
  /// **'电影'**
  String get mediaTypeMovie;

  /// Media type label.
  ///
  /// In zh, this message translates to:
  /// **'电视节目'**
  String get mediaTypeTv;

  /// Media type label.
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get mediaTypeDirectory;

  /// Media type label.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get mediaTypeOther;

  /// Media type label.
  ///
  /// In zh, this message translates to:
  /// **'电视直播'**
  String get mediaTypeLive;

  /// Media type label.
  ///
  /// In zh, this message translates to:
  /// **'剧集'**
  String get mediaTypeEpisode;

  /// Media type label.
  ///
  /// In zh, this message translates to:
  /// **'季'**
  String get mediaTypeSeason;

  /// Poster subtitle for a show with several seasons.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 季'**
  String mediaSeasonCount(String count);

  /// Poster subtitle for a single season.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 季'**
  String mediaSeasonNumber(String number);

  /// Poster subtitle for an episode count.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 集'**
  String mediaEpisodeCount(String count);

  /// Play detail subtitle for an episode.
  ///
  /// In zh, this message translates to:
  /// **'第 {season} 季 · 第 {episode} 集'**
  String mediaEpisodeDetail(String season, String episode);

  /// Cloud storage provider name.
  ///
  /// In zh, this message translates to:
  /// **'百度网盘'**
  String get cloudStorageBaiduPan;

  /// Cloud storage provider name.
  ///
  /// In zh, this message translates to:
  /// **'阿里云盘'**
  String get cloudStorageAliyunDrive;

  /// Cloud storage provider name.
  ///
  /// In zh, this message translates to:
  /// **'115 生活'**
  String get cloudStorage115;

  /// Cloud storage provider name.
  ///
  /// In zh, this message translates to:
  /// **'夸克网盘'**
  String get cloudStorageQuark;

  /// Cloud storage provider name.
  ///
  /// In zh, this message translates to:
  /// **'123 云盘'**
  String get cloudStorage123;

  /// Label of the remember-password checkbox on the login form.
  ///
  /// In zh, this message translates to:
  /// **'记住密码'**
  String get loginRememberPassword;

  /// Fallback label for the injected remember-password checkbox on the NAS login web page.
  ///
  /// In zh, this message translates to:
  /// **'登录页面'**
  String get loginWebViewInjectedPlaceholder;

  /// Fallback label shown when the installed app version is unknown.
  ///
  /// In zh, this message translates to:
  /// **'当前安装版本'**
  String get updateCurrentVersionLabel;

  /// Toast shown when opening the manual download page fails.
  ///
  /// In zh, this message translates to:
  /// **'无法打开手动下载页面，请稍后重试。'**
  String get updateManualDownloadOpenFailed;

  /// Toast shown when opening an update link fails.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接，请稍后重试。'**
  String get updateOpenLinkFailed;

  /// Accessibility label of the update badge in the title bar.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本 {version}，打开更新详情'**
  String updateBadgeSemanticLabel(String version);

  /// Update dialog title while checking for updates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get updateDialogTitleChecking;

  /// Update dialog title when a new version is available.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get updateDialogTitleAvailable;

  /// Update dialog title while downloading.
  ///
  /// In zh, this message translates to:
  /// **'正在下载更新'**
  String get updateDialogTitleDownloading;

  /// Update dialog title after the download completes.
  ///
  /// In zh, this message translates to:
  /// **'下载完成'**
  String get updateDialogTitleDownloaded;

  /// Update dialog title while verifying the package.
  ///
  /// In zh, this message translates to:
  /// **'正在校验更新'**
  String get updateDialogTitleVerifying;

  /// Update dialog title when the update is ready to install.
  ///
  /// In zh, this message translates to:
  /// **'更新已准备就绪'**
  String get updateDialogTitleReadyToInstall;

  /// Update dialog title while launching the installer.
  ///
  /// In zh, this message translates to:
  /// **'正在启动安装'**
  String get updateDialogTitleInstalling;

  /// Update dialog title when checking for updates failed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败'**
  String get updateDialogTitleCheckFailed;

  /// Update dialog title when the download failed.
  ///
  /// In zh, this message translates to:
  /// **'下载更新失败'**
  String get updateDialogTitleDownloadFailed;

  /// Update dialog title when package verification failed.
  ///
  /// In zh, this message translates to:
  /// **'更新包校验失败'**
  String get updateDialogTitleVerificationFailed;

  /// Update dialog title when launching the installer failed.
  ///
  /// In zh, this message translates to:
  /// **'启动安装失败'**
  String get updateDialogTitleInstallFailed;

  /// Update dialog title when the automatic download did not finish.
  ///
  /// In zh, this message translates to:
  /// **'自动下载未完成'**
  String get updateDialogTitleAutomaticDownloadExhausted;

  /// Update dialog title in the idle state.
  ///
  /// In zh, this message translates to:
  /// **'应用更新'**
  String get updateDialogTitleNone;

  /// Update dialog button to keep checking in the background.
  ///
  /// In zh, this message translates to:
  /// **'后台检查'**
  String get updateActionCheckInBackground;

  /// Update dialog button to skip this version.
  ///
  /// In zh, this message translates to:
  /// **'跳过此版本'**
  String get updateActionSkipVersion;

  /// Update dialog button to postpone the update.
  ///
  /// In zh, this message translates to:
  /// **'稍后再说'**
  String get updateActionLater;

  /// Update dialog button to download the update.
  ///
  /// In zh, this message translates to:
  /// **'下载更新'**
  String get updateActionDownload;

  /// Update dialog button to continue downloading in the background.
  ///
  /// In zh, this message translates to:
  /// **'后台下载'**
  String get updateActionDownloadInBackground;

  /// Update dialog button to cancel the download.
  ///
  /// In zh, this message translates to:
  /// **'取消下载'**
  String get updateActionCancelDownload;

  /// Update dialog button to install later.
  ///
  /// In zh, this message translates to:
  /// **'稍后安装'**
  String get updateActionInstallLater;

  /// Update dialog button to quit and install now.
  ///
  /// In zh, this message translates to:
  /// **'退出并安装'**
  String get updateActionQuitAndInstall;

  /// Update dialog button to let the update run in the background.
  ///
  /// In zh, this message translates to:
  /// **'后台运行'**
  String get updateActionRunInBackground;

  /// Update dialog button to download the update again.
  ///
  /// In zh, this message translates to:
  /// **'重新下载'**
  String get updateActionRetryDownload;

  /// Update dialog button to retry the installation.
  ///
  /// In zh, this message translates to:
  /// **'重试安装'**
  String get updateActionRetryInstall;

  /// Update dialog button to open the manual download page.
  ///
  /// In zh, this message translates to:
  /// **'手动下载'**
  String get updateActionManualDownload;

  /// Update dialog button to close the dialog.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get updateActionClose;

  /// Update dialog status while fetching update information.
  ///
  /// In zh, this message translates to:
  /// **'正在从 GitHub Releases 获取更新信息…'**
  String get updateStatusCheckingMessage;

  /// Update dialog status when the app is up to date.
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本。'**
  String get updateStatusUpToDate;

  /// Update dialog status after the download completes.
  ///
  /// In zh, this message translates to:
  /// **'更新包已下载完成，可以稍后安装或立即退出并安装。'**
  String get updateStatusDownloadedMessage;

  /// Update dialog status when a downloaded update was found.
  ///
  /// In zh, this message translates to:
  /// **'已找到可用的已下载更新包。'**
  String get updateStatusReadyMessage;

  /// Update dialog status while verifying the package.
  ///
  /// In zh, this message translates to:
  /// **'正在安全校验更新包，请稍候…'**
  String get updateStatusVerifyingMessage;

  /// Update dialog status while launching the installer.
  ///
  /// In zh, this message translates to:
  /// **'正在启动系统安装程序，请勿重复操作。'**
  String get updateStatusInstallingMessage;

  /// Update dialog status before any check has been run.
  ///
  /// In zh, this message translates to:
  /// **'尚未执行更新检查。'**
  String get updateStatusIdleMessage;

  /// Update dialog line showing the new version and the current version.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}（当前 {current}）'**
  String updateVersionLine(String version, String current);

  /// Update dialog line showing the download size.
  ///
  /// In zh, this message translates to:
  /// **'安装包大小 {size}'**
  String updatePackageSize(String size);

  /// Heading of the release-notes section in the update dialog.
  ///
  /// In zh, this message translates to:
  /// **'更新内容'**
  String get updateReleaseNotesHeader;

  /// Fallback text used while downloading when the asset name is unknown.
  ///
  /// In zh, this message translates to:
  /// **'正在下载更新包'**
  String get updateDownloadingPackage;

  /// Update dialog text showing the downloaded size.
  ///
  /// In zh, this message translates to:
  /// **'已下载 {size}'**
  String updateDownloadedSize(String size);

  /// Update dialog text showing download progress.
  ///
  /// In zh, this message translates to:
  /// **'{received} / {total}'**
  String updateDownloadProgress(String received, String total);

  /// Failure summary when the GitHub API rate limit is reached.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 接口访问频率超限，通常稍后会自动恢复，请稍后再试。'**
  String get updateErrorRateLimited;

  /// Failure summary when the update package failed verification.
  ///
  /// In zh, this message translates to:
  /// **'更新包未通过安全校验，请重新下载。'**
  String get updateErrorVerificationFailed;

  /// Failure summary when checking for updates failed.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法获取更新信息，请检查网络后重试。'**
  String get updateErrorCheckFailed;

  /// Failure summary when the update download failed.
  ///
  /// In zh, this message translates to:
  /// **'更新包下载未完成，请稍后重试。'**
  String get updateErrorDownloadFailed;

  /// Failure summary when launching the installer failed.
  ///
  /// In zh, this message translates to:
  /// **'无法启动系统安装程序，请稍后重试。'**
  String get updateErrorInstallFailed;

  /// Failure summary when the automatic download was exhausted.
  ///
  /// In zh, this message translates to:
  /// **'自动下载多次未完成，你可以稍后重试或前往发布页手动下载。'**
  String get updateErrorAutomaticDownloadExhausted;

  /// Generic failure summary for update operations.
  ///
  /// In zh, this message translates to:
  /// **'更新操作未完成，请稍后重试。'**
  String get updateErrorGeneric;

  /// Placeholder shown when the release notes are empty.
  ///
  /// In zh, this message translates to:
  /// **'本次更新未提供更新说明'**
  String get updateMarkdownEmpty;

  /// Alt text for a blocked remote image in the release notes.
  ///
  /// In zh, this message translates to:
  /// **'远程图片'**
  String get updateMarkdownRemoteImageAlt;

  /// Label for a blocked remote image in the release notes.
  ///
  /// In zh, this message translates to:
  /// **'远程图片已阻止：{alt}'**
  String updateMarkdownRemoteImageBlocked(String alt);

  /// Suffix appended to release notes when they exceed the maximum length.
  ///
  /// In zh, this message translates to:
  /// **'\n\n更新说明过长，已截断显示。'**
  String get updateMarkdownTruncatedSuffix;

  /// Login field placeholder for the NAS host or FN ID.
  ///
  /// In zh, this message translates to:
  /// **'请输入 IP:Port、域名或 FN ID'**
  String get loginHostOrFnIdPlaceholder;

  /// Toast shown when the entered host or FN ID is invalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入正确的 IP、域名或 FN ID'**
  String get loginHostValidationMessage;

  /// Toast shown when the host field is empty.
  ///
  /// In zh, this message translates to:
  /// **'请输入 IP、域名或 FN ID'**
  String get loginHostRequiredMessage;

  /// Toast shown when the username field is empty.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get loginUsernameRequiredMessage;

  /// Toast shown when the password field is empty.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get loginPasswordRequiredMessage;

  /// Toast shown when preparing the WebView for NAS login fails.
  ///
  /// In zh, this message translates to:
  /// **'浏览器组件初始化失败，请稍后重试。'**
  String get loginWebViewInitFailed;

  /// Login field placeholder for the host.
  ///
  /// In zh, this message translates to:
  /// **'请输入 IP、域名或 FN ID'**
  String get loginHostPlaceholder;

  /// Login field placeholder for the port.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get loginPortPlaceholder;

  /// Login field placeholder for the username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get loginUsernameLabel;

  /// Login field placeholder for the password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get loginPasswordLabel;

  /// Login toggle label to sign in with a NAS account.
  ///
  /// In zh, this message translates to:
  /// **'使用 NAS 登录'**
  String get loginUseNasLogin;

  /// Login toggle label for enabling HTTPS.
  ///
  /// In zh, this message translates to:
  /// **'HTTPS 安全访问'**
  String get loginHttpsSecureAccess;

  /// Login button label for the NAS probe step.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get loginNext;

  /// Login button label.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get loginSignIn;

  /// Login web view toolbar text while verifying the server.
  ///
  /// In zh, this message translates to:
  /// **'正在验证服务器...'**
  String get loginVerifyingServer;

  /// Toast shown when the username or password is wrong.
  ///
  /// In zh, this message translates to:
  /// **'用户名或密码错误'**
  String get loginInvalidCredentials;

  /// Login error for a non-success HTTP response.
  ///
  /// In zh, this message translates to:
  /// **'服务器返回错误（HTTP {status}），请检查服务状态。'**
  String loginServerHttpError(String status);

  /// Login error for an SSL certificate failure.
  ///
  /// In zh, this message translates to:
  /// **'SSL 证书验证失败，请检查 HTTPS 设置或服务器证书。'**
  String get loginSslCertificateFailed;

  /// Login error for a connection timeout.
  ///
  /// In zh, this message translates to:
  /// **'连接服务器超时，请确认服务器地址或网络状态。'**
  String get loginConnectionTimeout;

  /// Login error when the server is unreachable.
  ///
  /// In zh, this message translates to:
  /// **'无法连接到服务器，请检查地址、端口或网络。'**
  String get loginConnectionFailed;

  /// Login error when the request was cancelled.
  ///
  /// In zh, this message translates to:
  /// **'登录请求已取消。'**
  String get loginRequestCancelled;

  /// Login error for an unknown or bad response.
  ///
  /// In zh, this message translates to:
  /// **'登录失败，请检查服务器地址或稍后再试。'**
  String get loginFailedCheckServer;

  /// Generic login error message.
  ///
  /// In zh, this message translates to:
  /// **'登录失败，请检查网络或服务器设置。'**
  String get loginFailedCheckNetwork;

  /// Login error when the NAS flow returns an empty token.
  ///
  /// In zh, this message translates to:
  /// **'登录失败: Token 为空'**
  String get loginFailedTokenEmpty;

  /// Login error with the underlying error message.
  ///
  /// In zh, this message translates to:
  /// **'登录失败: {error}'**
  String loginFailedWithError(String error);

  /// Fallback login error when the server rejects the token exchange.
  ///
  /// In zh, this message translates to:
  /// **'认证失败'**
  String get loginAuthFailed;

  /// Login error when the fnOS access-code gateway rejects the code.
  ///
  /// In zh, this message translates to:
  /// **'访问码错误'**
  String get loginAccessCodeInvalid;

  /// Title of the dialog prompting for the NAS access code.
  ///
  /// In zh, this message translates to:
  /// **'请输入访问码'**
  String get loginAccessCodeTitle;

  /// Hint shown in the access-code dialog.
  ///
  /// In zh, this message translates to:
  /// **'该服务器启用了访问码，请输入后继续。'**
  String get loginAccessCodeHint;

  /// Validation error when resolving an empty FN ID.
  ///
  /// In zh, this message translates to:
  /// **'FN ID 不能为空'**
  String get loginFnIdEmpty;

  /// Title of the login history sidebar.
  ///
  /// In zh, this message translates to:
  /// **'登录历史'**
  String get loginHistoryTitle;

  /// Empty state of the login history sidebar.
  ///
  /// In zh, this message translates to:
  /// **'暂无历史记录'**
  String get loginHistoryEmpty;

  /// Retry button shown when the media library row fails to load.
  ///
  /// In zh, this message translates to:
  /// **'加载失败，点击重试'**
  String get homeRetryLoad;

  /// Title of the home page.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get homeTitle;

  /// Title of the continue-watching row on the home page.
  ///
  /// In zh, this message translates to:
  /// **'继续观看'**
  String get homeContinueWatching;

  /// Heading of the media library card row on the home page.
  ///
  /// In zh, this message translates to:
  /// **'媒体库'**
  String get homeMediaLibrary;

  /// Toast shown after an item is removed from continue watching.
  ///
  /// In zh, this message translates to:
  /// **'已从“继续观看”中移除'**
  String get homeContinueRemoved;

  /// Toast shown when removing an item from continue watching fails.
  ///
  /// In zh, this message translates to:
  /// **'移除失败'**
  String get homeContinueRemoveFailed;

  /// Toast shown when removing an item from continue watching throws.
  ///
  /// In zh, this message translates to:
  /// **'移除失败：{error}'**
  String homeContinueRemoveError(String error);

  /// Title of the delete-video confirmation dialog.
  ///
  /// In zh, this message translates to:
  /// **'删除 《{title}》'**
  String homeDeleteDialogTitle(String title);

  /// Body text of the delete-video confirmation dialog.
  ///
  /// In zh, this message translates to:
  /// **'从媒体库移除后，所选视频文件将不再被扫描添加到当前媒体库中。请确认是否同时删除关联的视频文件。'**
  String get homeDeleteDialogBody;

  /// Delete dialog button to remove the entry and delete the files.
  ///
  /// In zh, this message translates to:
  /// **'移除并删除文件'**
  String get homeDeleteRemoveAndDeleteFile;

  /// Delete dialog button to remove the entry but keep the files.
  ///
  /// In zh, this message translates to:
  /// **'仅移除'**
  String get homeDeleteRemoveOnly;

  /// Toast shown after the video is deleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get homeDeleted;

  /// Toast shown when deleting the video fails.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get homeDeleteFailed;

  /// Toast shown when deleting the video throws.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String homeDeleteFailedWithError(String error);

  /// Toast shown after removing an item from favorites.
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏'**
  String get homeFavoriteRemoved;

  /// Toast shown after adding an item to favorites.
  ///
  /// In zh, this message translates to:
  /// **'已收藏'**
  String get homeFavorited;

  /// Toast shown after marking an item as unwatched.
  ///
  /// In zh, this message translates to:
  /// **'标记为未观看'**
  String get homeMarkedUnwatched;

  /// Toast shown after marking an item as watched.
  ///
  /// In zh, this message translates to:
  /// **'标记为已观看'**
  String get homeMarkedWatched;

  /// Toast shown when a favorite or watched action fails.
  ///
  /// In zh, this message translates to:
  /// **'操作失败'**
  String get homeActionFailed;

  /// Toast shown when a favorite or watched action throws.
  ///
  /// In zh, this message translates to:
  /// **'操作失败，{error}'**
  String homeActionFailedWithError(String error);

  /// More-menu entry to remove an item from continue watching.
  ///
  /// In zh, this message translates to:
  /// **'从“继续观看”中移除'**
  String get homeMenuRemoveFromContinue;

  /// More-menu entry to resume playback.
  ///
  /// In zh, this message translates to:
  /// **'继续播放'**
  String get homeMenuResume;

  /// More-menu entry to restart playback from the beginning.
  ///
  /// In zh, this message translates to:
  /// **'从头开始播放'**
  String get homeMenuRestart;

  /// More-menu entry to delete the video.
  ///
  /// In zh, this message translates to:
  /// **'删除视频'**
  String get homeMenuDeleteVideo;

  /// Placeholder of the capsule search box.
  ///
  /// In zh, this message translates to:
  /// **'搜索片名、演员'**
  String get searchPlaceholder;

  /// Search category tab: all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get searchTabAll;

  /// Search category tab: movies.
  ///
  /// In zh, this message translates to:
  /// **'电影'**
  String get searchTabMovie;

  /// Search category tab: TV series.
  ///
  /// In zh, this message translates to:
  /// **'电视剧'**
  String get searchTabTv;

  /// Search category tab: live channels.
  ///
  /// In zh, this message translates to:
  /// **'电视直播'**
  String get searchTabLiveChannel;

  /// Search category tab: people.
  ///
  /// In zh, this message translates to:
  /// **'人物'**
  String get searchTabPerson;

  /// Search category tab: other.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get searchTabOther;

  /// Empty state of the search dropdown after a search.
  ///
  /// In zh, this message translates to:
  /// **'搜索无结果'**
  String get searchNoResults;

  /// Empty state of the search dropdown before searching.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词搜索'**
  String get searchEnterKeyword;

  /// Work count shown for a person in the search results.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个作品'**
  String searchWorkCount(String count);

  /// Suffix for the rating score in the search results.
  ///
  /// In zh, this message translates to:
  /// **'分'**
  String get searchScoreSuffix;

  /// Episode count shown for a TV series in the search results.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 集'**
  String searchEpisodeCount(String count);

  /// Empty state shown when a person has no record on the server.
  ///
  /// In zh, this message translates to:
  /// **'无数据'**
  String get personNoData;

  /// Works section title for acting roles.
  ///
  /// In zh, this message translates to:
  /// **'作为演员'**
  String get personSectionActor;

  /// Works section title for directing roles.
  ///
  /// In zh, this message translates to:
  /// **'作为导演'**
  String get personSectionDirector;

  /// Works section title for writing roles.
  ///
  /// In zh, this message translates to:
  /// **'作为编剧'**
  String get personSectionWriter;

  /// Inline link that opens the full biography.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get personMore;

  /// Title of the full-biography dialog.
  ///
  /// In zh, this message translates to:
  /// **'演员简介'**
  String get personBiographyTitle;

  /// Generic delete button label.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// Title and link label of the forgot-password dialog.
  ///
  /// In zh, this message translates to:
  /// **'忘记密码？'**
  String get forgotPasswordTitle;

  /// Sidebar label for an external storage mount.
  ///
  /// In zh, this message translates to:
  /// **'外接存储'**
  String get storageExternal;

  /// Sidebar label for a remote mount.
  ///
  /// In zh, this message translates to:
  /// **'远程挂载'**
  String get storageRemoteMount;

  /// Label for a numbered storage volume.
  ///
  /// In zh, this message translates to:
  /// **'存储空间 {number}'**
  String storageVolumeName(String number);

  /// Duration with hours and minutes.
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小时 {minutes} 分钟'**
  String durationHoursMinutes(String hours, String minutes);

  /// Duration in hours.
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小时'**
  String durationHours(String hours);

  /// Duration with minutes and seconds.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟 {seconds} 秒'**
  String durationMinutesSeconds(String minutes, String seconds);

  /// Duration in minutes.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟'**
  String durationMinutes(String minutes);

  /// Zero-length duration.
  ///
  /// In zh, this message translates to:
  /// **'0 分钟'**
  String get durationZeroMinutes;

  /// Label for a user's authorized directory.
  ///
  /// In zh, this message translates to:
  /// **'{username} 的文件'**
  String authDirUserFiles(String username);

  /// Fallback label when the user name is unknown.
  ///
  /// In zh, this message translates to:
  /// **'用户 {uid}'**
  String authDirUnknownUser(String uid);

  /// Empty value placeholder.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get authDirNone;

  /// Unknown value placeholder.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get authDirUnknown;

  /// Media stream kind label.
  ///
  /// In zh, this message translates to:
  /// **'音频'**
  String get mediaStreamAudio;

  /// Media stream kind label.
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get mediaStreamVideo;

  /// Media stream kind label.
  ///
  /// In zh, this message translates to:
  /// **'字幕'**
  String get mediaStreamSubtitle;

  /// Body text of the forgot-password dialog.
  ///
  /// In zh, this message translates to:
  /// **'1. 如果您是 NAS 用户，请尝试 NAS 帐号登录；\n2. 请联系管理员修改密码。'**
  String get forgotPasswordBody;

  /// Episode card title combining the episode number and name.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 集 {title}'**
  String tvDetailEpisodeNumberTitle(String number, String title);

  /// Appends a default marker to a subtitle display name.
  ///
  /// In zh, this message translates to:
  /// **' - 默认'**
  String get movieDetailSubtitleDefaultSuffix;

  /// Relative time: now.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get timeJustNow;

  /// Relative time.
  ///
  /// In zh, this message translates to:
  /// **'{count} 分钟前'**
  String timeMinutesAgo(String count);

  /// Relative time.
  ///
  /// In zh, this message translates to:
  /// **'{count} 小时前'**
  String timeHoursAgo(String count);

  /// Relative time.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天前'**
  String timeDaysAgo(String count);

  /// Relative time.
  ///
  /// In zh, this message translates to:
  /// **'{count} 周前'**
  String timeWeeksAgo(String count);

  /// Relative time.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个月前'**
  String timeMonthsAgo(String count);

  /// Relative time.
  ///
  /// In zh, this message translates to:
  /// **'{count} 年前'**
  String timeYearsAgo(String count);

  /// Shown when a release has no notes.
  ///
  /// In zh, this message translates to:
  /// **'暂无更新说明。'**
  String get updateNotesEmpty;

  /// Appended when release notes exceed the size limit.
  ///
  /// In zh, this message translates to:
  /// **'\n\n> 更新说明已截断。请前往 [Release 页面]({url}) 查看完整内容。'**
  String updateNotesTruncated(String url);

  /// Navigation pane label for the categories section.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get navCategories;

  /// Navigation pane label and fallback title for the favorites page.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get navFavorites;

  /// Placeholder shown in the navigation pane when the media library list is empty.
  ///
  /// In zh, this message translates to:
  /// **'暂无媒体库'**
  String get navNoMediaLibrary;

  /// Fallback title used for a folder when its real name is unavailable.
  ///
  /// In zh, this message translates to:
  /// **'文件夹'**
  String get folderFallbackName;

  /// Menu action that rescrapes (re-identifies) the current folder.
  ///
  /// In zh, this message translates to:
  /// **'重新识别'**
  String get folderRescrap;

  /// Toast shown after a folder rescrape request is accepted.
  ///
  /// In zh, this message translates to:
  /// **'已发起重新识别'**
  String get folderRescrapStarted;

  /// Toast title shown when a folder rescrape request fails.
  ///
  /// In zh, this message translates to:
  /// **'重新识别失败'**
  String get folderRescrapFailed;

  /// Toast shown when a folder rescrape request throws.
  ///
  /// In zh, this message translates to:
  /// **'重新识别失败：{error}'**
  String folderRescrapFailedWithError(String error);

  /// Menu action that refreshes the current folder's metadata.
  ///
  /// In zh, this message translates to:
  /// **'刷新元数据'**
  String get folderRefreshMetadata;

  /// Toast shown after a folder metadata refresh request is accepted.
  ///
  /// In zh, this message translates to:
  /// **'已发起刷新元数据'**
  String get folderRefreshMetadataStarted;

  /// Toast title shown when a folder metadata refresh request fails.
  ///
  /// In zh, this message translates to:
  /// **'刷新元数据失败'**
  String get folderRefreshMetadataFailed;

  /// Toast shown when a folder metadata refresh request throws.
  ///
  /// In zh, this message translates to:
  /// **'刷新元数据失败：{error}'**
  String folderRefreshMetadataFailedWithError(String error);

  /// Fallback name used in the folder delete confirmation when the folder name is unknown.
  ///
  /// In zh, this message translates to:
  /// **'该文件夹'**
  String get folderThisFolder;

  /// Title of the folder deletion confirmation dialog.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get folderDeleteConfirmTitle;

  /// Body of the folder deletion confirmation dialog, reusing the generic delete title.
  ///
  /// In zh, this message translates to:
  /// **'确定要从媒体库删除「{title}」吗？\n仅移除媒体库条目，不会删除磁盘上的文件。'**
  String folderDeleteConfirmBody(String title);

  /// Toast shown when a folder deletion request throws.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String folderDeleteFailedWithError(String error);

  /// Footer count of items shown in the folder screen.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 项'**
  String folderItemCount(String count);

  /// Favorites tab label for single episodes.
  ///
  /// In zh, this message translates to:
  /// **'单集'**
  String get favoritesTabSingleEpisode;

  /// Error shown when the server version could not be fetched.
  ///
  /// In zh, this message translates to:
  /// **'获取服务端版本失败'**
  String get serverUpdateGetVersionFailed;

  /// Error shown when checking for a server update throws.
  ///
  /// In zh, this message translates to:
  /// **'检查服务端更新异常'**
  String get serverUpdateCheckFailed;

  /// Error shown when checking for a server update throws, with the error detail.
  ///
  /// In zh, this message translates to:
  /// **'检查服务端更新异常: {error}'**
  String serverUpdateCheckFailedWithError(String error);

  /// Error shown when no matching server release was found.
  ///
  /// In zh, this message translates to:
  /// **'服务端更新包未找到'**
  String get serverUpdatePackageNotFound;

  /// Error shown when the server release has no usable asset.
  ///
  /// In zh, this message translates to:
  /// **'服务端更新包资产缺失'**
  String get serverUpdateAssetMissing;

  /// Status shown when the server self-update is starting.
  ///
  /// In zh, this message translates to:
  /// **'开始服务端更新...'**
  String get serverUpdateStarting;

  /// Error shown when the server self-update fails.
  ///
  /// In zh, this message translates to:
  /// **'服务端更新失败'**
  String get serverUpdateFailed;

  /// Error shown when the server self-update fails, with the error detail.
  ///
  /// In zh, this message translates to:
  /// **'服务端更新失败: {error}'**
  String serverUpdateFailedWithError(String error);

  /// Status shown while waiting for the server to restart after updating.
  ///
  /// In zh, this message translates to:
  /// **'等待服务端重启...'**
  String get serverUpdateWaitingRestart;

  /// Status shown when the server finished updating to a new version.
  ///
  /// In zh, this message translates to:
  /// **'服务端已更新到 {version}'**
  String serverUpdateSucceeded(String version);

  /// Error shown when the server did not come back after updating.
  ///
  /// In zh, this message translates to:
  /// **'服务端更新超时，请检查服务端日志'**
  String get serverUpdateTimeout;

  /// Error shown when the FlyNarwhal server address is not a valid URL.
  ///
  /// In zh, this message translates to:
  /// **'FlyNarwhal 服务端地址无效'**
  String get connectionTestInvalidUrl;

  /// Error shown when the FlyNarwhal server returned an empty version.
  ///
  /// In zh, this message translates to:
  /// **'FlyNarwhal 服务端未返回版本号'**
  String get connectionTestNoVersion;

  /// Success message shown when a smart analysis request was queued.
  ///
  /// In zh, this message translates to:
  /// **'已加入分析队列'**
  String get smartAnalysisQueued;

  /// Fallback success message shown when a smart analysis request was submitted.
  ///
  /// In zh, this message translates to:
  /// **'分析请求已提交'**
  String get smartAnalysisSubmitted;

  /// Error shown listing the seasons whose smart analysis submission failed.
  ///
  /// In zh, this message translates to:
  /// **'失败剧季：{seasons}'**
  String smartAnalysisFailedSeasons(String seasons);

  /// Error shown when a smart analysis request could not be submitted.
  ///
  /// In zh, this message translates to:
  /// **'分析请求提交失败'**
  String get smartAnalysisSubmitFailed;

  /// Keyboard shortcut action name.
  ///
  /// In zh, this message translates to:
  /// **'聚焦搜索输入框'**
  String get shortcutFocusSearch;

  /// Keyboard shortcut action name.
  ///
  /// In zh, this message translates to:
  /// **'播放/暂停'**
  String get shortcutTogglePlayPause;

  /// Keyboard shortcut action name.
  ///
  /// In zh, this message translates to:
  /// **'静音/取消静音'**
  String get shortcutMute;

  /// Keyboard shortcut action name.
  ///
  /// In zh, this message translates to:
  /// **'快退 10 秒'**
  String get shortcutSeekBackward;

  /// Keyboard shortcut action name.
  ///
  /// In zh, this message translates to:
  /// **'快进 10 秒'**
  String get shortcutSeekForward;

  /// Keyboard shortcut action name.
  ///
  /// In zh, this message translates to:
  /// **'音量增加'**
  String get shortcutVolumeUp;

  /// Keyboard shortcut action name.
  ///
  /// In zh, this message translates to:
  /// **'音量减少'**
  String get shortcutVolumeDown;

  /// Keyboard shortcut action name.
  ///
  /// In zh, this message translates to:
  /// **'切换全屏'**
  String get shortcutToggleFullscreen;

  /// Keyboard shortcut action name.
  ///
  /// In zh, this message translates to:
  /// **'退出全屏'**
  String get shortcutExitFullscreen;

  /// Keyboard shortcut action name.
  ///
  /// In zh, this message translates to:
  /// **'下一个搜索项'**
  String get shortcutSearchNext;

  /// Keyboard shortcut action name.
  ///
  /// In zh, this message translates to:
  /// **'上一个搜索项'**
  String get shortcutSearchPrev;

  /// Keyboard shortcut action name.
  ///
  /// In zh, this message translates to:
  /// **'选中搜索项'**
  String get shortcutSearchSelect;

  /// Keyboard shortcut action name.
  ///
  /// In zh, this message translates to:
  /// **'切换搜索分类'**
  String get shortcutSearchSwitchTab;

  /// Keyboard shortcut action name.
  ///
  /// In zh, this message translates to:
  /// **'退出搜索'**
  String get shortcutSearchExit;

  /// Suffix appended to a subtitle language name when the subtitle is external.
  ///
  /// In zh, this message translates to:
  /// **' - 外挂'**
  String get playerSubtitleExternalSuffix;

  /// Suffix appended to a subtitle language name when the subtitle is the default track.
  ///
  /// In zh, this message translates to:
  /// **' - 默认'**
  String get playerSubtitleDefaultSuffix;

  /// Toast shown when the volume changes, with the new volume percentage.
  ///
  /// In zh, this message translates to:
  /// **'当前音量：{value}%'**
  String playerVolumeLabel(String value);

  /// Toast shown when unmuting, with the restored volume percentage.
  ///
  /// In zh, this message translates to:
  /// **'解除静音：{value}%'**
  String playerVolumeUnmuteLabel(String value);

  /// Toast shown when muting the player.
  ///
  /// In zh, this message translates to:
  /// **'静音'**
  String get playerVolumeMute;

  /// Toast prefix shown when rewinding, followed by the target timestamp.
  ///
  /// In zh, this message translates to:
  /// **'快退至'**
  String get playerSeekRewindTo;

  /// Toast prefix shown when fast-forwarding, followed by the target timestamp.
  ///
  /// In zh, this message translates to:
  /// **'快进至'**
  String get playerSeekForwardTo;

  /// Toast shown when seeking via keyboard, combining the rewind/forward label and the target timestamp.
  ///
  /// In zh, this message translates to:
  /// **'{label}：{time}'**
  String playerSeekTimeToast(String label, String time);

  /// Reason shown when the force-H.264 transcoding switch is disabled because the video is already H.264.
  ///
  /// In zh, this message translates to:
  /// **'当前视频为 H.264'**
  String get playerForceH264Disabled;

  /// Reason shown when the force-SDR color switch is disabled because the video is already SDR.
  ///
  /// In zh, this message translates to:
  /// **'当前视频为 SDR'**
  String get playerForceSdrDisabled;

  /// Label for the netdisk direct-link cloud playback mode.
  ///
  /// In zh, this message translates to:
  /// **'网盘直连播放'**
  String get playerCloudModeDirect;

  /// Label for the NAS proxy cloud playback mode.
  ///
  /// In zh, this message translates to:
  /// **'NAS 代理播放'**
  String get playerCloudModeNasProxy;

  /// Toast shown after the cloud playback mode is switched, with the new mode label.
  ///
  /// In zh, this message translates to:
  /// **'播放方式切换至 {label}'**
  String playerCloudModeSwitchedToast(String label);

  /// Toast shown when NAS proxy negotiation fails and playback falls back to the netdisk direct link.
  ///
  /// In zh, this message translates to:
  /// **'NAS 代理播放失败，正在切换为网盘直连播放'**
  String get playerCloudProxyFailedFallbackDirect;

  /// Toast shown when subtitle search is invoked but the current file info is missing.
  ///
  /// In zh, this message translates to:
  /// **'当前文件信息缺失，无法搜索字幕'**
  String get playerInfoMissingSearchSubtitle;

  /// Toast shown when adding a NAS subtitle is invoked but the current file info is missing.
  ///
  /// In zh, this message translates to:
  /// **'当前文件信息缺失，无法添加 NAS 字幕'**
  String get playerInfoMissingAddNasSubtitle;

  /// Toast shown when uploading a local subtitle is invoked but the current file info is missing.
  ///
  /// In zh, this message translates to:
  /// **'当前文件信息缺失，无法上传字幕'**
  String get playerInfoMissingUploadSubtitle;

  /// Title of the confirm dialog for deleting an external subtitle.
  ///
  /// In zh, this message translates to:
  /// **'删除外挂字幕'**
  String get playerSubtitleDeleteTitle;

  /// Body of the confirm dialog for deleting an external subtitle, with the subtitle display name.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除 {displayName} 外挂字幕吗？'**
  String playerSubtitleDeleteConfirm(String displayName);

  /// Toast shown after a subtitle is deleted successfully.
  ///
  /// In zh, this message translates to:
  /// **'删除字幕成功'**
  String get playerSubtitleDeleteSuccess;

  /// Toast shown when deleting a subtitle fails, with the error.
  ///
  /// In zh, this message translates to:
  /// **'删除字幕失败: {error}'**
  String playerSubtitleDeleteFailed(String error);

  /// Title of the dialog for adding a NAS subtitle file.
  ///
  /// In zh, this message translates to:
  /// **'添加 NAS 字幕文件'**
  String get playerSubtitleAddNasTitle;

  /// Toast shown after a NAS subtitle is added successfully.
  ///
  /// In zh, this message translates to:
  /// **'NAS 字幕添加成功'**
  String get playerSubtitleAddNasSuccess;

  /// Toast shown when the selected file has already been added as a subtitle.
  ///
  /// In zh, this message translates to:
  /// **'该文件已被添加为字幕'**
  String get playerSubtitleAlreadyMarked;

  /// Toast shown when adding a NAS subtitle fails, with the error.
  ///
  /// In zh, this message translates to:
  /// **'添加 NAS 字幕失败: {error}'**
  String playerSubtitleAddNasFailed(String error);

  /// Toast shown after a subtitle is downloaded successfully.
  ///
  /// In zh, this message translates to:
  /// **'下载成功'**
  String get playerSubtitleDownloadSuccess;

  /// Toast shown when downloading a subtitle fails, with the error.
  ///
  /// In zh, this message translates to:
  /// **'下载字幕失败: {error}'**
  String playerSubtitleDownloadFailed(String error);

  /// Toast shown after a subtitle download task is created.
  ///
  /// In zh, this message translates to:
  /// **'已创建字幕下载任务'**
  String get playerSubtitleTaskCreated;

  /// Toast shown when creating a subtitle download task fails.
  ///
  /// In zh, this message translates to:
  /// **'创建字幕下载任务失败，请重试'**
  String get playerSubtitleTaskFailed;

  /// Toast shown when switching subtitles fails, with the error.
  ///
  /// In zh, this message translates to:
  /// **'切换字幕失败: {error}'**
  String playerSubtitleSwitchFailed(String error);

  /// Toast shown when switching back to the original quality fails, with the error.
  ///
  /// In zh, this message translates to:
  /// **'切换原画失败: {error}'**
  String playerSwitchOriginalQualityFailed(String error);

  /// Toast shown when loading media fails, with the error.
  ///
  /// In zh, this message translates to:
  /// **'加载失败: {error}'**
  String playerLoadFailed(String error);

  /// Toast shown when toggling fullscreen fails, with the error.
  ///
  /// In zh, this message translates to:
  /// **'切换全屏失败: {error}'**
  String playerToggleFullscreenFailed(String error);

  /// Toast shown when restarting for transcode settings fails, with the error.
  ///
  /// In zh, this message translates to:
  /// **'切换播放设置失败: {error}'**
  String playerSwitchPlaybackSettingsFailed(String error);

  /// Toast shown when a player action is requested before the player is ready.
  ///
  /// In zh, this message translates to:
  /// **'播放器尚未准备完成'**
  String get playerNotReady;

  /// Toast shown when entering picture-in-picture fails, with the error.
  ///
  /// In zh, this message translates to:
  /// **'进入画中画失败: {error}'**
  String playerEnterPipFailed(String error);

  /// Toast shown when exiting picture-in-picture fails, with the error.
  ///
  /// In zh, this message translates to:
  /// **'退出画中画失败: {error}'**
  String playerExitPipFailed(String error);

  /// Toast shown when switching video quality fails, with the error.
  ///
  /// In zh, this message translates to:
  /// **'切换画质失败: {error}'**
  String playerSwitchQualityFailed(String error);

  /// Toast shown when switching the cloud playback mode fails, with the error.
  ///
  /// In zh, this message translates to:
  /// **'切换播放方式失败: {error}'**
  String playerSwitchPlayModeFailed(String error);

  /// Toast shown when switching audio tracks fails, with the error.
  ///
  /// In zh, this message translates to:
  /// **'切换音频失败: {error}'**
  String playerSwitchAudioFailed(String error);

  /// Toast shown when switching to a subtitle, with the language name only.
  ///
  /// In zh, this message translates to:
  /// **'字幕正在切换至：{language}'**
  String playerSubtitleSwitchingTo(String language);

  /// Toast shown when switching to a subtitle, with the language name and uppercased format.
  ///
  /// In zh, this message translates to:
  /// **'字幕正在切换至：{language} {format}'**
  String playerSubtitleSwitchingToFormat(String language, String format);

  /// Tooltip for the close button.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get playerClose;

  /// Tooltip for the back button.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get playerBack;

  /// Tooltip for the rewind 10 seconds button.
  ///
  /// In zh, this message translates to:
  /// **'快退 10 秒'**
  String get playerRewindTenSeconds;

  /// Tooltip for the forward 10 seconds button.
  ///
  /// In zh, this message translates to:
  /// **'快进 10 秒'**
  String get playerForwardTenSeconds;

  /// Tooltip for the play/pause button.
  ///
  /// In zh, this message translates to:
  /// **'播放/暂停'**
  String get playerPlayPause;

  /// Tooltip for the picture-in-picture button.
  ///
  /// In zh, this message translates to:
  /// **'画中画'**
  String get playerPip;

  /// Tooltip for the exit picture-in-picture button.
  ///
  /// In zh, this message translates to:
  /// **'退出画中画'**
  String get playerExitPip;

  /// Tooltip for the danmaku button when danmaku is visible.
  ///
  /// In zh, this message translates to:
  /// **'关闭弹幕'**
  String get playerDanmakuClose;

  /// Tooltip for the danmaku button when danmaku is hidden.
  ///
  /// In zh, this message translates to:
  /// **'开启弹幕'**
  String get playerDanmakuOpen;

  /// Tooltip for the playback details button.
  ///
  /// In zh, this message translates to:
  /// **'播放详细信息'**
  String get playerPlaybackDetailsTooltip;

  /// Toast shown after the intro/credits skip configuration is saved successfully.
  ///
  /// In zh, this message translates to:
  /// **'设置成功'**
  String get playerSkipConfigSaved;

  /// Toast shown when saving the skip configuration fails, with the error.
  ///
  /// In zh, this message translates to:
  /// **'设置失败: {error}'**
  String playerSkipConfigSaveFailed(String error);

  /// Toast shown when the danmaku API request fails.
  ///
  /// In zh, this message translates to:
  /// **'请求弹幕接口失败，请检查飞鲸服务端配置'**
  String get playerDanmakuRequestFailed;

  /// Toast shown when the smart intro/credits analysis API request fails.
  ///
  /// In zh, this message translates to:
  /// **'请求智能片头片尾接口失败，请检查飞鲸服务端配置'**
  String get playerSmartSkipRequestFailed;

  /// Toast shown when a not-yet-implemented feature is invoked, with the feature name.
  ///
  /// In zh, this message translates to:
  /// **'{feature} 暂未接入'**
  String playerFeatureComingSoon(String feature);

  /// Live player error message shown when playback fails, suggesting switching lines.
  ///
  /// In zh, this message translates to:
  /// **'播放出错,请尝试切换线路'**
  String get playerPlayErrorRetrySwitch;

  /// Live player error message shown when the channel has no available playback line.
  ///
  /// In zh, this message translates to:
  /// **'该频道没有可用的播放线路'**
  String get playerNoPlayableLine;

  /// Live player error message shown when loading fails, suggesting going back and retrying.
  ///
  /// In zh, this message translates to:
  /// **'加载失败,请返回重试'**
  String get playerLoadFailedBackRetry;

  /// Live player error message shown when playback fails, suggesting switching lines.
  ///
  /// In zh, this message translates to:
  /// **'播放失败,请尝试切换线路'**
  String get playerPlayFailedSwitchLine;

  /// Badge text shown while a live stream is playing.
  ///
  /// In zh, this message translates to:
  /// **'直播中'**
  String get playerLive;

  /// Tooltip for the pause button.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get playerPause;

  /// Tooltip for the play button.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get playerPlay;

  /// Tooltip for the danmaku settings control-bar button.
  ///
  /// In zh, this message translates to:
  /// **'弹幕设置'**
  String get playerDanmakuSettingsTooltip;

  /// Title of the danmaku settings flyout.
  ///
  /// In zh, this message translates to:
  /// **'弹幕设置'**
  String get playerDanmakuSettingsTitle;

  /// Action label that opens the advanced danmaku settings page.
  ///
  /// In zh, this message translates to:
  /// **'高级设置'**
  String get playerDanmakuAdvancedSettings;

  /// Label of the danmaku display-area slider.
  ///
  /// In zh, this message translates to:
  /// **'显示区域 {value}%'**
  String playerDanmakuDisplayArea(String value);

  /// Label of the danmaku opacity slider.
  ///
  /// In zh, this message translates to:
  /// **'不透明度 {value}%'**
  String playerDanmakuOpacity(String value);

  /// Label of the danmaku font-size slider.
  ///
  /// In zh, this message translates to:
  /// **'字号 {value}%'**
  String playerDanmakuFontSize(String value);

  /// Label of the danmaku speed slider.
  ///
  /// In zh, this message translates to:
  /// **'速度 {value}'**
  String playerDanmakuSpeed(String value);

  /// Danmaku speed label for the slowest speed step.
  ///
  /// In zh, this message translates to:
  /// **'极慢'**
  String get playerDanmakuSpeedVerySlow;

  /// Danmaku speed label for a slower-than-normal speed step.
  ///
  /// In zh, this message translates to:
  /// **'较慢'**
  String get playerDanmakuSpeedSlow;

  /// Danmaku speed label for the normal speed step.
  ///
  /// In zh, this message translates to:
  /// **'适中'**
  String get playerDanmakuSpeedNormal;

  /// Danmaku speed label for a faster-than-normal speed step.
  ///
  /// In zh, this message translates to:
  /// **'较快'**
  String get playerDanmakuSpeedFast;

  /// Danmaku speed label for the fastest speed step.
  ///
  /// In zh, this message translates to:
  /// **'极快'**
  String get playerDanmakuSpeedVeryFast;

  /// Toggle title for syncing danmaku speed with playback rate.
  ///
  /// In zh, this message translates to:
  /// **'弹幕速度同步播放倍速'**
  String get playerDanmakuSyncPlaybackSpeed;

  /// Toggle title for showing danmaku debug information.
  ///
  /// In zh, this message translates to:
  /// **'显示弹幕调试信息'**
  String get playerDanmakuShowDebugInfo;

  /// Hover tip shown on the cloud icon for STRM media that is playing via direct link.
  ///
  /// In zh, this message translates to:
  /// **'正在直连播放 STRM 文件'**
  String get playerStrmDirectPlaying;

  /// Description under the direct-link play mode card (faster, saves bandwidth).
  ///
  /// In zh, this message translates to:
  /// **'速度较快、省流'**
  String get playerCloudModeDirectDescription;

  /// Description under the NAS proxy play mode card (try switching when color or audio is abnormal).
  ///
  /// In zh, this message translates to:
  /// **'色调或音频异常时可尝试切换'**
  String get playerCloudModeNasProxyDescription;

  /// Badge marking the recommended play mode card.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get playerCloudPlayRecommend;

  /// Notice that a netdisk file is playing and that speed/quality follow the netdisk provider's rules.
  ///
  /// In zh, this message translates to:
  /// **'正在播放网盘上的文件，播放速度和画质取决于网盘方规则。'**
  String get playerCloudPlayingNotice;

  /// Hint suggesting the user switch the play mode when playback is abnormal.
  ///
  /// In zh, this message translates to:
  /// **'如遇播放异常，可尝试切换播放方式。'**
  String get playerCloudSwitchNotice;

  /// Section label of the play-mode selector flyout.
  ///
  /// In zh, this message translates to:
  /// **'播放方式'**
  String get playerPlayModeLabel;

  /// Fallback account name shown in the cloud flyout when the masked nickname is empty.
  ///
  /// In zh, this message translates to:
  /// **'网盘'**
  String get playerCloudFallbackName;

  /// Generic title on the cloud playback error page.
  ///
  /// In zh, this message translates to:
  /// **'抱歉，播放出错了'**
  String get playerCloudPlayErrorTitle;

  /// Error page action button that switches to another quality.
  ///
  /// In zh, this message translates to:
  /// **'播放其他画质'**
  String get playerCloudSwitchQuality;

  /// Error page action button that switches to NAS proxy playback.
  ///
  /// In zh, this message translates to:
  /// **'切换 NAS 代理播放'**
  String get playerCloudSwitchToProxy;

  /// Cause hint on the STRM playback error page.
  ///
  /// In zh, this message translates to:
  /// **'STRM 直连播放异常，可能原因：网盘挂载连接断开、触发网盘风控、网盘限制非会员操作、浏览器不支持该文件类型。'**
  String get playerStrmPlaybackErrorHint;

  /// Fallback line label shown by the live channel selector when no channel name is available.
  ///
  /// In zh, this message translates to:
  /// **'线路'**
  String get playerChannelLineFallback;

  /// Title of the subtitle search dialog for adding subtitles.
  ///
  /// In zh, this message translates to:
  /// **'添加字幕'**
  String get playerSubtitleAddDialogTitle;

  /// Hint shown above the subtitle search results explaining they are sorted by relevance.
  ///
  /// In zh, this message translates to:
  /// **'按相关度排序：'**
  String get playerSubtitleSearchSortHint;

  /// Empty-state text shown when a subtitle search returns no results.
  ///
  /// In zh, this message translates to:
  /// **'未搜索到相关字幕'**
  String get playerSubtitleSearchNoResults;

  /// Download count shown next to a subtitle search result.
  ///
  /// In zh, this message translates to:
  /// **'下载量 {count}'**
  String playerSubtitleSearchDownloadCount(String count);

  /// Label of the subtitle download button while a download is in progress.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get playerSubtitleSearchDownloading;

  /// Label of the subtitle download button once the download has finished.
  ///
  /// In zh, this message translates to:
  /// **'下载完成'**
  String get playerSubtitleSearchDownloadDone;

  /// Label of the button that downloads a subtitle from the search results.
  ///
  /// In zh, this message translates to:
  /// **'下载字幕'**
  String get playerSubtitleSearchDownload;

  /// Label of the button that downloads a similar subtitle for the other episodes of a series.
  ///
  /// In zh, this message translates to:
  /// **'为其他集下载相似字幕'**
  String get playerSubtitleDownloadSimilarForEpisodes;

  /// Display label of the Simplified Chinese subtitle search language option.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get playerSubtitleLanguageSimplifiedChinese;

  /// Display label of the English subtitle search language option.
  ///
  /// In zh, this message translates to:
  /// **'英文'**
  String get playerSubtitleLanguageEnglish;

  /// Title of the subtitle adjustment panel.
  ///
  /// In zh, this message translates to:
  /// **'调整字幕'**
  String get playerSubtitleAdjust;

  /// Label of the button that resets subtitle adjustments to their defaults.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get playerSubtitleReset;

  /// Title of the subtitle timing offset adjustment slider.
  ///
  /// In zh, this message translates to:
  /// **'偏移'**
  String get playerSubtitleOffset;

  /// Left label of the subtitle offset slider (minus five seconds).
  ///
  /// In zh, this message translates to:
  /// **'-5秒'**
  String get playerSubtitleOffsetMin;

  /// Right label of the subtitle offset slider (plus five seconds).
  ///
  /// In zh, this message translates to:
  /// **'+5秒'**
  String get playerSubtitleOffsetMax;

  /// Unit suffix shown next to the subtitle offset input value.
  ///
  /// In zh, this message translates to:
  /// **'秒'**
  String get playerSubtitleSecondsSuffix;

  /// Title of the subtitle vertical position adjustment slider.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get playerSubtitlePosition;

  /// Left label of the subtitle position slider (bottom).
  ///
  /// In zh, this message translates to:
  /// **'底部'**
  String get playerSubtitlePositionBottom;

  /// Right label of the subtitle position slider (top).
  ///
  /// In zh, this message translates to:
  /// **'顶部'**
  String get playerSubtitlePositionTop;

  /// Hint shown when the subtitle position slider is disabled because the subtitle is a danmaku or ASS effect subtitle with positioning tags.
  ///
  /// In zh, this message translates to:
  /// **'当前字幕为弹幕/特效字幕（含定位标签），位置调整不可用'**
  String get playerSubtitlePositionLockedHint;

  /// Title of the subtitle font size adjustment slider.
  ///
  /// In zh, this message translates to:
  /// **'字号'**
  String get playerSubtitleFontSize;

  /// Left label of the subtitle font size slider (minimum).
  ///
  /// In zh, this message translates to:
  /// **'最小'**
  String get playerSubtitleFontSizeMin;

  /// Right label of the subtitle font size slider (maximum).
  ///
  /// In zh, this message translates to:
  /// **'最大'**
  String get playerSubtitleFontSizeMax;

  /// Title of the subtitle selection panel.
  ///
  /// In zh, this message translates to:
  /// **'字幕'**
  String get playerSubtitlePanelTitle;

  /// Label of the button that opens the subtitle adjustment panel.
  ///
  /// In zh, this message translates to:
  /// **'调整'**
  String get playerSubtitleAdjustButton;

  /// Label of the button that opens the add-subtitle menu.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get playerSubtitleAddButton;

  /// Label of the list row that turns off subtitles.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get playerSubtitleOff;

  /// Menu item that opens the subtitle search dialog.
  ///
  /// In zh, this message translates to:
  /// **'搜索字幕'**
  String get playerSubtitleSearchMenu;

  /// Menu item that adds a subtitle file stored on the NAS.
  ///
  /// In zh, this message translates to:
  /// **'添加 NAS 字幕文件'**
  String get playerSubtitleAddNasFile;

  /// Menu item that adds a subtitle file stored on the local computer.
  ///
  /// In zh, this message translates to:
  /// **'添加电脑字幕文件'**
  String get playerSubtitleAddLocalFile;

  /// Label shown at the bottom of the subtitle panel when built-in subtitles cannot be fetched during direct-link transcoded playback.
  ///
  /// In zh, this message translates to:
  /// **'直连播放缺失内置字幕'**
  String get playerSubtitleDirectLinkMissingTitle;

  /// Bubble hint explaining why built-in subtitles are missing and how to switch playback mode.
  ///
  /// In zh, this message translates to:
  /// **'由于网盘方的限制，直连转码播放时可能无法获取内置字幕列表。如需切换内置字幕，请切换播放方式为“NAS 代理播放”。'**
  String get playerSubtitleDirectLinkMissingContent;

  /// Separator placed between a playback details field label and its value.
  ///
  /// In zh, this message translates to:
  /// **'：'**
  String get playerDetailSeparator;

  /// Playback details field label for the current play type.
  ///
  /// In zh, this message translates to:
  /// **'播放类型'**
  String get playerPlayType;

  /// Play type value for a STRM file played via direct link.
  ///
  /// In zh, this message translates to:
  /// **'STRM 直连播放'**
  String get playerPlayTypeStrmDirect;

  /// Play type value for a transcoded playback session.
  ///
  /// In zh, this message translates to:
  /// **'转码播放'**
  String get playerPlayTypeTranscode;

  /// Play type value for direct playback of a local file.
  ///
  /// In zh, this message translates to:
  /// **'直接播放'**
  String get playerPlayTypeDirect;

  /// Playback details field label for the transcoding reasons.
  ///
  /// In zh, this message translates to:
  /// **'转码原因'**
  String get playerTranscodeReason;

  /// Separator joining multiple transcoding reasons.
  ///
  /// In zh, this message translates to:
  /// **'；'**
  String get playerTranscodeReasonSeparator;

  /// Section heading for live playback statistics.
  ///
  /// In zh, this message translates to:
  /// **'播放信息'**
  String get playerPlaybackInfo;

  /// Section heading for media source information.
  ///
  /// In zh, this message translates to:
  /// **'媒体源信息'**
  String get playerMediaSourceInfo;

  /// Playback details field label for the container format.
  ///
  /// In zh, this message translates to:
  /// **'封装容器'**
  String get playerContainerFormat;

  /// Playback details field label for the buffer duration.
  ///
  /// In zh, this message translates to:
  /// **'缓冲时长'**
  String get playerBufferDuration;

  /// Playback details field label for the audio codec.
  ///
  /// In zh, this message translates to:
  /// **'音频编码'**
  String get playerAudioCodec;

  /// Playback details field label for the GPU in use.
  ///
  /// In zh, this message translates to:
  /// **'启用 GPU'**
  String get playerGpuEnabled;

  /// Playback details field label for the decode method.
  ///
  /// In zh, this message translates to:
  /// **'解码方式'**
  String get playerDecodeMethod;

  /// Playback details field label for the encode method.
  ///
  /// In zh, this message translates to:
  /// **'编码方式'**
  String get playerEncodeMethod;

  /// Playback details field label for the transcode frame rate.
  ///
  /// In zh, this message translates to:
  /// **'转码帧率'**
  String get playerTranscodeFrameRate;

  /// Playback details field label for the dropped frame count.
  ///
  /// In zh, this message translates to:
  /// **'丢帧'**
  String get playerDroppedFrames;

  /// Playback details field label for the corrupted frame count.
  ///
  /// In zh, this message translates to:
  /// **'坏帧'**
  String get playerCorruptedFrames;

  /// Media source stream field label for the codec.
  ///
  /// In zh, this message translates to:
  /// **'编码'**
  String get playerCodec;

  /// Media source stream field label for the dynamic range.
  ///
  /// In zh, this message translates to:
  /// **'动态范围'**
  String get playerDynamicRange;

  /// Tooltip of the fullscreen button when the player is not in fullscreen mode.
  ///
  /// In zh, this message translates to:
  /// **'进入全屏'**
  String get playerFullscreenEnter;

  /// Tooltip of the fullscreen button when the player is in fullscreen mode.
  ///
  /// In zh, this message translates to:
  /// **'退出全屏'**
  String get playerFullscreenExit;

  /// Label and tooltip of the next-episode button in the player.
  ///
  /// In zh, this message translates to:
  /// **'下一个视频'**
  String get playerNextVideo;

  /// Episode number label shown in the player episode list.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 集'**
  String playerEpisodeNumber(String number);

  /// Label of the replay button on the playback end overlay.
  ///
  /// In zh, this message translates to:
  /// **'重播'**
  String get playerReplay;

  /// Label of the undo action on the auto-skipped intro prompt.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get playerUndo;

  /// Message shown on the prompt after the intro was auto-skipped.
  ///
  /// In zh, this message translates to:
  /// **'已自动跳过片头'**
  String get playerSkipIntroAutoSkipped;

  /// Outro prompt message shown when autoplay is off or credits have post-credits content.
  ///
  /// In zh, this message translates to:
  /// **'{seconds} 秒后跳过片尾'**
  String playerSkipOutroInSeconds(int seconds);

  /// Outro prompt message shown when the next episode is ready to autoplay.
  ///
  /// In zh, this message translates to:
  /// **'{seconds} 秒后播放下一集'**
  String playerSkipOutroNextEpisodeInSeconds(int seconds);

  /// Outro prompt message shown when playback will simply stop.
  ///
  /// In zh, this message translates to:
  /// **'{seconds} 秒后结束播放'**
  String playerSkipOutroEndInSeconds(int seconds);

  /// Fallback label for an unknown audio track language or episode title.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get playerUnknown;

  /// Audio track primary label suffix marking the track as the default one.
  ///
  /// In zh, this message translates to:
  /// **'{language} - 默认'**
  String playerAudioDefaultSuffix(String language);

  /// Value of the window aspect ratio setting when it follows the video.
  ///
  /// In zh, this message translates to:
  /// **'跟随视频比例'**
  String get playerSettingsWindowAspectRatioFollowVideo;

  /// Value of the video fill mode setting meaning the original aspect ratio.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get playerSettingsAspectRatioDefault;

  /// Title of the player settings main panel; opens the advanced settings.
  ///
  /// In zh, this message translates to:
  /// **'高级'**
  String get playerSettingsAdvanced;

  /// Player setting label for automatically playing the next episode.
  ///
  /// In zh, this message translates to:
  /// **'自动连播'**
  String get playerSettingsAutoNext;

  /// Player setting label for the skip intro and outro configuration.
  ///
  /// In zh, this message translates to:
  /// **'跳过片头/片尾'**
  String get playerSettingsSkipIntroOutro;

  /// Player setting label and screen title for the window aspect ratio.
  ///
  /// In zh, this message translates to:
  /// **'窗口比例'**
  String get playerSettingsWindowRatio;

  /// Player setting label and screen title for the video fill mode.
  ///
  /// In zh, this message translates to:
  /// **'画面比例'**
  String get playerSettingsAspectRatio;

  /// Player setting label and screen title for the decode mode.
  ///
  /// In zh, this message translates to:
  /// **'客户端解码模式'**
  String get playerSettingsClientDecodeMode;

  /// Player settings audio option label and audio screen title.
  ///
  /// In zh, this message translates to:
  /// **'音频'**
  String get playerSettingsAudio;

  /// Audio screen top-right entry label and the audio-passthrough switch title.
  ///
  /// In zh, this message translates to:
  /// **'音频直通'**
  String get playerSettingsAudioPassthrough;

  /// Header title of the audio-passthrough settings screen.
  ///
  /// In zh, this message translates to:
  /// **'音频直通'**
  String get playerSettingsAudioPassthroughTitle;

  /// Description under the audio-passthrough switch.
  ///
  /// In zh, this message translates to:
  /// **'将 AC3/DTS/EAC3/TrueHD 等压缩音频流原样输出到 HDMI/S-PDIF 外接设备解码。仅对原始音轨的直链播放生效，转码音轨会自动回落为本地解码。'**
  String get playerSettingsAudioPassthroughDescription;

  /// Audio output device entry label and sub-page title.
  ///
  /// In zh, this message translates to:
  /// **'输出设备'**
  String get playerSettingsAudioOutputDevice;

  /// Label of the automatic (system default) audio output device option.
  ///
  /// In zh, this message translates to:
  /// **'自动（默认）'**
  String get playerSettingsAudioOutputDeviceAuto;

  /// Shown when mpv enumerates no audio output devices.
  ///
  /// In zh, this message translates to:
  /// **'未检测到可用的音频输出设备'**
  String get playerSettingsAudioOutputDeviceEmpty;

  /// Header title of the player advanced settings screen.
  ///
  /// In zh, this message translates to:
  /// **'高级设置'**
  String get playerSettingsAdvancedTitle;

  /// Advanced player setting title toggling HEVC to H.264 transcoding.
  ///
  /// In zh, this message translates to:
  /// **'HEVC 转为 H.264'**
  String get playerSettingsHevcToH264;

  /// Description of the HEVC to H.264 advanced player setting.
  ///
  /// In zh, this message translates to:
  /// **'播放有声音无画面时可尝试开启'**
  String get playerSettingsHevcToH264Description;

  /// Advanced player setting title forcing tone mapping to SDR.
  ///
  /// In zh, this message translates to:
  /// **'色调强制映射为 SDR'**
  String get playerSettingsForceSdr;

  /// Description of the force SDR advanced player setting.
  ///
  /// In zh, this message translates to:
  /// **'画面偏暗时可尝试开启，适用于不支持 HDR 的设备'**
  String get playerSettingsForceSdrDescription;

  /// Advanced player setting title enabling Quark CDN segment direct link.
  ///
  /// In zh, this message translates to:
  /// **'夸克 CDN 分片直连'**
  String get playerSettingsQuarkCdnSegment;

  /// Description of the Quark CDN segment direct link advanced player setting.
  ///
  /// In zh, this message translates to:
  /// **'开启后按分片预取夸克网盘直连流；关闭则使用原有直连方式'**
  String get playerSettingsQuarkCdnSegmentDescription;

  /// Value shown when smart skip is enabled for the intro/outro configuration.
  ///
  /// In zh, this message translates to:
  /// **'智能跳过'**
  String get playerSettingsSmartSkip;

  /// Value shown when both a manual intro and outro are configured.
  ///
  /// In zh, this message translates to:
  /// **'跳过片头片尾'**
  String get playerSettingsSkipIntroOutroBoth;

  /// Value shown when only a manual intro is configured.
  ///
  /// In zh, this message translates to:
  /// **'已设置片头'**
  String get playerSettingsIntroConfigured;

  /// Value shown when only a manual outro is configured.
  ///
  /// In zh, this message translates to:
  /// **'已设置片尾'**
  String get playerSettingsOutroConfigured;

  /// Value shown when no intro/outro configuration exists.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get playerSettingsNotSet;

  /// Scope line of the skip intro/outro settings, with the series title and season number.
  ///
  /// In zh, this message translates to:
  /// **'生效范围: 《{title}》 第 {season} 季'**
  String playerSettingsSkipScope(String title, String season);

  /// Toggle title enabling smart intro/outro skipping.
  ///
  /// In zh, this message translates to:
  /// **'智能跳过片头/片尾'**
  String get playerSettingsSmartSkipIntroOutro;

  /// Label of the intro duration slider.
  ///
  /// In zh, this message translates to:
  /// **'片头时长'**
  String get playerSettingsIntroDuration;

  /// Label of the outro duration slider.
  ///
  /// In zh, this message translates to:
  /// **'片尾时长'**
  String get playerSettingsOutroDuration;

  /// One-click shortcut button label setting the outro to the current remaining time.
  ///
  /// In zh, this message translates to:
  /// **'将当前剩余时长 {time} 设为片尾'**
  String playerSettingsSetOutroToRemaining(String time);

  /// One-click shortcut button label setting the intro to the current time.
  ///
  /// In zh, this message translates to:
  /// **'将当前时间 {time} 设为片头'**
  String playerSettingsSetIntroToCurrent(String time);

  /// Slider boundary caption for a ten minute range.
  ///
  /// In zh, this message translates to:
  /// **'10 分钟'**
  String get playerSettingsTenMinutes;

  /// Slider start boundary caption.
  ///
  /// In zh, this message translates to:
  /// **'开始'**
  String get playerSettingsSliderStart;

  /// Slider end boundary caption.
  ///
  /// In zh, this message translates to:
  /// **'结束'**
  String get playerSettingsSliderEnd;

  /// Tooltip describing the automatic decode mode.
  ///
  /// In zh, this message translates to:
  /// **'自动选择硬件解码,失败时回退到软件解码。推荐。'**
  String get playerSettingsDecodeAutoTip;

  /// Tooltip describing the software decode mode.
  ///
  /// In zh, this message translates to:
  /// **'强制使用软件解码,兼容性最好;硬解花屏/黑屏时的兜底方案。'**
  String get playerSettingsDecodeSoftwareTip;

  /// Tooltip describing the copy-back decode mode.
  ///
  /// In zh, this message translates to:
  /// **'硬件解码但将帧拷回内存,可与所有滤镜/弹幕/截图功能共存;略费 CPU。'**
  String get playerSettingsDecodeCopyTip;

  /// Decode mode option using software decoding.
  ///
  /// In zh, this message translates to:
  /// **'软件解码'**
  String get playerSettingsSoftwareDecode;

  /// Decode mode option copying hardware-decoded frames back to memory.
  ///
  /// In zh, this message translates to:
  /// **'回拷模式'**
  String get playerSettingsCopyBackMode;

  /// Decode mode option and screen title for choosing a specific hardware decoder.
  ///
  /// In zh, this message translates to:
  /// **'指定硬件解码器'**
  String get playerSettingsSpecifyHwdec;

  /// Empty-state message when no hardware decoder was probed as usable.
  ///
  /// In zh, this message translates to:
  /// **'未探测到可用的硬件解码器'**
  String get playerSettingsNoHwdecAvailable;

  /// Header of the video quality selection panel in the player.
  ///
  /// In zh, this message translates to:
  /// **'视频质量'**
  String get playerQualityTitle;

  /// Label for the original (highest) video quality option.
  ///
  /// In zh, this message translates to:
  /// **'原画'**
  String get playerQualityOriginal;

  /// Label for the custom video quality entry that opens the fine-grained picker.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get playerQualityCustom;

  /// Title of the custom video quality selection page.
  ///
  /// In zh, this message translates to:
  /// **'自定义视频质量'**
  String get playerQualityCustomTitle;

  /// Tooltip shown on a disabled quality option that direct-link playback does not support.
  ///
  /// In zh, this message translates to:
  /// **'直连播放暂不支持该画质'**
  String get playerQualityDirectUnsupported;

  /// Hint in the cloud direct-link quality panel explaining the low-risk marked option.
  ///
  /// In zh, this message translates to:
  /// **'选项风控概率相对低，建议优先选择'**
  String get playerQualityLowRiskHint;

  /// Short hint title warning that the original quality may have no sound in direct-link playback.
  ///
  /// In zh, this message translates to:
  /// **'直连播放原画无声音'**
  String get playerQualityOriginalNoAudioHint;

  /// Tooltip explaining why the original quality may have no sound in direct-link playback and how to work around it.
  ///
  /// In zh, this message translates to:
  /// **'由于播放器对音频编码格式的支持有限，直连播放原画可能出现无声音的情况。可尝试切换播放方式为 “NAS 代理播放”。'**
  String get playerQualityOriginalNoAudioTooltip;

  /// Neutral label for the playback speed control at the default speed.
  ///
  /// In zh, this message translates to:
  /// **'倍速'**
  String get playerSpeedLabel;

  /// Decode mode option that automatically selects hardware decoding.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get playerSettingsAuto;

  /// Lower quality per video quality setting
  ///
  /// In zh, this message translates to:
  /// **'根据视频质量设置降低画质'**
  String get playerTranscodeReasonLowerQuality;

  /// Subtitle burn-in
  ///
  /// In zh, this message translates to:
  /// **'字幕烧录'**
  String get playerTranscodeReasonSubtitleBurn;

  /// Subtitle converted to vtt segments
  ///
  /// In zh, this message translates to:
  /// **'字幕转为 vtt 切片'**
  String get playerTranscodeReasonSubtitleToVtt;

  /// Video format conversion
  ///
  /// In zh, this message translates to:
  /// **'视频格式转换'**
  String get playerTranscodeReasonVideoFormat;

  /// Audio format conversion
  ///
  /// In zh, this message translates to:
  /// **'音频格式转换'**
  String get playerTranscodeReasonAudioFormat;

  /// Tone mapping
  ///
  /// In zh, this message translates to:
  /// **'色调映射'**
  String get playerTranscodeReasonToneMapping;

  /// Software decoding
  ///
  /// In zh, this message translates to:
  /// **'软解码'**
  String get playerDecodeMethodSoftware;

  /// QSV decoding
  ///
  /// In zh, this message translates to:
  /// **'QSV 解码'**
  String get playerDecodeMethodQsv;

  /// VAAPI decoding
  ///
  /// In zh, this message translates to:
  /// **'VAAPI 解码'**
  String get playerDecodeMethodVaapi;

  /// NVDEC decoding
  ///
  /// In zh, this message translates to:
  /// **'NVDEC 解码'**
  String get playerDecodeMethodNvdec;

  /// RKMPP decoding
  ///
  /// In zh, this message translates to:
  /// **'RKMPP 解码'**
  String get playerDecodeMethodRkmpp;

  /// Software encoding
  ///
  /// In zh, this message translates to:
  /// **'软编码'**
  String get playerEncodeMethodSoftware;

  /// QSV encoding
  ///
  /// In zh, this message translates to:
  /// **'QSV 编码'**
  String get playerEncodeMethodQsv;

  /// QSV low-power encoding
  ///
  /// In zh, this message translates to:
  /// **'QSV 低电压编码'**
  String get playerEncodeMethodQsvLowPower;

  /// VAAPI encoding
  ///
  /// In zh, this message translates to:
  /// **'VAAPI 编码'**
  String get playerEncodeMethodVaapi;

  /// NVENC encoding
  ///
  /// In zh, this message translates to:
  /// **'NVENC 编码'**
  String get playerEncodeMethodNvenc;

  /// RKMPP encoding
  ///
  /// In zh, this message translates to:
  /// **'RKMPP 编码'**
  String get playerEncodeMethodRkmpp;

  /// Toast shown immediately after queueing a season analysis.
  ///
  /// In zh, this message translates to:
  /// **'片头/片尾分析任务已提交'**
  String get smartAnalysisQueuedLoading;

  /// Rejection message when the media backend cannot be analyzed.
  ///
  /// In zh, this message translates to:
  /// **'网盘或 STRM 视频无法使用“智能分析片头/片尾”功能'**
  String get smartAnalysisCloudOrStrmRejected;

  /// Skip-segment kind name.
  ///
  /// In zh, this message translates to:
  /// **'片头'**
  String get playerSkipSegmentIntro;

  /// Skip-segment kind name.
  ///
  /// In zh, this message translates to:
  /// **'前情提要'**
  String get playerSkipSegmentRecap;

  /// Skip-segment kind name.
  ///
  /// In zh, this message translates to:
  /// **'片尾'**
  String get playerSkipSegmentOutro;

  /// Skip-segment kind name.
  ///
  /// In zh, this message translates to:
  /// **'下集预告'**
  String get playerSkipSegmentPreview;

  /// Skip-segment kind name.
  ///
  /// In zh, this message translates to:
  /// **'广告'**
  String get playerSkipSegmentCommercial;

  /// Fallback skip-segment kind name.
  ///
  /// In zh, this message translates to:
  /// **'片段'**
  String get playerSkipSegmentGeneric;

  /// Joins several skip-segment names; keep the connector language-specific.
  ///
  /// In zh, this message translates to:
  /// **'{parts}'**
  String playerSkipSegmentJoined(String parts);

  /// Countdown before auto-skipping a segment.
  ///
  /// In zh, this message translates to:
  /// **'{seconds} 秒后跳过{subject}'**
  String playerSkipSegmentInSeconds(String seconds, String subject);

  /// Toast after automatically skipping a segment.
  ///
  /// In zh, this message translates to:
  /// **'已自动跳过{subject}'**
  String playerSkipAutoSkipped(String subject);

  /// Smart-skip switch label.
  ///
  /// In zh, this message translates to:
  /// **'跳过前情提要'**
  String get playerSettingsSkipRecap;

  /// Smart-skip switch label.
  ///
  /// In zh, this message translates to:
  /// **'跳过下集预告'**
  String get playerSettingsSkipPreview;

  /// Smart-skip switch label.
  ///
  /// In zh, this message translates to:
  /// **'跳过广告'**
  String get playerSettingsSkipCommercial;

  /// Menu entry that opens the smart-skip config dialog.
  ///
  /// In zh, this message translates to:
  /// **'智能跳过配置'**
  String get playerSettingsSmartSkipConfig;

  /// Smart-skip switch label.
  ///
  /// In zh, this message translates to:
  /// **'跳过片头'**
  String get playerSettingsSkipIntroOnly;

  /// Smart-skip switch label.
  ///
  /// In zh, this message translates to:
  /// **'跳过片尾'**
  String get playerSettingsSkipOutroOnly;

  /// Separator joining several skip-segment names.
  ///
  /// In zh, this message translates to:
  /// **'与'**
  String get playerSkipSegmentConnector;

  /// Title of the smart-skip configuration dialog.
  ///
  /// In zh, this message translates to:
  /// **'智能跳过配置'**
  String get smartSkipConfigTitle;

  /// Dialog primary action.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get smartSkipSave;

  /// Toast after saving the configuration.
  ///
  /// In zh, this message translates to:
  /// **'智能跳过配置已保存'**
  String get smartSkipSaved;

  /// Title shown when saving fails.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get smartSkipSaveFailed;

  /// Shown when the user is not signed in.
  ///
  /// In zh, this message translates to:
  /// **'请先登录后配置'**
  String get smartSkipLoginRequired;

  /// Banner when server config cannot be loaded.
  ///
  /// In zh, this message translates to:
  /// **'服务端配置加载失败，当前展示默认配置'**
  String get smartSkipLoadFailed;

  /// Section heading.
  ///
  /// In zh, this message translates to:
  /// **'检测模式'**
  String get smartSkipDetectMode;

  /// Detection-mode option.
  ///
  /// In zh, this message translates to:
  /// **'动漫模式'**
  String get smartSkipAnimeMode;

  /// Detection-mode option.
  ///
  /// In zh, this message translates to:
  /// **'优先指纹匹配'**
  String get smartSkipPreferChromaprint;

  /// Detection-mode option.
  ///
  /// In zh, this message translates to:
  /// **'备用黑帧分析器'**
  String get smartSkipAlternativeBlackFrame;

  /// Detection toggle.
  ///
  /// In zh, this message translates to:
  /// **'检测片头'**
  String get smartSkipDetectIntro;

  /// Detection toggle.
  ///
  /// In zh, this message translates to:
  /// **'检测片尾'**
  String get smartSkipDetectOutro;

  /// Detection toggle.
  ///
  /// In zh, this message translates to:
  /// **'检测前情提要'**
  String get smartSkipDetectRecap;

  /// Detection toggle.
  ///
  /// In zh, this message translates to:
  /// **'检测下集预告'**
  String get smartSkipDetectPreview;

  /// Detection toggle.
  ///
  /// In zh, this message translates to:
  /// **'检测广告'**
  String get smartSkipDetectCommercial;

  /// Heading of the advanced settings section.
  ///
  /// In zh, this message translates to:
  /// **'高级'**
  String get smartSkipAdvanced;

  /// Field label.
  ///
  /// In zh, this message translates to:
  /// **'时长限制（秒）'**
  String get smartSkipDurationLimit;

  /// Field label.
  ///
  /// In zh, this message translates to:
  /// **'边界偏移（秒）'**
  String get smartSkipBoundaryOffset;

  /// Field label.
  ///
  /// In zh, this message translates to:
  /// **'片头开始偏移'**
  String get smartSkipIntroStartOffset;

  /// Field label.
  ///
  /// In zh, this message translates to:
  /// **'片头结束偏移'**
  String get smartSkipIntroEndOffset;

  /// Field label.
  ///
  /// In zh, this message translates to:
  /// **'片头最短时长'**
  String get smartSkipIntroMinDuration;

  /// Field label.
  ///
  /// In zh, this message translates to:
  /// **'片头最长时长'**
  String get smartSkipIntroMaxDuration;

  /// Field label.
  ///
  /// In zh, this message translates to:
  /// **'片尾最短时长'**
  String get smartSkipOutroMinDuration;

  /// Field label.
  ///
  /// In zh, this message translates to:
  /// **'片尾最长时长'**
  String get smartSkipOutroMaxDuration;

  /// Field label.
  ///
  /// In zh, this message translates to:
  /// **'片尾结束偏移'**
  String get smartSkipOutroEndOffset;

  /// Dialog action.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get smartSkipRestoreDefaults;

  /// Smart-skip switch label.
  ///
  /// In zh, this message translates to:
  /// **'跳过片头'**
  String get playerSettingsSmartSkipIntro;

  /// Smart-skip switch label.
  ///
  /// In zh, this message translates to:
  /// **'跳过片尾'**
  String get playerSettingsSmartSkipOutro;

  /// Toast when submitting season analysis fails.
  ///
  /// In zh, this message translates to:
  /// **'分析请求提交失败，请稍后重试'**
  String get smartSkipAnalysisFailedRetry;

  /// Error shown when loading the config fails.
  ///
  /// In zh, this message translates to:
  /// **'加载智能跳过配置失败'**
  String get smartSkipLoadConfigFailed;

  /// Error shown when saving the config fails.
  ///
  /// In zh, this message translates to:
  /// **'保存智能跳过配置失败'**
  String get smartSkipSaveConfigFailed;

  /// Button that opens the smart skip config dialog.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get smartSkipConfigConfigure;

  /// Caption under the smart skip config row.
  ///
  /// In zh, this message translates to:
  /// **'服务端智能分析片头片尾的参数'**
  String get settingsSmartSkipConfigCaption;

  /// Heading of the dandanplay danmu source card in server settings.
  ///
  /// In zh, this message translates to:
  /// **'弹弹play 弹幕源'**
  String get settingsDanmuDandanSource;

  /// Caption under the dandanplay source card.
  ///
  /// In zh, this message translates to:
  /// **'配置弹弹play官方服务与中转服务，可分别启用并指定优先使用的来源'**
  String get settingsDanmuDandanSourceCaption;

  /// Heading of the fallback danmu servers card.
  ///
  /// In zh, this message translates to:
  /// **'兜底弹幕服务器'**
  String get settingsDanmuFallbackServers;

  /// Caption under the fallback servers card.
  ///
  /// In zh, this message translates to:
  /// **'所有直连弹幕源为空时，按顺序尝试已启用的第三方服务器'**
  String get settingsDanmuFallbackServersCaption;

  /// Hover tip explaining what to add and when fallback servers are used.
  ///
  /// In zh, this message translates to:
  /// **'当服务端为影片找不到弹幕时，会按顺序依次尝试这里添加的第三方弹幕服务器。请填写兼容弹弹play协议的弹幕服务地址（以 http:// 或 https:// 开头的完整网址）；只有开启的服务器才会被尝试。'**
  String get settingsDanmuFallbackServersHelp;

  /// Button that opens the fallback servers dialog.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get danmuSourceConfigure;

  /// Save button in danmu source config UI.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get danmuSourceSave;

  /// Toast after a successful save.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get danmuSourceSaved;

  /// Toast after a successful delete.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get danmuSourceDeleted;

  /// Title of the fallback servers management dialog.
  ///
  /// In zh, this message translates to:
  /// **'兜底弹幕服务器'**
  String get danmuSourceFallbackDialogTitle;

  /// Button to add a fallback server.
  ///
  /// In zh, this message translates to:
  /// **'添加服务器'**
  String get danmuSourceFallbackAdd;

  /// Sub-dialog title when editing a fallback server.
  ///
  /// In zh, this message translates to:
  /// **'编辑服务器'**
  String get danmuSourceFallbackEdit;

  /// Placeholder of the name field.
  ///
  /// In zh, this message translates to:
  /// **'名称（可选）'**
  String get danmuSourceFallbackNameHint;

  /// Placeholder of the URL field.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get danmuSourceFallbackUrlHint;

  /// Empty state of the fallback list.
  ///
  /// In zh, this message translates to:
  /// **'暂无兜底服务器'**
  String get danmuSourceFallbackEmpty;

  /// Title of the delete confirmation dialog.
  ///
  /// In zh, this message translates to:
  /// **'删除服务器'**
  String get danmuSourceFallbackDeleteTitle;

  /// Message of the delete confirmation dialog.
  ///
  /// In zh, this message translates to:
  /// **'确定删除“{name}”吗？'**
  String danmuSourceFallbackDeleteMessage(String name);

  /// Destructive confirm button.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get danmuSourceDelete;

  /// Inline validation error for the URL field.
  ///
  /// In zh, this message translates to:
  /// **'地址需以 http:// 或 https:// 开头'**
  String get danmuSourceUrlInvalid;

  /// Error when loading the config fails.
  ///
  /// In zh, this message translates to:
  /// **'读取弹幕源配置失败'**
  String get danmuSourceLoadFailed;

  /// Fallback error when saving fails.
  ///
  /// In zh, this message translates to:
  /// **'保存弹幕源配置失败'**
  String get danmuSourceSaveFailed;

  /// Fallback error when deleting fails.
  ///
  /// In zh, this message translates to:
  /// **'删除兜底服务器失败'**
  String get danmuSourceDeleteFailed;

  /// Label of the per-server enable toggle.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get danmuSourceEnabled;

  /// Warning when testing the relay with an empty address.
  ///
  /// In zh, this message translates to:
  /// **'请填写弹弹play中转地址'**
  String get danmuSourceRelayRequired;

  /// Warning when testing the official service with an empty AppId.
  ///
  /// In zh, this message translates to:
  /// **'请填写 AppId'**
  String get danmuSourceAppIdRequired;

  /// Warning when testing the official service with an empty AppSecret.
  ///
  /// In zh, this message translates to:
  /// **'请填写 AppSecret'**
  String get danmuSourceAppSecretRequired;

  /// Toast when the relay connectivity test passes.
  ///
  /// In zh, this message translates to:
  /// **'弹弹play中继连通'**
  String get danmuSourceRelayReachable;

  /// Toast when the relay connectivity test fails.
  ///
  /// In zh, this message translates to:
  /// **'弹弹play中继不可用'**
  String get danmuSourceRelayUnreachable;

  /// Title of the merged dandanplay source dialog.
  ///
  /// In zh, this message translates to:
  /// **'弹弹play 弹幕源'**
  String get danmuDandanDialogTitle;

  /// Heading of the official open-network card.
  ///
  /// In zh, this message translates to:
  /// **'官方服务'**
  String get danmuDandanOfficialTitle;

  /// Caption under the official card.
  ///
  /// In zh, this message translates to:
  /// **'官方开放平台，弹幕更全（含部分美剧）'**
  String get danmuDandanOfficialCaption;

  /// Heading of the relay card.
  ///
  /// In zh, this message translates to:
  /// **'中转服务'**
  String get danmuDandanRelayTitle;

  /// Caption under the relay card.
  ///
  /// In zh, this message translates to:
  /// **'通过第三方 ddp 中转访问弹弹play'**
  String get danmuDandanRelayCaption;

  /// Label of the per-source enable switch.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get danmuDandanEnable;

  /// Label of the mutually exclusive preferred-source switch.
  ///
  /// In zh, this message translates to:
  /// **'首选'**
  String get danmuDandanPreferred;

  /// Explains what the preferred switch does.
  ///
  /// In zh, this message translates to:
  /// **'优先使用该来源搜索，无匹配结果时再尝试另一个'**
  String get danmuDandanPreferredTooltip;

  /// Tooltip when the preferred switch is greyed out because the source is off.
  ///
  /// In zh, this message translates to:
  /// **'需先启用该来源'**
  String get danmuDandanPreferredNeedsEnable;

  /// Placeholder of the AppId field.
  ///
  /// In zh, this message translates to:
  /// **'AppId'**
  String get danmuDandanOfficialAppIdHint;

  /// Placeholder of the AppSecret field.
  ///
  /// In zh, this message translates to:
  /// **'AppSecret'**
  String get danmuDandanOfficialAppSecretHint;

  /// Hint telling where to register the app.
  ///
  /// In zh, this message translates to:
  /// **'在 doc.dandanplay.com/open 免费申请应用获取 AppId/AppSecret'**
  String get danmuDandanOfficialHint;

  /// Placeholder of the relay address field.
  ///
  /// In zh, this message translates to:
  /// **'https://example.com/ddp/v1'**
  String get danmuDandanRelayUrlHint;

  /// Connectivity test button on either source card.
  ///
  /// In zh, this message translates to:
  /// **'测试连通性'**
  String get danmuDandanTest;

  /// Label of the test button while a probe runs.
  ///
  /// In zh, this message translates to:
  /// **'测试中…'**
  String get danmuDandanTesting;

  /// Toast when the official API accepts the credentials.
  ///
  /// In zh, this message translates to:
  /// **'官方服务连通'**
  String get danmuDandanOfficialTestOk;

  /// Toast when the official credentials probe fails.
  ///
  /// In zh, this message translates to:
  /// **'官方服务不可用'**
  String get danmuDandanOfficialTestFailed;

  /// Toast when the relay probe passes.
  ///
  /// In zh, this message translates to:
  /// **'中转服务连通'**
  String get danmuDandanRelayTestOk;

  /// Toast when the relay probe fails.
  ///
  /// In zh, this message translates to:
  /// **'中转服务不可用'**
  String get danmuDandanRelayTestFailed;

  /// Source state in the settings card summary.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get danmuDandanStatusEnabled;

  /// Source state in the settings card summary.
  ///
  /// In zh, this message translates to:
  /// **'已停用'**
  String get danmuDandanStatusDisabled;

  /// Marks the preferred source in the settings card summary.
  ///
  /// In zh, this message translates to:
  /// **'优先'**
  String get danmuDandanStatusPreferred;

  /// Summary shown when both dandan sources are off.
  ///
  /// In zh, this message translates to:
  /// **'未启用任何弹弹play来源'**
  String get danmuDandanNoneEnabled;
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
