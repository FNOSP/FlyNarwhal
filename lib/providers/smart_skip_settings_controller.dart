import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_info.dart';
import '../data/storage/preferences_manager.dart';

class SmartSkipSettingsState {
  final String? userGuid;
  final bool enabled;
  final bool isLoading;

  const SmartSkipSettingsState({
    this.userGuid,
    this.enabled = true,
    this.isLoading = false,
  });

  SmartSkipSettingsState copyWith({
    String? userGuid,
    bool clearUserGuid = false,
    bool? enabled,
    bool? isLoading,
  }) {
    return SmartSkipSettingsState(
      userGuid: clearUserGuid ? null : userGuid ?? this.userGuid,
      enabled: enabled ?? this.enabled,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SmartSkipSettingsController
    extends StateNotifier<SmartSkipSettingsState> {
  final PreferencesManager _preferencesManager;
  int _loadGeneration = 0;

  SmartSkipSettingsController(this._preferencesManager)
      : super(const SmartSkipSettingsState());

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
      final enabled =
          await _preferencesManager.loadSmartSkipEnabled(effectiveUserGuid);
      if (loadGeneration != _loadGeneration) return;
      state = state.copyWith(enabled: enabled, isLoading: false);
    } catch (_) {
      if (loadGeneration != _loadGeneration) return;
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final previousEnabled = state.enabled;
    final userGuid = state.userGuid;
    state = state.copyWith(enabled: enabled);

    try {
      if (userGuid == null) {
        await _preferencesManager.saveLegacySmartSkipEnabled(enabled);
      } else {
        await _preferencesManager.saveSmartSkipEnabledForUser(
          userGuid,
          enabled,
        );
      }
    } catch (_) {
      state = state.copyWith(enabled: previousEnabled);
      rethrow;
    }
  }
}
