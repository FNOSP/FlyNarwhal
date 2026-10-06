@Tags(['live'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/data/datasources/remote/fly_narwhal_remote_data_source.dart';
import 'package:fly_narwhal/data/models/fly_narwhal/index.dart';
import 'package:fly_narwhal/providers/fly_narwhal_server_capabilities.dart';

/// Drives the real client HTTP + signing stack against a live >0.7.0 server's
/// danmu source config CRUD:
///   flutter test test/integration/danmu_source_config_live_test.dart \
///     --dart-define=LIVE_BASE_URL=http://localhost:5365 \
///     --dart-define=LIVE_AUTH_CODE=FN1_...
const String _baseUrl = String.fromEnvironment(
  'LIVE_BASE_URL',
  defaultValue: 'http://localhost:5365',
);
const String _authCode = String.fromEnvironment('LIVE_AUTH_CODE');

FlyNarwhalRemoteDataSource _dataSource() {
  return FlyNarwhalRemoteDataSource(
    getToken: () => '',
    getCookie: () => '',
    getFnBaseUrl: () => _baseUrl,
    getFlyNarwhalBaseUrl: () => _baseUrl,
    getFlyNarwhalServerEnabled: () => true,
    getAuthCode: () => _authCode,
    getClientVersion: () => '9.9.9',
    dio: Dio(BaseOptions(
      responseType: ResponseType.plain,
      followRedirects: true,
      validateStatus: (status) => true,
    )),
  );
}

Future<DanmuSourceConfig> _configOrFail(FlyNarwhalRemoteDataSource ds) async {
  final result = await ds.getDanmuSourceConfig();
  expect(result.isSuccess, isTrue, reason: 'GET source-config failed');
  final config = result.dataOrNull?.data;
  expect(config, isNotNull);
  return config!;
}

void main() {
  test('the live server exposes the danmu source config API', () async {
    final ds = _dataSource();
    final versionResult = await ds.getVersion();
    expect(versionResult.isSuccess, isTrue, reason: 'version probe failed');
    final version = versionResult.dataOrNull?.data?.trim() ?? '';
    final capabilities = FlyNarwhalServerCapabilities.fromVersion(version);
    expect(
      capabilities.supportsModernContract,
      isTrue,
      reason: 'this live test needs a server 2.0.0 or newer (got $version)',
    );

    final config = await _configOrFail(ds);
    final originalRelay = config.dandan;

    // 1) Dandan relay upsert: trailing slash must come back trimmed.
    var save = await ds.saveDandanRelay(
      dandan: const DanmuDandanConfig(
        url: 'https://relay-test.example/ddp/v1/',
        enabled: true,
      ),
    );
    expect(save.isSuccess && save.dataOrNull!.isSuccess(), isTrue);
    var cfg = await _configOrFail(ds);
    expect(cfg.dandan.url, 'https://relay-test.example/ddp/v1');
    expect(cfg.dandan.enabled, isTrue);

    // 2) Switching the relay off keeps its address — the switch, not an empty
    //    field, is what disables a source now.
    save = await ds.saveDandanRelay(
      dandan: cfg.dandan.copyWith(enabled: false),
    );
    expect(save.isSuccess && save.dataOrNull!.isSuccess(), isTrue);
    cfg = await _configOrFail(ds);
    expect(cfg.dandan.enabled, isFalse);
    expect(cfg.dandan.url, 'https://relay-test.example/ddp/v1',
        reason: 'disabling must not wipe the stored address');

    // 3) Restore the original relay state.
    save = await ds.saveDandanRelay(dandan: originalRelay.copyWith(enabled: true));
    expect(save.isSuccess && save.dataOrNull!.isSuccess(), isTrue);
    cfg = await _configOrFail(ds);
    expect(cfg.dandan.url, originalRelay.url);
    expect(cfg.dandan.enabled, isTrue);

    // 4) Preferred switch is mutual: setting one clears the other.
    save = await ds.setDandanPreferred(officialPreferred: true);
    expect(save.isSuccess && save.dataOrNull!.isSuccess(), isTrue);
    cfg = await _configOrFail(ds);
    expect(cfg.dandanAccount.priority, 0);
    expect(cfg.dandan.priority, 1);

    save = await ds.setDandanPreferred(officialPreferred: false);
    expect(save.isSuccess && save.dataOrNull!.isSuccess(), isTrue);
    cfg = await _configOrFail(ds);
    expect(cfg.dandan.priority, 0);
    expect(cfg.dandanAccount.priority, 1);

    // Restore the original preference so the live server is left as found.
    final restorePreferred = originalRelay.priority != 1;
    save = await ds.setDandanPreferred(officialPreferred: restorePreferred);
    expect(save.isSuccess && save.dataOrNull!.isSuccess(), isTrue);

    // 5) Fallback server lifecycle: add → toggle off → rename → delete.
    cfg = await _configOrFail(ds);
    final before = cfg.fallbackServers.length;
    save = await ds.saveFallbackServer(
      server: const DanmuFallbackServer(
        name: 'live-test',
        url: 'https://fallback-a.example/',
      ),
    );
    expect(save.isSuccess && save.dataOrNull!.isSuccess(), isTrue);
    cfg = await _configOrFail(ds);
    expect(cfg.fallbackServers.length, before + 1);
    final added = cfg.fallbackServers.firstWhere(
      (s) => s.url == 'https://fallback-a.example',
      orElse: () => throw StateError('added server missing; trim failed?'),
    );
    final id = added.id;
    expect(id, isNotNull);
    expect(added.enabled, isTrue);

    save = await ds.saveFallbackServer(
      server: added.copyWith(enabled: false),
    );
    expect(save.isSuccess && save.dataOrNull!.isSuccess(), isTrue);
    cfg = await _configOrFail(ds);
    expect(
      cfg.fallbackServers.firstWhere((s) => s.id == id).enabled,
      isFalse,
      reason: 'toggle off did not stick',
    );

    save = await ds.saveFallbackServer(
      server: added.copyWith(name: 'live-test-renamed', enabled: true),
    );
    expect(save.isSuccess && save.dataOrNull!.isSuccess(), isTrue);
    cfg = await _configOrFail(ds);
    final renamed = cfg.fallbackServers.firstWhere((s) => s.id == id);
    expect(renamed.name, 'live-test-renamed');
    expect(renamed.enabled, isTrue);

    final del = await ds.deleteFallbackServer(id!);
    expect(del.isSuccess && del.dataOrNull!.isSuccess(), isTrue);
    cfg = await _configOrFail(ds);
    expect(cfg.fallbackServers.any((s) => s.id == id), isFalse);
    expect(cfg.fallbackServers.length, before);
  });

  test('an invalid relay URL is rejected with a validation message', () async {
    final ds = _dataSource();
    final save = await ds.saveDandanRelay(
      dandan: const DanmuDandanConfig(url: 'ftp://relay.example', enabled: true),
    );
    // Transport succeeds; the business result must carry the failure.
    final smart = save.dataOrNull;
    if (save.isSuccess && smart != null) {
      expect(smart.isSuccess(), isFalse);
      expect(smart.msg, contains('http'));
    } else {
      expect(save.isSuccess, isFalse);
    }
  });
}
