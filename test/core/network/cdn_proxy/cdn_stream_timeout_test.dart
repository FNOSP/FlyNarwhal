import 'package:fly_narwhal/core/network/cdn_proxy/cdn_http_transport.dart';
import 'package:fly_narwhal/core/network/cdn_proxy/cdn_proxy_errors.dart';
import 'package:fly_narwhal/core/network/cdn_proxy/cdn_range_source.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/data/datasources/remote/cdn_range_remote_data_source.dart';

void main() {
  final uri = Uri.parse('https://provider.example/video?signature=secret-sign');
  const cookie = 'sid=secret-cookie';
  late _Adapter adapter;
  late CdnRangeRemoteDataSource source;

  setUp(() {
    adapter = _Adapter();
    source = CdnRangeRemoteDataSource(
      transport: CdnHttpTransport(adapter: adapter),
    );
  });
  tearDown(() => source.close());

  Future<ApiResult<CdnRangeResponse>> open() => source.open(
        uri: uri,
        headers: const {'Cookie': cookie},
        start: 0,
        end: 0,
        cancelToken: CancelToken(),
      );

  void expectPrivate(FailureInfo failure) {
    for (final value in [failure.message, failure.displayMessage]) {
      expect(value, isNot(contains(uri.toString())));
      expect(value, isNot(contains('secret-sign')));
      expect(value, isNot(contains(cookie)));
    }
  }

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.unknown,
  ]) {
    test(
        'Given $type, when a CDN range opens, then its typed timeout survives without credentials',
        () async {
      adapter.respond = (options) async => throw DioException(
            requestOptions: options,
            type: type,
            message: 'Failed $uri with $cookie',
            error: TimeoutException('Timed out $uri with $cookie'),
          );

      final failure = (await open()).failureOrNull!;

      expect(failure is CdnRequestFailure && failure.isTimeout, isTrue);
      expectPrivate(failure);
      // The scheduler owns retrying; opening a range performs one attempt.
      expect(adapter.requests, hasLength(1));
    });
  }

  for (final type in [
    DioExceptionType.cancel,
    DioExceptionType.connectionError,
    DioExceptionType.badCertificate,
    DioExceptionType.badResponse,
    DioExceptionType.unknown,
  ]) {
    test(
        'Given $type without a timeout, when a CDN range opens, then timeout words do not enable retry',
        () async {
      adapter.respond = (options) async => throw DioException(
            requestOptions: options,
            type: type,
            message: 'Connection timeout $uri with $cookie',
            error: StateError('receive timeout $uri with $cookie'),
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 503,
              data: {'msg': 'Provider timeout $uri with $cookie'},
            ),
          );

      final failure = (await open()).failureOrNull!;

      expect(failure is CdnRequestFailure && failure.isTimeout, isFalse);
      expectPrivate(failure);
      expect(adapter.requests, hasLength(1));
    });
  }

  test(
      'Given cancellation wrapping an earlier timeout, when opened, then cancellation stays terminal',
      () async {
    adapter.respond = (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: TimeoutException('Timed out $uri with $cookie'),
        );

    final failure = (await open()).failureOrNull!;

    expect(failure is CdnRequestFailure && failure.isTimeout, isFalse);
    expect(failure.message, 'Request was cancelled');
    expectPrivate(failure);
  });

  for (final status in [408, 504, 403, 429, 500, 503]) {
    test(
        'Given HTTP $status, when a CDN range opens, then only an explicit upstream timeout is retryable',
        () async {
      adapter.respond = (_) async => ResponseBody.fromString(
            'Gateway timeout $uri with $cookie',
            status,
          );

      final failure = (await open()).failureOrNull!;

      expect(failure is CdnRequestFailure && failure.isTimeout,
          status == 408 || status == 504);
      expect(failure.message, contains('HTTP $status'));
      expectPrivate(failure);
    });
  }

  test(
      'Given ordinary failures, when using existing constructors, then timeout defaults to false',
      () {
    const failure = FailureInfo(message: 'Timeout', displayMessage: 'Timeout');
    expect(failure is CdnRequestFailure && failure.isTimeout, isFalse);
    expect(FailureInfo.fromMessage('Timeout'), isNot(isA<CdnRequestFailure>()));
  });

  test(
      'Given a valid range, when opened, then typed bytes still pass through unchanged',
      () async {
    adapter.respond = (_) async => ResponseBody.fromBytes([42], 206,
        headers: {
          'content-range': ['bytes 0-0/1'],
          'content-length': ['1'],
        });

    final response = (await open()).getOrThrow();

    expect(response.totalLength, 1);
    expect(await response.stream.expand((chunk) => chunk).toList(), [42]);
  });
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  late Future<ResponseBody> Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}
