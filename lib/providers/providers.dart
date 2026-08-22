import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/runtime_configuration.dart';
import '../core/config/secret_bridge_selector.dart';
import '../core/network/dio_client.dart';
import '../core/security/password_cipher.dart';
import '../core/utils/log/app_talker.dart';
import '../core/utils/log/error_log_exporter.dart';
import '../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../data/datasources/remote/media_remote_data_source.dart';
import '../data/datasources/remote/file_remote_data_source.dart';
import '../data/datasources/remote/subtitle_remote_data_source.dart';
import '../data/datasources/remote/tag_remote_data_source.dart';
import '../data/datasources/remote/user_remote_data_source.dart';
import '../data/models/user_info.dart';
import '../data/repositories/tag_repository_impl.dart';
import '../data/storage/account_settings_store.dart';
import '../data/storage/fly_narwhal_settings.dart';
import '../data/storage/login_history_password_service.dart';
import '../data/storage/player_settings_store.dart';
import '../data/storage/preferences_manager.dart';
import '../data/storage/shortcut_settings_store.dart';
import '../domain/repositories/i_tag_repository.dart';
import 'danmaku_controller.dart';
import 'fly_narwhal_connection_test_notifier.dart';
import 'smart_analysis_controller.dart';
import 'smart_analysis_status_controller.dart';
import 'smart_skip_settings_controller.dart';
import 'season_analysis_status_controller.dart';
import 'episode_analysis_controller.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

final preferencesManagerProvider = Provider<PreferencesManager>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesManager(prefs);
});

final accountSettingsStoreProvider = Provider<AccountSettingsStore>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AccountSettingsStore(prefs);
});

// 当前登录用户的 guid，未登录返回 null。设置项隔离、迁移统一依赖它。
final currentUserGuidProvider = Provider<String?>((ref) {
  final userInfo = ref.watch(userInfoProvider).valueOrNull;
  final guid = userInfo?.guid.trim();
  return (guid == null || guid.isEmpty) ? null : guid;
});

final runtimeConfigurationProvider = Provider<RuntimeConfiguration>((ref) {
  return NativeRuntimeConfiguration(resolveSecretBridge());
});

final errorLogExporterProvider = Provider<ErrorLogExporter>((ref) {
  return DesktopErrorLogExporter();
});

final passwordCipherProvider = Provider<PasswordCipher>((ref) {
  final configuration = ref.watch(runtimeConfigurationProvider);
  return PasswordCipher(configuration);
});

final loginHistoryPasswordServiceProvider =
    Provider<LoginHistoryPasswordService>((ref) {
  final passwordCipher = ref.watch(passwordCipherProvider);
  return LoginHistoryPasswordService(passwordCipher);
});

final authRefreshProvider = StateProvider<int>((ref) => 0);

class SessionStateController {
  SessionStateController(this._ref);

  final Ref _ref;

  // Clear all persisted auth state and force router re-evaluation.
  Future<void> invalidateSession() async {
    _ref.read(userInfoProvider.notifier).clear();
    final prefs = _ref.read(preferencesManagerProvider);
    await prefs.clear();
    _ref.read(authRefreshProvider.notifier).state++;
  }
}

final sessionStateControllerProvider = Provider<SessionStateController>((ref) {
  return SessionStateController(ref);
});

final lastNavigationKeyProvider = StateProvider<String?>((ref) => null);
final navigationStackProvider =
    StateNotifierProvider<NavigationStackNotifier, List<String>>(
  (ref) => NavigationStackNotifier(),
);

class NavigationStackNotifier extends StateNotifier<List<String>> {
  NavigationStackNotifier() : super(const []);

  /// The page the player was entered from. The player routes live outside the
  /// [ShellRoute] so they never reach the stack; remember the current top
  /// separately when navigating into the player so exiting the player can
  /// return to the originating page.
  String? playerSourcePath;

  void pushPath(String path) {
    if (path.isEmpty) return;
    if (state.isNotEmpty && state.last == path) return;
    final updated = [...state, path];
    if (updated.length > 20) {
      updated.removeAt(0);
    }
    state = updated;
  }

  String? pop() {
    if (state.length <= 1) return null;
    final updated = [...state]..removeLast();
    state = updated;
    return updated.isNotEmpty ? updated.last : null;
  }
}

final dioClientProvider = Provider<DioClient>((ref) {
  final prefsManager = ref.watch(preferencesManagerProvider);
  return DioClient.withCallbacks(
    getToken: () => prefsManager.getToken() ?? '',
    getCookie: () => prefsManager.getCookie() ?? '',
    getBaseUrl: () => prefsManager.getBaseUrl() ?? '',
  );
});

final tagRemoteDataSourceProvider = Provider<TagRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return TagRemoteDataSource(dioClient);
});

final iTagRepositoryProvider = Provider<ITagRepository>((ref) {
  final remoteDataSource = ref.watch(tagRemoteDataSourceProvider);
  return TagRepositoryImpl(remoteDataSource);
});

final mediaRemoteDataSourceProvider = Provider<MediaRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return MediaRemoteDataSource(dioClient);
});

// User remote data source provider
final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return UserRemoteDataSource(dioClient);
});

// File browsing remote data source provider
final fileRemoteDataSourceProvider = Provider<FileRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return FileRemoteDataSource(dioClient);
});

// Subtitle search / download remote data source provider
final subtitleRemoteDataSourceProvider =
    Provider<SubtitleRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return SubtitleRemoteDataSource(dioClient);
});

final flyNarwhalSettingsProvider = Provider<FlyNarwhalSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final userGuid = ref.watch(currentUserGuidProvider);
  return FlyNarwhalSettings(prefs, userGuid: userGuid);
});

final flyNarwhalRemoteDataSourceProvider =
    Provider<FlyNarwhalRemoteDataSource>((ref) {
  final prefsManager = ref.watch(preferencesManagerProvider);
  final flyNarwhalSettings = ref.watch(flyNarwhalSettingsProvider);
  final runtimeConfiguration = ref.watch(runtimeConfigurationProvider);
  return FlyNarwhalRemoteDataSource(
    getToken: () => prefsManager.getToken() ?? '',
    getCookie: () => prefsManager.getCookie() ?? '',
    getFnBaseUrl: () => prefsManager.getBaseUrl() ?? '',
    getFlyNarwhalBaseUrl: () => flyNarwhalSettings.baseUrl ?? '',
    getFlyNarwhalServerEnabled: () => flyNarwhalSettings.enabled,
    getAuthCode: () => flyNarwhalSettings.authCode ?? '',
    runtimeConfiguration: runtimeConfiguration,
  );
});

final flyNarwhalConnectionTestProvider = StateNotifierProvider<
    FlyNarwhalConnectionTestNotifier, AsyncValue<String?>>((ref) {
  final dataSource = ref.watch(flyNarwhalRemoteDataSourceProvider);
  return FlyNarwhalConnectionTestNotifier(dataSource);
});

final smartAnalysisControllerProvider = StateNotifierProvider<
    SmartAnalysisController, SmartAnalysisSubmissionState>((ref) {
  final flyNarwhalDataSource = ref.watch(flyNarwhalRemoteDataSourceProvider);
  final mediaDataSource = ref.watch(mediaRemoteDataSourceProvider);
  return SmartAnalysisController(
    flyNarwhalDataSource,
    mediaDataSource,
    startSeasonPolling: (seasonGuid) {
      ref
          .read(seasonAnalysisStatusControllerProvider.notifier)
          .startForcedPolling(seasonGuid);
    },
  );
});

final smartAnalysisStatusControllerProvider = StateNotifierProvider<
    SmartAnalysisStatusController, SmartAnalysisStatusState>((ref) {
  final dataSource = ref.watch(flyNarwhalRemoteDataSourceProvider);
  final settings = ref.watch(flyNarwhalSettingsProvider);
  return SmartAnalysisStatusController(dataSource, settings);
});

final smartSkipSettingsControllerProvider =
    StateNotifierProvider<SmartSkipSettingsController, SmartSkipSettingsState>(
        (ref) {
  final controller = SmartSkipSettingsController(
    ref.watch(preferencesManagerProvider),
  );
  ref.listen<AsyncValue<UserInfo?>>(userInfoProvider, (previous, next) {
    controller.updateUserInfo(next.valueOrNull);
  }, fireImmediately: true);
  return controller;
});

final seasonAnalysisStatusControllerProvider = StateNotifierProvider<
    SeasonAnalysisStatusController,
    Map<String, SeasonAnalysisStatusEntry>>((ref) {
  return SeasonAnalysisStatusController(
    ref.watch(flyNarwhalRemoteDataSourceProvider),
  );
});

final episodeAnalysisControllerProvider =
    StateNotifierProvider<EpisodeAnalysisController, EpisodeAnalysisState>(
        (ref) {
  return EpisodeAnalysisController(
    ref.watch(flyNarwhalRemoteDataSourceProvider),
  );
});

final danmakuControllerProvider =
    StateNotifierProvider<DanmakuController, DanmakuState>((ref) {
  final dataSource = ref.watch(flyNarwhalRemoteDataSourceProvider);
  final settingsManager = ref.watch(playerSettingsManagerProvider);
  final controller = DanmakuController(
    dataSource,
    settingsManager,
    () {
      final settings = ref.read(settingsProvider);
      return settings.flyNarwhalServerEnabled &&
          settings.flyNarwhalServerBaseUrl.isNotEmpty &&
          settings.hasFlyNarwhalAuthCode;
    },
  );
  ref.listen<SettingsState>(settingsProvider, (previous, next) {
    final wasAvailable = previous != null &&
        previous.flyNarwhalServerEnabled &&
        previous.flyNarwhalServerBaseUrl.isNotEmpty &&
        previous.hasFlyNarwhalAuthCode;
    final isAvailable = next.flyNarwhalServerEnabled &&
        next.flyNarwhalServerBaseUrl.isNotEmpty &&
        next.hasFlyNarwhalAuthCode;
    if (wasAvailable && !isAvailable) {
      controller.clear();
    }
  });
  return controller;
});

class SettingsState {
  final bool followSystemTheme;
  final bool darkMode;
  final String navigationDisplayMode;
  final bool flyNarwhalServerEnabled;
  final String flyNarwhalServerBaseUrl;
  final bool hasFlyNarwhalAuthCode;

  const SettingsState({
    required this.followSystemTheme,
    required this.darkMode,
    required this.navigationDisplayMode,
    required this.flyNarwhalServerEnabled,
    required this.flyNarwhalServerBaseUrl,
    required this.hasFlyNarwhalAuthCode,
  });

  // Whether the FlyNarwhal server is fully configured and ready to use
  bool get isFlyNarwhalServerAvailable {
    return flyNarwhalServerEnabled &&
        flyNarwhalServerBaseUrl.isNotEmpty &&
        hasFlyNarwhalAuthCode;
  }

  SettingsState copyWith({
    bool? followSystemTheme,
    bool? darkMode,
    String? navigationDisplayMode,
    bool? flyNarwhalServerEnabled,
    String? flyNarwhalServerBaseUrl,
    bool? hasFlyNarwhalAuthCode,
  }) {
    return SettingsState(
      followSystemTheme: followSystemTheme ?? this.followSystemTheme,
      darkMode: darkMode ?? this.darkMode,
      navigationDisplayMode:
          navigationDisplayMode ?? this.navigationDisplayMode,
      flyNarwhalServerEnabled:
          flyNarwhalServerEnabled ?? this.flyNarwhalServerEnabled,
      flyNarwhalServerBaseUrl:
          flyNarwhalServerBaseUrl ?? this.flyNarwhalServerBaseUrl,
      hasFlyNarwhalAuthCode:
          hasFlyNarwhalAuthCode ?? this.hasFlyNarwhalAuthCode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._prefs, this._flyNarwhalSettings, {String? userGuid})
      : _userGuid = PreferencesManager.normalizeGuid(userGuid),
        super(SettingsState(
          followSystemTheme: _prefs.getFollowSystemTheme(userGuid: userGuid),
          darkMode: _prefs.getDarkMode(userGuid: userGuid),
          navigationDisplayMode:
              _prefs.getNavigationDisplayMode(userGuid: userGuid),
          flyNarwhalServerEnabled: _flyNarwhalSettings.enabled,
          flyNarwhalServerBaseUrl: _flyNarwhalSettings.baseUrl?.trim() ?? '',
          hasFlyNarwhalAuthCode:
              _flyNarwhalSettings.authCode?.trim().isNotEmpty ?? false,
        ));

  final PreferencesManager _prefs;
  final FlyNarwhalSettings _flyNarwhalSettings;
  final String? _userGuid;

  Future<void> setFollowSystemTheme(bool value) async {
    await _prefs.saveFollowSystemTheme(value, userGuid: _userGuid);
    state = state.copyWith(followSystemTheme: value);
  }

  Future<void> setDarkMode(bool value) async {
    await _prefs.saveDarkMode(value, userGuid: _userGuid);
    state = state.copyWith(darkMode: value);
  }

  Future<void> setNavigationDisplayMode(String value) async {
    await _prefs.saveNavigationDisplayMode(value, userGuid: _userGuid);
    state = state.copyWith(navigationDisplayMode: value);
  }

  Future<void> setFlyNarwhalServerEnabled(bool value) async {
    await _flyNarwhalSettings.setEnabled(value);
    state = state.copyWith(flyNarwhalServerEnabled: value);
  }

  Future<void> setFlyNarwhalServerBaseUrl(String value) async {
    final normalizedBaseUrl = value.trim();
    await _flyNarwhalSettings.setBaseUrl(normalizedBaseUrl);
    state = state.copyWith(flyNarwhalServerBaseUrl: normalizedBaseUrl);
  }

  Future<void> setFlyNarwhalAuthCode(String value) async {
    final normalizedAuthCode = value.trim();
    await _flyNarwhalSettings.setAuthCode(normalizedAuthCode);
    state = state.copyWith(
      hasFlyNarwhalAuthCode: normalizedAuthCode.isNotEmpty,
    );
  }

  String getFlyNarwhalAuthCode() {
    return _flyNarwhalSettings.authCode ?? '';
  }

  bool get isFlyNarwhalServerAvailable {
    return state.flyNarwhalServerEnabled &&
        state.flyNarwhalServerBaseUrl.isNotEmpty &&
        state.hasFlyNarwhalAuthCode;
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(preferencesManagerProvider);
  final flyNarwhalSettings = ref.watch(flyNarwhalSettingsProvider);
  final userGuid = ref.watch(currentUserGuidProvider);
  return SettingsNotifier(prefs, flyNarwhalSettings, userGuid: userGuid);
});

class UserInfoNotifier extends StateNotifier<AsyncValue<UserInfo?>> {
  UserInfoNotifier(this._prefs, this._dataSource, this._invalidateSession)
      : super(const AsyncValue.data(null));

  final PreferencesManager _prefs;
  final UserRemoteDataSource _dataSource;
  final Future<void> Function() _invalidateSession;

  // Load user info only when the current session is authenticated.
  Future<void> loadUserInfo({bool force = false}) async {
    final token = _prefs.getToken();
    final baseUrl = _prefs.getBaseUrl();
    final isLoggedIn = token != null &&
        token.isNotEmpty &&
        baseUrl != null &&
        baseUrl.isNotEmpty;
    if (!isLoggedIn) {
      state = const AsyncValue.data(null);
      return;
    }

    if (!force) {
      if (state is AsyncLoading<UserInfo?>) {
        return;
      }
      if (state.valueOrNull != null) {
        return;
      }
    }

    state = const AsyncValue.loading();
    try {
      final result = await _dataSource.getUserInfo();
      state = AsyncValue.data(result.getOrThrow());
    } catch (_) {
      // Any user-info failure invalidates the local session and returns to login,
      // mirroring KMP LoginStateManager behavior.
      await _invalidateSession();
      state = const AsyncValue.data(null);
    }
  }

  // Clear cached user info without triggering a new request.
  void clear() {
    state = const AsyncValue.data(null);
  }
}

final userInfoProvider =
    StateNotifierProvider<UserInfoNotifier, AsyncValue<UserInfo?>>((ref) {
  final prefs = ref.watch(preferencesManagerProvider);
  final dataSource = ref.watch(userRemoteDataSourceProvider);
  return UserInfoNotifier(
    prefs,
    dataSource,
    ref.read(sessionStateControllerProvider).invalidateSession,
  );
});

final imageCacheManagerProvider = Provider<CacheManager>((ref) {
  const maxCacheBytes = 300 * 1024 * 1024;
  const maxCacheObjects = 100;
  return CacheManager(
    Config(
      'fly_narwhal_memory_cache',
      maxNrOfCacheObjects: maxCacheObjects,
      repo: _InMemoryCacheInfoRepository(
        maxObjects: maxCacheObjects,
        maxBytes: maxCacheBytes,
      ),
      fileSystem: IOFileSystem('fly_narwhal_memory_cache'),
    ),
  );
});

class LoggingCacheManager extends CacheManager {
  LoggingCacheManager(super.config);

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    final resolvedKey = key ?? url;
    final cacheFile = await getFileFromCache(resolvedKey);
    final now = DateTime.now();
    if (cacheFile == null) {
      _logCacheDecision('network', url, resolvedKey, cacheFile);
    } else if (cacheFile.validTill.isBefore(now)) {
      _logCacheDecision('stale_network', url, resolvedKey, cacheFile);
    } else {
      _logCacheDecision('cache', url, resolvedKey, cacheFile);
    }
    yield* super.getFileStream(
      url,
      key: resolvedKey,
      headers: headers,
      withProgress: withProgress,
    );
  }

  void _logCacheDecision(
    String source,
    String url,
    String key,
    FileInfo? cacheFile,
  ) {
    final size = cacheFile?.file.lengthSync();
    final validTill = cacheFile?.validTill.toIso8601String();
    AppTalker.info(
      'ImageCache',
      'source=$source url=$url key=$key size=${size ?? '-'} validTill=${validTill ?? '-'}',
    );
  }
}

class _InMemoryCacheInfoRepository implements CacheInfoRepository {
  _InMemoryCacheInfoRepository({
    required this.maxObjects,
    required this.maxBytes,
  });

  final int maxObjects;
  final int maxBytes;
  final Map<String, CacheObject> _cacheObjects = {};
  final Map<int, CacheObject> _cacheObjectsById = {};
  int _nextId = 0;

  @override
  Future<CacheObject?> get(String url) {
    return Future.value(_cacheObjects[url]);
  }

  @override
  Future<List<CacheObject>> getAllObjects() async {
    return _cacheObjects.values.toList();
  }

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async {
    final entries = _cacheObjects.values.toList()
      ..sort((a, b) => _touchedAt(a).compareTo(_touchedAt(b)));

    final toRemove = <CacheObject>[];
    var totalBytes = _totalBytes(entries);
    while (entries.length > maxObjects || totalBytes > maxBytes) {
      final removed = entries.removeAt(0);
      toRemove.add(removed);
      totalBytes -= removed.length ?? 0;
    }
    return toRemove;
  }

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) async {
    final threshold = DateTime.now().subtract(maxAge);
    return _cacheObjects.values
        .where((object) => _touchedAt(object).isBefore(threshold))
        .toList();
  }

  @override
  Future<CacheObject> insert(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) async {
    final id = ++_nextId;
    final stored = _withId(cacheObject, id, setTouchedToNow: setTouchedToNow);
    _cacheObjects[stored.key] = stored;
    _cacheObjectsById[id] = stored;
    return stored;
  }

  @override
  Future<int> update(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) async {
    final id = cacheObject.id;
    if (id == null || !_cacheObjectsById.containsKey(id)) {
      return 0;
    }
    final stored = _withId(cacheObject, id, setTouchedToNow: setTouchedToNow);
    _cacheObjects[stored.key] = stored;
    _cacheObjectsById[id] = stored;
    return 1;
  }

  @override
  Future updateOrInsert(CacheObject cacheObject) async {
    final id = cacheObject.id;
    if (id == null || !_cacheObjectsById.containsKey(id)) {
      return insert(cacheObject);
    }
    return update(cacheObject);
  }

  @override
  Future<int> delete(int id) async {
    final cacheObject = _cacheObjectsById.remove(id);
    if (cacheObject == null) {
      return 0;
    }
    _cacheObjects.remove(cacheObject.key);
    return 1;
  }

  @override
  Future<int> deleteAll(Iterable<int> ids) async {
    var deleted = 0;
    for (final id in ids) {
      deleted += await delete(id);
    }
    return deleted;
  }

  @override
  Future<bool> open() async {
    return true;
  }

  @override
  Future<bool> close() async {
    return true;
  }

  @override
  Future<void> deleteDataFile() async {
    _cacheObjects.clear();
    _cacheObjectsById.clear();
  }

  @override
  Future<bool> exists() async {
    return _cacheObjects.isNotEmpty;
  }

  DateTime _touchedAt(CacheObject cacheObject) {
    return cacheObject.touched ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _totalBytes(List<CacheObject> objects) {
    var total = 0;
    for (final object in objects) {
      total += object.length ?? 0;
    }
    return total;
  }

  CacheObject _withId(
    CacheObject cacheObject,
    int id, {
    required bool setTouchedToNow,
  }) {
    final map = cacheObject.toMap(setTouchedToNow: setTouchedToNow);
    map[CacheObject.columnId] = id;
    return CacheObject.fromMap(map);
  }
}

// Player settings manager provider
final playerSettingsManagerProvider = Provider<PlayerSettingsManager>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final userGuid = ref.watch(currentUserGuidProvider);
  return PlayerSettingsManager(prefs, userGuid: userGuid);
});

final shortcutSettingsStoreProvider = Provider<ShortcutSettingsStore>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final userGuid = ref.watch(currentUserGuidProvider);
  return ShortcutSettingsStore(prefs, userGuid: userGuid);
});
