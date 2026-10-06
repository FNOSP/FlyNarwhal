import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/log/app_talker.dart';
import 'fly_narwhal_server_update_notifier.dart';
import 'providers.dart';

/// First server release that carries the whole-work danmaku key (a movie's
/// danmaku comes back under `default` instead of an episode ordinal), the
/// `/api/analysis/smart-skip-config` endpoint and the `/api/danmu/source-config`
/// endpoints. Anything older must be talked to with the pre-2.0.0 contract.
const String minServerVersionForModernContract = '2.0.0';

/// What the connected FlyNarwhal server is known to support.
///
/// An old server and an unreachable one are deliberately indistinguishable from
/// the caller's side: both leave every capability flag false, so the client
/// falls back to the legacy contract instead of assuming a feature exists.
final class FlyNarwhalServerCapabilities {
  const FlyNarwhalServerCapabilities({
    required this.rawVersion,
    required this.versionKnown,
    required this.supportsModernContract,
  });

  /// Unknown — the probe failed, timed out, or the server reported nothing.
  const FlyNarwhalServerCapabilities.unknown()
      : rawVersion = '',
        versionKnown = false,
        supportsModernContract = false;

  /// Version exactly as the server reported it, or `''` when unknown.
  final String rawVersion;

  final bool versionKnown;

  /// Server is 2.0.0 or newer: it keys a whole-work danmaku response by
  /// `default` rather than by an episode ordinal (where a movie lands on `1`),
  /// and exposes `/api/analysis/smart-skip-config` plus the runtime-editable
  /// `/api/danmu/source-config` endpoints.
  final bool supportsModernContract;

  static FlyNarwhalServerCapabilities fromVersion(String version) {
    final trimmed = version.trim();
    if (trimmed.isEmpty || trimmed == '0.0.0') {
      return const FlyNarwhalServerCapabilities.unknown();
    }
    final isModern = FlyNarwhalServerUpdateNotifier.compareVersions(
          trimmed,
          minServerVersionForModernContract,
        ) >=
        0;
    return FlyNarwhalServerCapabilities(
      rawVersion: trimmed,
      versionKnown: true,
      supportsModernContract: isModern,
    );
  }
}

/// Probes the server version on every read — there is no cache, by design.
///
/// The server can be updated (or rolled back) underneath a running client at
/// any time, so a cached answer would silently keep talking the wrong contract
/// until the app restarts. Callers that need a fresh answer refresh this
/// provider before use.
final flyNarwhalServerCapabilitiesProvider =
    FutureProvider<FlyNarwhalServerCapabilities>((ref) async {
  final settings = ref.watch(settingsProvider);
  if (!settings.isFlyNarwhalServerAvailable) {
    return const FlyNarwhalServerCapabilities.unknown();
  }
  try {
    final result =
        await ref.watch(flyNarwhalRemoteDataSourceProvider).getVersion();
    final version = result.dataOrNull?.data?.trim() ?? '';
    if (version.isEmpty) {
      AppTalker.warning('FlyNarwhalCapabilities', '服务端未返回版本号，按旧版处理');
      return const FlyNarwhalServerCapabilities.unknown();
    }
    final capabilities = FlyNarwhalServerCapabilities.fromVersion(version);
    AppTalker.info(
      'FlyNarwhalCapabilities',
      '服务端版本 $version, 新契约=${capabilities.supportsModernContract}',
    );
    return capabilities;
  } catch (error) {
    AppTalker.warning('FlyNarwhalCapabilities', '探测服务端版本失败，按旧版处理: $error');
    return const FlyNarwhalServerCapabilities.unknown();
  }
});

/// Probes the server version now, bypassing any previous result.
///
/// Returns the legacy capabilities when the probe fails, so callers can use the
/// answer directly without a second failure branch.
Future<FlyNarwhalServerCapabilities> probeFlyNarwhalServerCapabilities(
  WidgetRef ref,
) async {
  try {
    return await ref.refresh(flyNarwhalServerCapabilitiesProvider.future);
  } catch (_) {
    return const FlyNarwhalServerCapabilities.unknown();
  }
}
