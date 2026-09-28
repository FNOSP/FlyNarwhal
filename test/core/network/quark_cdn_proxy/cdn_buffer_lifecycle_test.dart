import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_errors.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_service.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_policy.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_session.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_source.dart';

const _chunk = 10 * 1024 * 1024;
const _deadline = Duration(seconds: 5);
const _tag = CdnEntityTag(opaqueValue: 'stable-resource');
final _uri = Uri.parse('https://cdn.example.test/media');

void main() {
  test(
      'Given producer cancellation is unfinished, then old buffers remain owned while a replacement starts independently',
      () async {
    final releaseCancellation = Completer<void>();
    final oldSource =
        _Source(3 * _chunk, cancellationGate: releaseCancellation.future);
    final nextSource = _Source(100);
    final oldSession = _session(oldSource);
    final nextSession = _session(nextSource);
    addTearDown(() async {
      if (!releaseCancellation.isCompleted) releaseCancellation.complete();
      await oldSession.close();
      await nextSession.close();
    });
    await oldSession.initialize();
    final oldRead = _Read(
        oldSession.read(const CdnByteRange(start: 0, end: 3 * _chunk - 1)));
    final oldBodies = [for (var i = 0; i < 3; i++) await oldSource.bodyAt(i)];
    expect(oldSession.allocatedBufferBytes, 3 * _chunk);
    expect(oldSession.allocatedChunkCount, 3);

    var closed = false;
    final oldClose = oldSession.close().then((_) => closed = true);
    await Future.wait(oldBodies.map((body) => body.cancellationStarted.future))
        .timeout(_deadline);
    await nextSession.initialize().timeout(_deadline);
    expect(closed, isFalse);
    expect(nextSource.probeCalls, 1,
        reason: 'A replacement does not wait for another reader storage');
    expect(oldSession.allocatedBufferBytes, 3 * _chunk);
    expect(oldSession.allocatedChunkCount, 3);

    final newRead =
        _Read(nextSession.read(const CdnByteRange(start: 10, end: 29)));
    final nextBody = await nextSource.bodyAt(0);
    expect(nextSession.allocatedChunkCount, 1);
    expect(oldSession.allocatedChunkCount, 3);
    nextBody.complete();
    await newRead.done.timeout(_deadline);
    expect(newRead.errors, isEmpty);
    expect(newRead.bytes, 20);
    expect(nextSession.allocatedBufferBytes, 0);
    expect(nextSession.allocatedChunkCount, 0);
    expect(closed, isFalse,
        reason:
            'The new read finishes before old producer cleanup is released');
    expect(oldSession.allocatedBufferBytes, 3 * _chunk);

    releaseCancellation.complete();
    await oldClose.timeout(_deadline);
    await oldRead.done.timeout(_deadline);
    expect(oldSession.allocatedBufferBytes, 0);
    expect(oldSession.allocatedChunkCount, 0);
    expect(oldSession.activeDownloadCount, 0);
    expect(oldSession.peakAllocatedChunkCount, 3);
  });

  test(
      'Given a paused consumer, when the session closes, then buffers and producers are released without resuming it',
      () async {
    final source = _Source(3 * _chunk);
    final session = _session(source);
    addTearDown(session.close);
    await session.initialize();
    final paused = Completer<void>();
    late StreamSubscription<Uint8List> subscription;
    subscription = session
        .read(const CdnByteRange(start: 0, end: 3 * _chunk - 1))
        .listen((_) {
      subscription.pause();
      if (!paused.isCompleted) paused.complete();
    }, onError: (Object _) {});
    final bodies = [for (var i = 0; i < 3; i++) await source.bodyAt(i)];
    bodies.first.body.add(Uint8List(16));
    await paused.future.timeout(_deadline);
    expect(session.allocatedBufferBytes, 3 * _chunk);
    await session.close().timeout(_deadline);
    expect(subscription.isPaused, isTrue);
    expect(session.allocatedBufferBytes, 0);
    expect(session.activeDownloadCount, 0);
    expect(session.allocatedChunkCount, 0);
    expect(
        bodies.every((body) => body.cancellationStarted.isCompleted), isTrue);
    await subscription.cancel().timeout(_deadline);
    expect(source.closeCalls, 1);
  });

  test(
      'Given completed buffers and a paused reader, then storage stays owned until cancellation cleanup',
      () async {
    final source = _Source(2 * _chunk);
    final session = _session(source);
    addTearDown(session.close);
    await session.initialize();
    final paused = Completer<void>();
    late StreamSubscription<Uint8List> subscription;
    subscription = session
        .read(const CdnByteRange(start: 0, end: 2 * _chunk - 1))
        .listen((_) {
      subscription.pause();
      if (!paused.isCompleted) paused.complete();
    }, onError: (Object _) {});
    final first = await source.bodyAt(0);
    final second = await source.bodyAt(1);
    first.complete();
    second.complete();
    await paused.future.timeout(_deadline);
    await Future.wait([
      first.cancellationStarted.future,
      second.cancellationStarted.future
    ]).timeout(_deadline);
    await _eventTurn();
    expect(session.activeDownloadCount, 0);
    expect(session.allocatedBufferBytes, 2 * _chunk);
    expect(session.allocatedChunkCount, 2);
    await subscription.cancel().timeout(_deadline);
    expect(session.allocatedBufferBytes, 0);
    expect(session.allocatedChunkCount, 0);
  });

  test(
      'Given one reader holds its three buffers, then another reader starts and finishes without borrowing them',
      () async {
    final source = _Source(6 * _chunk);
    final session = _session(source);
    addTearDown(session.close);
    await session.initialize();
    final first =
        _Read(session.read(const CdnByteRange(start: 0, end: 3 * _chunk - 1)));
    final firstBodies = [for (var i = 0; i < 3; i++) await source.bodyAt(i)];
    expect(session.allocatedChunkCount, 3);
    final second = _Read(session
        .read(const CdnByteRange(start: 3 * _chunk, end: 6 * _chunk - 1)));
    final secondBodies = [for (var i = 3; i < 6; i++) await source.bodyAt(i)];
    expect(session.allocatedChunkCount, 6);
    expect(session.allocatedBufferBytes, 6 * _chunk);
    expect(session.peakAllocatedChunkCount, 6);
    for (final body in secondBodies) {
      body.complete();
    }
    await second.done.timeout(_deadline);
    expect(second.errors, isEmpty);
    expect(second.bytes, 3 * _chunk);
    expect(first.bytes, 0);
    expect(session.allocatedChunkCount, 3);
    expect(firstBodies.every((body) => !body.cancellationStarted.isCompleted),
        isTrue);
    for (final body in firstBodies) {
      body.complete();
    }
    await first.done.timeout(_deadline);
    expect(first.errors, isEmpty);
    expect(first.bytes, 3 * _chunk);
    expect(session.allocatedChunkCount, 0);
    expect(session.allocatedBufferBytes, 0);
  });

  test(
      'Given global identity failure followed by repeated service close, then the owned source closes once',
      () async {
    final source = _Source(100);
    final errors = <Object>[];
    final service = CdnProxyService(source: source, onError: errors.add);
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await service.close();
    });
    final uri = await service.open(uri: _uri, headers: const {});
    source.mediaTag = const CdnEntityTag(opaqueValue: 'changed-resource');
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=10-29');
    final response = await request.close().timeout(_deadline);
    final completed =
        response.drain<void>().then<void>((_) {}, onError: (Object _) {});
    await source.bodyAt(0);
    await completed.timeout(_deadline);
    final closed = service.close();
    expect(identical(closed, service.close()), isTrue);
    await closed.timeout(_deadline);
    expect(errors, [isA<CdnResourceChanged>()]);
    expect(source.closeCalls, 1);
    expect(service.activeWriterCount, 0);
    expect(service.allocatedBufferBytes, 0);
    expect(service.activeDownloadCount, 0);
  });
}

CdnRangeSession _session(_Source source) => CdnRangeSession(
    source: source,
    uri: _uri,
    headers: const {},
    retryJitter: () => Duration.zero);
Future<void> _eventTurn() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _Read {
  _Read(Stream<Uint8List> stream) {
    stream.listen((data) => bytes += data.length,
        onError: errors.add, onDone: _done.complete);
  }
  int bytes = 0;
  final errors = <Object>[];
  final _done = Completer<void>();
  Future<void> get done => _done.future;
}

class _Source implements CdnRangeSource {
  _Source(this.total, {this.cancellationGate});
  final int total;
  final Future<void>? cancellationGate;
  final bodies = <_Body>[];
  final _waiters = <({int index, Completer<_Body> result})>[];
  int probeCalls = 0;
  int closeCalls = 0;
  CdnEntityTag mediaTag = _tag;

  Future<_Body> bodyAt(int index) {
    if (bodies.length > index) return Future.value(bodies[index]);
    final result = Completer<_Body>();
    _waiters.add((index: index, result: result));
    return result.future.timeout(_deadline);
  }

  @override
  Future<ApiResult<CdnRangeResponse>> open(
      {required Uri uri,
      required Map<String, String> headers,
      required int start,
      required int end,
      required CancelToken cancelToken,
      String? ifRangeEtag}) async {
    if (start == 0 && end == 0) {
      probeCalls++;
      return Success(CdnRangeResponse(
          totalLength: total,
          entityTag: _tag,
          stream: Stream.value(Uint8List(1))));
    }
    final body = _Body(start, end, cancellationGate);
    bodies.add(body);
    for (final waiter in _waiters.toList()) {
      if (bodies.length > waiter.index) {
        waiter.result.complete(bodies[waiter.index]);
        _waiters.remove(waiter);
      }
    }
    return Success(CdnRangeResponse(
        totalLength: total, entityTag: mediaTag, stream: body.body.stream));
  }

  @override
  void close() => closeCalls++;
}

class _Body {
  _Body(this.start, this.end, Future<void>? cancellationGate) {
    body = StreamController<Uint8List>(onCancel: () async {
      if (!cancellationStarted.isCompleted) cancellationStarted.complete();
      await cancellationGate;
    });
  }
  final int start;
  final int end;
  late final StreamController<Uint8List> body;
  final cancellationStarted = Completer<void>();
  void complete() {
    body.add(Uint8List(end - start + 1));
    unawaited(body.close());
  }
}
