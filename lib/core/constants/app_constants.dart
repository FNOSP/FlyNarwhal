/// App-wide constants
class AppConstants {
  const AppConstants._();

  // API
  static const String defaultApiKey = "NDzZTVxnRKP8Z0jXg1VAMonaG8akvh";
  static const String defaultApiSecret = "16CCEB3D-AB42-077D-36A1-F355324E4237";

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

  // Media
  static const String mediaDbList = '/v/api/v1/mediadb/list';
  static const String mediaDbSum = '/v/api/v1/mediadb/sum';
  static const String playList = '/v/api/v1/play/list';
  static const String playInfo = '/v/api/v1/play/info';
  static const String itemList = '/v/api/v1/item/list';
  static const String favoriteList = '/v/api/v1/favorite/list';
  static const String itemDetail = '/v/api/v1/item/detail';
  static const String itemPrefix = '/v/api/v1/item';
  static const String streamListPrefix = '/v/api/v1/stream/list';
  static const String personListPrefix = '/v/api/v1/person/list';
  static const String seasonListPrefix = '/v/api/v1/season/list';
  static const String episodeListPrefix = '/v/api/v1/episode/list';

  // Favorite & Watched
  static const String favorite = '/v/api/v1/item/favorite';
  static const String watched = '/v/api/v1/item/watched';

  // Tags
  static const String tagGenres = '/v/api/v1/tag/genres';
  static const String tagList = '/v/api/v1/tag/list';

  // App
  static const String authorizedDir = '/v/api/v1/app/authorized/dir';

  static String itemByGuid(String guid) => '$itemPrefix/$guid';

  static String streamListByGuid(String guid) => '$streamListPrefix/$guid';

  static String personListByGuid(String guid) => '$personListPrefix/$guid';

  static String seasonListByGuid(String guid) => '$seasonListPrefix/$guid';

  static String episodeListByGuid(String guid) => '$episodeListPrefix/$guid';
}

/// Response code constants
class ResponseCodes {
  const ResponseCodes._();

  static const int success = 0;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int serverError = 500;
}

/// Storage keys
class StorageKeys {
  const StorageKeys._();

  static const String authToken = 'auth_token';
  static const String baseUrl = 'base_url';
  static const String cookieState = 'cookie_state';
  static const String authCode = 'auth_code';
  static const String loginHistory = 'login_history';
  static const String followSystemTheme = 'follow_system_theme';
  static const String darkMode = 'dark_mode';
  static const String navigationDisplayMode = 'navigation_display_mode';
}
