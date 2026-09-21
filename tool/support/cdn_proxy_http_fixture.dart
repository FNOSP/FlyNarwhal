import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const fixtureMiB = 1024 * 1024;

/// Deterministic public test data, independent of chunk/request boundaries.
int fixtureByteAt(int offset) => (offset + offset ~/ 4096) % 251;

class FixtureRangeRequest {
  FixtureRangeRequest(this.start, this.end, this.openedAt);

  final int start;
  final int end;
  final Duration openedAt;
  int sentBytes = 0;
  Duration? lastDataAt;
  Duration? completedAt;

  int get length => end - start + 1;
}

/// Real loopback HTTP origin used by both the Dart CLI and slow-link tests.
///
/// [sharedBytesPerSecond] limits the combined rate of all active responses.
/// The first body can instead send a distinct prefix and remain idle, so a
/// retry must discard that prefix before returning the replacement range.
class CdnProxyHttpFixture {
  CdnProxyHttpFixture._(
    this._server, {
    required this.totalBytes,
    required this.sharedBytesPerSecond,
    required this.stallFirstBody,
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
  }) async {
    if (totalBytes <= 1 ||
        (sharedBytesPerSecond != null && sharedBytesPerSecond <= 0)) {
      throw ArgumentError(
          'The fixture requires positive length and bandwidth.');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return CdnProxyHttpFixture._(
      server,
      totalBytes: totalBytes,
      sharedBytesPerSecond: sharedBytesPerSecond,
      stallFirstBody: stallFirstBody,
    );
  }

  final HttpServer _server;
  final int totalBytes;
  final int? sharedBytesPerSecond;
  final bool stallFirstBody;
  final Stopwatch clock = Stopwatch()..start();
  final List<FixtureRangeRequest> bodyRequests = [];
  final Completer<void> firstBodyStarted = Completer<void>();
  final List<String> errors = [];
  final List<_SendJob> _jobs = [];
  Timer? _ticker;
  Future<void>? _pendingTick;
  bool _tickInProgress = false;
  bool _closed = false;
  int peakActiveBodyRequests = 0;

  Uri get uri => Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: _server.port,
        path: '/fixture.bin',
      );

  Future<void> _serve(HttpRequest request) async {
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
        ..set(HttpHeaders.contentTypeHeader, 'application/octet-stream');
      // Cancellation is expected for the deliberately stalled response.
      unawaited(response.done.then<void>((_) {}, onError: (Object _) {}));
      if (start == 0 && end == 0) {
        response.add([fixtureByteAt(0)]);
        await response.close();
        return;
      }
      final record = FixtureRangeRequest(start, end, clock.elapsed);
      bodyRequests.add(record);
      if (stallFirstBody && bodyRequests.length == 1) {
        final count = math.min(64 * 1024, record.length);
        await _send(response, record, count, corrupt: true);
        if (!firstBodyStarted.isCompleted) firstBodyStarted.complete();
        // Intentionally leave the response open without another data event.
        return;
      }
      if (!firstBodyStarted.isCompleted) firstBodyStarted.complete();
      if (sharedBytesPerSecond == null) {
        while (record.sentBytes < record.length && !_closed) {
          await _send(response, record,
              math.min(64 * 1024, record.length - record.sentBytes));
        }
        await response.close();
        record.completedAt = clock.elapsed;
        return;
      }
      _jobs.add(_SendJob(response, record));
      peakActiveBodyRequests = math.max(peakActiveBodyRequests, _jobs.length);
    } catch (error) {
      if (!_closed) errors.add(error.runtimeType.toString());
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
        if (!_closed) errors.add(error.runtimeType.toString());
      }
    }));
  }

  Future<void> _send(
      HttpResponse response, FixtureRangeRequest record, int count,
      {bool corrupt = false}) async {
    final bytes = Uint8List(count);
    for (var i = 0; i < count; i++) {
      bytes[i] =
          corrupt ? 0xFF : fixtureByteAt(record.start + record.sentBytes + i);
    }
    response.add(bytes);
    await response.flush();
    record.sentBytes += count;
    record.lastDataAt = clock.elapsed;
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
