import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/log/app_talker.dart';
import '../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../data/models/fly_narwhal/index.dart';
import '../data/storage/player_settings_store.dart';

enum DanmakuLoadStatus {
  idle,
  loading,
  loaded,
  empty,
  failure,
}

class DanmakuSettings {
  static const double minimumArea = 0.1;
  static const double maximumArea = 1.0;
  static const double minimumOpacity = 0.0;
  static const double maximumOpacity = 1.0;
  static const double minimumFontSizeScale = 0.5;
  static const double maximumFontSizeScale = 1.7;
  static const double minimumSpeed = 0.5;
  static const double maximumSpeed = 2.0;

  final double area;
  final double opacity;
  final double fontSizeScale;
  final double speed;
  final bool syncPlaybackSpeed;
  final bool debugEnabled;

  const DanmakuSettings({
    this.area = 1.0,
    this.opacity = 1.0,
    this.fontSizeScale = 1.0,
    this.speed = 1.0,
    this.syncPlaybackSpeed = false,
    this.debugEnabled = false,
  });

  factory DanmakuSettings.clamped({
    double area = 1.0,
    double opacity = 1.0,
    double fontSizeScale = 1.0,
    double speed = 1.0,
    bool syncPlaybackSpeed = false,
    bool debugEnabled = false,
  }) {
    return DanmakuSettings(
      area: area.clamp(minimumArea, maximumArea).toDouble(),
      opacity: opacity.clamp(minimumOpacity, maximumOpacity).toDouble(),
      fontSizeScale: fontSizeScale
          .clamp(minimumFontSizeScale, maximumFontSizeScale)
          .toDouble(),
      speed: speed.clamp(minimumSpeed, maximumSpeed).toDouble(),
      syncPlaybackSpeed: syncPlaybackSpeed,
      debugEnabled: debugEnabled,
    );
  }

  DanmakuSettings copyWith({
    double? area,
    double? opacity,
    double? fontSizeScale,
    double? speed,
    bool? syncPlaybackSpeed,
    bool? debugEnabled,
  }) {
    return DanmakuSettings.clamped(
      area: area ?? this.area,
      opacity: opacity ?? this.opacity,
      fontSizeScale: fontSizeScale ?? this.fontSizeScale,
      speed: speed ?? this.speed,
      syncPlaybackSpeed: syncPlaybackSpeed ?? this.syncPlaybackSpeed,
      debugEnabled: debugEnabled ?? this.debugEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DanmakuSettings &&
            other.area == area &&
            other.opacity == opacity &&
            other.fontSizeScale == fontSizeScale &&
            other.speed == speed &&
            other.syncPlaybackSpeed == syncPlaybackSpeed &&
            other.debugEnabled == debugEnabled;
  }

  @override
  int get hashCode => Object.hash(
        area,
        opacity,
        fontSizeScale,
        speed,
        syncPlaybackSpeed,
        debugEnabled,
      );
}

class DanmakuState {
  final List<Danmaku> danmakuList;
  final bool isVisible;
  final DanmakuSettings settings;
  final DanmakuLoadStatus loadStatus;
  final String? errorMessage;
  final String? activeMediaGuid;

  const DanmakuState({
    this.danmakuList = const [],
    this.isVisible = true,
    this.settings = const DanmakuSettings(),
    this.loadStatus = DanmakuLoadStatus.idle,
    this.errorMessage,
    this.activeMediaGuid,
  });

  DanmakuState copyWith({
    List<Danmaku>? danmakuList,
    bool? isVisible,
    DanmakuSettings? settings,
    DanmakuLoadStatus? loadStatus,
    String? errorMessage,
    String? activeMediaGuid,
    bool clearErrorMessage = false,
    bool clearActiveMediaGuid = false,
  }) {
    return DanmakuState(
      danmakuList: danmakuList ?? this.danmakuList,
      isVisible: isVisible ?? this.isVisible,
      settings: settings ?? this.settings,
      loadStatus: loadStatus ?? this.loadStatus,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      activeMediaGuid:
          clearActiveMediaGuid ? null : activeMediaGuid ?? this.activeMediaGuid,
    );
  }
}

class DanmakuController extends StateNotifier<DanmakuState> {
  final FlyNarwhalRemoteDataSource _remoteDataSource;
  final PlayerSettingsManager _settingsManager;
  final bool Function() _canLoadDanmaku;
  int _requestGeneration = 0;

  DanmakuController(
    this._remoteDataSource,
    this._settingsManager,
    this._canLoadDanmaku,
  ) : super(
          DanmakuState(
            settings: DanmakuSettings.clamped(
              area: _settingsManager.getDanmakuArea(),
              opacity: _settingsManager.getDanmakuOpacity(),
              fontSizeScale: _settingsManager.getDanmakuFontSizeScale(),
              speed: _settingsManager.getDanmakuSpeed(),
              syncPlaybackSpeed: _settingsManager.getDanmakuSyncPlaybackSpeed(),
              debugEnabled: _settingsManager.getDanmakuDebugEnabled(),
            ),
          ),
        );

  Future<bool> loadDanmaku(DanmakuRequest request) async {
    if (!_canLoadDanmaku()) {
      clear();
      return false;
    }

    final currentRequestGeneration = ++_requestGeneration;
    state = state.copyWith(
      danmakuList: const [],
      loadStatus: DanmakuLoadStatus.loading,
      activeMediaGuid: request.guid,
      clearErrorMessage: true,
    );

    try {
      final response =
          (await _remoteDataSource.getDanmaku(request)).getOrThrow();
      if (currentRequestGeneration != _requestGeneration) {
        return false;
      }

      final selectedDanmaku = _selectDanmaku(
        response,
        request.episodeNumber,
      );
      final normalizedDanmaku = _normalizeAndSort(selectedDanmaku);
      final loadStatus = normalizedDanmaku.isEmpty
          ? DanmakuLoadStatus.empty
          : DanmakuLoadStatus.loaded;
      state = state.copyWith(
        danmakuList: normalizedDanmaku,
        loadStatus: loadStatus,
        clearErrorMessage: true,
      );
      return true;
    } catch (error) {
      if (currentRequestGeneration != _requestGeneration) {
        return false;
      }

      AppTalker.warning(
        'Danmaku',
        'Failed to load danmaku for media ${request.guid}: $error',
      );
      state = state.copyWith(
        danmakuList: const [],
        loadStatus: DanmakuLoadStatus.failure,
        errorMessage: error.toString(),
        isVisible: false,
      );
      return false;
    }
  }

  void toggleVisibility() {
    setVisibility(!state.isVisible);
  }

  void setVisibility(bool visible) {
    state = state.copyWith(isVisible: visible);
  }

  void updateArea(double value) {
    final settings = state.settings.copyWith(area: value);
    state = state.copyWith(settings: settings);
    _persistSetting(() => _settingsManager.setDanmakuArea(settings.area));
  }

  void updateOpacity(double value) {
    final settings = state.settings.copyWith(opacity: value);
    state = state.copyWith(settings: settings);
    _persistSetting(
      () => _settingsManager.setDanmakuOpacity(settings.opacity),
    );
  }

  void updateFontSizeScale(double value) {
    final settings = state.settings.copyWith(fontSizeScale: value);
    state = state.copyWith(settings: settings);
    _persistSetting(
      () => _settingsManager.setDanmakuFontSizeScale(settings.fontSizeScale),
    );
  }

  void updateSpeed(double value) {
    final settings = state.settings.copyWith(speed: value);
    state = state.copyWith(settings: settings);
    _persistSetting(() => _settingsManager.setDanmakuSpeed(settings.speed));
  }

  void updateSyncPlaybackSpeed(bool value) {
    final settings = state.settings.copyWith(syncPlaybackSpeed: value);
    state = state.copyWith(settings: settings);
    _persistSetting(
      () => _settingsManager.setDanmakuSyncPlaybackSpeed(value),
    );
  }

  void updateDebugEnabled(bool value) {
    final settings = state.settings.copyWith(debugEnabled: value);
    state = state.copyWith(settings: settings);
    _persistSetting(() => _settingsManager.setDanmakuDebugEnabled(value));
  }

  void clear() {
    _requestGeneration++;
    state = state.copyWith(
      danmakuList: const [],
      loadStatus: DanmakuLoadStatus.idle,
      clearErrorMessage: true,
      clearActiveMediaGuid: true,
    );
  }

  List<Danmaku> _selectDanmaku(
    Map<String, List<Danmaku>> danmakuByEpisode,
    int episodeNumber,
  ) {
    return danmakuByEpisode[episodeNumber.toString()] ??
        danmakuByEpisode['default'] ??
        (danmakuByEpisode.values.isNotEmpty
            ? danmakuByEpisode.values.first
            : const <Danmaku>[]);
  }

  List<Danmaku> _normalizeAndSort(List<Danmaku> danmakuList) {
    final indexedDanmaku = <({Danmaku danmaku, int originalIndex})>[];
    for (var index = 0; index < danmakuList.length; index++) {
      final danmaku = danmakuList[index];
      if (danmaku.text.trim().isEmpty ||
          !danmaku.time.isFinite ||
          danmaku.time < 0) {
        continue;
      }
      indexedDanmaku.add((danmaku: danmaku, originalIndex: index));
    }

    indexedDanmaku.sort((left, right) {
      final timeComparison = left.danmaku.time.compareTo(right.danmaku.time);
      if (timeComparison != 0) {
        return timeComparison;
      }
      return left.originalIndex.compareTo(right.originalIndex);
    });
    return List<Danmaku>.unmodifiable(
      indexedDanmaku.map((entry) => entry.danmaku),
    );
  }

  void _persistSetting(Future<void> Function() writeSetting) {
    unawaited(
      writeSetting().catchError((Object error, StackTrace stackTrace) {
        AppTalker.warning('Danmaku', 'Failed to persist setting: $error');
      }),
    );
  }
}
