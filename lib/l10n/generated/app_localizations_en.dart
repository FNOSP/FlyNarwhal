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
}
