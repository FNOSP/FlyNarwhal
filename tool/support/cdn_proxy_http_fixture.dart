import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const fixtureMiB = 1024 * 1024;
int fixtureByteAt(int offset) => (offset + offset ~/ 4096) % 251;

/// One origin request, including the metadata probe. No URLs or secrets are logged.
class CdnFixtureRequest {
  CdnFixtureRequest._(
      this.start, this.end, this.requestHeaders, this._clock, this._sockets)
      : openedAt = _clock.elapsed;

  final int start;
  final int end;
  final Map<String, String> requestHeaders;
  final Stopwatch _clock;
  final Set<Socket> _sockets;
  final Duration openedAt;
  int get length => end - start + 1;
  int sentBytes = 0;
  int statusCode = HttpStatus.partialContent;
  String? errorType;
  Duration? firstBodyAt;
  Duration? completedAt;

  Uint8List _bytes(int count) => Uint8List.fromList(
      List.generate(count, (i) => fixtureByteAt(start + sentBytes + i)));

  /// A handler may write a prefix, await its own gate, then resume default output.
  Future<void> write(HttpResponse response, int count) async {
    if (count == 0) return;
    response.add(_bytes(count));
    sentBytes += count;
    firstBodyAt ??= _clock.elapsed;
    await response.flush();
  }

  /// Send an incomplete but correct body. Call before writing this response.
  Future<void> disconnect(HttpResponse response, int prefixBytes) async {
    final socket = await response.detachSocket(writeHeaders: true);
    _sockets.add(socket);
    try {
      final count = math.min(prefixBytes, length);
      socket.add(_bytes(count));
      sentBytes += count;
      firstBodyAt ??= _clock.elapsed;
      await socket.flush();
      await socket.close();
    } finally {
      _sockets.remove(socket);
      socket.destroy();
    }
  }

  Map<String, Object?> toJson() => {
        'start': start,
        'end': end,
        'status': statusCode,
        'sentBytes': sentBytes,
        'openedMs': openedAt.inMilliseconds,
        'firstBodyMs': firstBodyAt?.inMilliseconds,
        'completedMs': completedAt?.inMilliseconds,
        if (errorType != null) 'errorType': errorType,
      };
}

/// Real HTTP origin shared by transport tests, proxy tests, and the Dart CLI.
///
/// [handle] runs after default range headers are prepared. Return true after
/// handling the response, or false to continue normal output. Tests own any
/// gates they introduce. Bandwidth is shared by all active body responses.
class CdnHttpFixture {
  CdnHttpFixture._(this._server, this.length, this.bytesPerSecond,
      this.disconnectAfter, this.stallAfter, this.handle) {
    _server.listen((request) => unawaited(_serve(request)));
    if (bytesPerSecond != null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        final jobs = _jobs.toList();
        final allowance =
            math.max(1, bytesPerSecond! ~/ 10 ~/ math.max(1, jobs.length));
        for (final job in jobs) {
          if (job.writing) continue;
          job.writing = true;
          unawaited(
              _advance(job, allowance).whenComplete(() => job.writing = false));
        }
      });
    }
  }

  static Future<CdnHttpFixture> start({
    required int length,
    int? bytesPerSecond,
    int? disconnectAfter,
    int? stallAfter,
    Future<bool> Function(HttpRequest, CdnFixtureRequest)? handle,
  }) async {
    if (length < 0 ||
        (bytesPerSecond != null && bytesPerSecond <= 0) ||
        (disconnectAfter != null && stallAfter != null)) {
      throw ArgumentError('Invalid HTTP fixture configuration');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return CdnHttpFixture._(
        server, length, bytesPerSecond, disconnectAfter, stallAfter, handle);
  }

  final HttpServer _server;
  final int length;
  final int? bytesPerSecond;
  final int? disconnectAfter;
  final int? stallAfter;
  final Future<bool> Function(HttpRequest, CdnFixtureRequest)? handle;
  final Stopwatch clock = Stopwatch()..start();
  final List<CdnFixtureRequest> requests = [];
  final List<_ResponseJob> _jobs = [];
  final Set<Socket> _sockets = {};
  Timer? _ticker;
  bool _closed = false;
  bool _faultUsed = false;
  int activeRequests = 0;
  int peakActiveRequests = 0;

  Uri get uri => Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: _server.port,
      path: '/fixture.bin');

  Future<void> _serve(HttpRequest request) async {
    CdnFixtureRequest? entry;
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
      final headers = <String, String>{};
      request.headers
          .forEach((name, values) => headers[name] = values.join(', '));
      final record = CdnFixtureRequest._(start, end, headers, clock, _sockets);
      entry = record;
      requests.add(record);
      activeRequests++;
      peakActiveRequests = math.max(peakActiveRequests, activeRequests);
      unawaited(request.response.done.then<void>((_) {
        activeRequests--;
      }, onError: (Object error) {
        activeRequests--;
        record.errorType = error.runtimeType.toString();
      }));
      final response = request.response..bufferOutput = false;
      if (end < start || end >= length) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
        record.statusCode = response.statusCode;
        await response.close();
        record.completedAt = clock.elapsed;
        return;
      }
      response.statusCode = HttpStatus.partialContent;
      response.contentLength = record.length;
      response.headers
        ..set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$length')
        ..set(HttpHeaders.contentTypeHeader, 'application/octet-stream')
        ..set(HttpHeaders.etagHeader, '"fixture-$length"');
      if (await handle?.call(request, record) == true) {
        record.statusCode = response.statusCode;
        return;
      }
      record.statusCode = response.statusCode;
      if (_closed) return;
      if (!_faultUsed &&
          record.length > 1 &&
          (disconnectAfter != null || stallAfter != null)) {
        _faultUsed = true;
        if (disconnectAfter != null) {
          await record.disconnect(response, disconnectAfter!);
        } else {
          await record.write(response, math.min(stallAfter!, record.length));
        }
        return;
      }
      await response.flush();
      if (bytesPerSecond != null && record.length > 1) {
        _jobs.add(_ResponseJob(response, record));
      } else {
        while (!_closed && record.sentBytes < record.length) {
          await record.write(
              response, math.min(64 * 1024, record.length - record.sentBytes));
        }
        await response.close();
        record.completedAt = clock.elapsed;
      }
    } catch (error) {
      entry?.errorType = error.runtimeType.toString();
    }
  }

  Future<void> _advance(_ResponseJob job, int allowance) async {
    try {
      if (_closed) return;
      await job.entry.write(job.response,
          math.min(allowance, job.entry.length - job.entry.sentBytes));
      if (job.entry.sentBytes == job.entry.length) {
        await job.response.close();
        job.entry.completedAt = clock.elapsed;
        _jobs.remove(job);
      }
    } catch (error) {
      job.entry.errorType = error.runtimeType.toString();
      _jobs.remove(job);
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _ticker?.cancel();
    _jobs.clear();
    for (final socket in _sockets.toList()) {
      socket.destroy();
    }
    _sockets.clear();
    await _server.close(force: true);
    clock.stop();
  }
}

class _ResponseJob {
  _ResponseJob(this.response, this.entry);
  final HttpResponse response;
  final CdnFixtureRequest entry;
  bool writing = false;
}
