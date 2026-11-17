import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fly_narwhal/data/storage/fly_narwhal_settings.dart';
import 'package:fly_narwhal/providers/fly_narwhal_client_auth.dart';
import 'package:fly_narwhal/providers/providers.dart';

/// The deprecation warning must fire only for "legacy FN1 code configured
/// against a new-authorization server" — never for unconfigured users, old
/// servers, or FNK2 codes.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer containerWith({
    required bool enabled,
    required String baseUrl,
    required String code,
    required bool newAuthSystem,
  }) {
    final settings = FlyNarwhalSettings(prefs);
    settings.setEnabled(enabled);
    settings.setBaseUrl(baseUrl);
    settings.setAuthCode(code);
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      flyNarwhalSettingsProvider.overrideWithValue(settings),
    ]);
    container.read(flyNarwhalNewAuthSystemProvider.notifier).state =
        newAuthSystem;
    // Force the settings state to reload from the overridden storage.
    container.read(settingsProvider);
    return container;
  }

  test('unconfigured server never warns', () {
    final c = containerWith(
        enabled: false, baseUrl: '', code: '', newAuthSystem: true);
    expect(c.read(legacyAuthDeprecationProvider), isFalse);
  });

  test('enabled but empty url/code never warns', () {
    final c = containerWith(
        enabled: true, baseUrl: '', code: '', newAuthSystem: true);
    expect(c.read(legacyAuthDeprecationProvider), isFalse);
  });

  test('FN1 code on an old server does not warn', () {
    final c = containerWith(
        enabled: true,
        baseUrl: 'http://nas:5367',
        code: 'FN1_abc',
        newAuthSystem: false);
    expect(c.read(legacyAuthDeprecationProvider), isFalse);
  });

  test('FN1 code on a new-authorization server warns', () {
    final c = containerWith(
        enabled: true,
        baseUrl: 'http://nas:5367',
        code: 'FN1_abc',
        newAuthSystem: true);
    expect(c.read(legacyAuthDeprecationProvider), isTrue);
  });

  test('FNK2 code never warns even on a new server', () {
    final c = containerWith(
        enabled: true,
        baseUrl: 'http://nas:5367',
        code: 'FNK2_AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8',
        newAuthSystem: true);
    expect(c.read(legacyAuthDeprecationProvider), isFalse);
  });

  test('legacy FN1 codes keep write access to server config', () {
    final c = containerWith(
        enabled: true,
        baseUrl: 'http://nas:5367',
        code: 'FN1_abc',
        newAuthSystem: true);
    expect(c.read(flyNarwhalCanWriteServerConfigProvider), isTrue);
  });
}
