@Tags(['live'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/data/datasources/remote/fly_narwhal_remote_data_source.dart';
import 'package:fly_narwhal/data/models/fly_narwhal/index.dart';

/// Proves the NEW client's legacy FN1 path against the OLD-contract server
/// (the 2.1.0 dev build installed on the NAS before the authorization system
/// landed). This is the review-window scenario: the client ships first and
/// must keep every feature against a server that has no Fnauth support.
///
/// Run:
///   flutter test test/integration/fn1_old_server_live_test.dart \
///     --dart-define=LEGACY_BASE_URL=http://192.168.31.73:5367 \
///     --dart-define=LEGACY_AUTH_CODE=FN1_...
const String _baseUrl = String.fromEnvironment(
  'LEGACY_BASE_URL',
  defaultValue: 'http://192.168.31.73:5367',
);
const String _authCode = String.fromEnvironment('LEGACY_AUTH_CODE');

FlyNarwhalRemoteDataSource _dataSource({void Function()? onLegacyAuthMode}) {
  return FlyNarwhalRemoteDataSource(
    getToken: () => '',
    getCookie: () => '',
    getFnBaseUrl: () => _baseUrl,
    getFlyNarwhalBaseUrl: () => _baseUrl,
    getFlyNarwhalServerEnabled: () => true,
    getAuthCode: () => _authCode,
    getClientVersion: () => '9.9.9',
    getInstanceId: () => 'flutter_live-test-device',
    onLegacyAuthMode: onLegacyAuthMode,
    dio: Dio(BaseOptions(
      responseType: ResponseType.plain,
      followRedirects: true,
      validateStatus: (status) => true,
    )),
  );
}

void main() {
  test('FN1 version probe succeeds against the old-contract server', () async {
    final result = await _dataSource().getVersion();
    expect(result.isSuccess, isTrue,
        reason: 'version probe failed: ${result.failureOrNull?.message}');
    final version = result.dataOrNull?.data?.trim() ?? '';
    expect(version, isNotEmpty);
  });

  test('old server sends no legacy marker, so no deprecation warning fires',
      () async {
    var legacySeen = false;
    final ds = _dataSource(onLegacyAuthMode: () => legacySeen = true);
    final result = await ds.getVersion();
    expect(result.isSuccess, isTrue);
    expect(legacySeen, isFalse,
        reason: 'the old-contract server must not carry X-Fn-Auth-Mode');
  });

  test('FN1 analysis status query works (capability endpoints stay open)',
      () async {
    final result = await _dataSource()
        .getStatus(type: 'SEASON', guid: 'live-test-nonexistent');
    // A nonexistent guid may answer a business error, but the request itself
    // must authenticate (not 401) — the legacy signature path is intact.
    final failure = result.failureOrNull;
    if (failure != null) {
      expect(failure.code, isNot(401),
          reason: 'legacy auth must not be rejected by the old server');
    }
  });

  test('FNK2 code against the old server fails cleanly (no silent success)',
      () async {
    // A well-formed FNK2 code the old server cannot know: the Fnauth header is
    // ignored by the old interceptor, which then demands Authx and answers 401.
    const fakeFnk2 = 'FNK2_AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8';
    final ds = FlyNarwhalRemoteDataSource(
      getToken: () => '',
      getCookie: () => '',
      getFnBaseUrl: () => _baseUrl,
      getFlyNarwhalBaseUrl: () => _baseUrl,
      getFlyNarwhalServerEnabled: () => true,
      getAuthCode: () => fakeFnk2,
      getClientVersion: () => '9.9.9',
      getInstanceId: () => 'flutter_live-test-device',
      dio: Dio(BaseOptions(
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (status) => true,
      )),
    );
    final result = await ds.getVersion();
    expect(result.isSuccess, isFalse,
        reason: 'an old server must not accept a FNK2-only request');
  });
}
