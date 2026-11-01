import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/log/app_talker.dart';
import 'fly_narwhal_server_update_notifier.dart';
import 'providers.dart';
import 'update_providers.dart' show flyNarwhalServerUpdateAvailableProvider;

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
///
/// The provider keeps the failure to itself: a probe that runs on its own
/// (reading the version-gated cards) must not interrupt the user. Callers that
/// need the failure refresh [serverVersionProbeProvider] instead.
final flyNarwhalServerCapabilitiesProvider =
    FutureProvider<FlyNarwhalServerCapabilities>((ref) async {
  return (await ref.watch(serverVersionProbeProvider.future)).capabilities;
});

/// Probes the server version now, bypassing any previous result.
///
/// Returns the legacy capabilities when the probe fails, so callers can use the
/// answer directly without a second failure branch.
Future<FlyNarwhalServerCapabilities> probeFlyNarwhalServerCapabilities(
  WidgetRef ref,
) async {
  return (await ref.refresh(serverVersionProbeProvider.future)).capabilities;
}

/// One probe's outcome: the capabilities to apply, plus why the version could
/// not be read, if it could not.
final class FlyNarwhalServerProbeResult {
  const FlyNarwhalServerProbeResult({
    required this.capabilities,
    this.failure,
  });

  final FlyNarwhalServerCapabilities capabilities;

  /// Why no version came back; null on success. A server that answers without
  /// a version counts too — the caller asked for a version and did not get one.
  final String? failure;

  FlyNarwhalServerProbeResult toResult() {
    if (failure != null || capabilities.versionKnown) return this;
    return FlyNarwhalServerProbeResult(
      capabilities: capabilities,
      failure: serverReturnedNoVersion,
    );
  }
}

/// [FlyNarwhalServerProbeResult.failure] marker: the server answered but
/// reported no version, as opposed to not answering at all. Callers map it to
/// their own localized text.
const String serverReturnedNoVersion = '\u0000no-version';

/// The single place the server version is read from.
///
/// [flyNarwhalServerCapabilitiesProvider] watches this, so the version-gated
/// widgets redraw from whichever probe produced the latest answer.
final serverVersionProbeProvider =
    FutureProvider<FlyNarwhalServerProbeResult>((ref) async {
  return (await _probeServerVersion(ref.container)).toResult();
});

/// Re-probes the server now and reports a failure the user should be told
/// about.
///
/// Probes directly rather than refreshing [serverVersionProbeProvider]: that
/// provider remembers the settings it first read, and a probe that ran before
/// the settings loaded would keep answering "server not configured" forever.
Future<FlyNarwhalServerProbeResult> probeFlyNarwhalServer(WidgetRef ref) async {
  final container = ProviderScope.containerOf(ref.context);
  final result = await _probeServerVersion(container);
  if (result.capabilities.versionKnown) {
    await ref
        .read(flyNarwhalServerUpdateAvailableProvider.notifier)
        .check(result.capabilities.rawVersion);
  }
  return result.toResult();
}

Future<FlyNarwhalServerProbeResult> _probeServerVersion(
  ProviderContainer container,
) async {
  final settings = container.read(settingsProvider);
  if (!settings.isFlyNarwhalServerAvailable) {
    return const FlyNarwhalServerProbeResult(
      capabilities: FlyNarwhalServerCapabilities.unknown(),
    );
  }
  final result =
      await container.read(flyNarwhalRemoteDataSourceProvider).getVersion();
  final failure = result.failureOrNull;
  if (failure != null) {
    final message = failure.displayMessage.isNotEmpty
        ? failure.displayMessage
        : failure.message;
    AppTalker.warning('FlyNarwhalCapabilities', '探测服务端版本失败，按旧版处理: $message');
    return FlyNarwhalServerProbeResult(
      capabilities: const FlyNarwhalServerCapabilities.unknown(),
      failure: message,
    );
  }
  final version = result.dataOrNull?.data?.trim() ?? '';
  if (version.isEmpty) {
    AppTalker.warning('FlyNarwhalCapabilities', '服务端未返回版本号，按旧版处理');
    return const FlyNarwhalServerProbeResult(
      capabilities: FlyNarwhalServerCapabilities.unknown(),
    );
  }
  final capabilities = FlyNarwhalServerCapabilities.fromVersion(version);
  AppTalker.info(
    'FlyNarwhalCapabilities',
    '服务端版本 $version, 新契约=${capabilities.supportsModernContract}',
  );
  return FlyNarwhalServerProbeResult(capabilities: capabilities);
}
