import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/network/fly_narwhal_client_code.dart';
import '../data/models/fly_narwhal/index.dart';
import '../l10n/generated/app_localizations.dart';
import '../ui/settings/app_language.dart';
import 'providers.dart';

/// Whether the connected server runs the new per-client authorization system.
///
/// Old and new servers can share the same version number (2.1.0), so the
/// version string alone cannot decide this: the signal is the passive
/// `X-Fn-Auth-Mode: legacy` response header (seen on any legacy-path request)
/// or a successful `/api/client/me` probe. Starts false and flips true once
/// observed; a server downgrade mid-session is picked up on the next probe.
final flyNarwhalNewAuthSystemProvider = StateProvider<bool>((ref) => false);

/// Process-lifetime flag: the once-per-launch deprecation dialog was shown.
final legacyAuthPromptShownProvider = StateProvider<bool>((ref) => false);

/// True when the user configured the FlyNarwhal server with a legacy FN1 code
/// AND the server runs the new authorization system. This is the only
/// combination that shows the "regenerate your authorization code" warning;
/// unconfigured users and old servers never see it.
final legacyAuthDeprecationProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.flyNarwhalServerEnabled ||
      settings.flyNarwhalServerBaseUrl.isEmpty ||
      !settings.hasFlyNarwhalAuthCode) {
    return false;
  }
  final code = ref.read(settingsProvider.notifier).getFlyNarwhalAuthCode();
  if (!FlyNarwhalClientCode.isLegacyFn1(code)) {
    return false;
  }
  return ref.watch(flyNarwhalNewAuthSystemProvider);
});

/// Whether the configured code may edit server-side configuration. Legacy FN1
/// codes are always read/write (released-client compatibility); FNK2 codes
/// follow their activated scope, refreshed from /me.
final flyNarwhalCanWriteServerConfigProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.hasFlyNarwhalAuthCode) {
    return true;
  }
  final code = ref.read(settingsProvider.notifier).getFlyNarwhalAuthCode();
  if (!FlyNarwhalClientCode.isFnk2(code)) {
    return true;
  }
  final meta = ref.watch(flyNarwhalClientCodeMetaProvider);
  return meta?.isReadOnly != true;
});

/// Persisted metadata snapshot of the activated FNK2 code (name/expiry/scope).
final flyNarwhalClientCodeMetaProvider =
    StateProvider<ClientCodeInfo?>((ref) {
  final settings = ref.watch(flyNarwhalSettingsProvider);
  final raw = settings.authCodeMeta;
  if (raw == null || raw.isEmpty) return null;
  try {
    return ClientCodeInfo.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  } catch (_) {
    return null;
  }
});

/// Activates a FNK2 code against the configured server. Returns null on
/// success (metadata persisted), or a localized error message on failure.
/// The caller saves the code itself only after this returns null.
Future<String?> activateFlyNarwhalClientCode(
  WidgetRef ref, {
  required String code,
  required String deviceLabel,
}) async {
  final l10n = lookupAppLocalizations(
    AppLanguage.localeFromValue(ref.read(settingsProvider).language),
  );
  final parsed = FlyNarwhalClientCode.tryParse(code);
  if (parsed == null) {
    return l10n.authCodeInvalid;
  }
  final notifier = ref.read(settingsProvider.notifier);
  final previousCode = notifier.getFlyNarwhalAuthCode();
  // Temporarily install the new code so the datasource signs with it.
  await notifier.setFlyNarwhalAuthCode(code);
  final datasource = ref.read(flyNarwhalRemoteDataSourceProvider);
  final result = await datasource.activateClientCode(
    deviceLabel: deviceLabel,
    platform: _platformName(),
  );
  final failure = result.failureOrNull;
  if (failure != null) {
    await notifier.setFlyNarwhalAuthCode(previousCode);
    return _localizedAuthError(l10n, failure.code) ?? failure.displayMessage;
  }
  final info = result.dataOrNull?.data;
  if (info == null) {
    await notifier.setFlyNarwhalAuthCode(previousCode);
    return l10n.authCodeActivateFailed;
  }
  await ref.read(flyNarwhalSettingsProvider).setAuthCodeMeta(
        jsonEncode(info.toJson()),
      );
  ref.read(flyNarwhalClientCodeMetaProvider.notifier).state = info;
  ref.read(flyNarwhalNewAuthSystemProvider.notifier).state = true;
  return null;
}

/// Refreshes the configured FNK2 code's metadata from /me; returns a localized
/// error message on failure, null on success.
Future<String?> refreshFlyNarwhalClientCodeInfo(WidgetRef ref) async {
  final l10n = lookupAppLocalizations(
    AppLanguage.localeFromValue(ref.read(settingsProvider).language),
  );
  final datasource = ref.read(flyNarwhalRemoteDataSourceProvider);
  final result = await datasource.getClientCodeInfo();
  final failure = result.failureOrNull;
  if (failure != null) {
    return _localizedAuthError(l10n, failure.code) ?? failure.displayMessage;
  }
  final info = result.dataOrNull?.data;
  if (info == null) {
    return l10n.authCodeActivateFailed;
  }
  await ref.read(flyNarwhalSettingsProvider).setAuthCodeMeta(
        jsonEncode(info.toJson()),
      );
  ref.read(flyNarwhalClientCodeMetaProvider.notifier).state = info;
  ref.read(flyNarwhalNewAuthSystemProvider.notifier).state = true;
  return null;
}

String? _localizedAuthError(AppLocalizations l10n, int? code) {
  return switch (code) {
    ResponseCodes.authCodeInvalid => l10n.authCodeInvalid,
    ResponseCodes.authCodeExpired => l10n.authCodeExpired,
    ResponseCodes.authCodeDisabled => l10n.authCodeDisabled,
    ResponseCodes.authCodeDeviceMismatch => l10n.authCodeDeviceMismatch,
    ResponseCodes.authCodeRateLimited => l10n.authCodeRateLimited,
    ResponseCodes.authCodeReplayed => l10n.authCodeReplayed,
    ResponseCodes.authCodeReadOnly => l10n.authCodeReadOnly,
    _ => null,
  };
}

String _platformName() {
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isLinux) return 'Linux';
  return Platform.operatingSystem;
}