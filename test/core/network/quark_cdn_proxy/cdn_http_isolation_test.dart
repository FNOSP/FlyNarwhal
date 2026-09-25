import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_http_range_source.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/dio_client.dart';
import 'package:fly_narwhal/core/network/interceptors/index.dart';
import 'package:fly_narwhal/core/network/interceptors/ssl_trust_interceptor.dart';

void main() {
  test('Given an external client, then no NAS interceptors are installed', () {
    final client = CdnHttpRangeSource();
    addTearDown(() => client.dio.close(force: true));
    expect(client.dio.options.baseUrl, isEmpty);
    expect(client.dio.options.headers, isEmpty);
    expect(client.dio.interceptors.whereType<AuthInterceptor>(), isEmpty);
    expect(client.dio.interceptors.whereType<RetryInterceptor>(), isEmpty);
    expect(client.dio.interceptors.whereType<LoggingInterceptor>(), isEmpty);
    expect(client.dio.interceptors.whereType<ErrorInterceptor>(), isEmpty);
    expect(client.dio.interceptors.whereType<SslTrustInterceptor>(), isEmpty);
    final adapter = client.dio.httpClientAdapter as IOHttpClientAdapter;
    final httpClient = adapter.createHttpClient!();
    expect(httpClient.autoUncompress, isFalse);
    httpClient.close(force: true);
  });

  test('Given the normal constructor, then existing interceptors remain', () {
    final client = DioClient.withCallbacks(
      getToken: () => 'nas-token',
      getCookie: () => 'nas-cookie',
      getBaseUrl: () => 'https://nas.example',
    );
    addTearDown(() => client.dio.close(force: true));
    expect(client.dio.interceptors.whereType<AuthInterceptor>(), hasLength(1));
    expect(client.dio.interceptors.whereType<RetryInterceptor>(), hasLength(1));
    expect(
        client.dio.interceptors.whereType<LoggingInterceptor>(), hasLength(1));
    expect(client.dio.interceptors.whereType<ErrorInterceptor>(), hasLength(1));
    expect(
        client.dio.interceptors.whereType<SslTrustInterceptor>(), hasLength(1));
    expect(client.dio.options.responseType, ResponseType.json);
  });

  test('Given a normal GET, then NAS auth and JSON decoding remain unchanged',
      () async {
    final adapter = _JsonAdapter();
    final dio = Dio();
    final client = DioClient.withCallbacks(
      getToken: () => 'nas-token',
      getCookie: () => 'nas-cookie',
      getBaseUrl: () => 'https://nas.example',
      config: const DioClientConfig(enableLogging: false, enableRetry: false),
      dio: dio,
    );
    addTearDown(() => client.dio.close(force: true));
    // The normal constructor installs the upstream certificate-trust adapter.
    // Replace it afterward so this request remains isolated from real network IO.
    client.dio.httpClientAdapter.close(force: true);
    client.dio.httpClientAdapter = adapter;
    final response = await client.get<Map<String, dynamic>>('/metadata');
    expect(response.getOrThrow(), {'code': 0, 'data': 'decoded'});
    expect(adapter.request!.headers['Authorization'], 'nas-token');
    expect(adapter.request!.headers['Cookie'], 'nas-cookie');
    expect(adapter.request!.headers['Authx'], isNotEmpty);
    expect(adapter.request!.uri, Uri.parse('https://nas.example/metadata'));
  });
}

class _JsonAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString('{"code":0,"data":"decoded"}', 200,
        headers: {
          'content-type': ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}
