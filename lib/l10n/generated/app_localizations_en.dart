// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FlyNarwhal';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageCaption =>
      'Choose the display language of the app';

  @override
  String get settingsSectionServer => 'Server';

  @override
  String get settingsSectionPrivacy => 'Privacy and Security';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsAccountUnloaded => 'User info not loaded';

  @override
  String get settingsAccountUnloadedCaption =>
      'Sign in to verify the account automatically on the home page';

  @override
  String get settingsAccountAdminBadge => 'Admin';

  @override
  String get settingsAccountSignOut => 'Sign out';

  @override
  String get settingsAccountSignOutCaption => 'Sign out of the current account';

  @override
  String get settingsAccountSignOutConfirm =>
      'Sign out of the current account?';

  @override
  String get settingsAppearanceThemeMode => 'Theme';

  @override
  String get settingsAppearanceThemeModeCaption =>
      'Whether to follow the system theme';

  @override
  String get settingsAppearanceFollowSystem => 'Follow system';

  @override
  String get settingsAppearanceManual => 'Manual';

  @override
  String get settingsAppearanceColor => 'Theme color';

  @override
  String get settingsAppearanceColorCaption => 'Choose the theme color';

  @override
  String get settingsAppearanceDark => 'Dark';

  @override
  String get settingsAppearanceLight => 'Light';

  @override
  String get settingsAppearanceNavStyle => 'Navigation layout';

  @override
  String get settingsAppearanceNavStyleCaption =>
      'Choose the navigation view layout';

  @override
  String get settingsGeneralFontSize => 'Font size';

  @override
  String get settingsGeneralFontSizeCaption =>
      'Adjust the overall text size of the app';

  @override
  String get settingsGeneralShortcuts => 'Keyboard shortcuts';

  @override
  String get settingsGeneralShortcutsCaption => 'Customize keyboard shortcuts';

  @override
  String get settingsGeneralCustomize => 'Customize';

  @override
  String get settingsServerEnable => 'Enable the FlyNarwhal server';

  @override
  String get settingsServerEnableCaption =>
      'Connect to the FlyNarwhal server for intro/outro detection, danmaku and more';

  @override
  String get settingsServerAddress => 'FlyNarwhal server address';

  @override
  String get settingsServerAddressHttpsRequired =>
      'An HTTPS address is required';

  @override
  String get settingsServerAddressIncomplete => 'Enter the complete server URL';

  @override
  String get settingsServerAuthCode => 'Auth code';

  @override
  String get settingsServerAuthCodePlaceholder => 'Enter auth code';

  @override
  String get settingsServerAuthCodeFilled => 'Auth code is set';

  @override
  String get settingsServerAuthCodePrompt =>
      'Enter the FlyNarwhal server auth code';

  @override
  String get settingsServerAuthCodeLabel =>
      'Enter the FlyNarwhal server auth code:';

  @override
  String get settingsServerAuthCodeHint =>
      'On the FlyNarwhal server page, click \"Get auth code\" and paste it here.';

  @override
  String get settingsServerAuthCodeHelp =>
      'Open the FlyNarwhal server address deployed on your NAS in a browser (for the app-center build, click \"FlyNarwhal\" on the fnOS desktop), click \"Get auth code\" in the top-right corner, then paste the code into the auth code field.\\nServer version >= 0.6.0 is required. Older servers cannot auto-update to 0.6.0 or above; update them manually.';

  @override
  String get settingsServerTest => 'Test';

  @override
  String get settingsServerTesting => 'Testing';

  @override
  String settingsServerTestSuccess(String version) {
    return 'Connected to the FlyNarwhal server. Server version: $version';
  }

  @override
  String settingsServerTestConnectFailed(String error) {
    return 'Could not connect to the FlyNarwhal server: $error';
  }

  @override
  String get settingsServerUnreachable =>
      'The FlyNarwhal server is unreachable';

  @override
  String get settingsPrivacySslTitle => 'Trusted SSL certificates';

  @override
  String get settingsPrivacySslCaption =>
      'Trust a server certificate when validation fails; manage them here';

  @override
  String settingsPrivacySslTrustedCount(String count) {
    return '$count trusted certificates';
  }

  @override
  String get settingsPrivacyManage => 'Manage';

  @override
  String get settingsPrivacyStatement => 'Privacy statement';

  @override
  String get settingsPrivacyStatementBody =>
      'To improve performance we collect some hardware information (such as CPU and GPU models) for reference. It is used only to optimize the software and does not involve personal privacy.';

  @override
  String get settingsPrivacyGitHubProxy => 'GitHub asset proxy';

  @override
  String get settingsPrivacyGitHubProxyCaption =>
      'Used only for installer downloads; off by default';

  @override
  String get settingsPrivacyProxyAddress => 'Proxy address';

  @override
  String get settingsAboutVersion => 'Current version';

  @override
  String get settingsAboutCheckUpdate => 'Check for updates';

  @override
  String get settingsAboutChangelog => 'Changelog';

  @override
  String get settingsAboutChangelogCaption =>
      'See what changed in each version';

  @override
  String get settingsAboutPrerelease => 'Receive pre-release updates';

  @override
  String get settingsAboutPrereleaseEarly => 'Early access';

  @override
  String get settingsAboutAutoDownload => 'Download updates automatically';

  @override
  String get settingsAboutAutoDownloadCaption =>
      'Download and verify an installer in the background when an update is found';

  @override
  String get settingsAboutOpen => 'On';

  @override
  String get settingsAboutClose => 'Off';

  @override
  String get settingsAboutExportLogs => 'Export error logs';

  @override
  String get settingsAboutExportLogsCaption =>
      'Export the last three days of error logs to help developers diagnose issues';

  @override
  String get settingsAboutExport => 'Export';

  @override
  String get settingsAboutExportError => 'Export failed';

  @override
  String get settingsAboutVersionLoading => 'Reading version information…';

  @override
  String get settingsAboutVersionUnavailable =>
      'Could not read version information';

  @override
  String get commonLoading => 'Loading';

  @override
  String get commonConfirm => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonGotIt => 'Got it';

  @override
  String get commonUserInfoLoadFailed => 'Failed to load user info';

  @override
  String get commonUserInfoLoading => 'Loading user info…';
}
