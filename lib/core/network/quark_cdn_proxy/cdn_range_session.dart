import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../api_result.dart';
import 'cdn_cancellation.dart';
import 'cdn_concurrency_policy.dart';
import 'cdn_proxy_constants.dart';
import 'cdn_proxy_errors.dart';
import 'cdn_range_diagnostics.dart';
import 'cdn_range_policy.dart';
import 'cdn_range_source.dart';

/// A completed body still owns this storage until its last byte is consumed.
class _StreamingChunk {
  _StreamingChunk(this.id, this.range) : _bytes = Uint8List(range.length);
  final int id;
  final CdnByteRange range;
  Uint8List? _bytes;
  Uint8List get bytes => _bytes!;
  int get capacity => _bytes?.length ?? 0;
  bool complete = false;
  bool empty = false;
  int accepted = 0;
  int delivered = 0;

  int get outputLength => empty ? 0 : range.length;
  int get readable => complete ? accepted : min(accepted, outputLength - 1);
  void release() => _bytes = null;
}

class _ReadRequest {
  _ReadRequest(this.range,
      {this.probe = false,
      this.bitrate = 0,
      })
      : ranges = (probe ? [range] : splitCdnRange(range)).iterator,
        single = probe || range.length <= CdnProxyDefaults.chunkSize,
        _concurrency = initialConcurrency(bitrate);
  final CdnByteRange range;
  final bool probe;
  final bool single;
  final int bitrate;
  final Iterator<CdnByteRange> ranges;
  final CdnCancellation cancellation = CdnCancellation();
  final Map<int, _StreamingChunk> chunks = {};
  final Set<CancelToken> attempts = {};
  final Set<Future<void>> work = {};
  Completer<void> changed = Completer();
  Future<void> retryQueue = Future.value();
  Object? error;
  Future<void>? cleanup;
  final Set<Future<void>> ownings = {};
  bool get cancelled => cancellation.isCancelled;
  bool exhausted = false;
  bool prefetchAllowed = false;
  int nextId = 0;
  int readingId = 0;

  /// Current number of simultaneous downloads allowed for this reader.
  int _concurrency;

  /// Cumulative bytes pulled since the current measurement window opened.
  int _windowBytes = 0;

  /// Active download time accumulated since the current measurement window
  /// opened. Gaps where the player paused reading are excluded, so the
  /// measured rate reflects the transport rather than downstream backpressure.
  int _windowActiveMs = 0;

  /// Wall-clock start of the current active download segment, or zero when no
  /// chunk is downloading. Backpressure gaps are excluded from [_windowActiveMs].
  int _activeSegmentStartMs = 0;
  int _unproductiveProbes = 0;
  bool _probePending = false;
  double _preProbeThroughput = 0;

  void _markDownloadStarted() {
    if (_activeSegmentStartMs == 0) {
      _activeSegmentStartMs = DateTime.now().millisecondsSinceEpoch;
    }
  }

  void _markDownloadStopped() {
    if (work.isNotEmpty) return;
    if (_activeSegmentStartMs == 0) return;
    _windowActiveMs +=
        DateTime.now().millisecondsSinceEpoch - _activeSegmentStartMs;
    _activeSegmentStartMs = 0;
  }

  /// Records one completed chunk download and, once an active-download
  /// measurement window has elapsed, moves the concurrency in response.
  void recordNetworkWindow(int bytes) {
    if (probe || bytes <= 0 || bitrate <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final activeMs = _windowActiveMs +
        (_activeSegmentStartMs == 0 ? 0 : now - _activeSegmentStartMs);
    _windowBytes += bytes;
    if (activeMs < CdnProxyDefaults.throughputMeasurementWindowMs) return;
    final measured = _windowBytes * 1000 / activeMs;
    _windowBytes = 0;
    _windowActiveMs = 0;
    if (_activeSegmentStartMs != 0) {
      _activeSegmentStartMs = now;
    }
    _adjustConcurrency(measured);
  }

  /// Moves the concurrency in response to [measured] aggregate throughput.
  void _adjustConcurrency(double measured) {
    final decision = decideConcurrency(
      concurrency: _concurrency,
      bitrate: bitrate,
      measured: measured,
      probePending: _probePending,
      unproductiveProbes: _unproductiveProbes,
      preProbeThroughput: _preProbeThroughput,
    );
    _concurrency = decision.concurrency;
    _probePending = decision.probePending;
    _unproductiveProbes = decision.unproductiveProbes;
    _preProbeThroughput = decision.preProbeThroughput;
  }

  /// Reserves the right to end an attempt's body connection. A later body
  /// teardown only cancels the token when it won this race, so the token never
  /// sees a second cancel with a different reason.
  Future<void> claim() {
    final owning = Future<void>.value();
    ownings.add(owning);
    return owning;
  }

  bool owns(Future<void> owning) => ownings.contains(owning);

  void signal() {
    final previous = changed;
    changed = Completer();
    previous.complete();
  }

  void check() {
    if (error != null) throw error!;
    if (cancelled) throw const CdnRangeCancelled();
  }

  Future<T> wait<T>(Future<T> future) async {
    try {
      final result = await cancellation.wait(future);
      check();
      return result;
    } catch (_) {
      // A failed read keeps its original reason even when cancellation wins.
      check();
      rethrow;
    }
  }

  Future<void> delay(Duration duration) async {
    final done = Completer<void>();
    final timer = Timer(duration, done.complete);
    try {
      await wait(done.future);
    } finally {
      timer.cancel();
    }
  }

  Future<void> retryLater(Duration duration) {
    final previous = retryQueue;
    final finished = Completer<void>();
    retryQueue = finished.future;
    return () async {
      try {
        await wait(previous);
        await delay(duration);
      } finally {
        finished.complete();
      }
    }();
  }

  void fail(Object cause) {
    if (cancelled) return;
    error = cause;
    cancel();
  }

  void cancel() {
    if (cancelled) return;
    cancellation.cancel();
    // Take every outstanding body connection with the token. A body that was
    // still mid-read then finds it no longer owns the teardown and stays
    // silent instead of cancelling the token a second time.
    ownings.clear();
    for (final attempt in attempts.toList()) {
      attempt.cancel('CDN read cancelled');
    }
    signal();
    cleanup = () async {
      try {
        await Future.wait(work.toList());
      } finally {
        for (final chunk in chunks.values) {
          chunk.release();
        }
        chunks.clear();
      }
    }();
  }

  int get windowLimit => prefetchAllowed
      ? min(_concurrency,
          (range.length - 1) ~/ CdnProxyDefaults.chunkSize + 1)
      : 1;
}

/// Pure Dart ordered streaming downloader. One HTTP read is one failure domain.
class CdnRangeSession {
  CdnRangeSession({
    required this.source,
    required this.uri,
    required Map<String, String> headers,
    this.bitrate = 0,
    this.onError,
    Duration Function()? retryJitter,
    this.diagnostics,
  })  : headers = Map.unmodifiable(headers),
        retryJitter = retryJitter ??
            (() => Duration(milliseconds: 200 + _random.nextInt(300)));

  static final Random _random = Random();
  final CdnRangeSource source;
  final Uri uri;
  final Map<String, String> headers;
  final int bitrate;
  final void Function(Object)? onError;
  final Duration Function() retryJitter;
  final CdnRangeDiagnostics? diagnostics;
  final Set<_ReadRequest> _requests = {};
  int _peakAllocatedChunkCount = 0;
  int? _length;
  String? _contentType;
  CdnEntityTag? _entityTag;
  DateTime? _lastModified;
  bool _identitySupplemented = false;
  Object? _failure;
  bool _closed = false;
  bool _sourceClosed = false;
  CdnRangeFailure? _sourceCloseError;
  Future<void>? _initializing;
  Future<void>? _closing;

  int get totalLength =>
      _length ?? (throw StateError('Source not initialized'));
  String? get contentType => _contentType;
  int get allocatedChunkCount =>
      _requests.fold(0, (count, request) => count + request.chunks.length);
  int get peakAllocatedChunkCount => _peakAllocatedChunkCount;
  int get activeDownloadCount =>
      _requests.fold(0, (count, request) => count + request.work.length);
  int get allocatedBufferBytes => _requests.fold(
      0,
      (count, request) =>
          count +
          request.chunks.values
              .fold<int>(0, (bytes, chunk) => bytes + chunk.capacity));
  int get bufferedBytes => _requests.fold(
      0,
      (count, request) =>
          count +
          request.chunks.values.fold<int>(
              0, (bytes, chunk) => bytes + chunk.accepted - chunk.delivered));

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    _checkActive();
    final request = _ReadRequest(const CdnByteRange(start: 0, end: 0),
        probe: true,
        bitrate: bitrate);
    try {
      await _read(request).drain<void>();
      _checkActive();
      diagnostics?.initialized(totalLength);
    } catch (cause) {
      if (cause is! CdnRangeCancelled && !_closed) _fail(cause);
      rethrow;
    }
  }

  Stream<Uint8List> read(CdnByteRange range) {
    try {
      _checkActive();
      if (range.start < 0 ||
          range.end < range.start ||
          range.end >= totalLength) {
        throw const CdnRangeNotSatisfiable();
      }
    } catch (cause, stack) {
      return Stream<Uint8List>.error(cause, stack);
    }
    final request = _ReadRequest(range, bitrate: bitrate);
    StreamSubscription<Uint8List>? subscription;
    late final StreamController<Uint8List> controller;
    controller = StreamController(
      sync: true,
      onListen: () {
        subscription = _read(request).listen(controller.add,
            onError: controller.addError, onDone: controller.close);
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        request.cancel();
        try {
          await subscription?.cancel();
        } catch (_) {
          // The stream owns terminal failures; cancel must still finish cleanup.
        }
      },
    );
    return controller.stream;
  }

  Stream<Uint8List> _read(_ReadRequest request) async* {
    _checkActive();

    _requests.add(request);
    try {
      _pump(request);
      while (true) {
        request.check();
        final chunk = request.chunks[request.readingId];
        if (chunk == null) {
          // Admission is synchronous and always fills a contiguous window.
          assert(request.exhausted && request.readingId == request.nextId);
          break;
        }
        final available = chunk.readable - chunk.delivered;
        if (available > 0) {
          final end = chunk.delivered +
              min<int>(available, CdnProxyDefaults.outputBlockSize);
          final bytes = Uint8List.fromList(
              Uint8List.sublistView(chunk.bytes, chunk.delivered, end));
          chunk.delivered = end;
          yield bytes;
          continue;
        }
        if (chunk.complete && chunk.delivered == chunk.outputLength) {
          // The generator resumes only after the writer has flushed this part.
          chunk.release();
          request.chunks.remove(chunk.id);
          request.readingId++;
          _pump(request);
          continue;
        }
        await request.wait(request.changed.future);
      }
    } finally {
      request.cancel();
      try {
        await request.cleanup;
      } finally {
        _requests.remove(request);
      }
    }
  }

  void _pump(_ReadRequest request) {
    while (!request.cancelled &&
        !request.exhausted &&
        request.chunks.length < request.windowLimit) {
      if (!request.ranges.moveNext()) {
        request.exhausted = true;
        break;
      }
      final chunk = _StreamingChunk(request.nextId++, request.ranges.current);
      request.chunks[chunk.id] = chunk;
      _peakAllocatedChunkCount =
          max(_peakAllocatedChunkCount, allocatedChunkCount);
      // Register ownership before invoking a source that may throw or cancel
      // synchronously. Every task observes failure and unregisters itself.
      late final Future<void> task;
      task = Future<void>.microtask(() async {
        try {
          await _download(request, chunk);
        } catch (cause) {
          request.fail(_safeError(cause));
        } finally {
          request.work.remove(task);
          request._markDownloadStopped();
        }
      });
      request.work.add(task);
    }
  }

  Future<void> _download(_ReadRequest request, _StreamingChunk chunk) async {
    var failures = 0;
    var attemptNumber = 0;
    try {
      while (true) {
        request.check();
        final token = CancelToken();
        request.attempts.add(token);
        final start = chunk.range.start + chunk.accepted;
        final trace = diagnostics?.begin(
            start: start, end: chunk.range.end, probe: request.probe);
        var outcome = 'cancelled';
        Stream<Uint8List>? unreadBody;
        var bodyPhase = false;
        // The body connection has one owner. Whichever side reaches the
        // teardown first takes it and ends the token with its own reason; the
        // other must stay silent, because a second cancel with a different
        // reason makes the token warn.
        final owning = request.claim();
        Object? failed;
        Duration delay = Duration.zero;
        var serializeDelay = false;
        try {
          attemptNumber++;
          final opening = source
              .open(
            uri: uri,
            headers: headers,
            start: start,
            end: chunk.range.end,
            cancelToken: token,
            ifRangeEtag: _entityTag?.strongValue,
          )
              .then((result) {
            if (token.isCancelled && result is Success<CdnRangeResponse>) {
              unawaited(_discard(result.data.stream));
            }
            return result;
          });
          final response = (await request.wait(opening)).getOrThrow();
          unreadBody = response.stream;
          trace?.headersReceived(response.totalLength);
          _validateIdentity(response, request.probe);

          if (request.probe && response.totalLength == 0) {
            chunk.empty = true;
            chunk.complete = true;
          } else {
            if (!request.single && chunk.id == 0 && !request.prefetchAllowed) {
              request.prefetchAllowed = true;
              _pump(request);
            }
            bodyPhase = true;
            unreadBody = null;
            request._markDownloadStarted();
            await _consume(
                response.stream, request, chunk, token, trace, owning);
            chunk.complete = true;
            request.recordNetworkWindow(chunk.accepted);
          }
          request.signal();
          outcome = 'success';
          return;
        } catch (cause) {
          trace?.failed(cause);
          if (request.cancelled) request.check();
          if (request.single || cause is CdnRangeFailure) {
            failed = cause;
          } else if (cause is CdnRequestFailure &&
              cause.kind == CdnRequestFailureKind.httpStatus) {
            final status = cause.statusCode;
            if (status == 416) {
              failed = cause;
            } else if (chunk.id == 0) {
              if ({429, 502, 503, 504}.contains(status) &&
                  failures < CdnProxyDefaults.maxBodyRetries) {
                failures++;
                delay = retryJitter();
              } else {
                failed = cause;
              }
            } else if (chunk.id != request.readingId) {
              delay = retryJitter();
              serializeDelay = true;
            }
          } else if (bodyPhase &&
              !(cause is CdnRequestFailure &&
                  cause.kind == CdnRequestFailureKind.protocol) &&
              chunk.accepted < chunk.range.length &&
              failures < CdnProxyDefaults.maxBodyRetries) {
            failures++;
          } else {
            failed = cause;
          }
          if (failed != null) {
            outcome = 'failed';
          } else {
            outcome = 'retrying';
            if (trace != null) {
              diagnostics?.retrying(trace,
                  attempt: attemptNumber,
                  delay: delay,
                  acceptedBytes: chunk.accepted,
                  deliveredBytes: chunk.delivered,
                  remainingBytes: chunk.range.length - chunk.accepted,
                  windowLimit: request.windowLimit);
            }
          }
        } finally {
          // The body connection is handed over only once its read completed, so
          // a failed or cancelled attempt still ends its own token here.
          if (request.owns(owning)) token.cancel('CDN attempt finished');
          request.ownings.remove(owning);
          if (unreadBody != null) await _discard(unreadBody);
          request.attempts.remove(token);
          if (trace != null) diagnostics?.finish(trace, outcome);
        }
        if (failed != null) throw failed;
        if (serializeDelay) {
          await request.retryLater(delay);
        } else {
          // Even an immediate retry yields so cancellation cannot be starved.
          await request.delay(delay);
        }
      }
    } catch (cause) {
      if (!request.cancelled) {
        if (cause is CdnResourceChanged) {
          _fail(cause);
        } else {
          diagnostics?.rangeFailed(
              allocatedChunkCount: allocatedChunkCount,
              activeReaders: _requests.length);
          request.fail(_safeError(cause));
        }
      }
    }
  }

  Future<void> _consume(
    Stream<Uint8List> stream,
    _ReadRequest request,
    _StreamingChunk chunk,
    CancelToken token,
    CdnRangeTrace? trace,
    Future<void> owning,
  ) async {
    final done = Completer<void>();
    final subscription = stream.listen((bytes) {
      if (done.isCompleted || request.cancelled) return;
      trace?.received(bytes.length);
      if (chunk.accepted + bytes.length > chunk.range.length) {
        done.completeError(const CdnRangeFailure('CDN 分片超过请求范围'));
        return;
      }
      chunk.bytes
          .setRange(chunk.accepted, chunk.accepted + bytes.length, bytes);
      chunk.accepted += bytes.length;
      request.signal();
    }, onError: (Object cause, StackTrace stack) {
      if (!done.isCompleted) {
        done.completeError(
            chunk.accepted == chunk.range.length
                ? const CdnRangeFailure('CDN 分片未正常结束')
                : cause,
            stack);
      }
    }, onDone: () {
      if (done.isCompleted) return;
      if (chunk.accepted == chunk.range.length) {
        done.complete();
      } else {
        done.completeError(const _IncompleteBody());
      }
    });
    try {
      await request.wait(done.future);
    } finally {
      // Only the owner names the token's cancellation. When the read already
      // claimed it, cancelling again with a different reason would warn.
      if (request.owns(owning)) {
        request.ownings.remove(owning);
        token.cancel('CDN body finished');
      }
      // Retain error ownership even if cancellation wins before stream failure.
      await subscription.cancel();
    }
  }

  void _validateIdentity(CdnRangeResponse response, bool probe) {
    if (probe) {
      _length = response.totalLength;
      _contentType = response.contentType;
      _entityTag = response.entityTag;
      _lastModified = response.lastModified?.toUtc();
      return;
    }
    if (response.totalLength != _length) {
      throw const CdnResourceChanged('CDN 资源大小已变化');
    }
    if ((_entityTag != null && _entityTag != response.entityTag) ||
        (_lastModified != null &&
            _lastModified != response.lastModified?.toUtc())) {
      throw const CdnResourceChanged('CDN 资源标识已变化或缺失');
    }
    if (!_identitySupplemented) {
      _entityTag ??= response.entityTag;
      _lastModified ??= response.lastModified?.toUtc();
      _identitySupplemented = true;
    }
  }

  static Future<void> _discard(Stream<Uint8List> stream) async {
    try {
      await stream.listen((_) {}, onError: (Object _) {}).cancel();
    } catch (_) {
      // A late transport error must not escape cancellation.
    }
  }

  Object _safeError(Object cause) => cause is CdnRangeFailure
      ? cause
      : cause is CdnRangeCancelled
          ? cause
          : cause is FailureInfo
              ? CdnRangeFailure(cause.displayMessage)
              : const CdnRangeFailure('CDN 分片读取失败，请重试');

  void _checkActive() {
    if (_failure != null) throw _failure!;
    if (_closed) throw const CdnRangeCancelled();
  }

  void _fail(Object cause) {
    if (_failure != null || _closed || cause is CdnRangeCancelled) return;
    _failure = _safeError(cause);
    for (final request in _requests.toList()) {
      request.fail(_failure!);
    }
    _closeSource();
    diagnostics?.failed(
        allocatedChunkCount: allocatedChunkCount,
        activeReaders: _requests.length);
    try {
      onError?.call(_failure!);
    } catch (_) {
      // Notification cannot replace the source failure or interrupt cleanup.
    }
  }

  void _closeSource() {
    if (_sourceClosed) return;
    _sourceClosed = true;
    try {
      source.close();
    } catch (_) {
      // Report a safe close error only after every reader has been cleaned up.
      _sourceCloseError = const CdnRangeFailure('CDN 代理资源清理失败');
    }
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    for (final request in _requests.toList()) {
      request.cancel();
    }
    _closeSource();
    try {
      await Future.wait<void>([
        for (final request in _requests.toList())
          if (request.cleanup != null) request.cleanup!,
      ]);
    } finally {
      _requests.clear();
    }
    if (_sourceCloseError != null) throw _sourceCloseError!;
  }
}

class _IncompleteBody implements Exception {
  const _IncompleteBody();
}
