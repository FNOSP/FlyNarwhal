import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/dio_client.dart';
import 'package:fly_narwhal/data/datasources/remote/cdn_range_remote_data_source.dart';

void main() {
  final uri = Uri.parse('https://provider.example/video?signature=private');
  late _FakeAdapter adapter;
  late CdnRangeRemoteDataSource source;

  setUp(() {
    adapter = _FakeAdapter();
    source = CdnRangeRemoteDataSource(
      dioClient: DioClient.external(adapter: adapter),
    );
  });
  tearDown(() => source.close());

  test('Given provider metadata, when flattened, then HTTP values are valid',
      () {
    expect(
        CdnRangeRemoteDataSource.normalizeHeaders({
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
    expect(response.statusCode, 206);
    expect(response.headers['x-provider'], ['one', 'two']);
    final chunks = response.stream.toList();
    body.add(Uint8List.fromList([0xff, 0, 0x7b, 0xfe]));
    await body.close();
    expect(await chunks, [
      Uint8List.fromList([0xff, 0, 0x7b, 0xfe])
    ]);
  });

  test('Given HTTP 416, when opened, then the scheduler can inspect its status',
      () async {
    adapter.respond = (_, __) async => ResponseBody.fromBytes([], 416,
        headers: {
          'content-range': ['bytes */100']
        });
    final response = (await source.open(
      uri: uri,
      headers: {},
      start: 100,
      end: 110,
      cancelToken: CancelToken(),
    ))
        .getOrThrow();
    expect(response.statusCode, 416);
    expect(response.headers['content-range'], ['bytes */100']);
    await response.stream.drain<void>();
  });

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
    adapter.respond = (_, __) async => ResponseBody(body.stream, 206);
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
        emitsError(isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
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
    adapter.respond = (_, __) async => ResponseBody(body.stream, 206);
    final token = CancelToken();
    final response = await source.open(
      uri: uri,
      headers: {},
      start: 0,
      end: 9,
      cancelToken: token,
    );
    expect(response.isSuccess, isTrue);

    // Header validation can reject this response before its exposed stream is
    // ever listened to (for example, a missing Content-Range or empty source).
    token.cancel('Rejected response headers');
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
      (_, __) async => ResponseBody.fromBytes([], 206);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    return respond(options, cancelFuture);
  }

  @override
  void close({bool force = false}) => closedForcefully = force;
}
