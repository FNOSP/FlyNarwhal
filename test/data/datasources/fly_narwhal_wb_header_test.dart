import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/config/wb_signer_bridge_ffi.dart';
import 'package:fly_narwhal/core/config/wb_signer_selector.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/core/network/fly_narwhal_auth_helper.dart';
import 'package:fly_narwhal/core/network/fly_narwhal_client_code.dart';
import 'package:fly_narwhal/core/network/fly_narwhal_wb_helper.dart';
import 'package:fly_narwhal/data/datasources/remote/fly_narwhal_remote_data_source.dart';

/// Exercises the Fnwb build-proof header through the real _buildHeaders path
/// with an injected fake signer; no native library is needed.
void main() {
  final secret = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final code = 'FNK2_${base64Url.encode(secret).replaceAll('=', '')}';
  const fakeSig = '0123456789abcdef0123456789abcdef';
  const instanceId = 'macos-arm64-FN-0123456789abcdef';

  group('Fnwb header on FNK2 requests', () {
    late _RecordingInterceptor recorder;
    late FlyNarwhalRemoteDataSource dataSource;
    late _FakeWbSigner signer;

    setUp(() {
      recorder = _RecordingInterceptor();
      signer = _FakeWbSigner(fakeSig);
      final dio = Dio(BaseOptions(responseType: ResponseType.plain))
        ..interceptors.add(recorder);
      dataSource = FlyNarwhalRemoteDataSource(
        getToken: () => '',
        getCookie: () => '',
        getFnBaseUrl: () => '',
        getFlyNarwhalBaseUrl: () => 'http://127.0.0.1:9',
        getAuthCode: () => code,
        getInstanceId: () => instanceId,
        dio: dio,
        wbSigner: signer,
      );
    });

    test('GET carries Fnwb bound to the exact Fnauth signature', () async {
      final result = await dataSource.getVersion();
      expect(result, isA<Success<dynamic>>());
      expect(recorder.requests, hasLength(1));
      final headers = recorder.requests.single.headers;
      expect(headers['Fnwb'], 'v=2&sig=$fakeSig');

      final fnauth = headers['Fnauth']! as String;
      final parts = FlyNarwhalWbHelper.parseFnauth(fnauth);
      final expectedMessage = FlyNarwhalWbHelper.buildFnwbMessage(
        method: 'GET',
        url: '/api/config/version',
        ts: parts['ts']!,
        nonce: parts['nonce']!,
        dataJsonMd5: FlyNarwhalAuthHelper.buildDataJsonMd5(),
        instanceId: instanceId,
        fnauthSig: parts['sig']!,
      );
      expect(signer.messages, <String>[expectedMessage]);

      // The Fnauth HMAC itself must stay valid and unchanged by the addition.
      final parsed = FlyNarwhalClientCode.tryParse(code)!;
      final signKey = await (await parsed.deriveSignKey()).extractBytes();
      final fnk2Message = [
        'FNK2',
        'GET',
        '/api/config/version',
        parts['ts'],
        parts['nonce'],
        FlyNarwhalAuthHelper.buildDataJsonMd5(),
        instanceId,
      ].join('_');
      expect(
        parts['sig'],
        crypto.Hmac(crypto.sha256, signKey)
            .convert(utf8.encode(fnk2Message))
            .toString(),
      );
    });

    test('POST signs the uppercased method and the body md5', () async {
      final result = await dataSource.activateClientCode(
        deviceLabel: 'test-pc',
        platform: 'macos',
      );
      expect(result, isA<Success<dynamic>>());
      final headers = recorder.requests.single.headers;
      expect(headers['Fnwb'], 'v=2&sig=$fakeSig');

      final parts =
          FlyNarwhalWbHelper.parseFnauth(headers['Fnauth']! as String);
      final body = recorder.requests.single.data as Map<String, dynamic>;
      final expectedMessage = FlyNarwhalWbHelper.buildFnwbMessage(
        method: 'POST',
        url: '/api/client/activate',
        ts: parts['ts']!,
        nonce: parts['nonce']!,
        dataJsonMd5: FlyNarwhalAuthHelper.buildDataJsonMd5(data: body),
        instanceId: instanceId,
        fnauthSig: parts['sig']!,
      );
      expect(signer.messages, <String>[expectedMessage]);
      expect(expectedMessage, startsWith('FNWB2_POST_'));
    });

    test('legacy FN1 requests never carry Fnwb and never sign', () async {
      final legacyRecorder = _RecordingInterceptor();
      final legacy = FlyNarwhalRemoteDataSource(
        getToken: () => '',
        getCookie: () => '',
        getFnBaseUrl: () => '',
        getFlyNarwhalBaseUrl: () => 'http://127.0.0.1:9',
        getAuthCode: () => 'FN1_TEST',
        getInstanceId: () => instanceId,
        dio: Dio(BaseOptions(responseType: ResponseType.plain))
          ..interceptors.add(legacyRecorder),
        wbSigner: signer,
      );
      final result = await legacy.getVersion();
      expect(result, isA<Success<dynamic>>());
      final headers = legacyRecorder.requests.single.headers;
      expect(headers.containsKey('Fnwb'), isFalse);
      expect(headers['Authx'], isNotNull);
      expect(headers['Signx'], isNotNull);
      expect(signer.messages, isEmpty);
    });
  });

  group('Fnwb failure and absence semantics', () {
    test('a throwing signer fails the request instead of dropping Fnwb',
        () async {
      final recorder = _RecordingInterceptor();
      final dataSource = FlyNarwhalRemoteDataSource(
        getToken: () => '',
        getCookie: () => '',
        getFnBaseUrl: () => '',
        getFlyNarwhalBaseUrl: () => 'http://127.0.0.1:9',
        getAuthCode: () => code,
        getInstanceId: () => instanceId,
        dio: Dio(BaseOptions(responseType: ResponseType.plain))
          ..interceptors.add(recorder),
        wbSigner: _ThrowingWbSigner(),
      );
      final result = await dataSource.getVersion();
      expect(result, isA<ResultFailure<dynamic>>());
      final failure = (result as ResultFailure<dynamic>).info;
      expect(failure.message, contains('wb signing unavailable'));
      // The request must never reach the transport without its build proof.
      expect(recorder.requests, isEmpty);
    });

    test('dev selector returns null when no library is bundled', () {
      // The test runner executable directory has no libfly_narwhal_wb; the
      // failed load is cached, so repeated calls stay null without retrying.
      expect(tryLoadWbSigner(), isNull);
      expect(tryLoadWbSigner(), isNull);
    });

    test('null signer keeps FNK2 requests working without Fnwb', () async {
      // Constructed before the selector test above could cache anything, and
      // with the library absent this exercises the dev (no-library) path.
      final recorder = _RecordingInterceptor();
      final dataSource = FlyNarwhalRemoteDataSource(
        getToken: () => '',
        getCookie: () => '',
        getFnBaseUrl: () => '',
        getFlyNarwhalBaseUrl: () => 'http://127.0.0.1:9',
        getAuthCode: () => code,
        getInstanceId: () => instanceId,
        dio: Dio(BaseOptions(responseType: ResponseType.plain))
          ..interceptors.add(recorder),
      );
      final result = await dataSource.getVersion();
      expect(result, isA<Success<dynamic>>());
      final headers = recorder.requests.single.headers;
      expect(headers.containsKey('Fnwb'), isFalse);
      expect(headers['Fnauth'], isNotNull);
    });
  });
}

class _FakeWbSigner implements WbSigner {
  _FakeWbSigner(this.signature);

  final String signature;
  final List<String> messages = <String>[];

  @override
  String sign(String message) {
    messages.add(message);
    return signature;
  }
}

class _ThrowingWbSigner implements WbSigner {
  @override
  String sign(String message) {
    throw StateError('wb signing unavailable');
  }
}

/// Answers every request with a minimal success envelope and records the
/// outgoing options, so no network is touched.
class _RecordingInterceptor implements Interceptor {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        data: '{"code":0,"msg":"ok","data":{}}',
      ),
    );
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) =>
      handler.next(response);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) =>
      handler.next(err);
}