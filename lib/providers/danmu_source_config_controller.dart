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
    // Keep the values we already have as the loading state's data. A reload runs
    // after every save, and dropping the data here blanks the dialog for the
    // length of the round-trip — the user sees the cards they just toggled
    // replace by a spinner and back, which reads as a flash.
    final previous = state.config.valueOrNull;
    state = state.copyWith(
      config: previous == null
          ? const AsyncLoading<DanmuSourceConfig>()
          : const AsyncLoading<DanmuSourceConfig>()
              .copyWithPrevious(AsyncData(previous)),
      clearLoadError: true,
    );
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


  /// Saves the dandanplay relay (address and enable switch together).
  Future<bool> saveDandanRelay(DanmuDandanConfig dandan) {
    return _mutate(() => _dataSource.saveDandanRelay(dandan: dandan),
        _getL10n().danmuSourceSaveFailed);
  }

  /// Switches the relay on or off, preserving its address and priority.
  Future<bool> setDandanRelayEnabled(bool enabled) {
    final current = _dandan ?? const DanmuDandanConfig();
    return saveDandanRelay(current.copyWith(enabled: enabled));
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

  /// Saves the dandanplay open-network credentials and their enable switch.
  Future<bool> saveDandanAccount(DandanAccount account) {
    return _mutate(() => _dataSource.saveDandanAccount(account: account),
        _getL10n().danmuSourceSaveFailed);
  }

  /// Switches the official channel on or off. Turning it on over incomplete
  /// credentials is allowed — the server stores it as unusable rather than
  /// rejecting the switch, the same way a blank relay address behaves.
  Future<bool> setDandanOfficialEnabled(bool enabled) {
    final current = _dandanAccount ??
        const DandanAccount();
    return saveDandanAccount(current.copyWith(enabled: enabled));
  }

  /// Picks which channel is tried first. The server writes both rows in one
  /// call, so the pair always agrees on an order.
  Future<bool> setPreferredDandanSource({required bool officialPreferred}) {
    return _mutate(
        () => _dataSource.setDandanPreferred(
            officialPreferred: officialPreferred),
        _getL10n().danmuSourceSaveFailed);
  }

  /// Probes the official open API with the given credentials (blank fields fall
  /// back to the stored ones). Returns the failure detail, or null on success.
  Future<String?> testDandanAccount(DandanAccount account) async {
    try {
      final result = await _dataSource.testDandanAccount(account: account);
      return result.when(
        success: (smart) {
          final data = smart.data;
          if (data != null && data['ok'] == true) return null;
          final detail = data?['detail']?.toString();
          return (detail == null || detail.isEmpty)
              ? _getL10n().danmuDandanOfficialTestFailed
              : detail;
        },
        failure: (failure) => failure.displayMessage,
      );
    } catch (_) {
      return _getL10n().danmuDandanOfficialTestFailed;
    }
  }

  /// Current relay row, or null while the config has not loaded.
  DanmuDandanConfig? get _dandan => state.config.valueOrNull?.dandan;

  /// Current official-channel row, or null while the config has not loaded.
  DandanAccount? get _dandanAccount => state.config.valueOrNull?.dandanAccount;

  /// Drops a stale [actionError] without touching anything else.
  ///
  /// [_mutate] only clears the previous error when the *next* mutation starts,
  /// so an error left by a failed save survives closing and reopening the
  /// dialog. Callers clear it on entry so every open starts clean.
  void clearActionError() {
    if (state.actionError == null) return;
    state = state.copyWith(clearActionError: true);
  }

  /// Runs one mutation; on success reloads the config so the UI mirrors the
  /// stored state, on failure records [actionError] and returns false so the
  /// caller can surface it (the dialog shows it as a toast).
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
            error = _localizeServerError(smart.msg);
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

  /// The mutation error to show the user, or null when the last one succeeded.
  String? get actionError => state.actionError;

  /// Maps the server's URL-validation reasons to the user's language.
  ///
  /// The server answers with fixed English constants
  /// (see `DanmuSourceConfigService.normalizeUrl`); showing them raw leaves
  /// English text in a localized dialog. Unknown reasons pass through
  /// untouched so a newly added server-side message is still diagnosable.
  String _localizeServerError(String message) {
    final l10n = _getL10n();
    switch (message.trim()) {
      case 'url is required':
        return l10n.danmuSourceUrlRequired;
      case 'url must start with http:// or https://':
        return l10n.danmuSourceUrlInvalid;
      case 'url is invalid':
        return l10n.danmuSourceUrlMalformed;
      case 'url host is invalid':
        return l10n.danmuSourceUrlMissingHost;
      default:
        return message;
    }
  }
}
