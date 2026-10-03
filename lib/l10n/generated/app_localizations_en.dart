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

  @override
  String get shortcutsTitle => 'Keyboard shortcuts';

  @override
  String get shortcutsTabKeyboard => 'Keyboard';

  @override
  String get shortcutsTabPlayback => 'Playback';

  @override
  String get shortcutsTabHelp => 'Help';

  @override
  String get shortcutsRestoreDefaults => 'Restore defaults';

  @override
  String get shortcutsSearch => 'Search';

  @override
  String get shortcutsPrompt => 'Press a key or combination on the keyboard';

  @override
  String get sslTrustedTitle => 'Trusted SSL certificates';

  @override
  String get sslTrustedEmpty =>
      'No trusted certificates. When server certificate validation fails, you can choose \"Trust this certificate\" in the prompt.';

  @override
  String sslTrustedAddedAt(String time) {
    return 'Added: $time';
  }

  @override
  String get sslTrustedRemove => 'Remove';

  @override
  String get sslTrustedRemoveAll => 'Clear all';

  @override
  String get sslTrustedRemoveTitle => 'Remove trusted certificate';

  @override
  String sslTrustedRemoveBody(String host) {
    return 'After removal, the certificate for \"$host\" will be validated again on the next visit.';
  }

  @override
  String get sslTrustedClearTitle => 'Clear all trusted certificates';

  @override
  String get sslTrustedClearBody =>
      'After clearing, every server certificate will be validated again.';

  @override
  String get supportAuthorTitle => 'Support the author';

  @override
  String get supportAuthorBody =>
      'Your support keeps this project going. If you find it useful, please give it a Star ⭐. Thank you! (^_−)☆';

  @override
  String get supportAuthorIssues =>
      'The project still has room to improve. If you hit a problem or a bug, feel free to open an Issue or a PR.';

  @override
  String get supportAuthorOpenRepo => 'Open the GitHub repository';

  @override
  String get supportAuthorLater => 'Maybe later';

  @override
  String get fontScaleSmall => 'Small';

  @override
  String get fontScaleMedium => 'Medium';

  @override
  String get fontScaleLarge => 'Large';

  @override
  String get filterTitle => 'Filter';

  @override
  String get filterReset => 'Reset';

  @override
  String get filterCollapse => 'Collapse';

  @override
  String get filterOptionAll => 'All';

  @override
  String get filterOptionMovie => 'Movie';

  @override
  String get filterOptionTv => 'TV series';

  @override
  String get filterOptionWatched => 'Watched';

  @override
  String get filterOptionUnwatched => 'Unwatched';

  @override
  String get filterOptionMatched => 'Matched';

  @override
  String get filterOptionUnmatched => 'Unmatched';

  @override
  String get filterOptionNfoMatched => 'NFO matched';

  @override
  String get filterOptionOthers => 'Others';

  @override
  String get filterOptionThisYear => 'This year';

  @override
  String filterOptionDecade(String decade) {
    return '${decade}s';
  }

  @override
  String get filterOptionDolbyVision => 'Dolby Vision';

  @override
  String get filterOptionDolbySurround => 'Dolby Surround';

  @override
  String get filterOptionDolbyAtmos => 'Dolby Atmos';

  @override
  String get filterOptionStereo => 'Stereo';

  @override
  String get filterRowMediaType => 'Media type';

  @override
  String get filterRowGenre => 'Genre';

  @override
  String get filterRowResolution => 'Resolution';

  @override
  String get filterRowColorRange => 'Dynamic range';

  @override
  String get filterRowAudioType => 'Audio';

  @override
  String get filterRowLocation => 'Country/Region';

  @override
  String get filterRowDecade => 'Release year';

  @override
  String get filterRowRecognitionStatus => 'Match status';

  @override
  String get filterRowWatched => 'Watched';

  @override
  String get mediaInfoTitle => 'File media info';

  @override
  String get mediaInfoEmpty => 'No data';

  @override
  String get mediaInfoSectionVideo => 'Video';

  @override
  String get mediaInfoSectionAudio => 'Audio';

  @override
  String get mediaInfoSectionSubtitle => 'Subtitles';

  @override
  String get mediaInfoFieldResolution => 'Resolution';

  @override
  String get mediaInfoFieldDynamicRange => 'Dynamic range';

  @override
  String get mediaInfoFieldCodec => 'Codec';

  @override
  String get mediaInfoFieldProfile => 'Profile';

  @override
  String get mediaInfoFieldLevel => 'Level';

  @override
  String get mediaInfoFieldFrameRate => 'Frame rate';

  @override
  String get mediaInfoFieldBitRate => 'Bit rate';

  @override
  String get mediaInfoFieldAspectRatio => 'Aspect ratio';

  @override
  String get mediaInfoFieldPixelFormat => 'Pixel format';

  @override
  String get mediaInfoFieldBitDepth => 'Bit depth';

  @override
  String get mediaInfoFieldColorSpace => 'Color space';

  @override
  String get mediaInfoFieldColorPrimaries => 'Color primaries';

  @override
  String get mediaInfoFieldColorTransfer => 'Color transfer';

  @override
  String get mediaInfoFieldReferenceFrames => 'Reference frames';

  @override
  String get mediaInfoFieldInterlaced => 'Interlaced';

  @override
  String get mediaInfoFieldLayout => 'Layout';

  @override
  String get mediaInfoFieldChannels => 'Channels';

  @override
  String get mediaInfoFieldSampleRate => 'Sample rate';

  @override
  String get mediaInfoFieldLanguage => 'Language';

  @override
  String get mediaInfoFieldDefault => 'Default';

  @override
  String get mediaInfoFieldForced => 'Forced';

  @override
  String get mediaInfoFieldExternal => 'External';

  @override
  String get mediaInfoYes => 'Yes';

  @override
  String get mediaInfoNo => 'No';

  @override
  String get subtitleUploadFileTypeName => 'Subtitle file';

  @override
  String get subtitleUploadSelect => 'Select';

  @override
  String get subtitleUploadAdded => 'Subtitles added';

  @override
  String get subtitleUploadFailed => 'Could not add the subtitles. Try again.';

  @override
  String subtitleUploadPartial(String count) {
    return 'Some subtitles were added; $count failed';
  }

  @override
  String subtitleUploadTooMany(String count) {
    return 'Select at most $count files';
  }

  @override
  String get subtitleUploadMissingUser =>
      'User info is missing; cannot restore the file picker state';

  @override
  String subtitleUploadPickerFailed(String error) {
    return 'Could not pick subtitle files: $error';
  }

  @override
  String subtitleUploadFormatSuffix(String formats) {
    return '$formats files';
  }

  @override
  String get captionBack => 'Back';

  @override
  String get captionRefresh => 'Refresh';

  @override
  String get captionToggleNav => 'Toggle navigation pane';

  @override
  String get captionAlwaysOnTop => 'Keep window on top';

  @override
  String get captionUnpin => 'Stop keeping on top';

  @override
  String get toastInfo => 'Info';

  @override
  String get toastSuccess => 'Success';

  @override
  String get toastWarning => 'Warning';

  @override
  String get toastError => 'Error';

  @override
  String get toastServerUrlRequired => 'Enter the FlyNarwhal server URL';

  @override
  String get toastServerAuthCodeRequired =>
      'Enter the FlyNarwhal server auth code';

  @override
  String get toastServerCredentialsRequired =>
      'Enter the FlyNarwhal server URL and auth code';

  @override
  String get sslPromptTitle => 'Certificate validation failed';

  @override
  String sslPromptBody(String host) {
    return 'Certificate validation failed for \"$host\". It may be expired, have a mismatched domain, or be self-signed.';
  }

  @override
  String sslPromptFingerprint(String fingerprint) {
    return 'Certificate fingerprint SHA-256: $fingerprint';
  }

  @override
  String get sslPromptQuestion =>
      'Continuing bypasses the security check. Continue anyway?';

  @override
  String get sslPromptTrustPersistent => 'Trust this certificate';

  @override
  String get sslPromptTrustOnce => 'Trust once';

  @override
  String get sslPromptCancel => 'Cancel';

  @override
  String get layoutTitle => 'Layout';

  @override
  String get layoutPosterWall => 'Poster wall';

  @override
  String get layoutVerticalPoster => 'Vertical posters';

  @override
  String get layoutBannerPoster => 'Banner posters';

  @override
  String get layoutList => 'List';

  @override
  String get castTitle => 'Cast & crew';

  @override
  String get castRoleDirector => 'Director';

  @override
  String get castRoleActor => 'Actor';

  @override
  String get castRoleWriter => 'Writer';

  @override
  String get castRoleProducer => 'Producer';

  @override
  String castCharacter(String role) {
    return 'as $role';
  }

  @override
  String get sortTitle => 'Title';

  @override
  String get sortAddedDate => 'Date added';

  @override
  String get sortReleaseYear => 'Release year';

  @override
  String get sortScore => 'Rating';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortDescending => 'Descending';

  @override
  String get nasSubtitleStorageLocation => 'Video location';

  @override
  String get nasSubtitleSelectStorage => 'Choose a storage volume';

  @override
  String nasSubtitleTooMany(String count) {
    return 'Select at most $count files';
  }

  @override
  String get loadFailedTitle => 'Loading failed';

  @override
  String get loadFailedUnknown => 'Unknown error';

  @override
  String get loadFailedRetry => 'Retry';

  @override
  String get episodeViewCard => 'Switch to card view';

  @override
  String get episodeViewButton => 'Switch to numbered view';

  @override
  String get nasBrowserEmpty => 'Nothing here';
}
