import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_info.dart';
import '../data/storage/preferences_manager.dart';
import '../ui/features/player/models/resolved_skip_segments.dart';

class SkipSwitchesState {
  final String? userGuid;
  final bool isLoading;
  final bool skipIntro;
  final bool skipCredits;
  final bool skipRecap;
  final bool skipPreview;

  const SkipSwitchesState({
    this.userGuid,
    this.isLoading = false,
    this.skipIntro = true,
    this.skipCredits = true,
    this.skipRecap = true,
    this.skipPreview = true,
  });

  bool valueFor(SkipSegmentKind kind) {
    switch (kind) {
      case SkipSegmentKind.intro:
        return skipIntro;
      case SkipSegmentKind.credits:
        return skipCredits;
      case SkipSegmentKind.recap:
        return skipRecap;
      case SkipSegmentKind.preview:
        return skipPreview;
    }
  }

  SkipSwitchesState copyWith({
    String? userGuid,
    bool clearUserGuid = false,
    bool? isLoading,
    bool? skipIntro,
    bool? skipCredits,
    bool? skipRecap,
    bool? skipPreview,
  }) {
    return SkipSwitchesState(
      userGuid: clearUserGuid ? null : userGuid ?? this.userGuid,
      isLoading: isLoading ?? this.isLoading,
      skipIntro: skipIntro ?? this.skipIntro,
      skipCredits: skipCredits ?? this.skipCredits,
      skipRecap: skipRecap ?? this.skipRecap,
      skipPreview: skipPreview ?? this.skipPreview,
    );
  }
}

/// Per-user playback skip switches (intro/credits/recap/preview), persisted
/// in SharedPreferences scoped by user guid like the other user settings.
class SkipSwitchesController extends StateNotifier<SkipSwitchesState> {
  final PreferencesManager _preferencesManager;
  int _loadGeneration = 0;

  SkipSwitchesController(this._preferencesManager)
      : super(const SkipSwitchesState());

  Future<void> updateUserInfo(UserInfo? userInfo) async {
    await updateUserGuid(userInfo?.guid);
  }

  Future<void> updateUserGuid(String? userGuid) async {
    final normalizedUserGuid = userGuid?.trim() ?? '';
    final effectiveUserGuid =
        normalizedUserGuid.isEmpty ? null : normalizedUserGuid;
    final loadGeneration = ++_loadGeneration;
    state = state.copyWith(
      userGuid: effectiveUserGuid,
      clearUserGuid: effectiveUserGuid == null,
      isLoading: true,
    );

    try {
      final skipIntro =
          _preferencesManager.getSkipIntro(userGuid: effectiveUserGuid);
      final skipCredits =
          _preferencesManager.getSkipCredits(userGuid: effectiveUserGuid);
      final skipRecap =
          _preferencesManager.getSkipRecap(userGuid: effectiveUserGuid);
      final skipPreview =
          _preferencesManager.getSkipPreview(userGuid: effectiveUserGuid);
      if (loadGeneration != _loadGeneration) return;
      state = state.copyWith(
        isLoading: false,
        skipIntro: skipIntro,
        skipCredits: skipCredits,
        skipRecap: skipRecap,
        skipPreview: skipPreview,
      );
    } catch (_) {
      if (loadGeneration != _loadGeneration) return;
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> setSwitch(SkipSegmentKind kind, bool value) async {
    final previousValue = state.valueFor(kind);
    final userGuid = state.userGuid;
    state = _withSwitch(kind, value);

    try {
      switch (kind) {
        case SkipSegmentKind.intro:
          await _preferencesManager.saveSkipIntro(value, userGuid: userGuid);
        case SkipSegmentKind.credits:
          await _preferencesManager.saveSkipCredits(value,
              userGuid: userGuid);
        case SkipSegmentKind.recap:
          await _preferencesManager.saveSkipRecap(value, userGuid: userGuid);
        case SkipSegmentKind.preview:
          await _preferencesManager.saveSkipPreview(value,
              userGuid: userGuid);
      }
    } catch (_) {
      state = _withSwitch(kind, previousValue);
      rethrow;
    }
  }

  SkipSwitchesState _withSwitch(SkipSegmentKind kind, bool value) {
    switch (kind) {
      case SkipSegmentKind.intro:
        return state.copyWith(skipIntro: value);
      case SkipSegmentKind.credits:
        return state.copyWith(skipCredits: value);
      case SkipSegmentKind.recap:
        return state.copyWith(skipRecap: value);
      case SkipSegmentKind.preview:
        return state.copyWith(skipPreview: value);
    }
  }
}
