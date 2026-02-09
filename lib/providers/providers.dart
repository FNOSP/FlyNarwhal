import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/base_response.dart';
import '../data/models/user_info.dart';
import '../data/storage/preferences_manager.dart';
import '../data/network/dio_client.dart';
import '../data/network/tag_repository.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

final preferencesManagerProvider = Provider<PreferencesManager>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesManager(prefs);
});

final dioClientProvider = Provider<DioClient>((ref) {
  final prefsManager = ref.watch(preferencesManagerProvider);
  return DioClient(prefsManager);
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return TagRepository(dioClient);
});

class SettingsState {
  final bool followSystemTheme;
  final bool darkMode;
  final String navigationDisplayMode;

  const SettingsState({
    required this.followSystemTheme,
    required this.darkMode,
    required this.navigationDisplayMode,
  });

  SettingsState copyWith({
    bool? followSystemTheme,
    bool? darkMode,
    String? navigationDisplayMode,
  }) {
    return SettingsState(
      followSystemTheme: followSystemTheme ?? this.followSystemTheme,
      darkMode: darkMode ?? this.darkMode,
      navigationDisplayMode: navigationDisplayMode ?? this.navigationDisplayMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._prefs)
      : super(SettingsState(
          followSystemTheme: _prefs.getFollowSystemTheme(),
          darkMode: _prefs.getDarkMode(),
          navigationDisplayMode: _prefs.getNavigationDisplayMode(),
        ));

  final PreferencesManager _prefs;

  Future<void> setFollowSystemTheme(bool value) async {
    await _prefs.saveFollowSystemTheme(value);
    state = state.copyWith(followSystemTheme: value);
  }

  Future<void> setDarkMode(bool value) async {
    await _prefs.saveDarkMode(value);
    state = state.copyWith(darkMode: value);
  }

  Future<void> setNavigationDisplayMode(String value) async {
    await _prefs.saveNavigationDisplayMode(value);
    state = state.copyWith(navigationDisplayMode: value);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(preferencesManagerProvider);
  return SettingsNotifier(prefs);
});

final userInfoProvider = FutureProvider<UserInfo>((ref) async {
  final dioClient = ref.read(dioClientProvider);
  final response = await dioClient.dio.get('/v/api/v1/user/info');
  final baseResponse = FnBaseResponse<UserInfo>.fromJson(
    response.data,
    (json) {
      if (json is Map<String, dynamic>) {
        return UserInfo.fromJson(json);
      }
      return UserInfo.fromJson(Map<String, dynamic>.from(json as Map));
    },
  );
  if (baseResponse.code != 0) {
    throw Exception(baseResponse.msg);
  }
  return baseResponse.data ?? UserInfo(guid: '', username: '', isAdmin: 0);
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
    debugPrint(
      'ImageCache source=$source url=$url key=$key size=${size ?? '-'} validTill=${validTill ?? '-'}',
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
