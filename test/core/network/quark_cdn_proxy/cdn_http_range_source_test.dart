import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/core/network/interceptors/index.dart';
import 'package:fly_narwhal/core/network/interceptors/ssl_trust_interceptor.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_http_range_source.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_errors.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_source.dart';

import '../../../../tool/support/cdn_proxy_http_fixture.dart';

void main() {
  late CdnHttpFixture origin;
  late CdnHttpRangeSource source;
  Future<bool> Function(HttpRequest, CdnFixtureRequest)? handle;
  final gates = <Completer<void>>[];

  Completer<void> gate() {
    final value = Completer<void>();
    gates.add(value);
    return value;
  }

  setUp(() async {
    handle = null;
    origin = await CdnHttpFixture.start(
      length: 256,
      handle: (request, entry) async =>
          await handle?.call(request, entry) ?? false,
    );
    source = CdnHttpRangeSource();
  });

  tearDown(() async {
    for (final value in gates) {
      if (!value.isCompleted) value.complete();
    }
    gates.clear();
    source.close();
    source.close();
    await origin.close();
  });

  Future<ApiResult<CdnRangeResponse>> open({CancelToken? token}) => source.open(
        uri: origin.uri,
        headers: const {},
        start: 2,
        end: 65,
        cancelToken: token ?? CancelToken(),
      );

  test(
      'Given CDN credentials, then real HTTP isolates headers and preserves bytes',
      () async {
    handle = (request, _) async {
      request.response.headers
          .set(HttpHeaders.lastModifiedHeader, 'Wed, 01 Jan 2025 00:00:00 GMT');
      return false;
    };
    final result = await source.open(
      uri: origin.uri,
      headers: const {
        'Cookie': 'sid=cdn-cookie',
        'Referer': 'https://provider.example/',
        'User-Agent': 'CDN test',
        'Authorization': 'Bearer nas-secret',
        'authx': 'nas-secret',
        'signx': 'nas-secret',
        'X-Nas-Token': 'nas-secret',
        'Range': 'bytes=99-100',
        'If-Range': '"stale"',
        'Accept-Encoding': 'gzip',
        'Host': 'wrong.example',
      },
      start: 2,
      end: 65,
      ifRangeEtag: '"fixture-256"',
      cancelToken: CancelToken(),
    );
    final response = result.getOrThrow();
    expect(await response.stream.expand((bytes) => bytes).toList(),
        List.generate(64, (i) => fixtureByteAt(2 + i)));
    expect(response.totalLength, 256);
    expect(response.contentType, 'application/octet-stream');
    expect(response.entityTag?.strongValue, '"fixture-256"');
    expect(response.lastModified, DateTime.utc(2025));
    final headers = origin.requests.single.requestHeaders;
    expect(headers['cookie'], 'sid=cdn-cookie');
    expect(headers['referer'], 'https://provider.example/');
    expect(headers['user-agent'], 'CDN test');
    expect(headers['range'], 'bytes=2-65');
    expect(headers['if-range'], '"fixture-256"');
    expect(headers['accept-encoding'], 'identity');
    expect(headers.toString(), isNot(contains('nas-secret')));
    expect(headers['host'], isNot('wrong.example'));
    expect(
        source.dio.interceptors,
        isNot(contains(anyOf(
          isA<AuthInterceptor>(),
          isA<RetryInterceptor>(),
          isA<LoggingInterceptor>(),
          isA<ErrorInterceptor>(),
          isA<SslTrustInterceptor>(),
        ))));
    expect(source.requestTimeout, const Duration(hours: 48));
    expect(source.dio.options.connectTimeout, isNull);
    expect(source.dio.options.sendTimeout, isNull);
    expect(source.dio.options.receiveTimeout, isNull);
    expect(source.activeAttemptCount, 0);
  });

  test(
      'Given an unfinished body, then its prefix reaches the caller before EOF',
      () async {
    final finish = gate();
    handle = (request, entry) async {
      await entry.write(request.response, 4);
      await finish.future;
      return false;
    };
    final response = (await open()).getOrThrow();
    final first = Completer<void>();
    final bytes = <int>[];
    final reading = response.stream.listen((data) {
      bytes.addAll(data);
      if (!first.isCompleted) first.complete();
    }).asFuture<void>();
    await first.future.timeout(const Duration(seconds: 3));
    expect(bytes, List.generate(4, (i) => fixtureByteAt(2 + i)));
    expect(origin.requests.single.completedAt, isNull);
    finish.complete();
    await reading.timeout(const Duration(seconds: 3));
    expect(bytes, List.generate(64, (i) => fixtureByteAt(2 + i)));
    expect(source.activeAttemptCount, 0);
  });

  for (final invalid in [
    'ignored range',
    'missing range',
    'wrong range',
    'wrong length',
    'compressed',
    'invalid etag',
    'invalid modification date',
  ]) {
    test('Given $invalid from HTTP, then rejects the response before media use',
        () async {
      handle = (request, _) async {
        final response = request.response;
        switch (invalid) {
          case 'ignored range':
            response.statusCode = HttpStatus.ok;
          case 'missing range':
            response.headers.removeAll(HttpHeaders.contentRangeHeader);
          case 'wrong range':
            response.headers
                .set(HttpHeaders.contentRangeHeader, 'bytes 3-66/256');
          case 'wrong length':
            response.contentLength = 65;
          case 'compressed':
            response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
          case 'invalid etag':
            response.headers.set(HttpHeaders.etagHeader, 'unquoted');
          case 'invalid modification date':
            response.headers.set(HttpHeaders.lastModifiedHeader, 'invalid');
        }
        return false;
      };
      final failure = (await open()).failureOrNull as CdnRequestFailure;
      expect(failure.kind, CdnRequestFailureKind.protocol);
      expect(failure.phase, CdnRequestFailurePhase.headers);
      expect(failure.isTimeout, isFalse);
      expect(source.activeAttemptCount, 0);
    });
  }

  for (final tag in <String?>['W/"version"', null]) {
    test('Given identity $tag, then preserves weak or absent identity honestly',
        () async {
      handle = (request, _) async {
        if (tag == null) {
          request.response.headers.removeAll(HttpHeaders.etagHeader);
        } else {
          request.response.headers.set(HttpHeaders.etagHeader, tag);
        }
        return false;
      };
      final response = (await open()).getOrThrow();
      await response.stream.drain<void>();
      expect(response.entityTag?.headerValue, tag);
      expect(response.entityTag?.strongValue, isNull);
    });
  }

  test('Given an empty origin, then its 416 probe becomes an empty resource',
      () async {
    await origin.close();
    origin = await CdnHttpFixture.start(length: 0);
    final response = (await source.open(
      uri: origin.uri,
      headers: const {},
      start: 0,
      end: 0,
      cancelToken: CancelToken(),
    ))
        .getOrThrow();
    expect(response.totalLength, 0);
    expect(await response.stream.toList(), isEmpty);
    expect(source.activeAttemptCount, 0);
  });

  for (final status in [403, 416, 503]) {
    test(
        'Given HTTP $status, then preserves the status without transport retry',
        () async {
      handle = (request, _) async {
        request.response
          ..statusCode = status
          ..contentLength = -1
          ..write('error with secret-sign and secret-cookie');
        await request.response.close();
        return true;
      };
      final failure = (await open()).failureOrNull as CdnRequestFailure;
      expect(failure.kind, CdnRequestFailureKind.httpStatus);
      expect(failure.phase, CdnRequestFailurePhase.headers);
      expect(failure.statusCode, status);
      expect(failure.isTimeout, isFalse);
      expect(failure.message, contains('HTTP $status'));
      expect('${failure.message} ${failure.displayMessage}',
          isNot(contains('secret-')));
      expect(origin.requests, hasLength(1));
      expect(source.activeAttemptCount, 0);
    });
  }

  test(
      'Given no response headers, then the total request deadline cancels HTTP',
      () async {
    handle = (_, __) async => true;
    source.close();
    source =
        CdnHttpRangeSource(requestTimeout: const Duration(milliseconds: 200));
    final failure = (await open().timeout(const Duration(seconds: 3)))
        .failureOrNull as CdnRequestFailure;
    expect(failure.isTimeout, isTrue);
    expect(failure.phase, CdnRequestFailurePhase.request);
    expect(source.activeAttemptCount, 0);
  });

  test('Given a progressing body, then data does not reset the total deadline',
      () async {
    handle = (request, entry) async {
      for (var i = 0; i < entry.length; i++) {
        await entry.write(request.response, 1);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await request.response.close();
      return true;
    };
    source.close();
    source =
        CdnHttpRangeSource(requestTimeout: const Duration(milliseconds: 200));
    final response = (await open()).getOrThrow();
    var received = 0;
    CdnRequestFailure? failure;
    try {
      await for (final bytes in response.stream) {
        received += bytes.length;
      }
    } on CdnRequestFailure catch (error) {
      failure = error;
    }
    expect(received, inExclusiveRange(0, 64));
    expect(failure?.isTimeout, isTrue);
    expect(failure?.phase, CdnRequestFailurePhase.body);
    expect(source.activeAttemptCount, 0);
  });

  test('Given pending headers, then cancellation is reported as cancellation',
      () async {
    final entered = gate();
    handle = (_, __) async {
      entered.complete();
      return true;
    };
    final token = CancelToken();
    final pending = open(token: token);
    await entered.future.timeout(const Duration(seconds: 3));
    token.cancel();
    final failure = (await pending.timeout(const Duration(seconds: 3)))
        .failureOrNull as CdnRequestFailure;
    expect(failure.kind, CdnRequestFailureKind.cancelled);
    expect(failure.isTimeout, isFalse);
    expect(source.activeAttemptCount, 0);
  });

  test('Given simultaneous bodies, then cancelling one leaves the other usable',
      () async {
    final finish = gate();
    final secondFinish = gate();
    handle = (request, entry) async {
      await entry.write(request.response, 4);
      await (entry.start == 2 ? finish : secondFinish).future;
      return false;
    };
    final token = CancelToken();
    final response = (await open(token: token)).getOrThrow();
    final first = Completer<void>();
    final failure = Completer<CdnRequestFailure>();
    final done = Completer<void>();
    response.stream.listen((_) {
      if (!first.isCompleted) first.complete();
    }, onError: (Object error) {
      failure.complete(error as CdnRequestFailure);
    }, onDone: done.complete);
    await first.future.timeout(const Duration(seconds: 3));
    final second = (await source.open(
      uri: origin.uri,
      headers: const {},
      start: 128,
      end: 191,
      cancelToken: CancelToken(),
    ))
        .getOrThrow();
    final secondStarted = Completer<void>();
    final secondBytes = <int>[];
    final secondDone = second.stream.listen((bytes) {
      secondBytes.addAll(bytes);
      if (!secondStarted.isCompleted) secondStarted.complete();
    }).asFuture<void>();
    await secondStarted.future.timeout(const Duration(seconds: 3));
    expect(source.activeAttemptCount, 2);
    token.cancel();
    expect((await failure.future).kind, CdnRequestFailureKind.cancelled);
    await done.future.timeout(const Duration(seconds: 3));
    expect(source.activeAttemptCount, 1);
    expect(secondBytes, List.generate(4, (i) => fixtureByteAt(128 + i)));
    secondFinish.complete();
    await secondDone.timeout(const Duration(seconds: 3));
    expect(secondBytes, List.generate(64, (i) => fixtureByteAt(128 + i)));
    expect(source.activeAttemptCount, 0);
  });
  for (final scenario in [
    (
      name: 'connection timeout',
      timeout: true,
      error: (RequestOptions options) => DioException.connectionTimeout(
          requestOptions: options,
          timeout: Duration.zero,
          error: const SocketException('Connection timed out secret-sign')),
    ),
    (
      name: 'connection error',
      timeout: false,
      error: (RequestOptions options) => DioException.connectionError(
          requestOptions: options,
          reason: 'Connection refused secret-cookie',
          error: const SocketException('Connection refused secret-cookie')),
    ),
    (
      name: 'TLS handshake',
      timeout: false,
      error: (RequestOptions _) =>
          const HandshakeException('TLS failed secret-sign secret-cookie'),
    ),
  ]) {
    test(
        'Given ${scenario.name}, then preserves classification without secrets',
        () async {
      final adapter = _ErrorAdapter(scenario.error);
      source.close();
      source = CdnHttpRangeSource(adapter: adapter);
      final failure = (await open()).failureOrNull as CdnRequestFailure;
      expect(failure.kind, CdnRequestFailureKind.transport);
      expect(failure.phase, CdnRequestFailurePhase.request);
      expect(failure.isTimeout, scenario.timeout);
      expect(failure.message, 'CDN network request failed');
      expect('${failure.message} ${failure.displayMessage}',
          isNot(contains('secret-')));
      expect(adapter.requests, 1);
      expect(source.activeAttemptCount, 0);
    });
  }
}

/// Native IO errors are injected at the adapter boundary; no response scripting.
class _ErrorAdapter implements HttpClientAdapter {
  _ErrorAdapter(this.error);
  final Object Function(RequestOptions) error;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests++;
    throw error(options);
  }

  @override
  void close({bool force = false}) {}
}
