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
