import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_errors.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_source.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_constants.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_service.dart';

const _deadline = Duration(seconds: 4);
const _chunk = CdnProxyDefaults.chunkSize;

void main() {
  test(
      'Given an unopened service whose source close throws, then repeated close shares one safe failure',
      () async {
    final source = _FakeCdn(100,
        autoRespond: false,
        closeFailure: StateError('Private source close Cookie=secret'));
    final service = CdnProxyService(source: source);
    addTearDown(() async => _closeError(service.close()));
    final closing = service.close();
    expect(identical(closing, service.close()), isTrue);
    final failure = await _closeError(closing).timeout(_deadline);
    expect(
        failure,
        isA<CdnRangeFailure>()
            .having((error) => error.message, 'message', 'CDN 代理资源清理失败'));
    expect(identical(closing, service.close()), isTrue);
    expect(await _closeError(service.close()), same(failure));
    expect(source.closeCount, 1);
    expect(source.requests, isEmpty);
    expect(service.activeWriterCount, 0);
    expect(service.activeDownloadCount, 0);
    expect(service.allocatedChunkCount, 0);
    expect(service.allocatedBufferBytes, 0);
    expect(service.bufferedBytes, 0);
  });

  test(
      'Given initialization fails while callback and source close throw, then open preserves its original failure',
      () async {
    const original = CdnRangeFailure('Safe metadata failure');
    final source = _FakeCdn(100,
        autoRespond: false,
        openingFailure: original,
        closeFailure: StateError('Private close signature=secret'));
    final notifications = <Object>[];
    final service = CdnProxyService(
        source: source,
        onError: (error) {
          notifications.add(error);
          throw StateError('Private callback Cookie=secret');
        });
    addTearDown(() async => _closeError(service.close()));
    await expectLater(
        service.open(
            uri: Uri.parse('https://cdn.invalid/media.mp4'), headers: const {}),
        throwsA(same(original)));
    expect(notifications, [same(original)]);
    final closing = service.close();
    expect(identical(closing, service.close()), isTrue);
    final failure = await _closeError(closing).timeout(_deadline);
    expect(
        failure,
        isA<CdnRangeFailure>()
            .having((error) => error.message, 'message', 'CDN 代理资源清理失败'));
    expect(source.closeCount, 1);
    expect(service.activeWriterCount, 0);
    expect(service.activeDownloadCount, 0);
    expect(service.allocatedChunkCount, 0);
    expect(service.allocatedBufferBytes, 0);
    expect(service.bufferedBytes, 0);
  });

  test(
      'Given an active writer and throwing source close, then close waits for delayed body cancellation before reporting safely',
      () async {
    final releaseCancellation = Completer<void>();
    final source = _FakeCdn(100,
        autoRespond: false,
        bodyCancellationGate: releaseCancellation.future,
        closeFailure: StateError('Private source close signature=secret'));
    final service = CdnProxyService(source: source);
    final client = HttpClient();
    addTearDown(() async {
      if (!releaseCancellation.isCompleted) releaseCancellation.complete();
      client.close(force: true);
      await _closeError(service.close());
    });
    final uri = await service.open(
        uri: Uri.parse('https://cdn.invalid/media.mp4'), headers: const {});
    final response =
        await (await client.getUrl(uri)).close().timeout(_deadline);
    final prefixReceived = Completer<void>();
    final received = <int>[];
    final bodyEnded = response
        .map((bytes) {
          received.addAll(bytes);
          if (received.length >= 16 && !prefixReceived.isCompleted) {
            prefixReceived.complete();
          }
          return bytes;
        })
        .drain<void>()
        .then<void>((_) {}, onError: (Object _) {});
    final upstream = await source.requestAt(1);
    // Headers and request registration alone do not prove that _consume owns
    // this body. Observe a real prefix before testing delayed cancellation.
    upstream.body.add(_bytes(upstream.start, 16));
    await prefixReceived.future.timeout(_deadline);
    expect(received, _bytes(upstream.start, 16));
    expect(upstream.bodyCancellationStarted.isCompleted, isFalse);
    expect(service.activeWriterCount, 1);
    final closing = service.close();
    expect(identical(closing, service.close()), isTrue);
    var completed = false;
    final outcome = _closeError(closing).then((error) {
      completed = true;
      return error;
    });
    await upstream.bodyCancellationStarted.future.timeout(_deadline);
    await Future<void>(() {});
    expect(completed, isFalse);
    expect(service.allocatedChunkCount, 1);
    expect(source.closeCount, 1);

    releaseCancellation.complete();
    final failure = await outcome.timeout(_deadline);
    expect(
        failure,
        isA<CdnRangeFailure>()
            .having((error) => error.message, 'message', 'CDN 代理资源清理失败'));
    await bodyEnded.timeout(_deadline);
    expect(identical(closing, service.close()), isTrue);
    expect(await _closeError(service.close()), same(failure));
    expect(source.closeCount, 1);
    expect(service.activeWriterCount, 0);
    expect(service.activeDownloadCount, 0);
    expect(service.allocatedChunkCount, 0);
    expect(service.allocatedBufferBytes, 0);
    expect(service.bufferedBytes, 0);
  });

  group('CdnProxyService actual loopback HTTP', () {
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
        await _waitForIdle(harness.service);
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
      expect(harness.service.allocatedChunkCount, 1);

      upstream.complete();
      expect(await _collect(response), _bytes(7, 12));
      await _waitForIdle(harness.service);
    });

    test(
        'Given an old reader holds three buffers, when seek opens a new Range, then the new reader completes independently',
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
      expect(harness.service.allocatedChunkCount, 3);
      final oldUpstream = harness.source.requests.skip(1).toList();

      final newRequest = await harness.client().getUrl(harness.uri);
      newRequest.headers.set(
          HttpHeaders.rangeHeader, 'bytes=${3 * _chunk}-${3 * _chunk + 15}');
      final newResponse = await newRequest.close().timeout(_deadline);
      expect(newResponse.statusCode, 206);
      expect(newResponse.headers.value(HttpHeaders.contentRangeHeader),
          'bytes ${3 * _chunk}-${3 * _chunk + 15}/${6 * _chunk}');
      final newUpstream = await harness.source.requestAt(4);
      expect(harness.source.requests, hasLength(5));
      expect(harness.service.allocatedChunkCount, 4);
      expect(newUpstream.start, 3 * _chunk);
      expect(newUpstream.end, 3 * _chunk + 15);

      // A seek must receive its body while the previous reader stays connected.
      newUpstream.complete();
      expect(await _collect(newResponse), _bytes(3 * _chunk, 16));
      await _waitForWriters(harness.service, 1);
      expect(harness.service.allocatedChunkCount, 3);
      expect(harness.service.peakAllocatedChunkCount, 4);
      expect(
          oldUpstream.every(
              (request) => !request.completed && !request.token.isCancelled),
          isTrue);

      oldClient.close(force: true);
      await Future.wait(oldUpstream.map((request) => request.cancelled.future))
          .timeout(_deadline);
      await oldBody.timeout(_deadline);
      await _waitForIdle(harness.service);
      expect(harness.errors, isEmpty);
    });

    test(
        'Given a client disconnects before body data, when socket closes, then cancels CDN and releases its buffers',
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
      await _waitForIdle(harness.service);
      expect(harness.errors, isEmpty);
    });

    test(
        'Given a multi-part body disconnect, then resumes the suffix in the same HTTP response',
        () async {
      final harness = await _Harness.open(2 * _chunk);
      addTearDown(harness.close);
      final request = await harness.client().getUrl(harness.uri);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=10-${_chunk + 19}');
      final response = await request.close().timeout(_deadline);
      final received = _collect(response);
      final first = await harness.source.requestAt(1);
      final second = await harness.source.requestAt(2);
      second.complete();
      first.body.add(_bytes(10, 2));
      first.body.addError(const SocketException('CDN body interrupted'));

      final retry = await harness.source.requestAt(3);
      expect(first.token.isCancelled, isTrue);
      expect((retry.start, retry.end), (12, 10 + _chunk ~/ 2 - 1));
      expect(harness.errors, isEmpty);
      retry.complete();
      expect(await received, _bytes(10, _chunk + 10));
      expect(response.statusCode, 206);
      expect(harness.errors, isEmpty);
      await _waitForIdle(harness.service);
    });

    test(
        'Given a single Range body fails, when the client disconnects, then no retry occurs and its buffer is freed',
        () async {
      final harness = await _Harness.open(128);
      addTearDown(harness.close);
      final client = harness.client();
      final request = await client.getUrl(harness.uri);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=10-19');
      final response = await request.close().timeout(_deadline);
      final bodyEnded = response.drain<void>().catchError((Object _) {});
      final first = await harness.source.requestAt(1);
      first.body.addError(TimeoutException('CDN body stalled'));
      await first.cancelled.future.timeout(_deadline);

      client.close(force: true);
      await bodyEnded.timeout(_deadline);
      await _waitForIdle(harness.service);
      expect(harness.source.requests, hasLength(2));
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
      expect(harness.errors, isEmpty);
      await _waitForIdle(harness.service);
    });

    test(
        'Given detached media sockets remain active, when service closes, then aborts connections and frees buffers',
        () async {
      final harness = await _Harness.open(3 * _chunk);
      addTearDown(harness.close);
      final response = await (await harness.client().getUrl(harness.uri))
          .close()
          .timeout(_deadline);
      final bodyEnded =
          expectLater(_collect(response), throwsA(isA<HttpException>()));
      await harness.source.requestAt(3);
      expect(harness.service.allocatedChunkCount, 3);

      await harness.service.close().timeout(_deadline);
      await bodyEnded.timeout(_deadline);
      expect(
          harness.source.requests
              .skip(1)
              .every((request) => request.token.isCancelled),
          isTrue);
      await _waitForIdle(harness.service);
      expect(harness.errors, isEmpty);
    });

    test(
        'Given a real stopped reader, when service closes, then releases its reader buffers',
        () async {
      final harness = await _Harness.open(6 * _chunk);
      addTearDown(harness.close);
      final socket =
          await RawSocket.connect(harness.uri.host, harness.uri.port);
      addTearDown(socket.close);
      socket.setRawOption(RawSocketOption.fromInt(
          RawSocketOption.levelSocket, Platform.isLinux ? 8 : 0x1002, 1024));
      final headersReceived = Completer<void>();
      var headers = '';
      final incoming = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final bytes = socket.read();
        if (bytes == null) return;
        headers += String.fromCharCodes(bytes);
        if (headers.contains('\r\n\r\n') && !headersReceived.isCompleted) {
          socket.readEventsEnabled = false;
          headersReceived.complete();
        }
      });
      addTearDown(incoming.cancel);
      final request = 'GET ${harness.uri.path} HTTP/1.1\r\n'
          'Host: ${harness.uri.host}\r\nConnection: close\r\n\r\n';
      expect(socket.write(request.codeUnits), request.length);
      await headersReceived.future.timeout(_deadline);
      await harness.source.requestAt(3);
      final upstream = harness.source.requests.skip(1).toList();
      for (final request in upstream) {
        request.complete();
      }
      await Future.wait(upstream.map((request) => request.body.done))
          .timeout(_deadline);
      expect(harness.service.allocatedChunkCount, 3);
      expect(harness.service.activeWriterCount, 1);
      await harness.service.close().timeout(_deadline);
      expect(harness.service.activeWriterCount, 0);
      expect(harness.service.allocatedChunkCount, 0);
      expect(harness.errors, isEmpty);
    });
    for (final lateDetachError in [false, true]) {
      test(
          'Given socket ownership is pending, when service closes, then handles its late result (lateDetachError=$lateDetachError)',
          () async {
        final detached = Completer<Socket>();
        final releaseSocket = Completer<void>();
        final harness = await _Harness.open(128,
            socketDetach: (response, writeHeaders) async {
          final socket =
              await response.detachSocket(writeHeaders: writeHeaders);
          detached.complete(socket);
          await releaseSocket.future;
          if (lateDetachError) {
            // A failing detacher retains responsibility for its own socket.
            socket.destroy();
            throw const SocketException('Late detach failure');
          }
          return socket;
        });
        addTearDown(harness.close);
        final response = await (await harness.client().getUrl(harness.uri))
            .close()
            .timeout(_deadline);
        final bodyEnded =
            expectLater(_collect(response), throwsA(isA<HttpException>()));
        await detached.future.timeout(_deadline);
        expect(harness.service.activeWriterCount, 1);

        await harness.service.close().timeout(_deadline);
        expect(harness.service.activeWriterCount, 0);
        expect(harness.service.allocatedChunkCount, 0);
        expect(harness.source.closeCount, 1);
        expect(harness.source.requests, hasLength(1));
        releaseSocket.complete();
        await bodyEnded.timeout(_deadline);
        await Future<void>(() {});
        expect(harness.service.activeWriterCount, 0);
        expect(harness.source.requests, hasLength(1));
        expect(harness.errors, isEmpty);
      });
    }
    for (final lateError in [false, true]) {
      test(
          'Given an unfinished flush, when close repeats, then joins writers and leaves replacement readers independent (lateError=$lateError)',
          () async {
        final flushStarted = Completer<void>();
        final flushing = Completer<void>();
        final harness = await _Harness.open(3 * _chunk, socketFlush: (_) {
          if (!flushStarted.isCompleted) flushStarted.complete();
          return flushing.future;
        });
        addTearDown(harness.close);
        final response = await (await harness.client().getUrl(harness.uri))
            .close()
            .timeout(_deadline);
        final bodyEnded = response.drain<void>().catchError((Object _) {});
        await harness.source.requestAt(3);
        harness.source.requests[1].complete();
        await flushStarted.future.timeout(_deadline);
        expect(harness.service.activeWriterCount, 1);
        expect(harness.service.allocatedChunkCount, 3);

        final firstClose = harness.service.close();
        expect(identical(firstClose, harness.service.close()), isTrue);
        await firstClose.timeout(_deadline);
        await bodyEnded.timeout(_deadline);
        expect(flushing.isCompleted, isFalse);
        expect(harness.service.activeWriterCount, 0);
        expect(harness.service.allocatedChunkCount, 0);
        expect(harness.source.closeCount, 1);
        expect(harness.source.requests, hasLength(4));
        expect(
            harness.source.requests
                .skip(1)
                .every((request) => request.token.isCancelled),
            isTrue);
        expect(harness.errors, isEmpty);

        // The closed service remains empty while a replacement independently
        // owns the buffers for its three simultaneous readers.
        final replacement = await _Harness.open(128);
        addTearDown(replacement.close);
        final responses = <HttpClientResponse>[];
        for (var index = 0; index < 3; index++) {
          final request = await replacement.client().getUrl(replacement.uri);
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$index-$index');
          responses.add(await request.close().timeout(_deadline));
        }
        await replacement.source.requestAt(3);
        expect(harness.service.allocatedChunkCount, 0);
        expect(replacement.service.allocatedChunkCount, 3);
        expect(replacement.service.peakAllocatedChunkCount, 3);
        for (final request in replacement.source.requests.skip(1)) {
          request.complete();
        }
        for (var index = 0; index < responses.length; index++) {
          expect(await _collect(responses[index]), [index]);
        }
        await _waitForIdle(replacement.service);
        await _waitForWriters(replacement.service, 0);
        expect(harness.service.allocatedChunkCount, 0);

        // A losing flush future can fail after its writer has been collected.
        // flutter_test fails this test if that late error escapes the zone.
        if (lateError) {
          flushing.completeError(StateError('Late downstream flush failure'));
        } else {
          flushing.complete();
        }
        await Future<void>(() {});
        expect(harness.service.activeWriterCount, 0);
        expect(harness.source.requests, hasLength(4));
      });
    }

    for (final flushFirst in [true, false]) {
      test(
          'Given flush completion and close race, then cleanup is idempotent (flushFirst=$flushFirst)',
          () async {
        final flushStarted = Completer<void>();
        final flushing = Completer<void>();
        final harness = await _Harness.open(128, socketFlush: (_) {
          if (!flushStarted.isCompleted) flushStarted.complete();
          return flushing.future;
        });
        addTearDown(harness.close);
        final request = await harness.client().getUrl(harness.uri);
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-9');
        final response = await request.close().timeout(_deadline);
        final bodyEnded = response.drain<void>().catchError((Object _) {});
        (await harness.source.requestAt(1)).complete();
        await flushStarted.future.timeout(_deadline);

        if (flushFirst) flushing.complete();
        final closing = harness.service.close();
        if (!flushFirst) flushing.complete();
        expect(identical(closing, harness.service.close()), isTrue);
        await closing.timeout(_deadline);
        await bodyEnded.timeout(_deadline);
        expect(harness.service.activeWriterCount, 0);
        expect(harness.service.allocatedChunkCount, 0);
        expect(harness.source.closeCount, 1);
        expect(harness.errors, isEmpty);
      });
    }

    test(
        'Given one writer is flushing, when another reader fails, then only the failed writer is cancelled',
        () async {
      final flushStarted = Completer<void>();
      final flushing = Completer<void>();
      final harness = await _Harness.open(3 * _chunk, socketFlush: (_) {
        if (!flushStarted.isCompleted) flushStarted.complete();
        return flushing.future;
      });
      addTearDown(harness.close);
      final first = await harness.client().getUrl(harness.uri);
      first.headers.set(HttpHeaders.rangeHeader, 'bytes=0-${2 * _chunk - 1}');
      final firstResponse = await first.close().timeout(_deadline);
      final firstEnded = firstResponse.drain<void>().catchError((Object _) {});
      (await harness.source.requestAt(1)).complete();
      await flushStarted.future.timeout(_deadline);
      final second = await harness.client().getUrl(harness.uri);
      second.headers.set(
          HttpHeaders.rangeHeader, 'bytes=${2 * _chunk}-${2 * _chunk + 9}');
      final secondResponse = await second.close().timeout(_deadline);
      final secondEnded =
          secondResponse.drain<void>().catchError((Object _) {});
      final failing = await harness.source.requestAt(3);
      expect(harness.service.activeWriterCount, 2);

      failing.body.addError(StateError('Terminal CDN failure'));
      await _waitForWriters(harness.service, 1);
      await secondEnded.timeout(_deadline);
      expect(flushing.isCompleted, isFalse);
      expect(harness.service.allocatedChunkCount, 2);
      expect(harness.errors, isEmpty);
      await harness.service.close().timeout(_deadline);
      await firstEnded.timeout(_deadline);
      expect(harness.service.allocatedChunkCount, 0);
      expect(failing.token.isCancelled, isTrue);
      expect(harness.errors, isEmpty);
      flushing.completeError(StateError('Late flush after terminal failure'));
      await Future<void>(() {});
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
        await _waitForIdle(harness.service);
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
Future<void> _waitForIdle(CdnProxyService service) async {
  final deadline = DateTime.now().add(_deadline);
  while (service.allocatedChunkCount != 0) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(
          'CDN allocated chunks did not return to zero', _deadline);
    }
    await Future<void>(() {});
  }
}

Future<void> _waitForWriters(CdnProxyService service, int count) async {
  final deadline = DateTime.now().add(_deadline);
  while (service.activeWriterCount != count) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('CDN writers did not finish', _deadline);
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
  _Harness(this.source, this.errors, this.service, this.uri);
  final _FakeCdn source;
  final List<Object> errors;
  final CdnProxyService service;
  final Uri uri;
  final _clients = <HttpClient>[];

  static Future<_Harness> open(int total,
      {bool autoRespond = false,
      Future<void> Function(Socket)? socketFlush,
      Future<Socket> Function(HttpResponse, bool)? socketDetach}) async {
    final source = _FakeCdn(total, autoRespond: autoRespond);
    final errors = <Object>[];
    final service = CdnProxyService(
        source: source,
        onError: errors.add,
        socketFlush: socketFlush,
        socketDetach: socketDetach);
    final uri = await service.open(
        uri: Uri.parse('https://cdn.invalid/media.mp4'),
        headers: const {'cookie': 'fake=value'}).timeout(_deadline);
    return _Harness(source, errors, service, uri);
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
  _FakeCdn(this.total,
      {required this.autoRespond,
      this.closeFailure,
      this.openingFailure,
      this.bodyCancellationGate});
  final int total;
  final bool autoRespond;
  final Object? closeFailure;
  final Object? openingFailure;
  final Future<void>? bodyCancellationGate;
  int closeCount = 0;
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
      required CancelToken cancelToken,
      String? ifRangeEtag}) async {
    if (openingFailure != null) throw openingFailure!;
    final probe = requests.isEmpty;
    final request = _FakeRequest(
        start, end, cancelToken, probe ? null : bodyCancellationGate);
    requests.add(request);
    for (final waiter in _waiters.toList()) {
      if (requests.length > waiter.$1) {
        _waiters.remove(waiter);
        waiter.$2.complete(requests[waiter.$1]);
      }
    }
    if (probe || autoRespond) request.complete(empty: total == 0);
    return Success(CdnRangeResponse(
      totalLength: total,
      contentType: 'video/mp4',
      stream: request.body.stream,
    ));
  }

  @override
  void close() {
    closeCount++;
    if (closeFailure != null) throw closeFailure!;
    for (final request in requests) {
      request.token.cancel('Fake source closed');
    }
  }
}

class _FakeRequest {
  _FakeRequest(
      this.start, this.end, this.token, Future<void>? cancellationGate) {
    body = StreamController<Uint8List>(
        onCancel: cancellationGate == null
            ? null
            : () async {
                if (!bodyCancellationStarted.isCompleted) {
                  bodyCancellationStarted.complete();
                }
                await cancellationGate;
              });
    unawaited(token.whenCancel.then((_) {
      if (!cancelled.isCompleted) cancelled.complete();
      if (!body.isClosed) unawaited(body.close());
    }));
  }
  final int start;
  final int end;
  final CancelToken token;
  final cancelled = Completer<void>();
  late final StreamController<Uint8List> body;
  final bodyCancellationStarted = Completer<void>();
  bool completed = false;

  void complete({bool empty = false}) {
    completed = true;
    if (!empty) body.add(_bytes(start, end - start + 1));
    unawaited(body.close());
  }
}

Future<Object?> _closeError(Future<void> future) =>
    future.then<Object?>((_) => null, onError: (Object error) => error);
