import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/interceptors/logging_interceptor.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/dio_logs.dart';

/// The signature-bearing headers must never reach the log in plaintext:
/// Fnauth/Fnwb join the pre-existing Authx/Signx/Keyx scrub list.
void main() {
  test('request logging masks all credential and signature headers', () {
    final interceptor = LoggingInterceptor(talker: Talker());
    final options = RequestOptions(
      path: 'http://127.0.0.1:9/api/config/version',
      headers: <String, dynamic>{
        'Authorization': 'secret-token',
        'Cookie': 'secret-cookie',
        'Authx': 'nonce=1&timestamp=2&sign=secret-authx',
        'Signx': 'secret-signx',
        'Fnauth': 'keyid=k&ts=1&nonce=n&sig=secret-fnauth',
        'Fnwb': 'v=2&sig=secret-fnwb',
        'Keyx': 'secret-keyx',
        'Accept': 'application/json',
      },
    );

    final log = DioRequestLog(
      'request',
      requestOptions: options,
      settings: interceptor.settings,
    );
    final text = log.generateTextMessage();

    expect(text, isNot(contains('secret-token')));
    expect(text, isNot(contains('secret-cookie')));
    expect(text, isNot(contains('secret-authx')));
    expect(text, isNot(contains('secret-signx')));
    expect(text, isNot(contains('secret-fnauth')));
    expect(text, isNot(contains('secret-fnwb')));
    expect(text, isNot(contains('secret-keyx')));
    // Non-secret headers stay visible for debugging.
    expect(text, contains('application/json'));
  });
}