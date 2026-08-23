import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/storage/update_settings_store.dart';
import 'providers.dart';

/// Supplies an injectable store for reactive update settings tests.
final reactiveUpdateSettingsStoreProvider =
    Provider<UpdateSettingsStore>((ref) {
  final userGuid = ref.watch(currentUserGuidProvider);
  return UpdateSettingsStore(
    ref.watch(sharedPreferencesProvider),
    userGuid: userGuid,
  );
});

/// Publishes update settings only after migration and schema writes complete.
final updateSettingsProvider =
    AsyncNotifierProvider<UpdateSettingsNotifier, UpdateSettings>(
  UpdateSettingsNotifier.new,
);

final class UpdateSettingsNotifier extends AsyncNotifier<UpdateSettings> {
  UpdateSettingsStore get _store =>
      ref.read(reactiveUpdateSettingsStoreProvider);

  @override
  Future<UpdateSettings> build() async {
    await _store.initialize();
    return _store.settings;
  }

  Future<void> setProxyEnabled(bool value) async {
    await _store.setProxyEnabled(value);
    _publishCurrentSettings();
  }

  Future<void> setProxyUrl(String value) async {
    await _store.setProxyUrl(value);
    _publishCurrentSettings();
  }

  Future<void> setIncludePrerelease(bool value) async {
    await _store.setIncludePrerelease(value);
    _publishCurrentSettings();
  }

  Future<void> setAutoDownload(bool value) async {
    await _store.setAutoDownload(value);
    _publishCurrentSettings();
  }

  Future<void> skipVersion(String version) async {
    await _store.skipVersion(version);
    _publishCurrentSettings();
  }

  void _publishCurrentSettings() {
    state = AsyncData<UpdateSettings>(_store.settings);
  }
}
