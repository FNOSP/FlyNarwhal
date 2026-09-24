import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_errors.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_http_range_source.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_request_headers.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _deadline = Duration(seconds: 3);

void main() {
  final uri = Uri.parse('https://provider.example/video?signature=private');
  late _FakeAdapter adapter;
  late CdnHttpRangeSource source;

  setUp(() {
    adapter = _FakeAdapter();
    source = CdnHttpRangeSource(adapter: adapter);
  });
  tearDown(() => source.close());

  test('Given provider metadata, when flattened, then HTTP values are valid',
      () {
    expect(
        normalizeCdnRequestHeaders({
          'Cookie': ['sid=provider', 'uid=42'],
          'User-Agent': ['provider-agent'],
          'Referer': 'https://provider.example/',
          'Accept': ['video/mp4', 'application/octet-stream'],
          'X-Provider': ['one', 'two'],
          'x-provider': 'three',
          'Empty': <String>[],
          'Missing': null,
          'Authorization': 'nas-token',
          'AUTHX': 'nas-signature',
          'Signx': 'nas-signature',
          'X-WP-Header': 'nas-routing',
          'X-Trim-Client': 'web',
          'X-Nas-Token': 'nas-token',
          'X-Fn-Token': 'nas-token',
        }),
        {
          'cookie': 'sid=provider; uid=42',
          'user-agent': 'provider-agent',
          'referer': 'https://provider.example/',
          'accept': 'video/mp4, application/octet-stream',
          'x-provider': 'one, two, three',
        });
  });

  test('Given mixed headers, when opened, then only bounded CDN headers leave',
      () async {
    final response = (await source.open(
      uri: uri,
      headers: {
        'Host': 'nas.example',
        'CONTENT-LENGTH': '999',
        'Connection': 'keep-alive',
        'Range': 'bytes=0-',
        'If-Range': '"stale"',
        'If-Match': '"stale"',
        'If-None-Match': '*',
        'If-Modified-Since': 'stale',
        'If-Unmodified-Since': 'stale',
        'Accept-Encoding': 'gzip',
        'Authx': 'nas-signature',
        'X-WP-Header': 'nas-routing',
        'X-Trim-Client-Version': '616',
        'Cookie': 'sid=provider',
        'User-Agent': 'provider-agent',
        'Referer': 'https://provider.example/',
      },
      start: 17,
      end: 29,
      cancelToken: CancelToken(),
    ))
        .getOrThrow();
    await response.stream.drain<void>();

    final request = adapter.requests.single;
    final headers = request.headers.map(
      (key, value) => MapEntry(key.toLowerCase(), value),
    );
    expect(request.uri, uri);
    expect(request.responseType, ResponseType.stream);
    expect(headers['range'], 'bytes=17-29');
    expect(headers['accept-encoding'], 'identity');
    expect(headers['cookie'], 'sid=provider');
    expect(headers['user-agent'], 'provider-agent');
    expect(headers['referer'], 'https://provider.example/');
    for (final forbidden in [
      'if-range',
      'if-match',
      'if-none-match',
      'if-modified-since',
      'if-unmodified-since',
      'host',
      'content-length',
      'connection',
      'authorization',
      'authx',
      'x-wp-header',
      'x-trim-client',
      'x-trim-client-version',
    ]) {
      expect(headers, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
      'Given an unfinished binary body, when opened, then bytes remain a stream',
      () async {
    final body = StreamController<Uint8List>();
    adapter.respond = (_, __) async => ResponseBody(body.stream, 206, headers: {
          'content-range': ['bytes 2-5/9'],
          'content-type': ['application/json'],
          'x-provider': ['one', 'two'],
        });

    final response = (await source.open(
      uri: uri,
      headers: {},
      start: 2,
      end: 5,
      cancelToken: CancelToken(),
    ))
        .getOrThrow();
    expect(response.totalLength, 9);
    expect(response.contentType, 'application/json');
    final chunks = response.stream.toList();
    body.add(Uint8List.fromList([0xff, 0, 0x7b, 0xfe]));
    await body.close();
    expect(await chunks, [
      Uint8List.fromList([0xff, 0, 0x7b, 0xfe])
    ]);
  });

  test(
      'Given an empty resource probe, when HTTP 416 confirms zero bytes, then the body is cancelled before returning an empty stream',
      () async {
    final stopped = Completer<void>();
    final body = StreamController<Uint8List>(onCancel: stopped.complete);
    addTearDown(() => body.close());
    adapter.respond = (_, __) async => ResponseBody(body.stream, 416, headers: {
          'content-range': ['bytes */0'],
        });
    final token = CancelToken();
    final response = (await source
            .open(
              uri: uri,
              headers: {},
              start: 0,
              end: 0,
              cancelToken: token,
            )
            .timeout(_deadline))
        .getOrThrow();
    expect(response.totalLength, 0);
    expect(token.isCancelled, isFalse,
        reason:
            'The transport owns a linked token; it does not cancel its caller.');
    await stopped.future.timeout(_deadline);
    expect(await response.stream.toList().timeout(_deadline), isEmpty);
  });

  final invalidResponses = <({
    String reason,
    int status,
    Map<String, List<String>> headers,
  })>[
    (reason: 'ignored Range', status: 200, headers: _rangeHeaders()),
    (reason: 'forbidden status', status: 403, headers: _rangeHeaders()),
    (
      reason: 'nonempty unsatisfied range',
      status: 416,
      headers: {
        'content-range': ['bytes */100']
      },
    ),
    (
      reason: 'empty response outside the initial probe',
      status: 416,
      headers: {
        'content-range': ['bytes */0']
      },
    ),
    (reason: 'missing Content-Range', status: 206, headers: {}),
    (
      reason: 'malformed Content-Range',
      status: 206,
      headers: _rangeHeaders(contentRange: 'not a range'),
    ),
    (
      reason: 'wrong starting byte',
      status: 206,
      headers: _rangeHeaders(contentRange: 'bytes 1-5/9'),
    ),
    (
      reason: 'wrong ending byte',
      status: 206,
      headers: _rangeHeaders(contentRange: 'bytes 2-6/9'),
    ),
    (
      reason: 'reversed range',
      status: 206,
      headers: _rangeHeaders(contentRange: 'bytes 5-2/9'),
    ),
    (
      reason: 'negative range',
      status: 206,
      headers: _rangeHeaders(contentRange: 'bytes -2-5/9'),
    ),
    (
      reason: 'unknown total size',
      status: 206,
      headers: _rangeHeaders(contentRange: 'bytes 2-5/*'),
    ),
    (
      reason: 'non-byte range unit',
      status: 206,
      headers: _rangeHeaders(contentRange: 'items 2-5/9'),
    ),
    (
      reason: 'total size excluding the last byte',
      status: 206,
      headers: _rangeHeaders(contentRange: 'bytes 2-5/5'),
    ),
    (
      reason: 'overflowing range start',
      status: 206,
      headers: _rangeHeaders(contentRange: 'bytes 9223372036854775808-5/9'),
    ),
    (
      reason: 'overflowing range end',
      status: 206,
      headers: _rangeHeaders(contentRange: 'bytes 2-9223372036854775808/9'),
    ),
    (
      reason: 'overflowing total size',
      status: 206,
      headers: _rangeHeaders(contentRange: 'bytes 2-5/9223372036854775808'),
    ),
    (
      reason: 'mismatched Content-Length',
      status: 206,
      headers: _rangeHeaders(contentLength: '5'),
    ),
    (
      reason: 'malformed Content-Length',
      status: 206,
      headers: _rangeHeaders(contentLength: 'unknown'),
    ),
    (
      reason: 'negative Content-Length',
      status: 206,
      headers: _rangeHeaders(contentLength: '-4'),
    ),
    (
      reason: 'overflowing Content-Length',
      status: 206,
      headers: _rangeHeaders(contentLength: '9223372036854775808'),
    ),
    (
      reason: 'compressed body',
      status: 206,
      headers: {
        ..._rangeHeaders(),
        'content-encoding': ['gzip'],
      },
    ),
  ];

  for (final scenario in invalidResponses) {
    test(
        'Given ${scenario.reason}, when validating headers, then failure cancels the unfinished body without reading it',
        () async {
      final stopped = Completer<void>();
      final body = StreamController<Uint8List>(onCancel: stopped.complete);
      addTearDown(() => body.close());
      adapter.respond = (_, __) async => ResponseBody(
            body.stream,
            scenario.status,
            headers: scenario.headers,
          );
      final token = CancelToken();

      // A stalled body must not keep invalid headers or a slot alive.
      final response = await source
          .open(
            uri: uri,
            headers: {},
            start: 2,
            end: 5,
            cancelToken: token,
          )
          .timeout(_deadline);

      expect(response.isFailure, isTrue);
      expect(response.failureOrNull?.displayMessage,
          matches(RegExp(r'[\u4e00-\u9fff]')));
      expect(token.isCancelled, isFalse,
          reason:
              'The transport owns a linked token; it does not cancel its caller.');
      await stopped.future.timeout(_deadline);
      expect(adapter.requests, hasLength(1));
    });
  }

  test(
      'Given mixed-case response headers, when validating an identity range, then typed metadata and bytes are preserved',
      () async {
    adapter.respond = (_, __) async => ResponseBody.fromBytes([2, 3, 4, 5], 206,
        headers: {
          'CoNtEnT-RaNgE': ['bytes 2-5/9'],
          'Content-Length': ['4'],
          'Content-Type': ['video/mp4'],
          'CONTENT-ENCODING': ['identity'],
        });
    final token = CancelToken();
    final response = (await source.open(
      uri: uri,
      headers: {},
      start: 2,
      end: 5,
      cancelToken: token,
    ))
        .getOrThrow();

    expect(response.totalLength, 9);
    expect(response.contentType, 'video/mp4');
    expect(
        await response.stream.expand((chunk) => chunk).toList(), [2, 3, 4, 5]);
    expect(token.isCancelled, isFalse);
  });

  for (final contentType in [null, 'application/vnd.apple.mpegurl']) {
    test(
        'Given a valid range without Content-Length and MIME $contentType, when opened, then no media-type restriction is added',
        () async {
      adapter.respond =
          (_, __) async => ResponseBody.fromBytes([2, 3, 4, 5], 206,
              headers: {
                'content-range': ['bytes 2-5/9'],
                if (contentType != null) 'content-type': [contentType],
              });
      final response = (await source.open(
        uri: uri,
        headers: {},
        start: 2,
        end: 5,
        cancelToken: CancelToken(),
      ))
          .getOrThrow();

      expect(response.totalLength, 9);
      expect(response.contentType, contentType);
      expect(await response.stream.expand((chunk) => chunk).toList(),
          [2, 3, 4, 5]);
    });
  }

  test('Given an invalid range or URL, when opened, then no request is sent',
      () async {
    for (final (start, end) in [
      (-1, 3),
      (3, 2),
      (0, 10 * 1024 * 1024),
      (0, 0x7fffffffffffffff),
    ]) {
      final response = await source.open(
        uri: uri,
        headers: {},
        start: start,
        end: end,
        cancelToken: CancelToken(),
      );
      expect(response.isFailure, isTrue);
    }
    final response = await source.open(
      uri: Uri.parse('file:///video.mp4'),
      headers: {},
      start: 0,
      end: 0,
      cancelToken: CancelToken(),
    );
    expect(response.isFailure, isTrue);
    expect(adapter.requests, isEmpty);
  });

  test('Given cancellation before headers, when cancelled, then fetching stops',
      () async {
    final entered = Completer<void>();
    final cancelled = Completer<void>();
    adapter.respond = (_, cancelFuture) {
      entered.complete();
      cancelFuture!.then((_) => cancelled.complete());
      return Completer<ResponseBody>().future;
    };
    final token = CancelToken();
    final response = source.open(
      uri: uri,
      headers: {},
      start: 0,
      end: 0,
      cancelToken: token,
    );
    await entered.future;
    token.cancel('seek');
    expect((await response).failureOrNull?.message, 'Request was cancelled');
    await cancelled.future;
    expect(adapter.requests, hasLength(1));
  });

  test(
      'Given cancellation during a body, when cancelled, then the stream stops',
      () async {
    final stopped = Completer<void>();
    final body = StreamController<Uint8List>(onCancel: stopped.complete);
    adapter.respond = (_, __) async => ResponseBody(body.stream, 206, headers: {
          'content-range': ['bytes 0-9/10'],
        });
    final token = CancelToken();
    final response = (await source.open(
      uri: uri,
      headers: {},
      start: 0,
      end: 9,
      cancelToken: token,
    ))
        .getOrThrow();
    final expectation = expectLater(
      response.stream,
      emitsInOrder([
        emitsError(isA<CdnRequestFailure>().having(
          (error) => error.kind,
          'kind',
          CdnRequestFailureKind.cancelled,
        )),
        emitsDone,
      ]),
    );
    token.cancel('seek');
    await expectation;
    await stopped.future;
    await body.close();
  });

  test(
      'Given an unconsumed response, when cancelled, then its source is released',
      () async {
    final stopped = Completer<void>();
    final body = StreamController<Uint8List>(onCancel: stopped.complete);
    adapter.respond = (_, __) async => ResponseBody(body.stream, 206, headers: {
          'content-range': ['bytes 0-9/10'],
        });
    final token = CancelToken();
    final response = await source.open(
      uri: uri,
      headers: {},
      start: 0,
      end: 9,
      cancelToken: token,
    );
    expect(response.isSuccess, isTrue);

    // Seeking can abandon a valid response before the scheduler listens to it.
    token.cancel('Seek abandoned this response');
    await stopped.future;
    await body.close();
    expect(adapter.requests, hasLength(1));
  });

  test('Given a transport error, when opened, then signed details stay private',
      () async {
    adapter.respond = (options, _) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Failed to open $uri with private provider cookie',
        );
    final response = await source.open(
      uri: uri,
      headers: {},
      start: 0,
      end: 0,
      cancelToken: CancelToken(),
    );
    expect(response.failureOrNull?.message, 'CDN network request failed');
    expect(adapter.requests, hasLength(1));
  });

  test('Given an owned client, when closed, then adapter closes active sockets',
      () {
    source.close();
    expect(adapter.closedForcefully, isTrue);
  });
}

class _FakeAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool closedForcefully = false;
  Future<ResponseBody> Function(RequestOptions, Future<void>?) respond =
      (options, _) async {
    final range = RegExp(r'^bytes=(\d+)-(\d+)$')
        .firstMatch(options.headers['range'] as String)!;
    final start = int.parse(range[1]!);
    final end = int.parse(range[2]!);
    return ResponseBody.fromBytes(List.filled(end - start + 1, 0), 206,
        headers: {
          'content-range': ['bytes $start-$end/${end + 1}'],
          'content-length': ['${end - start + 1}'],
        });
  };

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    return respond(options, cancelFuture);
  }

  @override
  void close({bool force = false}) => closedForcefully = force;
}

Map<String, List<String>> _rangeHeaders({
  String contentRange = 'bytes 2-5/9',
  String contentLength = '4',
}) =>
    {
      'content-range': [contentRange],
      'content-length': [contentLength],
    };
