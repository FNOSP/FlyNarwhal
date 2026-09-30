import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_cancellation.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_http_range_source.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_constants.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_errors.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_service.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_diagnostics.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_policy.dart';

import '../../../../tool/support/cdn_proxy_http_fixture.dart';

const _chunk = CdnProxyDefaults.chunkSize;
const _deadline = Duration(seconds: 5);

void main() {
  test('Given a source, HTTP requests preserve Range and HEAD semantics',
      () async {
    final proxy = await _proxy(length: 100);
    for (final item in [
      ('GET', null, 200, 0, 100),
      ('GET', 'bytes=12-29', 206, 12, 18),
      ('GET', 'bytes=-7', 206, 93, 7),
      ('GET', 'bytes=99-', 206, 99, 1),
      ('GET', 'bytes=100-', 416, 0, 0),
      ('GET', 'bytes=0-1,4-5', 416, 0, 0),
      ('HEAD', null, 200, 0, 0),
    ]) {
      final response = await proxy.get(range: item.$2, method: item.$1);
      expect(response.statusCode, item.$3);
      if (item.$3 == 206) {
        expect(response.headers.value(HttpHeaders.contentRangeHeader),
            'bytes ${item.$4}-${item.$4 + item.$5 - 1}/100');
      }
      expect(await _Download(response, item.$4).done, item.$5);
    }
    await _released(proxy);
    expect(proxy.fixture.requests.first.start, 0);
    expect(proxy.fixture.requests.first.end, 0);
  });

  test('Given metadata rejection, open fails once without retaining resources',
      () async {
    final proxy = await _proxy(
        initialize: false,
        handle: (request, entry) async {
          await _reject(request.response, 403);
          return true;
        });
    await expectLater(proxy.open(), throwsA(isA<CdnRangeFailure>()));
    await proxy.service.close().timeout(_deadline);
    expect(proxy.fixture.requests, hasLength(1));
    expect(proxy.errors, [isA<CdnRangeFailure>()]);
    await _released(proxy);
  });

  test('Given a selected byte range, OpenList splits cover it without gaps',
      () {
    for (final item in [
      (7, [7]),
      (_chunk, [_chunk]),
      (2 * _chunk, [_chunk, _chunk]),
      (23 * 1024 * 1024, [5, 8, 10].map((v) => v * 1024 * 1024).toList()),
      (26 * 1024 * 1024, [6, 10, 10].map((v) => v * 1024 * 1024).toList()),
    ]) {
      final parts =
          splitCdnRange(CdnByteRange(start: 37, end: 36 + item.$1)).toList();
      expect(parts.map((part) => part.length), item.$2);
      var next = 37;
      for (final part in parts) {
        expect(part.start, next);
        next = part.end + 1;
      }
      expect(next, 37 + item.$1);
    }
  });

  test('Given slow first bytes, output streams in order within three buffers',
      () async {
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    final proxy = await _proxy(
        length: 4 * _chunk,
        handle: (request, entry) async {
          if (entry.start == 0 && entry.length > 1) {
            await entry.write(request.response, 65536);
            await release.future;
          }
          return false;
        });
    final response = await proxy.get();
    final download = _Download(response, 0);
    await download.firstBytes.future.timeout(_deadline);
    await _until(() =>
        proxy.fixture.requests
            .where((e) => e.length > 1 && e.completedAt != null)
            .length ==
        2);
    expect(release.isCompleted, isFalse);
    expect(download.received, greaterThan(0));
    expect(download.received, lessThan(_chunk));
    expect(proxy.fixture.requests.where((e) => e.length > 1), hasLength(3));
    expect(proxy.service.allocatedChunkCount, 3);
    expect(proxy.service.allocatedBufferBytes, lessThanOrEqualTo(3 * _chunk));
    release.complete();
    expect(await download.done, 4 * _chunk);
    expect(proxy.service.peakAllocatedChunkCount, 3);
    await _released(proxy);
  });

  test(
      'Given interrupted bodies, the same HTTP response resumes exact suffixes',
      () async {
    var interrupted = 0;
    final proxy = await _proxy(
        length: 2 * _chunk,
        handle: (request, entry) async {
          if (entry.end == _chunk - 1 && interrupted < 2) {
            await entry.disconnect(
                request.response, interrupted++ == 0 ? 17 : 31);
            return true;
          }
          return false;
        });
    expect(await _Download(await proxy.get(), 0).done, 2 * _chunk);
    expect(
        proxy.fixture.requests
            .where((e) => e.end == _chunk - 1)
            .map((e) => e.start),
        [0, 17, 48]);
    expect(
        proxy.fixture.requests
            .where((e) => e.length > 1)
            .fold<int>(0, (sum, e) => sum + e.sentBytes),
        2 * _chunk);
    expect(proxy.errors, isEmpty);
    await _released(proxy);
  });

  test('Given HTTP then body failures, the first chunk shares a finite budget',
      () async {
    var attempts = 0;
    final proxy = await _proxy(
        length: 2 * _chunk,
        handle: (request, entry) async {
          if (entry.end != _chunk - 1) return false;
          if (++attempts == 1) {
            await _reject(request.response, 503);
          } else {
            await entry.disconnect(request.response, 11);
          }
          return true;
        });
    await expectLater(
        _Download(await proxy.get(), 0).done, throwsA(isA<HttpException>()));
    expect(attempts, 4);
    expect(proxy.errors, isEmpty);
    await _released(proxy);
  });

  test(
      'Given a small read fails, it ends without retry and later reads still work',
      () async {
    final proxy = await _proxy(handle: (request, entry) async {
      if (entry.start == 10) {
        await entry.disconnect(request.response, 5);
        return true;
      }
      return false;
    });
    await expectLater(_Download(await proxy.get(range: 'bytes=10-29'), 10).done,
        throwsA(isA<HttpException>()));
    expect(proxy.fixture.requests.where((e) => e.start == 10), hasLength(1));
    expect(await _Download(await proxy.get(range: 'bytes=40-59'), 40).done, 20);
    expect(proxy.errors, isEmpty);
    await _released(proxy);
  });

  for (final status in [403, 416]) {
    test('Given first-chunk HTTP $status, playback does not retry it',
        () async {
      final proxy = await _proxy(
          length: 2 * _chunk,
          handle: (request, entry) async {
            if (entry.length == 1) return false;
            await _reject(request.response, status);
            return true;
          });
      await expectLater(
          _Download(await proxy.get(), 0).done, throwsA(isA<HttpException>()));
      expect(proxy.fixture.requests, hasLength(2));
      await _released(proxy);
    });
  }

  for (final recover in [true, false]) {
    test(
        'Given later HTTP failures, retry can ${recover ? 'recover' : 'be cancelled'} beyond four attempts',
        () async {
      var attempts = 0;
      final retries = Completer<void>();
      final proxy = await _proxy(
          length: 2 * _chunk,
          handle: (request, entry) async {
            if (entry.start != _chunk) return false;
            attempts++;
            if (attempts == 5) retries.complete();
            if (recover && attempts > 5) return false;
            await _reject(request.response, 503);
            return true;
          });
      final download = _Download(await proxy.get(), 0);
      if (recover) {
        expect(await download.done, 2 * _chunk);
        expect(attempts, 6);
      } else {
        final stopped =
            expectLater(download.done, throwsA(isA<HttpException>()));
        await retries.future.timeout(_deadline);
        await proxy.service.close().timeout(_deadline);
        await stopped;
      }
      expect(proxy.errors, isEmpty);
      await _released(proxy);
    });
  }

  for (final change in ['ETag', 'total length']) {
    test(
        'Given resource $change changes, all readers end with one source failure',
        () async {
      final held = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final proxy = await _proxy(handle: (request, entry) async {
        request.response.headers.set(HttpHeaders.etagHeader,
            entry.start == 64 && change == 'ETag' ? '"changed"' : '"original"');
        if (entry.start == 64 && change == 'total length') {
          request.response.headers.set(HttpHeaders.contentRangeHeader,
              'bytes ${entry.start}-${entry.end}/129');
        }
        if (entry.start == 0 && entry.end == 63) {
          await entry.write(request.response, 17);
          held.complete();
          await release.future;
        }
        return false;
      });
      final first = _Download(await proxy.get(range: 'bytes=0-63'), 0);
      final firstEnded = expectLater(first.done, throwsA(isA<HttpException>()));
      await held.future.timeout(_deadline);
      final changed = _Download(await proxy.get(range: 'bytes=64-95'), 64);
      await expectLater(changed.done, throwsA(isA<HttpException>()));
      await firstEnded;
      expect(proxy.errors, [isA<CdnResourceChanged>()]);
      expect(
          proxy.fixture.requests
              .skip(1)
              .every((e) => e.requestHeaders['if-range'] == '"original"'),
          isTrue);
      await proxy.service.close().timeout(_deadline);
      release.complete();
      await _released(proxy);
    });
  }

  test(
      'Given an unfinished read, seek and an unrelated failed Range stay independent',
      () async {
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    final proxy = await _proxy(
        length: 4 * _chunk,
        handle: (request, entry) async {
          if (entry.start == 0 && entry.end == _chunk - 1) {
            await entry.write(request.response, 17);
            await release.future;
          }
          if (entry.start == 3 * _chunk + 100) {
            await _reject(request.response, 403);
            return true;
          }
          return false;
        });
    final oldClient = HttpClient();
    addTearDown(() => oldClient.close(force: true));
    final old = _Download(
        await proxy.get(range: 'bytes=0-${3 * _chunk - 1}', client: oldClient),
        0);
    final oldEnded = expectLater(old.done, throwsA(isA<HttpException>()));
    await old.firstBytes.future.timeout(_deadline);
    expect(
        await _Download(
                await proxy.get(
                    range: 'bytes=${3 * _chunk + 10}-${3 * _chunk + 29}'),
                3 * _chunk + 10)
            .done,
        20);
    await expectLater(
        _Download(
                await proxy.get(
                    range: 'bytes=${3 * _chunk + 100}-${3 * _chunk + 119}'),
                3 * _chunk + 100)
            .done,
        throwsA(isA<HttpException>()));
    expect(proxy.errors, isEmpty);
    expect(proxy.service.allocatedChunkCount, greaterThan(0));
    oldClient.close(force: true);
    await oldEnded;
    release.complete();
    await _released(proxy);
    expect(await _Download(await proxy.get(range: 'bytes=40-59'), 40).done, 20);
  });

  for (final metadata in [true, false]) {
    test(
        'Given pending ${metadata ? 'metadata' : 'body'}, exit releases it and a new source plays',
        () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final proxy = await _proxy(
          initialize: false,
          handle: (request, entry) async {
            if ((entry.length == 1) == metadata) {
              entered.complete();
              await release.future;
            }
            return false;
          });
      late Future<void> stopped;
      if (metadata) {
        stopped = expectLater(proxy.open(), throwsA(isA<CdnRangeCancelled>()));
      } else {
        await proxy.open();
        stopped = expectLater(_Download(await proxy.get(), 0).done,
            throwsA(isA<HttpException>()));
      }
      await entered.future.timeout(_deadline);
      await proxy.service.close().timeout(_deadline);
      await proxy.service.close().timeout(_deadline);
      await stopped;
      await _released(proxy);
      final replacement = await _proxy();
      expect(
          await _Download(await replacement.get(range: 'bytes=10-29'), 10).done,
          20);
      release.complete();
    });
  }

  test('Given a real stopped client, close does not need the client to resume',
      () async {
    final proxy = await _proxy(length: 12 * _chunk);
    final response = await proxy.get();
    final paused = Completer<void>();
    late StreamSubscription<List<int>> subscription;
    subscription = response.listen((_) {
      subscription.pause();
      if (!paused.isCompleted) paused.complete();
    }, onError: (Object _) {});
    await paused.future.timeout(_deadline);
    await proxy.service.close().timeout(_deadline);
    expect(subscription.isPaused, isTrue);
    await _released(proxy);
    await subscription.cancel();
  });

  test(
      'Given a hung flush, close releases writers and absorbs a late socket error',
      () async {
    final flushing = Completer<void>();
    final entered = Completer<void>();
    final proxy = await _proxy(
        length: 3 * _chunk,
        socketFlush: (_) {
          if (!entered.isCompleted) entered.complete();
          return flushing.future;
        });
    final body = _Download(await proxy.get(), 0);
    final stopped = expectLater(body.done, throwsA(isA<HttpException>()));
    await entered.future.timeout(_deadline);
    await proxy.service.close().timeout(_deadline);
    await proxy.service.close().timeout(_deadline);
    await stopped;
    expect(flushing.isCompleted, isFalse);
    await _released(proxy);
    final replacement = await _proxy();
    expect(await _Download(await replacement.get(), 0).done, 128);
    flushing.completeError(const SocketException('late flush failure'));
    await Future<void>(() {});
    expect(proxy.errors, isEmpty);
  });

  test(
      'Completed waits release cancellation listeners and late errors stay observed',
      () async {
    final cancellation = CdnCancellation();
    for (var i = 0; i < 100; i++) {
      expect(await cancellation.wait(Future.value(i)), i);
      await expectLater(
          cancellation.wait(Future<int>.error(const SocketException('reset'))),
          throwsA(isA<SocketException>()));
    }
    expect(cancellation.listenerCount, 0);
    final pending = Completer<int>();
    final stopped = expectLater(
        cancellation.wait(pending.future), throwsA(isA<CdnRangeCancelled>()));
    cancellation.cancel();
    cancellation.cancel();
    await stopped;
    expect(cancellation.listenerCount, 0);
    pending.completeError(const SocketException('late result'));

    await Future<void>(() {});
  });

  test('Diagnostic failures retain safe codes without URLs or credentials', () {
    final messages = <String>[];
    final diagnostics = CdnRangeDiagnostics(
        writeLog: (message, {required failure}) => messages.add(message));
    const secret = 'https://private.invalid/media?token=secret Cookie=private';
    for (var i = 0; i < 40; i++) {
      final trace = diagnostics.begin(start: i, end: i, probe: false)
        ..failed(
            const SocketException(secret, osError: OSError(secret, 10054)));
      diagnostics.finish(trace, 'failed');
    }
    diagnostics.failed(allocatedChunkCount: 0, activeReaders: 0);
    diagnostics.failed(allocatedChunkCount: 0, activeReaders: 0);
    expect(messages, hasLength(1));
    expect(messages.single, isNot(contains('private')));
    expect(messages.single, isNot(contains('secret')));
    final event = jsonDecode(messages.single) as Map<String, dynamic>;
    expect(event['recentChunks'], hasLength(32));
    expect((event['recentChunks'] as List).last['error']['osErrorCode'], 10054);
  });
}

Future<void> _reject(HttpResponse response, int status) async {
  response.statusCode = status;
  response.contentLength = 0;
  await response.close();
}

Future<_Proxy> _proxy({
  int length = 128,
  bool initialize = true,
  Future<bool> Function(HttpRequest, CdnFixtureRequest)? handle,
  Future<void> Function(Socket)? socketFlush,
}) async {
  final fixture = await CdnHttpFixture.start(length: length, handle: handle);
  final proxy = _Proxy(fixture, socketFlush);
  addTearDown(proxy.close);
  if (initialize) await proxy.open();
  return proxy;
}

class _Proxy {
  _Proxy(this.fixture, Future<void> Function(Socket)? socketFlush) {
    service = CdnProxyService(
        source: source,
        onError: errors.add,
        retryJitter: () => Duration.zero,
        socketFlush: socketFlush);
  }
  final CdnHttpFixture fixture;
  final source = CdnHttpRangeSource();
  final errors = <Object>[];
  final client = HttpClient();
  late final CdnProxyService service;
  late Uri uri;
  Future<void> open() async {
    uri = await service.open(uri: fixture.uri, headers: const {});
  }

  Future<HttpClientResponse> get(
      {String? range, String method = 'GET', HttpClient? client}) async {
    final request = await (client ?? this.client).openUrl(method, uri);
    if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
    return request.close().timeout(_deadline);
  }

  Future<void> close() async {
    client.close(force: true);
    try {
      await service.close().timeout(_deadline);
    } finally {
      await fixture.close();
    }
  }
}

class _Download {
  _Download(HttpClientResponse response, int offset) {
    done = response.forEach((bytes) {
      for (var i = 0; i < bytes.length; i++) {
        if (bytes[i] != fixtureByteAt(offset + received + i)) {
          fail('Incorrect byte at ${offset + received + i}');
        }
      }
      received += bytes.length;
      if (!firstBytes.isCompleted) firstBytes.complete();
    }).then((_) => received);
  }
  final firstBytes = Completer<void>();
  late final Future<int> done;
  int received = 0;
}

Future<void> _until(bool Function() condition) async {
  final deadline = Stopwatch()..start();
  while (!condition()) {
    if (deadline.elapsed >= _deadline) {
      fail('HTTP fixture did not reach the expected state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Future<void> _released(_Proxy proxy) async {
  await _until(() =>
      proxy.service.activeWriterCount == 0 &&
      proxy.service.activeDownloadCount == 0 &&
      proxy.source.activeAttemptCount == 0);
  expect([
    proxy.service.allocatedChunkCount,
    proxy.service.allocatedBufferBytes,
    proxy.service.bufferedBytes
  ], [
    0,
    0,
    0
  ]);
}
