@Tags(['live'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/data/datasources/remote/fly_narwhal_remote_data_source.dart';

/// Drives the NEW client's FNK2 path against the NEW server (dev build with
/// the authorization system). The code is created via the admin API first.
///
/// Run:
///   flutter test test/integration/fnk2_new_server_live_test.dart \
///     --dart-define=NEW_BASE_URL=http://192.168.31.73:5367 \
///     --dart-define=NEW_AUTH_CODE=FNK2_... \
///     --dart-define=NEW_DEVICE_ID=flutter_live-test
const String _baseUrl = String.fromEnvironment(
  'NEW_BASE_URL',
  defaultValue: 'http://192.168.31.73:5367',
);
const String _authCode = String.fromEnvironment('NEW_AUTH_CODE');
const String _deviceId = String.fromEnvironment(
  'NEW_DEVICE_ID',
  defaultValue: 'flutter_live-test',
);

FlyNarwhalRemoteDataSource _dataSource({
  String? code,
  String? deviceId,
  void Function(int, String)? onAuthCodeRejected,
}) {
  return FlyNarwhalRemoteDataSource(
    getToken: () => '',
    getCookie: () => '',
    getFnBaseUrl: () => _baseUrl,
    getFlyNarwhalBaseUrl: () => _baseUrl,
    getFlyNarwhalServerEnabled: () => true,
    getAuthCode: () => code ?? _authCode,
    getClientVersion: () => '9.9.9',
    getDeviceId: () => deviceId ?? _deviceId,
    onAuthCodeRejected: onAuthCodeRejected,
    dio: Dio(BaseOptions(
      responseType: ResponseType.plain,
      followRedirects: true,
      validateStatus: (status) => true,
    )),
  );
}

void main() {
  test('FNK2 version probe succeeds with v2 response decryption', () async {
    final result = await _dataSource().getVersion();
    expect(result.isSuccess, isTrue,
        reason: 'FNK2 probe failed: ${result.failureOrNull?.message}');
    expect(result.dataOrNull?.data?.trim(), isNotEmpty);
  });

  test('activate binds the device and returns metadata', () async {
    final result = await _dataSource().activateClientCode(
      deviceLabel: 'live-test',
      platform: 'linux',
    );
    expect(result.isSuccess, isTrue,
        reason: 'activate failed: ${result.failureOrNull?.message}');
    final info = result.dataOrNull?.data;
    expect(info, isNotNull);
    expect(info!.name, isNotEmpty);
    expect(info.boundDeviceId, _deviceId);
  });

  test('me reflects the bound device and scope', () async {
    final result = await _dataSource().getClientCodeInfo();
    expect(result.isSuccess, isTrue);
    final info = result.dataOrNull?.data;
    expect(info?.boundDeviceId, _deviceId);
    expect(info?.scope, anyOf('READ_WRITE', 'READ_ONLY'));
  });

  test('a different device is rejected with 4104', () async {
    int? rejectedCode;
    final result = await _dataSource(
      deviceId: 'flutter_other-device',
      onAuthCodeRejected: (code, _) => rejectedCode = code,
    ).getClientCodeInfo();
    expect(result.isSuccess, isFalse);
    expect(result.failureOrNull?.code, 4104);
    expect(rejectedCode, 4104);
  });

  test('an invalid code is rejected with 4101', () async {
    const bogus = 'FNK2_AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8';
    final result = await _dataSource(code: bogus).getVersion();
    expect(result.isSuccess, isFalse);
    expect(result.failureOrNull?.code, 4101);
  });
}
