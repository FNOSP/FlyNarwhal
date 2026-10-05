import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/log/app_talker.dart';
import 'fly_narwhal_server_update_notifier.dart';
import 'providers.dart';

/// First server release that carries both the whole-work danmaku key (a movie's
/// danmaku comes back under `default` instead of an episode ordinal) and the
/// `/api/analysis/smart-skip-config` endpoint. Anything older must be talked to
/// with the pre-0.7.0 contract.
const String minServerVersionForModernContract = '0.7.0';

/// The `/api/danmu/source-config` endpoints landed after 0.7.0 (in 0.11.0);
/// versions up to 0.10.0 were never publicly released, so the gate is a strict
/// "newer than 0.7.0" comparison.
const String minServerVersionForDanmuSourceConfig = '0.7.0';

/// What the connected FlyNarwhal server is known to support.
///
/// An old server and an unreachable one are deliberately indistinguishable from
/// the caller's side: both leave every capability flag false, so the client
/// falls back to the legacy contract instead of assuming a feature exists.
final class FlyNarwhalServerCapabilities {
  const FlyNarwhalServerCapabilities({
    required this.rawVersion,
    required this.versionKnown,
    required this.supportsWholeWorkDanmakuKey,
    required this.supportsSmartSkipConfig,
    required this.supportsDanmuSourceConfig,
  });

  /// Unknown — the probe failed, timed out, or the server reported nothing.
  const FlyNarwhalServerCapabilities.unknown()
      : rawVersion = '',
        versionKnown = false,
        supportsWholeWorkDanmakuKey = false,
        supportsSmartSkipConfig = false,
        supportsDanmuSourceConfig = false;

  /// Version exactly as the server reported it, or `''` when unknown.
  final String rawVersion;

  final bool versionKnown;

  /// Server keys a whole-work danmaku response by `default` rather than by an
  /// episode ordinal (where a movie lands on `1`).
  final bool supportsWholeWorkDanmakuKey;

  /// Server exposes `/api/analysis/smart-skip-config`.
  final bool supportsSmartSkipConfig;

  /// Server exposes the runtime-editable `/api/danmu/source-config` endpoints
  /// (dandanplay relay + third-party fallback servers).
  final bool supportsDanmuSourceConfig;

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
    final hasDanmuSourceConfig = FlyNarwhalServerUpdateNotifier.compareVersions(
          trimmed,
          minServerVersionForDanmuSourceConfig,
        ) >
        0;
    return FlyNarwhalServerCapabilities(
      rawVersion: trimmed,
      versionKnown: true,
      supportsWholeWorkDanmakuKey: isModern,
      supportsSmartSkipConfig: isModern,
      supportsDanmuSourceConfig: hasDanmuSourceConfig,
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
      '服务端版本 $version, 新契约=${capabilities.supportsSmartSkipConfig}',
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
