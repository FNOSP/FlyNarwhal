import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/data/datasources/remote/cdn_range_remote_data_source.dart';
import 'package:fly_narwhal/ui/features/player/services/cdn_range_policy.dart';
import 'package:fly_narwhal/ui/features/player/services/quark_cdn_range_service.dart';

const _deadline = Duration(seconds: 4);
const _chunk = cdnRangeChunkSize;

void main() {
  group('QuarkCdnRangeService actual loopback HTTP', () {
    for (final testCase in <(String, String?, int, int, int?)>[
      ('GET', null, 200, 0, 128),
      ('GET', 'bytes=2-9', 206, 2, 8),
      ('GET', 'bytes=124-', 206, 124, 4),
      ('GET', 'bytes=-3', 206, 125, 3),
      ('GET', 'bytes=124-999', 206, 124, 4),
      ('GET', 'bytes=128-', 416, 0, 0),
      ('GET', 'bytes=0-1,4-5', 416, 0, 0),
      ('HEAD', null, 200, 0, null),
      ('HEAD', 'bytes=999-', 200, 0, null),
    ]) {
      final (method, range, status, start, length) = testCase;
      test(
          'Given $method $range, when served, then returns correct HTTP semantics',
          () async {
        final harness = await _Harness.open(128, autoRespond: true);
        addTearDown(harness.close);
        final client = harness.client();
        final request = await client.openUrl(method, harness.uri);
        if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);

        final response = await request.close().timeout(_deadline);
        expect(response.statusCode, status);
        expect(response.contentLength, length ?? 128);
        final bytes = await _collect(response);
        if (method == 'HEAD') {
          expect(bytes, isEmpty);
          expect(harness.source.requests, hasLength(1));
          expect(
              response.headers.value(HttpHeaders.contentRangeHeader), isNull);
        } else if (status == 416) {
          expect(response.headers.value(HttpHeaders.contentRangeHeader),
              'bytes */128');
          expect(bytes, isEmpty);
          expect(harness.source.requests, hasLength(1));
        } else {
          expect(bytes, _bytes(start, length!));
          expect(
              response.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
          expect(response.headers.value(HttpHeaders.cacheControlHeader),
              'no-store');
          expect(response.headers.contentType?.mimeType, 'video/mp4');
          expect(
              response.headers.value(HttpHeaders.contentRangeHeader),
              status == 206
                  ? 'bytes $start-${start + length - 1}/128'
                  : isNull);
        }
        await _waitForIdle(harness.budget);
      });
    }

    test(
        'Given a wrong path or method, when requested, then rejects without CDN reads',
        () async {
      final harness = await _Harness.open(128, autoRespond: true);
      addTearDown(harness.close);
      final client = harness.client();
      final missing = await (await client
              .getUrl(harness.uri.replace(path: '/stale-source')))
          .close()
          .timeout(_deadline);
      expect(missing.statusCode, 404);
      await _collect(missing);
      final unsupported =
          await (await client.postUrl(harness.uri)).close().timeout(_deadline);
      expect(unsupported.statusCode, 405);
      expect(unsupported.headers.value(HttpHeaders.allowHeader), 'GET, HEAD');
      await _collect(unsupported);
      expect(harness.source.requests, hasLength(1));
    });

    test(
        'Given an empty resource, when GET or Range requested, then returns 200 or 416 without data',
        () async {
      final harness = await _Harness.open(0, autoRespond: true);
      addTearDown(harness.close);
      final client = harness.client();
      final full =
          await (await client.getUrl(harness.uri)).close().timeout(_deadline);
      expect(full.statusCode, 200);
      expect(full.contentLength, 0);
      expect(await _collect(full), isEmpty);
      final partialRequest = await client.getUrl(harness.uri);
      partialRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final partial = await partialRequest.close().timeout(_deadline);
      expect(partial.statusCode, 416);
      expect(
          partial.headers.value(HttpHeaders.contentRangeHeader), 'bytes */0');
      expect(await _collect(partial), isEmpty);
      expect(harness.source.requests, hasLength(1));
    });

    test(
        'Given unavailable CDN body, when Range requested, then headers arrive before the first chunk',
        () async {
      final harness = await _Harness.open(128);
      addTearDown(harness.close);
      final request = await harness.client().getUrl(harness.uri);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=7-18');

      // This deadline fails on the original response.addStream implementation:
      // its headers stayed buffered until the complete CDN chunk was ready.
      final response = await request.close().timeout(_deadline);
      expect(response.statusCode, 206);
      expect(response.contentLength, 12);
      expect(response.headers.value(HttpHeaders.contentRangeHeader),
          'bytes 7-18/128');
      expect(response.persistentConnection, isFalse);
      final upstream = await harness.source.requestAt(1);
      expect(upstream.completed, isFalse);
      expect(harness.budget.occupiedSlots, 1);

      upstream.complete();
      expect(await _collect(response), _bytes(7, 12));
      await _waitForIdle(harness.budget);
    });

    test(
        'Given an old connection holds all slots, when seek opens a new Range, then headers unblock switching',
        () async {
      final harness = await _Harness.open(6 * _chunk);
      addTearDown(harness.close);
      final oldClient = harness.client();
      final oldRequest = await oldClient.getUrl(harness.uri);
      oldRequest.headers
          .set(HttpHeaders.rangeHeader, 'bytes=0-${3 * _chunk - 1}');
      final oldResponse = await oldRequest.close().timeout(_deadline);
      final oldBody = oldResponse.drain<void>().catchError((Object _) {});
      await harness.source.requestAt(3);
      expect(harness.budget.occupiedSlots, 3);
      final oldUpstream = harness.source.requests.skip(1).toList();

      final newRequest = await harness.client().getUrl(harness.uri);
      newRequest.headers.set(
          HttpHeaders.rangeHeader, 'bytes=${3 * _chunk}-${3 * _chunk + 15}');
      final newResponse = await newRequest.close().timeout(_deadline);
      expect(newResponse.statusCode, 206);
      expect(newResponse.headers.value(HttpHeaders.contentRangeHeader),
          'bytes ${3 * _chunk}-${3 * _chunk + 15}/${6 * _chunk}');
      expect(harness.source.requests, hasLength(4));
      expect(harness.budget.occupiedSlots, 3);

      // FFmpeg can now close its previous request after accepting new headers.
      oldClient.close(force: true);
      await Future.wait(oldUpstream.map((request) => request.cancelled.future))
          .timeout(_deadline);
      await oldBody.timeout(_deadline);
      final newUpstream = await harness.source.requestAt(4);
      expect(newUpstream.start, 3 * _chunk);
      expect(newUpstream.end, 3 * _chunk + 15);
      newUpstream.complete();
      expect(await _collect(newResponse), _bytes(3 * _chunk, 16));
      expect(harness.budget.peakOccupiedSlots, 3);
      await _waitForIdle(harness.budget);
      expect(harness.errors, isEmpty);
    });

    test(
        'Given a client disconnects before body data, when socket closes, then cancels CDN and releases all slots',
        () async {
      final harness = await _Harness.open(3 * _chunk);
      addTearDown(harness.close);
      final client = harness.client();
      final response =
          await (await client.getUrl(harness.uri)).close().timeout(_deadline);
      final body = response.drain<void>().catchError((Object _) {});
      await harness.source.requestAt(3);
      final upstream = harness.source.requests.skip(1).toList();
      client.close(force: true);

      await Future.wait(upstream.map((request) => request.cancelled.future))
          .timeout(_deadline);
      await body.timeout(_deadline);
      await Future<void>(() {});
      expect(upstream.every((request) => request.token.isCancelled), isTrue);
      await _waitForIdle(harness.budget);
      expect(harness.errors, isEmpty);
    });

    test(
        'Given CDN fails after headers, when streaming, then terminates the response body',
        () async {
      final harness = await _Harness.open(128);
      addTearDown(harness.close);
      final request = await harness.client().getUrl(harness.uri);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=10-19');
      final response = await request.close().timeout(_deadline);
      expect(response.statusCode, 206);
      expect(response.contentLength, 10);
      final body =
          expectLater(_collect(response), throwsA(isA<HttpException>()));
      final upstream = await harness.source.requestAt(1);
      upstream.body.addError(StateError('Simulated CDN connection failure'));

      await body.timeout(_deadline);
      expect(harness.errors, hasLength(1));
      expect(harness.errors.single, isA<CdnRangeFailure>());
      await _waitForIdle(harness.budget);
    });

    test(
        'Given detached media sockets remain active, when service closes, then aborts connections and frees slots',
        () async {
      final harness = await _Harness.open(3 * _chunk);
      addTearDown(harness.close);
      final response = await (await harness.client().getUrl(harness.uri))
          .close()
          .timeout(_deadline);
      final bodyEnded =
          expectLater(_collect(response), throwsA(isA<HttpException>()));
      await harness.source.requestAt(3);
      expect(harness.budget.occupiedSlots, 3);

      await harness.service.close().timeout(_deadline);
      await bodyEnded.timeout(_deadline);
      expect(
          harness.source.requests
              .skip(1)
              .every((request) => request.token.isCancelled),
          isTrue);
      await _waitForIdle(harness.budget);
      expect(harness.errors, isEmpty);
    });

    for (final failureFirst in [true, false]) {
      test(
          'Given CDN failure and client disconnect race (failureFirst=$failureFirst), then cleanup has no uncaught errors',
          () async {
        final harness = await _Harness.open(128);
        addTearDown(harness.close);
        final client = harness.client();
        final response =
            await (await client.getUrl(harness.uri)).close().timeout(_deadline);
        final bodyEnded = response.drain<void>().catchError((Object _) {});
        final upstream = await harness.source.requestAt(1);
        if (failureFirst) {
          upstream.body.addError(StateError('Concurrent upstream failure'));
          client.close(force: true);
        } else {
          client.close(force: true);
          upstream.body.addError(StateError('Concurrent upstream failure'));
        }

        await upstream.cancelled.future.timeout(_deadline);
        await bodyEnded.timeout(_deadline);
        await harness.service.close().timeout(_deadline);
        await _waitForIdle(harness.budget);
        expect(harness.errors.length, lessThanOrEqualTo(1));
        expect(
            harness.errors.every((error) => error is CdnRangeFailure), isTrue);
      });
    }
  });
}

// A client can finish reading Content-Length before the server's final socket
// flush callback runs. Wait for that observable state, with a strict deadline,
// instead of assuming which socket callback the OS schedules first.
Future<void> _waitForIdle(CdnRangeBudget budget) async {
  final deadline = DateTime.now().add(_deadline);
  while (budget.occupiedSlots != 0) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('CDN budget did not return to zero', _deadline);
    }
    await Future<void>(() {});
  }
}

Future<List<int>> _collect(HttpClientResponse response) =>
    response.fold<List<int>>(
        <int>[], (bytes, data) => bytes..addAll(data)).timeout(_deadline);

Uint8List _bytes(int start, int length) =>
    Uint8List.fromList(List.generate(length, (index) => (start + index) % 251));

class _Harness {
  _Harness(this.source, this.budget, this.errors, this.service, this.uri);
  final _FakeCdn source;
  final CdnRangeBudget budget;
  final List<Object> errors;
  final QuarkCdnRangeService service;
  final Uri uri;
  final _clients = <HttpClient>[];

  static Future<_Harness> open(int total, {bool autoRespond = false}) async {
    final source = _FakeCdn(total, autoRespond: autoRespond);
    final budget = CdnRangeBudget();
    final errors = <Object>[];
    final service = QuarkCdnRangeService(
        source: source, budget: budget, onError: errors.add);
    final uri = await service.open(
        uri: Uri.parse('https://cdn.invalid/media.mp4'),
        headers: const {'cookie': 'fake=value'}).timeout(_deadline);
    return _Harness(source, budget, errors, service, uri);
  }

  HttpClient client() {
    final client = HttpClient()..connectionTimeout = _deadline;
    _clients.add(client);
    return client;
  }

  Future<void> close() async {
    for (final client in _clients) {
      client.close(force: true);
    }
    await service.close().timeout(_deadline);
  }
}

class _FakeCdn implements CdnRangeSource {
  _FakeCdn(this.total, {required this.autoRespond});
  final int total;
  final bool autoRespond;
  final requests = <_FakeRequest>[];
  final _waiters = <(int, Completer<_FakeRequest>)>[];

  Future<_FakeRequest> requestAt(int index) {
    if (requests.length > index) return Future.value(requests[index]);
    final completer = Completer<_FakeRequest>();
    _waiters.add((index, completer));
    return completer.future.timeout(_deadline);
  }

  @override
  Future<ApiResult<CdnRangeResponse>> open(
      {required Uri uri,
      required Map<String, String> headers,
      required int start,
      required int end,
      required CancelToken cancelToken}) async {
    final probe = requests.isEmpty;
    final request = _FakeRequest(start, end, cancelToken);
    requests.add(request);
    for (final waiter in _waiters.toList()) {
      if (requests.length > waiter.$1) {
        _waiters.remove(waiter);
        waiter.$2.complete(requests[waiter.$1]);
      }
    }
    if (probe || autoRespond) request.complete(empty: total == 0);
    return Success(CdnRangeResponse(
      statusCode: total == 0 ? 416 : 206,
      headers: {
        'content-range': [
          total == 0 ? 'bytes */0' : 'bytes $start-$end/$total'
        ],
        'content-length': ['${end - start + 1}'],
        'content-type': ['video/mp4'],
      },
      stream: request.body.stream,
    ));
  }

  @override
  void close() {
    for (final request in requests) {
      request.token.cancel('Fake source closed');
    }
  }
}

class _FakeRequest {
  _FakeRequest(this.start, this.end, this.token) {
    unawaited(token.whenCancel.then((_) {
      if (!cancelled.isCompleted) cancelled.complete();
      if (!body.isClosed) unawaited(body.close());
    }));
  }
  final int start;
  final int end;
  final CancelToken token;
  final cancelled = Completer<void>();
  final body = StreamController<Uint8List>();
  bool completed = false;

  void complete({bool empty = false}) {
    completed = true;
    if (!empty) body.add(_bytes(start, end - start + 1));
    unawaited(body.close());
  }
}
