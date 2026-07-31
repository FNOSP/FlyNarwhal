/// App-wide constants
class AppConstants {
  const AppConstants._();

  // API
  static const String defaultApiKey = "NDzZTVxnRKP8Z0jXg1VAMonaG8akvh";
  static const String defaultFlyNarwhalApiSecret =
      "16CCEB3D-AB42-077D-36A1-F355324E4237";
  static const String flyNarwhalApiSecret =
      String.fromEnvironment('FLY_NARWHAL_API_SECRET');

  // User Agent
  static const String userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36";

  // Timeouts
  static const Duration defaultConnectTimeout = Duration(seconds: 10);
  static const Duration defaultReceiveTimeout = Duration(seconds: 10);
  static const Duration defaultSendTimeout = Duration(seconds: 10);

  // Cache
  static const int maxCacheBytes = 300 * 1024 * 1024; // 300 MB
  static const int maxCacheObjects = 100;
  static const String cacheKey = 'fly_narwhal_memory_cache';

  // Navigation
  static const int maxNavigationStackSize = 20;
}

/// API endpoint constants
class ApiEndpoints {
  const ApiEndpoints._();

  // Base
  static const String apiBase = '/v/api/v1';

  // User
  static const String userInfo = '/v/api/v1/user/info';
  static const String userLogout = '/v/api/v1/user/logout';

  // Media
  static const String mediaDbList = '/v/api/v1/mediadb/list';
  static const String mediaDbSum = '/v/api/v1/mediadb/sum';
  static const String playList = '/v/api/v1/play/list';
  static const String playInfo = '/v/api/v1/play/info';
  static const String playPlay = '/v/api/v1/play/play';
  static const String playRecord = '/v/api/v1/play/record';
  static const String mediaP = '/v/api/v1/media/p';
  static const String itemList = '/v/api/v1/item/list';
  static const String favoriteList = '/v/api/v1/favorite/list';
  static const String searchList = '/v/api/v1/search/list';
  static const String itemDetail = '/v/api/v1/item/detail';
  static const String itemPrefix = '/v/api/v1/item';
  static const String stream = '/v/api/v1/stream';
  static const String streamListPrefix = '/v/api/v1/stream/list';
  static const String personListPrefix = '/v/api/v1/person/list';
  static const String personPrefix = '/v/api/v1/person';
  static const String personItemList = '/v/api/v1/person/item/list';
  static const String seasonListPrefix = '/v/api/v1/season/list';
  static const String episodeListPrefix = '/v/api/v1/episode/list';
  static const String configSetByItem = '/v/api/v1/play/setConfigByItem';

  // FlyNarwhal Server
  static const String flyNarwhalVersion = '/api/config/version';
  static const String flyNarwhalUpdateStart = '/api/config/update/start';
  static const String flyNarwhalAnalyze = '/api/analysis/analyze';
  static const String flyNarwhalSeasonStatus = '/api/analysis/season/status';
  static const String flyNarwhalAnalysisStatus = '/api/analysis/status';
  static const String flyNarwhalSegments = '/api/analysis/segments';
  static const String flyNarwhalFnBaseUrl = '/api/config/fn-base-url';
  static const String flyNarwhalDanmaku = '/api/danmu/get';

  // Favorite & Watched
  static const String favorite = '/v/api/v1/item/favorite';
  static const String watched = '/v/api/v1/item/watched';

  // Tags
  static const String tagGenres = '/v/api/v1/tag/genres';
  static const String tagList = '/v/api/v1/tag/list';

  // App
  static const String authorizedDir = '/v/api/v1/server/getAppAuthorizedDir';

  // Server file browsing
  static const String serverPath = '/v/api/v1/server/path';

  // Subtitle
  static const String subtitleSearch = '/v/api/v1/subtitle/search';
  static const String subtitleDownload = '/v/api/v1/subtitle/download';
  static const String subtitleMark = '/v/api/v1/subtitle/mark';
  static const String subtitlePredownload = '/v/api/v1/subtitle/predownload';
  static const String subtitleUploadPrefix = '/v/api/v1/subtitle/upload';

  static String itemByGuid(String guid) => '$itemPrefix/$guid';

  static String streamListByGuid(String guid) => '$streamListPrefix/$guid';

  static String personListByGuid(String guid) => '$personListPrefix/$guid';

  static String personByGuid(String guid) => '$personPrefix/$guid';

  static String seasonListByGuid(String guid) => '$seasonListPrefix/$guid';

  static String episodeListByGuid(String guid) => '$episodeListPrefix/$guid';

  static String subtitleDownloadByGuid(String guid) =>
      '$apiBase/subtitle/dl/$guid';

  static String tagByName(String tag) => '$apiBase/tag/$tag';
}

/// Response code constants
class ResponseCodes {
  const ResponseCodes._();

  static const int success = 0;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int serverError = 500;

  /// Business code from /v/api/v1/subtitle/mark: every submitted file is
  /// already registered as a subtitle, so nothing new was added.
  static const int subtitleAlreadyMarked = -50;
}

/// Storage keys
class StorageKeys {
  const StorageKeys._();

  static const String authToken = 'auth_token';
  static const String baseUrl = 'base_url';
  static const String cookieState = 'cookie_state';
  static const String loginHistory = 'login_history';
  static const String followSystemTheme = 'follow_system_theme';
  static const String darkMode = 'dark_mode';
  static const String navigationDisplayMode = 'navigation_display_mode';
}
