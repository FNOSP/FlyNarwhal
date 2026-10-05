import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_result.dart';
import '../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../data/models/fly_narwhal/index.dart';
import '../l10n/generated/app_localizations.dart';

class DanmuSourceConfigState {
  /// Server-sourced config. The server is the single source of truth; the
  /// client keeps no local copy.
  final AsyncValue<DanmuSourceConfig> config;
  final bool isSaving;
  final String? loadError;
  final String? actionError;

  const DanmuSourceConfigState({
    this.config = const AsyncData(DanmuSourceConfig()),
    this.isSaving = false,
    this.loadError,
    this.actionError,
  });

  DanmuSourceConfigState copyWith({
    AsyncValue<DanmuSourceConfig>? config,
    bool? isSaving,
    String? loadError,
    bool clearLoadError = false,
    String? actionError,
    bool clearActionError = false,
  }) {
    return DanmuSourceConfigState(
      config: config ?? this.config,
      isSaving: isSaving ?? this.isSaving,
      loadError: clearLoadError ? null : loadError ?? this.loadError,
      actionError: clearActionError ? null : actionError ?? this.actionError,
    );
  }
}

/// Loads and mutates the runtime danmu source config (dandanplay relay +
/// third-party fallback servers) on the fly-narwhal server. Every mutation
/// reloads the config afterwards so the UI always mirrors stored state.
class DanmuSourceConfigController
    extends StateNotifier<DanmuSourceConfigState> {
  final FlyNarwhalRemoteDataSource _dataSource;
  final AppLocalizations Function() _getL10n;

  DanmuSourceConfigController(this._dataSource,
      {required AppLocalizations Function() getL10n})
      : _getL10n = getL10n,
        super(const DanmuSourceConfigState());

  Future<void> load() async {
    state = state.copyWith(config: const AsyncLoading(), clearLoadError: true);
    try {
      final result = await _dataSource.getDanmuSourceConfig();
      result.when(
        success: (smart) {
          state = state.copyWith(
            config: AsyncData(smart.data ?? const DanmuSourceConfig()),
            clearLoadError: true,
          );
        },
        failure: (failure) {
          state = state.copyWith(
            config: const AsyncData(DanmuSourceConfig()),
            loadError: failure.displayMessage,
          );
        },
      );
    } catch (_) {
      state = state.copyWith(
        config: const AsyncData(DanmuSourceConfig()),
        loadError: _getL10n().danmuSourceLoadFailed,
      );
    }
  }

  /// Saves the dandanplay relay URL; an empty string disables the source.
  Future<bool> saveDandanRelay(String url) {
    return _mutate(() => _dataSource.saveDandanRelay(url: url.trim()),
        _getL10n().danmuSourceSaveFailed);
  }

  /// Inserts (no id) or updates one fallback server, toggle included.
  Future<bool> saveFallbackServer(DanmuFallbackServer server) {
    return _mutate(() => _dataSource.saveFallbackServer(server: server),
        _getL10n().danmuSourceSaveFailed);
  }

  Future<bool> toggleFallbackServer(
      DanmuFallbackServer server, bool enabled) {
    return saveFallbackServer(server.copyWith(enabled: enabled));
  }

  Future<bool> deleteFallbackServer(int id) {
    return _mutate(() => _dataSource.deleteFallbackServer(id),
        _getL10n().danmuSourceDeleteFailed);
  }

  /// Saves the dandanplay open-network credentials; both blank removes the
  /// stored account (official channel off).
  Future<bool> saveDandanAccount(DandanAccount account) {
    return _mutate(() => _dataSource.saveDandanAccount(account: account),
        _getL10n().danmuSourceSaveFailed);
  }

  /// Runs one mutation; on success reloads the config so the UI mirrors the
  /// stored state, on failure records [actionError] for inline display.
  Future<bool> _mutate(
    Future<ApiResult<SmartAnalysisResult<String>>> Function() request,
    String fallbackError,
  ) async {
    state = state.copyWith(isSaving: true, clearActionError: true);
    var ok = false;
    String? error;
    try {
      final result = await request();
      result.when(
        success: (smart) {
          if (smart.isSuccess()) {
            ok = true;
          } else {
            error = smart.msg;
          }
        },
        failure: (failure) {
          error = failure.displayMessage;
        },
      );
    } catch (_) {
      error = fallbackError;
    }
    if (ok) {
      await load();
      state = state.copyWith(isSaving: false, clearActionError: true);
      return true;
    }
    state = state.copyWith(isSaving: false, actionError: error ?? fallbackError);
    return false;
  }
}
