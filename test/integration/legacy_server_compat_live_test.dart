@Tags(['live'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/data/datasources/remote/fly_narwhal_remote_data_source.dart';
import 'package:fly_narwhal/data/models/fly_narwhal/danmaku.dart';
import 'package:fly_narwhal/providers/danmaku_controller.dart';
import 'package:fly_narwhal/providers/fly_narwhal_server_capabilities.dart';

/// Drives the real client HTTP + signing stack against a live server.
///
/// Run against a v0.6.4 instance to prove the legacy contract is detected and
/// that a movie's danmaku still resolves:
///   flutter test test/integration/legacy_server_compat_live_test.dart \
///     --dart-define=LEGACY_BASE_URL=http://localhost:5366 \
///     --dart-define=LEGACY_AUTH_CODE=FN1_...
const String _baseUrl = String.fromEnvironment(
  'LEGACY_BASE_URL',
  defaultValue: 'http://localhost:5366',
);
const String _authCode = String.fromEnvironment('LEGACY_AUTH_CODE');

/// A movie whose danmaku the legacy server can serve without any of the user's
/// own media (the danmaku source is keyed off the douban id alone).
const String _movieDoubanId = '1292052';

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

void main() {
  test('the live legacy server reports a pre-modern version', () async {
    final result = await _dataSource().getVersion();
    expect(result.isSuccess, isTrue, reason: 'version probe failed');
    final version = result.dataOrNull?.data?.trim() ?? '';
    expect(version, isNotEmpty);

    final capabilities = FlyNarwhalServerCapabilities.fromVersion(version);
    expect(capabilities.versionKnown, isTrue);
    expect(
      capabilities.supportsWholeWorkDanmakuKey,
      isFalse,
      reason: 'a pre-0.7.0 server keys a movie by the ordinal it was sent, '
          'so the whole-work key must stay off (version=$version)',
    );
    expect(capabilities.supportsSmartSkipConfig, isFalse);
  });

  test('a movie request against the legacy server is keyed by its ordinal',
      () async {
    final result = await _dataSource().getDanmaku(DanmakuRequest(
      doubanId: _movieDoubanId,
      episodeNumber: 0,
      episodeTitle: '',
      title: '肖申克的救赎',
      seasonNumber: 1,
      season: false,
      guid: '',
      parentGuid: '',
    ));
    expect(result.isSuccess, isTrue, reason: 'danmaku request failed');
    final byKey = result.dataOrNull!;
    expect(byKey, isNotEmpty, reason: 'the legacy server returned no danmaku');

    expect(
      byKey.containsKey(danmakuWholeWorkKey),
      isFalse,
      reason: 'the whole-work key is a 0.7.0+ concept',
    );
    expect(
      byKey.keys,
      contains('0'),
      reason: 'the legacy server echoes the ordinal the request carried, so the '
          'movie lands under "0" — the key the client fallback must accept',
    );
    expect(byKey['0'], isNotEmpty);
  });
}
