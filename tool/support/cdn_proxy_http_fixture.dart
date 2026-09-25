import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const fixtureMiB = 1024 * 1024;

/// Deterministic valid payload bytes, independent of request boundaries.
int fixtureByteAt(int offset) => (offset + offset ~/ 4096) % 251;

class FixtureRangeRequest {
  FixtureRangeRequest(this.start, this.end, this.openedAt);

  final int start;
  final int end;
  final Duration openedAt;
  int sentBytes = 0;
  Duration? headersAt;
  Duration? firstDataAt;
  Duration? lastDataAt;
  Duration? completedAt;
  Duration? disconnectedAt;

  int get length => end - start + 1;

  Map<String, Object?> toJson() => {
        'start': start,
        'end': end,
        'openedMs': openedAt.inMilliseconds,
        'headersMs': headersAt?.inMilliseconds,
        'firstDataMs': firstDataAt?.inMilliseconds,
        'lastDataMs': lastDataAt?.inMilliseconds,
        'completedMs': completedAt?.inMilliseconds,
        'disconnectedMs': disconnectedAt?.inMilliseconds,
        'sentBytes': sentBytes,
      };
}

/// Real loopback origin shared by the Dart CLI and slow-link regressions.
///
/// [sharedBytesPerSecond] limits the aggregate rate of active responses.
/// Faults always send a valid prefix: streaming consumers may already have
/// received it, so a retry must retain it and request only the missing suffix.
class CdnProxyHttpFixture {
  CdnProxyHttpFixture._(
    this._server, {
    required this.totalBytes,
    required this.sharedBytesPerSecond,
    required this.stallFirstBody,
    required this.disconnectFirstBody,
    required this.faultPrefixBytes,
  }) {
    _server.listen((request) => unawaited(_serve(request)));
    if (sharedBytesPerSecond != null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (_closed || _tickInProgress) return;
        _tickInProgress = true;
        _pendingTick = _sendTick().whenComplete(() => _tickInProgress = false);
      });
    }
  }

  static Future<CdnProxyHttpFixture> start({
    required int totalBytes,
    int? sharedBytesPerSecond,
    bool stallFirstBody = false,
    bool disconnectFirstBody = false,
    int faultPrefixBytes = 64 * 1024,
  }) async {
    if (totalBytes <= 1 ||
        faultPrefixBytes <= 0 ||
        (sharedBytesPerSecond != null && sharedBytesPerSecond <= 0) ||
        (stallFirstBody && disconnectFirstBody)) {
      throw ArgumentError('Invalid fixture length, bandwidth or fault mode.');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return CdnProxyHttpFixture._(
      server,
      totalBytes: totalBytes,
      sharedBytesPerSecond: sharedBytesPerSecond,
      stallFirstBody: stallFirstBody,
      disconnectFirstBody: disconnectFirstBody,
      faultPrefixBytes: faultPrefixBytes,
    );
  }

  final HttpServer _server;
  final int totalBytes;
  final int? sharedBytesPerSecond;
  final bool stallFirstBody;
  final bool disconnectFirstBody;
  final int faultPrefixBytes;
  final Stopwatch clock = Stopwatch()..start();
  final List<FixtureRangeRequest> bodyRequests = [];
  final Completer<void> firstBodyStarted = Completer<void>();
  final List<String> errors = [];
  final List<_SendJob> _jobs = [];
  Timer? _ticker;
  Future<void>? _pendingTick;
  bool _tickInProgress = false;
  bool _closed = false;
  int _activeBodyRequests = 0;
  int peakActiveBodyRequests = 0;

  Uri get uri => Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: _server.port,
        path: '/fixture.bin',
      );

  Future<void> _serve(HttpRequest request) async {
    FixtureRangeRequest? record;
    try {
      final match = RegExp(r'^bytes=(\d+)-(\d+)$')
          .firstMatch(request.headers.value(HttpHeaders.rangeHeader) ?? '');
      if (match == null) {
        request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await request.response.close();
        return;
      }
      final start = int.parse(match[1]!);
      final end = int.parse(match[2]!);
      final response = request.response;
      if (start < 0 || end < start || end >= totalBytes) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await response.close();
        return;
      }
      response.statusCode = HttpStatus.partialContent;
      response.contentLength = end - start + 1;
      response.bufferOutput = false;
      response.headers
        ..set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$totalBytes')
        ..set(HttpHeaders.contentTypeHeader, 'application/octet-stream')
        ..set(HttpHeaders.etagHeader, '"fixture-v1-$totalBytes"');
      // The proxy deliberately closes abandoned and failed requests.
      unawaited(response.done.then<void>((_) {}, onError: (Object _) {}));
      if (start == 0 && end == 0) {
        response.add([fixtureByteAt(0)]);
        await response.close();
        return;
      }
      final bodyRecord = FixtureRangeRequest(start, end, clock.elapsed);
      record = bodyRecord;
      bodyRequests.add(bodyRecord);
      _activeBodyRequests++;
      peakActiveBodyRequests =
          math.max(peakActiveBodyRequests, _activeBodyRequests);
      unawaited(response.done.then<void>((_) {
        _activeBodyRequests--;
      }, onError: (Object _) {
        _activeBodyRequests--;
        bodyRecord.disconnectedAt ??= clock.elapsed;
      }));
      final isFirst = identical(bodyRequests.first, bodyRecord);
      if (disconnectFirstBody && isFirst) {
        // detachSocket must run before HttpResponse has sent any headers.
        // Send a valid 206 then deliberately close below Content-Length.
        final socket = await response.detachSocket(writeHeaders: false);
        try {
          socket.add(ascii.encode('HTTP/1.1 206 Partial Content\r\n'
              'Content-Length: ${bodyRecord.length}\r\n'
              'Content-Range: bytes $start-$end/$totalBytes\r\n'
              'Content-Type: application/octet-stream\r\n'
              'ETag: "fixture-v1-$totalBytes"\r\n'
              'Connection: close\r\n\r\n'));
          await socket.flush();
          bodyRecord.headersAt = clock.elapsed;
          final count = math.min(faultPrefixBytes, bodyRecord.length);
          socket.add(Uint8List.fromList(
              List.generate(count, (index) => fixtureByteAt(start + index))));
          await socket.flush();
          bodyRecord.sentBytes = count;
          bodyRecord.firstDataAt = bodyRecord.lastDataAt = clock.elapsed;
          if (!firstBodyStarted.isCompleted) firstBodyStarted.complete();
          await socket.close();
          bodyRecord.disconnectedAt = clock.elapsed;
        } finally {
          socket.destroy();
        }
        return;
      }
      await response.flush();
      bodyRecord.headersAt = clock.elapsed;
      if (stallFirstBody && isFirst) {
        await _send(response, bodyRecord,
            math.min(faultPrefixBytes, bodyRecord.length));
        // An injected request deadline or client cancellation ends a stall.
        return;
      }
      if (sharedBytesPerSecond == null) {
        while (bodyRecord.sentBytes < bodyRecord.length && !_closed) {
          await _send(response, bodyRecord,
              math.min(64 * 1024, bodyRecord.length - bodyRecord.sentBytes));
        }
        await response.close();
        bodyRecord.completedAt = clock.elapsed;
        return;
      }
      _jobs.add(_SendJob(response, bodyRecord));
    } catch (error) {
      record?.disconnectedAt ??= clock.elapsed;
      if (!_closed && error is! SocketException && error is! HttpException) {
        errors.add(error.runtimeType.toString());
      }
    }
  }

  Future<void> _sendTick() async {
    final jobs = _jobs.toList();
    if (jobs.isEmpty) return;
    final perRequest = math.max(1, sharedBytesPerSecond! ~/ 10 ~/ jobs.length);
    await Future.wait(jobs.map((job) async {
      try {
        final record = job.record;
        await _send(job.response, record,
            math.min(perRequest, record.length - record.sentBytes));
        if (record.sentBytes == record.length) {
          await job.response.close();
          record.completedAt = clock.elapsed;
          _jobs.remove(job);
        }
      } catch (error) {
        _jobs.remove(job);
        job.record.disconnectedAt ??= clock.elapsed;
        if (!_closed && error is! SocketException && error is! HttpException) {
          errors.add(error.runtimeType.toString());
        }
      }
    }));
  }

  Future<void> _send(
      HttpResponse response, FixtureRangeRequest record, int count) async {
    final bytes = Uint8List(count);
    for (var i = 0; i < count; i++) {
      bytes[i] = fixtureByteAt(record.start + record.sentBytes + i);
    }
    response.add(bytes);
    await response.flush();
    record.sentBytes += count;
    record.firstDataAt ??= clock.elapsed;
    record.lastDataAt = clock.elapsed;
    if (!firstBodyStarted.isCompleted) firstBodyStarted.complete();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _ticker?.cancel();
    await _server.close(force: true);
    await _pendingTick;
    clock.stop();
  }
}

class _SendJob {
  _SendJob(this.response, this.record);
  final HttpResponse response;
  final FixtureRangeRequest record;
}
