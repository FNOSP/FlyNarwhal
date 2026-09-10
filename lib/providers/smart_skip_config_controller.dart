import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../data/models/fly_narwhal/index.dart';

class SmartSkipConfigState {
  /// Server-sourced config (defaults when the user has no saved row).
  /// The server is the single source of truth; the client keeps no local copy.
  final AsyncValue<SmartSkipConfig> config;
  final bool isSaving;
  final String? loadError;
  final String? saveError;

  const SmartSkipConfigState({
    this.config = const AsyncData(SmartSkipConfig()),
    this.isSaving = false,
    this.loadError,
    this.saveError,
  });

  SmartSkipConfigState copyWith({
    AsyncValue<SmartSkipConfig>? config,
    bool? isSaving,
    String? loadError,
    bool clearLoadError = false,
    String? saveError,
    bool clearSaveError = false,
  }) {
    return SmartSkipConfigState(
      config: config ?? this.config,
      isSaving: isSaving ?? this.isSaving,
      loadError: clearLoadError ? null : loadError ?? this.loadError,
      saveError: clearSaveError ? null : saveError ?? this.saveError,
    );
  }
}

/// Loads/saves the per-user smart skip config on the fly-narwhal server.
class SmartSkipConfigController extends StateNotifier<SmartSkipConfigState> {
  final FlyNarwhalRemoteDataSource _dataSource;

  SmartSkipConfigController(this._dataSource)
      : super(const SmartSkipConfigState());

  Future<void> load(String userGuid) async {
    state = state.copyWith(config: const AsyncLoading(), clearLoadError: true);
    try {
      final result =
          await _dataSource.getSmartSkipConfig(userGuid: userGuid);
      result.when(
        success: (smart) {
          state = state.copyWith(
            config: AsyncData(smart.data ?? const SmartSkipConfig()),
            clearLoadError: true,
          );
        },
        failure: (failure) {
          // Degrade to defaults so the screen stays usable offline; saving
          // stays disabled while the server is unreachable.
          state = state.copyWith(
            config: const AsyncData(SmartSkipConfig()),
            loadError: failure.displayMessage,
          );
        },
      );
    } catch (_) {
      state = state.copyWith(
        config: const AsyncData(SmartSkipConfig()),
        loadError: '加载智能跳过配置失败',
      );
    }
  }

  /// Apply an edit to the local draft; nothing hits the server until [save].
  void update(SmartSkipConfig config) {
    state = state.copyWith(config: AsyncData(config), clearSaveError: true);
  }

  Future<bool> save(String userGuid) async {
    final current = state.config.valueOrNull;
    if (current == null) return false;
    state = state.copyWith(isSaving: true, clearSaveError: true);
    try {
      final result = await _dataSource.saveSmartSkipConfig(
        request: SaveSmartSkipConfigRequest(userGuid: userGuid, config: current),
      );
      return result.when(
        success: (smart) {
          if (smart.isSuccess()) {
            state = state.copyWith(isSaving: false, clearSaveError: true);
            return true;
          }
          state = state.copyWith(isSaving: false, saveError: smart.msg);
          return false;
        },
        failure: (failure) {
          state = state.copyWith(
            isSaving: false,
            saveError: failure.displayMessage,
          );
          return false;
        },
      );
    } catch (_) {
      state = state.copyWith(isSaving: false, saveError: '保存智能跳过配置失败');
      return false;
    }
  }
}
