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
  String get settingsAppearanceDetailsLiquidGlass =>
      'Enable liquid glass for the playback details panel';

  @override
  String get settingsAppearanceDetailsLiquidGlassCaption =>
      'When on, the playback details panel uses the animated liquid glass style; when off, it uses the static frosted glass style';

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
      'Used only for installer downloads';

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

  @override
  String get actionPlay => 'Play';

  @override
  String get actionContinuePlay => 'Continue playing';

  @override
  String get actionFavoriteAdd => 'Add to favorites';

  @override
  String get actionFavoriteRemove => 'Remove from favorites';

  @override
  String get actionMarkWatched => 'Mark as watched';

  @override
  String get actionMarkUnwatched => 'Mark as unwatched';

  @override
  String get actionMore => 'More actions';

  @override
  String get actionMore2 => 'More';

  @override
  String get toastFavoriteAdded => 'Added to favorites';

  @override
  String get toastFavoriteRemoved => 'Removed from favorites';

  @override
  String get toastMarkedUnwatched => 'Marked as unwatched';

  @override
  String get toastMarkedWatched => 'Marked as watched';

  @override
  String get toastOperationFailed => 'Operation failed';

  @override
  String toastOperationFailedReason(String message) {
    return 'Operation failed: $message';
  }

  @override
  String get mediaInfoNoOverview => 'No overview available';

  @override
  String get mediaInfoNoInfo => 'No information';

  @override
  String get mediaInfoNoContent => 'No content';

  @override
  String get mediaInfoFileInfo => 'File info';

  @override
  String get mediaInfoFileLocation => 'File location';

  @override
  String get mediaInfoFileSize => 'File size';

  @override
  String get mediaInfoCreatedDate => 'Created';

  @override
  String get mediaInfoAddedDate => 'Added';

  @override
  String get mediaInfoStreamSection => 'Video/Audio info';

  @override
  String get linkLabel => 'Link:  ';

  @override
  String get imdbLinkLabel => 'IMDB link';

  @override
  String defaultSuffix(String title) {
    return '$title - Default';
  }

  @override
  String get actionViewAll => 'View all';

  @override
  String get movieDetailNotFound => 'Movie information not found';

  @override
  String get movieDetailDescriptionTitle => 'Movie overview';

  @override
  String get movieDetailEpisodeDescriptionTitle => 'Episode overview';

  @override
  String get movieDetailSubtitleAddTitle => 'Add subtitle';

  @override
  String get movieDetailSubtitleAlreadyAdded =>
      'This file is already added as a subtitle';

  @override
  String get movieDetailSubtitleAddFailed => 'Failed to add subtitle';

  @override
  String movieDetailSubtitleRetry(String error) {
    return 'Please try again later: $error';
  }

  @override
  String get movieDetailSubtitleSearchMissingFile =>
      'File information is missing; cannot search subtitles';

  @override
  String get movieDetailSubtitleUploadMissingFile =>
      'File information is missing; cannot upload subtitles';

  @override
  String get movieDetailSubtitleDownloadSuccess => 'Downloaded';

  @override
  String movieDetailSubtitleDownloadFailed(String error) {
    return 'Failed to download subtitle: $error';
  }

  @override
  String get movieDetailSubtitleTaskCreated => 'Subtitle download task created';

  @override
  String get movieDetailSubtitleTaskFailed =>
      'Failed to create subtitle download task; please retry';

  @override
  String get movieDetailSubtitleExternalSuffix => ' - External';

  @override
  String get movieDetailSubtitleDeleteTitle => 'Delete external subtitle';

  @override
  String movieDetailSubtitleDeleteConfirm(String name) {
    return 'Delete the external subtitle $name?';
  }

  @override
  String get movieDetailSubtitleDeleteSuccess => 'Subtitle deleted';

  @override
  String movieDetailSubtitleDeleteFailed(String error) {
    return 'Failed to delete subtitle: $error';
  }

  @override
  String get movieDetailSubtitleNone => 'No subtitles';

  @override
  String movieDetailSubtitleLanguageLabel(String language) {
    return '$language subtitles';
  }

  @override
  String get movieDetailAudioLabel => 'Audio';

  @override
  String movieDetailAudioLanguageLabel(String language) {
    return '$language audio';
  }

  @override
  String get movieDetailAudioStereo => 'Stereo';

  @override
  String movieDetailRemaining(String time) {
    return '$time left';
  }

  @override
  String movieDetailSmartAnalysisStatus(String status) {
    return 'Intro/outro detection status: $status';
  }

  @override
  String get movieDetailDolbyVision => 'Dolby Vision';

  @override
  String get movieDetailSubtitleLabel => 'Subtitles';

  @override
  String get tvDetailNotFound => 'TV series information not found';

  @override
  String get tvDetailSeasonNotFound => 'Season information not found';

  @override
  String get tvDetailDescriptionTitle => 'Series overview';

  @override
  String get tvDetailSmartAnalysis => 'Analyze intro/outro';

  @override
  String get tvDetailSeasonListTitle => 'Seasons';

  @override
  String tvDetailEpisodeNumber(String number) {
    return 'Episode $number';
  }

  @override
  String tvDetailSeasonNumber(String number) {
    return 'Season $number';
  }

  @override
  String tvDetailSeasonEpisodeNumbers(String season, String episode) {
    return 'Season $season Episode $episode';
  }

  @override
  String tvDetailEpisodeCount(String count) {
    return '$count episodes';
  }

  @override
  String get tvDetailEpisodeSectionTitle => 'Episodes';

  @override
  String get tvDetailUnknownSeason => 'Unknown season';

  @override
  String tvDetailSeasonTitleSummary(String title, String count) {
    return '$title · $count seasons';
  }

  @override
  String get tvDetailEpisodeNoneOverview => 'No episode overview';

  @override
  String tvDetailEpisodeRuntime(String minutes) {
    return '$minutes min';
  }

  @override
  String get tvDetailRuntimeUnknown => 'Unknown duration';

  @override
  String tvDetailScore(String score) {
    return '$score';
  }

  @override
  String get tvDetailPlayEpisode => 'Play this episode';

  @override
  String tvDetailSmartAnalysisStatus(String status) {
    return 'Smart analysis: $status';
  }

  @override
  String get tvDetailAnalysisFetching => 'Fetching';

  @override
  String get tvDetailAnalysisNotDetected => 'Not detected';

  @override
  String get tvDetailAnalysisFailed => 'Fetch failed';

  @override
  String get tvDetailAnalysisPreparing => 'Preparing';

  @override
  String get tvDetailAnalysisPending => 'Pending';

  @override
  String get tvDetailAnalysisInProgress => 'Analyzing';

  @override
  String get tvDetailAnalysisPartialSuccess => 'Partially succeeded';

  @override
  String get tvDetailAnalysisCompleted => 'Completed';

  @override
  String get tvDetailAnalysisStatusFailed => 'Failed';

  @override
  String get mediaTypeMovie => 'Movie';

  @override
  String get mediaTypeTv => 'TV show';

  @override
  String get mediaTypeDirectory => 'Folder';

  @override
  String get mediaTypeOther => 'Other';

  @override
  String get mediaTypeLive => 'Live TV';

  @override
  String get mediaTypeEpisode => 'Episode';

  @override
  String get mediaTypeSeason => 'Season';

  @override
  String mediaSeasonCount(String count) {
    return '$count seasons';
  }

  @override
  String mediaSeasonNumber(String number) {
    return 'Season $number';
  }

  @override
  String mediaEpisodeCount(String count) {
    return '$count episodes';
  }

  @override
  String mediaEpisodeDetail(String season, String episode) {
    return 'Season $season · Episode $episode';
  }

  @override
  String get cloudStorageBaiduPan => 'Baidu Netdisk';

  @override
  String get cloudStorageAliyunDrive => 'Aliyun Drive';

  @override
  String get cloudStorage115 => '115 Life';

  @override
  String get cloudStorageQuark => 'Quark Drive';

  @override
  String get cloudStorage123 => '123 Cloud Drive';

  @override
  String get loginRememberPassword => 'Remember password';

  @override
  String get loginWebViewInjectedPlaceholder => 'Login page';

  @override
  String get updateCurrentVersionLabel => 'Currently installed version';

  @override
  String get updateManualDownloadOpenFailed =>
      'Could not open the manual download page. Please try again later.';

  @override
  String get updateOpenLinkFailed =>
      'Could not open the link. Please try again later.';

  @override
  String updateBadgeSemanticLabel(String version) {
    return 'New version $version available. Open update details.';
  }

  @override
  String get updateDialogTitleChecking => 'Check for updates';

  @override
  String get updateDialogTitleAvailable => 'Update available';

  @override
  String get updateDialogTitleDownloading => 'Downloading update';

  @override
  String get updateDialogTitleDownloaded => 'Download complete';

  @override
  String get updateDialogTitleVerifying => 'Verifying update';

  @override
  String get updateDialogTitleReadyToInstall => 'Ready to install';

  @override
  String get updateDialogTitleInstalling => 'Starting installation';

  @override
  String get updateDialogTitleCheckFailed => 'Update check failed';

  @override
  String get updateDialogTitleDownloadFailed => 'Update download failed';

  @override
  String get updateDialogTitleVerificationFailed =>
      'Update verification failed';

  @override
  String get updateDialogTitleInstallFailed => 'Installation failed';

  @override
  String get updateDialogTitleAutomaticDownloadExhausted =>
      'Automatic download incomplete';

  @override
  String get updateDialogTitleNone => 'App update';

  @override
  String get updateActionCheckInBackground => 'Check in background';

  @override
  String get updateActionSkipVersion => 'Skip this version';

  @override
  String get updateActionLater => 'Later';

  @override
  String get updateActionDownload => 'Download update';

  @override
  String get updateActionDownloadInBackground => 'Download in background';

  @override
  String get updateActionCancelDownload => 'Cancel download';

  @override
  String get updateActionInstallLater => 'Install later';

  @override
  String get updateActionQuitAndInstall => 'Quit and install';

  @override
  String get updateActionRunInBackground => 'Run in background';

  @override
  String get updateActionRetryDownload => 'Download again';

  @override
  String get updateActionRetryInstall => 'Retry installation';

  @override
  String get updateActionManualDownload => 'Manual download';

  @override
  String get updateActionClose => 'Close';

  @override
  String get updateStatusCheckingMessage =>
      'Fetching update information from GitHub Releases…';

  @override
  String get updateStatusUpToDate => 'You are on the latest version.';

  @override
  String get updateStatusDownloadedMessage =>
      'The update has been downloaded. You can install it later or quit and install now.';

  @override
  String get updateStatusReadyMessage =>
      'A downloaded update is ready to install.';

  @override
  String get updateStatusVerifyingMessage =>
      'Verifying the update package securely, please wait…';

  @override
  String get updateStatusInstallingMessage =>
      'Launching the system installer. Do not repeat this action.';

  @override
  String get updateStatusIdleMessage => 'No update check has been run yet.';

  @override
  String updateVersionLine(String version, String current) {
    return 'Version $version (current $current)';
  }

  @override
  String updatePackageSize(String size) {
    return 'Package size $size';
  }

  @override
  String get updateReleaseNotesHeader => 'What\'s new';

  @override
  String get updateDownloadingPackage => 'Downloading update package';

  @override
  String updateDownloadedSize(String size) {
    return 'Downloaded $size';
  }

  @override
  String updateDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get updateErrorRateLimited =>
      'The GitHub API rate limit was reached. It usually recovers automatically, so please try again later.';

  @override
  String get updateErrorVerificationFailed =>
      'The update package failed the security check. Please download it again.';

  @override
  String get updateErrorCheckFailed =>
      'Could not fetch update information. Check your network and try again.';

  @override
  String get updateErrorDownloadFailed =>
      'The update download did not finish. Please try again later.';

  @override
  String get updateErrorInstallFailed =>
      'Could not launch the system installer. Please try again later.';

  @override
  String get updateErrorAutomaticDownloadExhausted =>
      'The automatic download did not finish after several attempts. You can retry later or download manually from the release page.';

  @override
  String get updateErrorGeneric =>
      'The update did not complete. Please try again later.';

  @override
  String get updateMarkdownEmpty =>
      'No release notes were provided for this update.';

  @override
  String get updateMarkdownRemoteImageAlt => 'Remote image';

  @override
  String updateMarkdownRemoteImageBlocked(String alt) {
    return 'Remote image blocked: $alt';
  }

  @override
  String get updateMarkdownTruncatedSuffix =>
      '\n\nRelease notes were too long and have been truncated.';

  @override
  String get loginHostOrFnIdPlaceholder => 'Enter IP:Port, domain, or FN ID';

  @override
  String get loginHostValidationMessage => 'Enter a valid IP, domain, or FN ID';

  @override
  String get loginHostRequiredMessage => 'Enter IP, domain, or FN ID';

  @override
  String get loginUsernameRequiredMessage => 'Enter your username';

  @override
  String get loginPasswordRequiredMessage => 'Enter your password';

  @override
  String get loginWebViewInitFailed =>
      'The browser component failed to initialize. Please try again later.';

  @override
  String get loginHostPlaceholder => 'Enter IP, domain, or FN ID';

  @override
  String get loginPortPlaceholder => 'Port';

  @override
  String get loginUsernameLabel => 'Username';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginUseNasLogin => 'Sign in with NAS';

  @override
  String get loginHttpsSecureAccess => 'HTTPS secure access';

  @override
  String get loginNext => 'Next';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String get loginVerifyingServer => 'Verifying server…';

  @override
  String get loginInvalidCredentials => 'Incorrect username or password';

  @override
  String loginServerHttpError(String status) {
    return 'The server returned an error (HTTP $status). Check the service status.';
  }

  @override
  String get loginSslCertificateFailed =>
      'SSL certificate verification failed. Check the HTTPS setting or the server certificate.';

  @override
  String get loginConnectionTimeout =>
      'Timed out connecting to the server. Check the server address or your network.';

  @override
  String get loginConnectionFailed =>
      'Could not connect to the server. Check the address, port, or network.';

  @override
  String get loginRequestCancelled => 'The sign-in request was cancelled.';

  @override
  String get loginFailedCheckServer =>
      'Sign-in failed. Check the server address or try again later.';

  @override
  String get loginFailedCheckNetwork =>
      'Sign-in failed. Check your network or server settings.';

  @override
  String get loginFailedTokenEmpty => 'Sign-in failed: empty token';

  @override
  String loginFailedWithError(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String get loginAuthFailed => 'Authentication failed';

  @override
  String get loginAccessCodeInvalid => 'Incorrect access code';

  @override
  String get loginAccessCodeTitle => 'Enter access code';

  @override
  String get loginAccessCodeHint =>
      'This server requires an access code to continue.';

  @override
  String get loginFnIdEmpty => 'FN ID cannot be empty';

  @override
  String get loginHistoryTitle => 'Login history';

  @override
  String get loginHistoryEmpty => 'No history yet';

  @override
  String get homeRetryLoad => 'Failed to load. Click to retry';

  @override
  String get homeTitle => 'Home';

  @override
  String get homeContinueWatching => 'Continue watching';

  @override
  String get homeMediaLibrary => 'Media library';

  @override
  String get homeContinueRemoved => 'Removed from Continue watching';

  @override
  String get homeContinueRemoveFailed => 'Failed to remove';

  @override
  String homeContinueRemoveError(String error) {
    return 'Failed to remove: $error';
  }

  @override
  String homeDeleteDialogTitle(String title) {
    return 'Delete \"$title\"';
  }

  @override
  String get homeDeleteDialogBody =>
      'After removing it from the library, the selected video files will no longer be scanned into this library. Choose whether to also delete the associated video files.';

  @override
  String get homeDeleteRemoveAndDeleteFile => 'Remove and delete files';

  @override
  String get homeDeleteRemoveOnly => 'Remove only';

  @override
  String get homeDeleted => 'Deleted';

  @override
  String get homeDeleteFailed => 'Delete failed';

  @override
  String homeDeleteFailedWithError(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get homeFavoriteRemoved => 'Removed from favorites';

  @override
  String get homeFavorited => 'Added to favorites';

  @override
  String get homeMarkedUnwatched => 'Marked as unwatched';

  @override
  String get homeMarkedWatched => 'Marked as watched';

  @override
  String get homeActionFailed => 'Operation failed';

  @override
  String homeActionFailedWithError(String error) {
    return 'Operation failed: $error';
  }

  @override
  String get homeMenuRemoveFromContinue => 'Remove from Continue watching';

  @override
  String get homeMenuResume => 'Resume playback';

  @override
  String get homeMenuRestart => 'Play from the beginning';

  @override
  String get homeMenuDeleteVideo => 'Delete video';

  @override
  String get searchPlaceholder => 'Search titles or actors';

  @override
  String get searchTabAll => 'All';

  @override
  String get searchTabMovie => 'Movies';

  @override
  String get searchTabTv => 'TV series';

  @override
  String get searchTabLiveChannel => 'Live channels';

  @override
  String get searchTabPerson => 'People';

  @override
  String get searchTabOther => 'Other';

  @override
  String get searchNoResults => 'No results found';

  @override
  String get searchEnterKeyword => 'Type a keyword to search';

  @override
  String searchWorkCount(String count) {
    return '$count works';
  }

  @override
  String get searchScoreSuffix => 'pts';

  @override
  String searchEpisodeCount(String count) {
    return '$count episodes';
  }

  @override
  String get personNoData => 'No data';

  @override
  String get personSectionActor => 'As actor';

  @override
  String get personSectionDirector => 'As director';

  @override
  String get personSectionWriter => 'As writer';

  @override
  String get personMore => 'More';

  @override
  String get personBiographyTitle => 'Biography';

  @override
  String get commonDelete => 'Delete';

  @override
  String get forgotPasswordTitle => 'Forgot password?';

  @override
  String get storageExternal => 'External storage';

  @override
  String get storageRemoteMount => 'Remote mount';

  @override
  String storageVolumeName(String number) {
    return 'Volume $number';
  }

  @override
  String durationHoursMinutes(String hours, String minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durationHours(String hours) {
    return '$hours h';
  }

  @override
  String durationMinutesSeconds(String minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String durationMinutes(String minutes) {
    return '$minutes min';
  }

  @override
  String get durationZeroMinutes => '0 min';

  @override
  String authDirUserFiles(String username) {
    return '$username\'s files';
  }

  @override
  String authDirUnknownUser(String uid) {
    return 'User $uid';
  }

  @override
  String get authDirNone => 'None';

  @override
  String get authDirUnknown => 'Unknown';

  @override
  String get mediaStreamAudio => 'Audio';

  @override
  String get mediaStreamVideo => 'Video';

  @override
  String get mediaStreamSubtitle => 'Subtitle';

  @override
  String get forgotPasswordBody =>
      '1. If you are a NAS user, try signing in with your NAS account.\n2. Otherwise, contact an administrator to reset your password.';

  @override
  String tvDetailEpisodeNumberTitle(String number, String title) {
    return 'Episode $number $title';
  }

  @override
  String get movieDetailSubtitleDefaultSuffix => ' - Default';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(String count) {
    return '$count min ago';
  }

  @override
  String timeHoursAgo(String count) {
    return '$count h ago';
  }

  @override
  String timeDaysAgo(String count) {
    return '$count d ago';
  }

  @override
  String timeWeeksAgo(String count) {
    return '$count wk ago';
  }

  @override
  String timeMonthsAgo(String count) {
    return '$count mo ago';
  }

  @override
  String timeYearsAgo(String count) {
    return '$count y ago';
  }

  @override
  String get updateNotesEmpty => 'No release notes.';

  @override
  String updateNotesTruncated(String url) {
    return '\n\n> Release notes were truncated. See the [Release page]($url) for the full content.';
  }

  @override
  String get navCategories => 'Categories';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navNoMediaLibrary => 'No media library';

  @override
  String get folderFallbackName => 'Folder';

  @override
  String get folderRescrap => 'Re-identify';

  @override
  String get folderRescrapStarted => 'Re-identification started';

  @override
  String get folderRescrapFailed => 'Re-identification failed';

  @override
  String folderRescrapFailedWithError(String error) {
    return 'Re-identification failed: $error';
  }

  @override
  String get folderRefreshMetadata => 'Refresh metadata';

  @override
  String get folderRefreshMetadataStarted => 'Metadata refresh started';

  @override
  String get folderRefreshMetadataFailed => 'Metadata refresh failed';

  @override
  String folderRefreshMetadataFailedWithError(String error) {
    return 'Metadata refresh failed: $error';
  }

  @override
  String get folderThisFolder => 'this folder';

  @override
  String get folderDeleteConfirmTitle => 'Delete';

  @override
  String folderDeleteConfirmBody(String title) {
    return 'Remove \"$title\" from the media library?\nOnly the media library entry is removed; files on disk are kept.';
  }

  @override
  String folderDeleteFailedWithError(String error) {
    return 'Delete failed: $error';
  }

  @override
  String folderItemCount(String count) {
    return '$count items in total';
  }

  @override
  String get favoritesTabSingleEpisode => 'Episode';

  @override
  String get serverUpdateGetVersionFailed => 'Failed to get the server version';

  @override
  String get serverUpdateCheckFailed => 'Server update check failed';

  @override
  String serverUpdateCheckFailedWithError(String error) {
    return 'Server update check failed: $error';
  }

  @override
  String get serverUpdatePackageNotFound => 'Server update package not found';

  @override
  String get serverUpdateAssetMissing =>
      'Server update package asset is missing';

  @override
  String get serverUpdateStarting => 'Starting server update...';

  @override
  String get serverUpdateFailed => 'Server update failed';

  @override
  String serverUpdateFailedWithError(String error) {
    return 'Server update failed: $error';
  }

  @override
  String get serverUpdateWaitingRestart =>
      'Waiting for the server to restart...';

  @override
  String serverUpdateSucceeded(String version) {
    return 'Server updated to $version';
  }

  @override
  String get serverUpdateTimeout =>
      'Server update timed out; check the server logs';

  @override
  String get connectionTestInvalidUrl => 'Invalid FlyNarwhal server address';

  @override
  String get connectionTestNoVersion => 'FlyNarwhal server returned no version';

  @override
  String get smartAnalysisQueued => 'Added to the analysis queue';

  @override
  String get smartAnalysisSubmitted => 'Analysis request submitted';

  @override
  String smartAnalysisFailedSeasons(String seasons) {
    return 'Failed seasons: $seasons';
  }

  @override
  String get smartAnalysisSubmitFailed =>
      'Failed to submit the analysis request';

  @override
  String get shortcutFocusSearch => 'Focus the search box';

  @override
  String get shortcutTogglePlayPause => 'Play/Pause';

  @override
  String get shortcutMute => 'Mute/Unmute';

  @override
  String get shortcutSeekBackward => 'Rewind 10 seconds';

  @override
  String get shortcutSeekForward => 'Forward 10 seconds';

  @override
  String get shortcutVolumeUp => 'Volume up';

  @override
  String get shortcutVolumeDown => 'Volume down';

  @override
  String get shortcutToggleFullscreen => 'Enter fullscreen';

  @override
  String get shortcutExitFullscreen => 'Exit fullscreen';

  @override
  String get shortcutSearchNext => 'Next search result';

  @override
  String get shortcutSearchPrev => 'Previous search result';

  @override
  String get shortcutSearchSelect => 'Select search result';

  @override
  String get shortcutSearchSwitchTab => 'Switch search category';

  @override
  String get shortcutSearchExit => 'Exit search';

  @override
  String get playerSubtitleExternalSuffix => ' - External';

  @override
  String get playerSubtitleDefaultSuffix => ' - Default';

  @override
  String playerVolumeLabel(String value) {
    return 'Volume: $value%';
  }

  @override
  String playerVolumeUnmuteLabel(String value) {
    return 'Unmuted: $value%';
  }

  @override
  String get playerVolumeMute => 'Mute';

  @override
  String get playerSeekRewindTo => 'Rewind to';

  @override
  String get playerSeekForwardTo => 'Fast-forward to';

  @override
  String playerSeekTimeToast(String label, String time) {
    return '$label: $time';
  }

  @override
  String get playerForceH264Disabled => 'This video is already H.264';

  @override
  String get playerForceSdrDisabled => 'This video is already SDR';

  @override
  String get playerCloudModeDirect => 'Netdisk direct link';

  @override
  String get playerCloudModeNasProxy => 'NAS proxy';

  @override
  String playerCloudModeSwitchedToast(String label) {
    return 'Playback mode switched to $label';
  }

  @override
  String get playerCloudProxyFailedFallbackDirect =>
      'NAS proxy playback failed, switching to netdisk direct link';

  @override
  String get playerInfoMissingSearchSubtitle =>
      'Current file info is missing; cannot search subtitles';

  @override
  String get playerInfoMissingAddNasSubtitle =>
      'Current file info is missing; cannot add a NAS subtitle';

  @override
  String get playerInfoMissingUploadSubtitle =>
      'Current file info is missing; cannot upload a subtitle';

  @override
  String get playerSubtitleDeleteTitle => 'Delete external subtitle';

  @override
  String playerSubtitleDeleteConfirm(String displayName) {
    return 'Delete the external subtitle $displayName?';
  }

  @override
  String get playerSubtitleDeleteSuccess => 'Subtitle deleted';

  @override
  String playerSubtitleDeleteFailed(String error) {
    return 'Failed to delete subtitle: $error';
  }

  @override
  String get playerSubtitleAddNasTitle => 'Add NAS subtitle file';

  @override
  String get playerSubtitleAddNasSuccess => 'NAS subtitle added';

  @override
  String get playerSubtitleAlreadyMarked =>
      'This file has already been added as a subtitle';

  @override
  String playerSubtitleAddNasFailed(String error) {
    return 'Failed to add NAS subtitle: $error';
  }

  @override
  String get playerSubtitleDownloadSuccess => 'Downloaded';

  @override
  String playerSubtitleDownloadFailed(String error) {
    return 'Failed to download subtitle: $error';
  }

  @override
  String get playerSubtitleTaskCreated => 'Subtitle download task created';

  @override
  String get playerSubtitleTaskFailed =>
      'Failed to create subtitle download task; please retry';

  @override
  String playerSubtitleSwitchFailed(String error) {
    return 'Failed to switch subtitle: $error';
  }

  @override
  String playerSwitchOriginalQualityFailed(String error) {
    return 'Failed to switch to original quality: $error';
  }

  @override
  String playerLoadFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String playerToggleFullscreenFailed(String error) {
    return 'Failed to toggle fullscreen: $error';
  }

  @override
  String playerSwitchPlaybackSettingsFailed(String error) {
    return 'Failed to switch playback settings: $error';
  }

  @override
  String get playerNotReady => 'The player is not ready yet';

  @override
  String playerEnterPipFailed(String error) {
    return 'Failed to enter picture-in-picture: $error';
  }

  @override
  String playerExitPipFailed(String error) {
    return 'Failed to exit picture-in-picture: $error';
  }

  @override
  String playerSwitchQualityFailed(String error) {
    return 'Failed to switch quality: $error';
  }

  @override
  String playerSwitchPlayModeFailed(String error) {
    return 'Failed to switch playback mode: $error';
  }

  @override
  String playerSwitchAudioFailed(String error) {
    return 'Failed to switch audio: $error';
  }

  @override
  String playerSubtitleSwitchingTo(String language) {
    return 'Switching subtitle to: $language';
  }

  @override
  String playerSubtitleSwitchingToFormat(String language, String format) {
    return 'Switching subtitle to: $language $format';
  }

  @override
  String get playerClose => 'Close';

  @override
  String get playerBack => 'Back';

  @override
  String get playerRewindTenSeconds => 'Rewind 10 seconds';

  @override
  String get playerForwardTenSeconds => 'Forward 10 seconds';

  @override
  String get playerPlayPause => 'Play/Pause';

  @override
  String get playerPip => 'Picture-in-picture';

  @override
  String get playerExitPip => 'Exit picture-in-picture';

  @override
  String get playerDanmakuClose => 'Hide danmaku';

  @override
  String get playerDanmakuOpen => 'Show danmaku';

  @override
  String get playerPlaybackDetailsTooltip => 'Playback details';

  @override
  String get playerSkipConfigSaved => 'Saved';

  @override
  String playerSkipConfigSaveFailed(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get playerDanmakuRequestFailed =>
      'Danmaku API request failed; please check the FlyNarwhal server configuration';

  @override
  String get playerSmartSkipRequestFailed =>
      'Smart intro/credits API request failed; please check the FlyNarwhal server configuration';

  @override
  String playerFeatureComingSoon(String feature) {
    return '$feature is not available yet';
  }

  @override
  String get playerPlayErrorRetrySwitch =>
      'Playback error, please try switching lines';

  @override
  String get playerNoPlayableLine =>
      'This channel has no available playback line';

  @override
  String get playerLoadFailedBackRetry =>
      'Load failed, please go back and retry';

  @override
  String get playerPlayFailedSwitchLine =>
      'Playback failed, please try switching lines';

  @override
  String get playerLive => 'LIVE';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerDanmakuSettingsTooltip => 'Danmaku settings';

  @override
  String get playerDanmakuSettingsTitle => 'Danmaku settings';

  @override
  String get playerDanmakuAdvancedSettings => 'Advanced settings';

  @override
  String playerDanmakuDisplayArea(String value) {
    return 'Display area $value%';
  }

  @override
  String playerDanmakuOpacity(String value) {
    return 'Opacity $value%';
  }

  @override
  String playerDanmakuFontSize(String value) {
    return 'Font size $value%';
  }

  @override
  String playerDanmakuSpeed(String value) {
    return 'Speed $value';
  }

  @override
  String get playerDanmakuSpeedVerySlow => 'Very slow';

  @override
  String get playerDanmakuSpeedSlow => 'Slow';

  @override
  String get playerDanmakuSpeedNormal => 'Normal';

  @override
  String get playerDanmakuSpeedFast => 'Fast';

  @override
  String get playerDanmakuSpeedVeryFast => 'Very fast';

  @override
  String get playerDanmakuSyncPlaybackSpeed =>
      'Sync danmaku speed with playback rate';

  @override
  String get playerDanmakuShowDebugInfo => 'Show danmaku debug info';

  @override
  String get playerStrmDirectPlaying => 'Playing STRM file via direct link';

  @override
  String get playerCloudModeDirectDescription => 'Faster, saves bandwidth';

  @override
  String get playerCloudModeNasProxyDescription =>
      'Try switching when color or audio is abnormal';

  @override
  String get playerCloudPlayRecommend => 'Recommended';

  @override
  String get playerCloudPlayingNotice =>
      'Playing a file on the netdisk. Playback speed and quality depend on the netdisk provider\'s rules.';

  @override
  String get playerCloudSwitchNotice =>
      'If playback is abnormal, try switching the play mode.';

  @override
  String get playerPlayModeLabel => 'Play Mode';

  @override
  String get playerCloudFallbackName => 'Netdisk';

  @override
  String get playerCloudPlayErrorTitle => 'Sorry, playback failed';

  @override
  String get playerCloudSwitchQuality => 'Play another quality';

  @override
  String get playerCloudSwitchToProxy => 'Switch to NAS proxy playback';

  @override
  String get playerStrmPlaybackErrorHint =>
      'STRM direct playback failed. Possible causes: the netdisk mount is disconnected, netdisk risk control was triggered, netdisk restrictions on non-members, or the browser does not support this file type.';

  @override
  String get playerChannelLineFallback => 'Line';

  @override
  String get playerSubtitleAddDialogTitle => 'Add Subtitle';

  @override
  String get playerSubtitleSearchSortHint => 'Sorted by relevance:';

  @override
  String get playerSubtitleSearchNoResults => 'No matching subtitles found';

  @override
  String playerSubtitleSearchDownloadCount(String count) {
    return 'Downloads $count';
  }

  @override
  String get playerSubtitleSearchDownloading => 'Downloading';

  @override
  String get playerSubtitleSearchDownloadDone => 'Downloaded';

  @override
  String get playerSubtitleSearchDownload => 'Download Subtitle';

  @override
  String get playerSubtitleDownloadSimilarForEpisodes =>
      'Download similar subtitles for other episodes';

  @override
  String get playerSubtitleLanguageSimplifiedChinese => 'Simplified Chinese';

  @override
  String get playerSubtitleLanguageEnglish => 'English';

  @override
  String get playerSubtitleAdjust => 'Adjust Subtitle';

  @override
  String get playerSubtitleReset => 'Reset';

  @override
  String get playerSubtitleOffset => 'Offset';

  @override
  String get playerSubtitleOffsetMin => '-5s';

  @override
  String get playerSubtitleOffsetMax => '+5s';

  @override
  String get playerSubtitleSecondsSuffix => 's';

  @override
  String get playerSubtitlePosition => 'Position';

  @override
  String get playerSubtitlePositionBottom => 'Bottom';

  @override
  String get playerSubtitlePositionTop => 'Top';

  @override
  String get playerSubtitlePositionLockedHint =>
      'This subtitle is a danmaku/effect subtitle (with positioning tags); position adjustment is unavailable.';

  @override
  String get playerSubtitleFontSize => 'Font Size';

  @override
  String get playerSubtitleFontSizeMin => 'Min';

  @override
  String get playerSubtitleFontSizeMax => 'Max';

  @override
  String get playerSubtitlePanelTitle => 'Subtitles';

  @override
  String get playerSubtitleAdjustButton => 'Adjust';

  @override
  String get playerSubtitleAddButton => 'Add';

  @override
  String get playerSubtitleOff => 'Off';

  @override
  String get playerSubtitleSearchMenu => 'Search Subtitles';

  @override
  String get playerSubtitleAddNasFile => 'Add NAS Subtitle File';

  @override
  String get playerSubtitleAddLocalFile => 'Add Computer Subtitle File';

  @override
  String get playerSubtitleDirectLinkMissingTitle =>
      'Built-in subtitles missing in direct-link playback';

  @override
  String get playerSubtitleDirectLinkMissingContent =>
      'Due to cloud storage restrictions, the built-in subtitle list may be unavailable during direct-link transcoded playback. To switch built-in subtitles, change the playback mode to \"NAS proxy playback\".';

  @override
  String get playerDetailSeparator => ':';

  @override
  String get playerPlayType => 'Play type';

  @override
  String get playerPlayTypeStrmDirect => 'STRM direct playback';

  @override
  String get playerPlayTypeTranscode => 'Transcode playback';

  @override
  String get playerPlayTypeDirect => 'Direct playback';

  @override
  String get playerTranscodeReason => 'Transcode reason';

  @override
  String get playerTranscodeReasonSeparator => '; ';

  @override
  String get playerPlaybackInfo => 'Playback info';

  @override
  String get playerMediaSourceInfo => 'Media source info';

  @override
  String get playerContainerFormat => 'Container';

  @override
  String get playerBufferDuration => 'Buffer duration';

  @override
  String get playerAudioCodec => 'Audio codec';

  @override
  String get playerGpuEnabled => 'GPU enabled';

  @override
  String get playerDecodeMethod => 'Decode method';

  @override
  String get playerEncodeMethod => 'Encode method';

  @override
  String get playerTranscodeFrameRate => 'Transcode frame rate';

  @override
  String get playerDroppedFrames => 'Dropped frames';

  @override
  String get playerCorruptedFrames => 'Corrupted frames';

  @override
  String get playerCodec => 'Codec';

  @override
  String get playerDynamicRange => 'Dynamic range';

  @override
  String get playerFullscreenEnter => 'Enter fullscreen';

  @override
  String get playerFullscreenExit => 'Exit fullscreen';

  @override
  String get playerNextVideo => 'Next video';

  @override
  String playerEpisodeNumber(String number) {
    return 'Episode $number';
  }

  @override
  String get playerReplay => 'Replay';

  @override
  String get playerUndo => 'Undo';

  @override
  String get playerSkipIntroAutoSkipped => 'Intro automatically skipped';

  @override
  String playerSkipOutroInSeconds(int seconds) {
    return 'Skipping outro in ${seconds}s';
  }

  @override
  String playerSkipOutroNextEpisodeInSeconds(int seconds) {
    return 'Playing next episode in ${seconds}s';
  }

  @override
  String playerSkipOutroEndInSeconds(int seconds) {
    return 'Ending playback in ${seconds}s';
  }

  @override
  String get playerUnknown => 'Unknown';

  @override
  String playerAudioDefaultSuffix(String language) {
    return '$language - Default';
  }

  @override
  String get playerSettingsWindowAspectRatioFollowVideo => 'Follow video';

  @override
  String get playerSettingsAspectRatioDefault => 'Default';

  @override
  String get playerSettingsAdvanced => 'Advanced';

  @override
  String get playerSettingsAutoNext => 'Auto next';

  @override
  String get playerSettingsSkipIntroOutro => 'Skip intro/outro';

  @override
  String get playerSettingsWindowRatio => 'Window ratio';

  @override
  String get playerSettingsAspectRatio => 'Aspect ratio';

  @override
  String get playerSettingsClientDecodeMode => 'Client decode mode';

  @override
  String get playerSettingsAudio => 'Audio';

  @override
  String get playerSettingsAudioPassthrough => 'Audio passthrough';

  @override
  String get playerSettingsAudioPassthroughTitle => 'Audio passthrough';

  @override
  String get playerSettingsAudioPassthroughDescription =>
      'Send compressed audio (AC3/DTS/EAC3/TrueHD) as-is to an HDMI/S-PDIF receiver to decode. Applies only to original audio in direct-link playback; transcoded audio falls back to local decoding.';

  @override
  String get playerSettingsAudioOutputDevice => 'Output device';

  @override
  String get playerSettingsAudioOutputDeviceAuto => 'Auto (default)';

  @override
  String get playerSettingsAudioOutputDeviceEmpty =>
      'No audio output devices detected';

  @override
  String get playerSettingsAdvancedTitle => 'Advanced settings';

  @override
  String get playerSettingsHevcToH264 => 'Convert HEVC to H.264';

  @override
  String get playerSettingsHevcToH264Description =>
      'Try enabling it when playback has audio but no video.';

  @override
  String get playerSettingsForceSdr => 'Force tone mapping to SDR';

  @override
  String get playerSettingsForceSdrDescription =>
      'Try enabling it when the image looks too dark; for devices that do not support HDR.';

  @override
  String get playerSettingsQuarkCdnSegment => 'Quark CDN segment direct link';

  @override
  String get playerSettingsQuarkCdnSegmentDescription =>
      'When on, prefetches the Quark netdisk direct stream by segment; when off, uses the original direct link method.';

  @override
  String get playerSettingsSmartSkip => 'Smart skip';

  @override
  String get playerSettingsSkipIntroOutroBoth => 'Skip intro and outro';

  @override
  String get playerSettingsIntroConfigured => 'Intro set';

  @override
  String get playerSettingsOutroConfigured => 'Outro set';

  @override
  String get playerSettingsNotSet => 'Not set';

  @override
  String playerSettingsSkipScope(String title, String season) {
    return 'Applies to: $title Season $season';
  }

  @override
  String get playerSettingsSmartSkipIntroOutro => 'Smart skip intro/outro';

  @override
  String get playerSettingsIntroDuration => 'Intro duration';

  @override
  String get playerSettingsOutroDuration => 'Outro duration';

  @override
  String playerSettingsSetOutroToRemaining(String time) {
    return 'Set outro to the current remaining time $time';
  }

  @override
  String playerSettingsSetIntroToCurrent(String time) {
    return 'Set intro to the current time $time';
  }

  @override
  String get playerSettingsTenMinutes => '10 minutes';

  @override
  String get playerSettingsSliderStart => 'Start';

  @override
  String get playerSettingsSliderEnd => 'End';

  @override
  String get playerSettingsDecodeAutoTip =>
      'Automatically selects hardware decoding and falls back to software decoding on failure. Recommended.';

  @override
  String get playerSettingsDecodeSoftwareTip =>
      'Forces software decoding; best compatibility and a fallback when hardware decoding shows artifacts or a black screen.';

  @override
  String get playerSettingsDecodeCopyTip =>
      'Hardware decoding with frames copied back to memory; works with all filters, danmaku and screenshot features at a slight CPU cost.';

  @override
  String get playerSettingsSoftwareDecode => 'Software decoding';

  @override
  String get playerSettingsCopyBackMode => 'Copy-back mode';

  @override
  String get playerSettingsSpecifyHwdec => 'Specify hardware decoder';

  @override
  String get playerSettingsNoHwdecAvailable =>
      'No usable hardware decoder was detected';

  @override
  String get playerQualityTitle => 'Video quality';

  @override
  String get playerQualityOriginal => 'Original';

  @override
  String get playerQualityCustom => 'Custom';

  @override
  String get playerQualityCustomTitle => 'Custom video quality';

  @override
  String get playerQualityDirectUnsupported =>
      'This quality is not yet supported for direct-link playback';

  @override
  String get playerQualityLowRiskHint =>
      'This option carries a relatively lower risk-control chance; choosing it first is recommended';

  @override
  String get playerQualityOriginalNoAudioHint =>
      'Original quality may have no sound via direct link';

  @override
  String get playerQualityOriginalNoAudioTooltip =>
      'Because the player has limited support for audio codec formats, the original quality may have no sound in direct-link playback. Try switching the playback mode to “NAS proxy”.';

  @override
  String get playerSpeedLabel => 'Speed';

  @override
  String get playerSettingsAuto => 'Auto';

  @override
  String get playerTranscodeReasonLowerQuality =>
      'Lower quality per video quality setting';

  @override
  String get playerTranscodeReasonSubtitleBurn => 'Subtitle burn-in';

  @override
  String get playerTranscodeReasonSubtitleToVtt =>
      'Subtitle converted to vtt segments';

  @override
  String get playerTranscodeReasonVideoFormat => 'Video format conversion';

  @override
  String get playerTranscodeReasonAudioFormat => 'Audio format conversion';

  @override
  String get playerTranscodeReasonToneMapping => 'Tone mapping';

  @override
  String get playerDecodeMethodSoftware => 'Software decoding';

  @override
  String get playerDecodeMethodQsv => 'QSV decoding';

  @override
  String get playerDecodeMethodVaapi => 'VAAPI decoding';

  @override
  String get playerDecodeMethodNvdec => 'NVDEC decoding';

  @override
  String get playerDecodeMethodRkmpp => 'RKMPP decoding';

  @override
  String get playerEncodeMethodSoftware => 'Software encoding';

  @override
  String get playerEncodeMethodQsv => 'QSV encoding';

  @override
  String get playerEncodeMethodQsvLowPower => 'QSV low-power encoding';

  @override
  String get playerEncodeMethodVaapi => 'VAAPI encoding';

  @override
  String get playerEncodeMethodNvenc => 'NVENC encoding';

  @override
  String get playerEncodeMethodRkmpp => 'RKMPP encoding';

  @override
  String get smartAnalysisQueuedLoading => 'Intro/outro analysis submitted';

  @override
  String get smartAnalysisCloudOrStrmRejected =>
      'Smart intro/outro analysis is unavailable for netdisk or STRM videos';

  @override
  String get playerSkipSegmentIntro => 'intro';

  @override
  String get playerSkipSegmentRecap => 'recap';

  @override
  String get playerSkipSegmentOutro => 'outro';

  @override
  String get playerSkipSegmentPreview => 'next-episode preview';

  @override
  String get playerSkipSegmentCommercial => 'advertisement';

  @override
  String get playerSkipSegmentGeneric => 'segment';

  @override
  String playerSkipSegmentJoined(String parts) {
    return '$parts';
  }

  @override
  String playerSkipSegmentInSeconds(String seconds, String subject) {
    return 'Skipping $subject in ${seconds}s';
  }

  @override
  String playerSkipAutoSkipped(String subject) {
    return 'Automatically skipped $subject';
  }

  @override
  String get playerSettingsSkipRecap => 'Skip recaps';

  @override
  String get playerSettingsSkipPreview => 'Skip next-episode previews';

  @override
  String get playerSettingsSkipCommercial => 'Skip advertisements';

  @override
  String get playerSettingsSmartSkipConfig => 'Smart skip settings';

  @override
  String get playerSettingsSkipIntroOnly => 'Skip intros';

  @override
  String get playerSettingsSkipOutroOnly => 'Skip outros';

  @override
  String get playerSkipSegmentConnector => ' and ';

  @override
  String get smartSkipConfigTitle => 'Smart skip settings';

  @override
  String get smartSkipSave => 'Save';

  @override
  String get smartSkipSaved => 'Smart skip settings saved';

  @override
  String get smartSkipSaveFailed => 'Could not save';

  @override
  String get smartSkipLoginRequired => 'Sign in to configure';

  @override
  String get smartSkipLoadFailed =>
      'Could not load the server settings; showing defaults';

  @override
  String get smartSkipDetectMode => 'Detection mode';

  @override
  String get smartSkipAnimeMode => 'Anime mode';

  @override
  String get smartSkipPreferChromaprint => 'Prefer fingerprint matching';

  @override
  String get smartSkipAlternativeBlackFrame =>
      'Alternative black-frame analyzer';

  @override
  String get smartSkipDetectIntro => 'Detect intros';

  @override
  String get smartSkipDetectOutro => 'Detect outros';

  @override
  String get smartSkipDetectRecap => 'Detect recaps';

  @override
  String get smartSkipDetectPreview => 'Detect next-episode previews';

  @override
  String get smartSkipDetectCommercial => 'Detect advertisements';

  @override
  String get smartSkipAdvanced => 'Advanced';

  @override
  String get smartSkipDurationLimit => 'Duration limit (seconds)';

  @override
  String get smartSkipBoundaryOffset => 'Boundary offset (seconds)';

  @override
  String get smartSkipIntroStartOffset => 'Intro start offset';

  @override
  String get smartSkipIntroEndOffset => 'Intro end offset';

  @override
  String get smartSkipIntroMinDuration => 'Minimum intro duration';

  @override
  String get smartSkipIntroMaxDuration => 'Maximum intro duration';

  @override
  String get smartSkipOutroMinDuration => 'Minimum outro duration';

  @override
  String get smartSkipOutroMaxDuration => 'Maximum outro duration';

  @override
  String get smartSkipOutroEndOffset => 'Outro end offset';

  @override
  String get smartSkipRestoreDefaults => 'Restore defaults';

  @override
  String get playerSettingsSmartSkipIntro => 'Skip intros';

  @override
  String get playerSettingsSmartSkipOutro => 'Skip outros';

  @override
  String get smartSkipAnalysisFailedRetry =>
      'Could not submit the analysis request. Try again later.';

  @override
  String get smartSkipLoadConfigFailed =>
      'Could not load the smart skip settings';

  @override
  String get smartSkipSaveConfigFailed =>
      'Could not save the smart skip settings';

  @override
  String get smartSkipConfigConfigure => 'Configure';

  @override
  String get settingsSmartSkipConfigCaption =>
      'Server-side parameters for smart intro/outro analysis';

  @override
  String get settingsDanmuDandanSource => 'Dandanplay danmu source';

  @override
  String get settingsDanmuDandanSourceCaption =>
      'Configure the dandanplay official and relay sources, enable them independently and pick which one is tried first';

  @override
  String get settingsDanmuFallbackServers => 'Fallback danmu servers';

  @override
  String get settingsDanmuFallbackServersCaption =>
      'Third-party servers tried in order when every direct danmu source comes back empty';

  @override
  String get danmuSourceConfigure => 'Configure';

  @override
  String get danmuSourceSave => 'Save';

  @override
  String get danmuSourceSaved => 'Saved';

  @override
  String get danmuSourceDeleted => 'Deleted';

  @override
  String get danmuSourceFallbackDialogTitle => 'Fallback Danmu Servers';

  @override
  String get danmuSourceFallbackAdd => 'Add server';

  @override
  String get danmuSourceFallbackEdit => 'Edit server';

  @override
  String get danmuSourceFallbackNameHint => 'Name (optional)';

  @override
  String get danmuSourceFallbackUrlHint => 'Server URL';

  @override
  String get danmuSourceFallbackEmpty => 'No fallback servers yet';

  @override
  String get danmuSourceFallbackDeleteTitle => 'Delete server';

  @override
  String danmuSourceFallbackDeleteMessage(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get danmuSourceDelete => 'Delete';

  @override
  String get danmuSourceUrlInvalid => 'URL must start with http:// or https://';

  @override
  String get danmuSourceLoadFailed => 'Failed to load danmu source config';

  @override
  String get danmuSourceSaveFailed => 'Failed to save danmu source config';

  @override
  String get danmuSourceDeleteFailed => 'Failed to delete the fallback server';

  @override
  String get danmuSourceEnabled => 'Enabled';

  @override
  String get danmuSourceRelayRequired => 'Enter the dandanplay relay URL';

  @override
  String get danmuSourceRelayReachable => 'Dandanplay relay reachable';

  @override
  String get danmuSourceRelayUnreachable => 'Dandanplay relay unreachable';

  @override
  String get danmuDandanDialogTitle => 'Dandanplay danmu source';

  @override
  String get danmuDandanOfficialTitle => 'Official service';

  @override
  String get danmuDandanOfficialCaption =>
      'The official open platform, with more danmaku (incl. some western shows)';

  @override
  String get danmuDandanRelayTitle => 'Relay service';

  @override
  String get danmuDandanRelayCaption =>
      'Reach dandanplay through a third-party ddp relay';

  @override
  String get danmuDandanEnable => 'Enable';

  @override
  String get danmuDandanPreferred => 'Preferred';

  @override
  String get danmuDandanPreferredTooltip =>
      'Search this source first, falling back to the other only when it finds nothing';

  @override
  String get danmuDandanPreferredNeedsEnable => 'Enable this source first';

  @override
  String get danmuDandanOfficialAppIdHint => 'AppId';

  @override
  String get danmuDandanOfficialAppSecretHint => 'AppSecret';

  @override
  String get danmuDandanOfficialHint =>
      'Register a free application at doc.dandanplay.com/open to get AppId/AppSecret';

  @override
  String get danmuDandanRelayUrlHint => 'https://example.com/ddp/v1';

  @override
  String get danmuDandanTest => 'Test connection';

  @override
  String get danmuDandanTesting => 'Testing…';

  @override
  String get danmuDandanOfficialTestOk => 'Official service reachable';

  @override
  String get danmuDandanOfficialTestFailed => 'Official service unavailable';

  @override
  String get danmuDandanRelayTestOk => 'Relay service reachable';

  @override
  String get danmuDandanRelayTestFailed => 'Relay service unavailable';

  @override
  String get danmuDandanStatusEnabled => 'enabled';

  @override
  String get danmuDandanStatusDisabled => 'disabled';

  @override
  String get danmuDandanStatusPreferred => 'preferred';

  @override
  String get danmuDandanNoneEnabled => 'No dandanplay source is enabled';
}
