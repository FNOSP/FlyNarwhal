import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../api_result.dart';
import 'cdn_proxy_constants.dart';
import 'cdn_proxy_errors.dart';
import 'cdn_range_diagnostics.dart';
import 'cdn_range_policy.dart';
import 'cdn_range_source.dart';

/// Buffer ownership spans download, retries, and downstream consumption.
class CdnRangeBudget {
  int _occupied = 0;
  int _peak = 0;
  final Queue<_SlotWaiter> _waiters = Queue();

  int get occupiedSlots => _occupied;
  int get peakOccupiedSlots => _peak;

  Future<_RangeLease> _acquire(
    CancelToken token, {
    required bool Function() isCurrent,
  }) async {
    if (token.isCancelled) throw const CdnRangeCancelled();
    if (_occupied < CdnProxyDefaults.maxConcurrent) return _grant();
    final waiter = _SlotWaiter(token, isCurrent);
    _waiters.add(waiter);
    unawaited(token.whenCancel.then((_) {
      if (!waiter.result.isCompleted) {
        _waiters.remove(waiter);
        waiter.result.completeError(const CdnRangeCancelled());
      }
    }));
    return waiter.result.future;
  }

  _RangeLease _grant() {
    _occupied++;
    _peak = max(_peak, _occupied);
    return _RangeLease(() {
      _occupied--;
      while (_waiters.isNotEmpty) {
        // Re-evaluate priority: a queued prefetch can become the current part.
        final waiter = _waiters.firstWhere(
          (waiter) => waiter.isCurrent(),
          orElse: () => _waiters.first,
        );
        _waiters.remove(waiter);
        if (waiter.result.isCompleted) continue;
        if (waiter.token.isCancelled) {
          waiter.result.completeError(const CdnRangeCancelled());
          continue;
        }
        waiter.result.complete(_grant());
        break;
      }
    });
  }
}

class _SlotWaiter {
  _SlotWaiter(this.token, this.isCurrent);
  final CancelToken token;
  final bool Function() isCurrent;
  final Completer<_RangeLease> result = Completer();
}

class _RangeLease {
  _RangeLease(this._release);
  void Function()? _release;
  void release() {
    final action = _release;
    _release = null;
    action?.call();
  }
}

/// A completed body still owns this storage until its last byte is consumed.
class _StreamingChunk {
  _StreamingChunk(this.id, this.range, this.lease, this.expansion)
      : _bytes = Uint8List(range.length);
  final int id;
  final CdnByteRange range;
  final _RangeLease lease;
  Uint8List? _bytes;
  Uint8List get bytes => _bytes!;
  int get capacity => _bytes?.length ?? 0;
  bool expansion;
  bool running = false;
  bool complete = false;
  bool released = false;
  bool empty = false;
  int accepted = 0;
  int delivered = 0;

  int get outputLength => empty ? 0 : range.length;
  int get readable => complete ? accepted : min(accepted, outputLength - 1);
  void release() {
    if (released) return;
    released = true;
    _bytes = null;
    lease.release();
  }
}

class _ReadRequest {
  _ReadRequest(this.session, this.range, {this.probe = false})
      : ranges = (probe ? [range] : splitCdnRange(range)).iterator,
        single = probe || range.length <= CdnProxyDefaults.chunkSize;
  final CdnRangeSession session;
  final CdnByteRange range;
  final bool probe;
  final bool single;
  final Iterator<CdnByteRange> ranges;
  final CancelToken cancelledToken = CancelToken();
  final Map<int, _StreamingChunk> chunks = {};
  final Set<CancelToken> attempts = {};
  final Set<Future<void>> work = {};
  Completer<void> changed = Completer();
  Future<void> retryQueue = Future.value();
  Object? error;
  Future<void>? cleanup;
  bool cancelled = false;
  bool admitting = false;
  bool exhausted = false;
  bool degraded = false;
  int nextId = 0;
  int readingId = 0;
  int workerLimit = 1;
  int running = 0;
  int expansionCredits = 0;

  void signal() {
    final previous = changed;
    changed = Completer();
    previous.complete();
  }

  void check() {
    if (error != null) throw error!;
    if (cancelled) throw const CdnRangeCancelled();
    session._checkActive();
  }

  Future<T> wait<T>(Future<T> future) async {
    check();
    final result = await Future.any<T>([
      future,
      cancelledToken.whenCancel.then<T>((_) {
        check();
        throw const CdnRangeCancelled();
      }),
    ]);
    check();
    return result;
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

  void track(Future<void> task) {
    work.add(task);
    session._inFlight.add(task);
    // All tasks handle their errors before reaching this ownership boundary.
    unawaited(task.then((_) {
      work.remove(task);
      session._inFlight.remove(task);
    }));
  }

  void fail(Object cause) {
    if (cancelled) return;
    error = session._safeError(cause);
    cancel();
  }

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    cancelledToken.cancel('CDN read cancelled');
    for (final attempt in attempts.toList()) {
      attempt.cancel('CDN read cancelled');
    }
    signal();
    cleanup = () async {
      await Future.wait(work.toList());
      for (final chunk in chunks.values) {
        chunk.release();
      }
      chunks.clear();
    }();
  }

  int get maxWorkers => cdnRangeConcurrency(range.length);

  void headersReady() {
    if (!single && !degraded && workerLimit < maxWorkers) {
      workerLimit++;
      expansionCredits++;
    }
    pump();
  }

  bool retire(_StreamingChunk chunk) {
    final stopExpansion = !degraded && workerLimit < maxWorkers;
    degraded = true;
    final shouldRetire = chunk.expansion || stopExpansion;
    chunk.expansion = false;
    if (shouldRetire && workerLimit > 1) {
      workerLimit--;
      return true;
    }
    return false;
  }

  void pump() {
    if (cancelled) return;
    // Existing buffers always run before requesting any further admission.
    for (final chunk in chunks.values) {
      if (running >= workerLimit) break;
      if (chunk.running || chunk.complete) continue;
      chunk.running = true;
      running++;
      track(session._download(this, chunk));
    }
    if (!admitting && !exhausted && chunks.length < workerLimit) {
      if (!ranges.moveNext()) {
        exhausted = true;
        signal();
        return;
      }
      final range = ranges.current;
      final id = nextId++;
      final expansion = expansionCredits > 0;
      if (expansion) expansionCredits--;
      admitting = true;
      track(_admit(id, range, expansion));
    }
  }

  Future<void> _admit(int id, CdnByteRange range, bool expansion) async {
    _RangeLease? lease;
    try {
      lease = await session.budget._acquire(
        cancelledToken,
        isCurrent: () => id == readingId,
      );
      check();
      chunks[id] = _StreamingChunk(id, range, lease, expansion);
      lease = null;
      signal();
    } catch (cause) {
      if (!cancelled) fail(cause);
    } finally {
      lease?.release();
      admitting = false;
      pump();
    }
  }
}

/// Pure Dart ordered streaming downloader. One HTTP read is one failure domain.
class CdnRangeSession {
  CdnRangeSession({
    required this.source,
    required this.uri,
    required Map<String, String> headers,
    CdnRangeBudget? budget,
    this.onError,
    Duration Function()? retryJitter,
    this.diagnostics,
  })  : headers = Map.unmodifiable(headers),
        budget = budget ?? _sharedBudget,
        retryJitter = retryJitter ??
            (() => Duration(milliseconds: 200 + _random.nextInt(300)));

  static final CdnRangeBudget _sharedBudget = CdnRangeBudget();
  static final Random _random = Random();
  final CdnRangeSource source;
  final Uri uri;
  final Map<String, String> headers;
  final CdnRangeBudget budget;
  final void Function(Object)? onError;
  final Duration Function() retryJitter;
  final CdnRangeDiagnostics? diagnostics;
  final Set<_ReadRequest> _requests = {};
  final Set<Future<void>> _inFlight = {};
  int? _length;
  String? _contentType;
  CdnEntityTag? _entityTag;
  DateTime? _lastModified;
  bool _identitySupplemented = false;
  Object? _failure;
  bool _closed = false;
  bool _sourceClosed = false;
  Future<void>? _initializing;
  Future<void>? _closing;

  int get totalLength =>
      _length ?? (throw StateError('Source not initialized'));
  String? get contentType => _contentType;
  int get activeDownloadCount =>
      _requests.fold(0, (count, request) => count + request.running);
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
    final request =
        _ReadRequest(this, const CdnByteRange(start: 0, end: 0), probe: true);
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
    final request = _ReadRequest(this, range);
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
    final range = request.range;
    if (!request.probe &&
        (range.start < 0 ||
            range.end < range.start ||
            range.end >= totalLength)) {
      throw const CdnRangeNotSatisfiable();
    }
    _requests.add(request);
    request.pump();
    try {
      while (true) {
        request.check();
        final chunk = request.chunks[request.readingId];
        if (chunk == null) {
          if (request.exhausted && request.readingId == request.nextId) break;
          await request.wait(request.changed.future);
          continue;
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
          request.pump();
          continue;
        }
        await request.wait(request.changed.future);
      }
    } finally {
      request.cancel();
      await request.cleanup;
      _requests.remove(request);
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
        Object? failed;
        Duration delay = Duration.zero;
        var serializeDelay = false;
        var retire = false;
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
          if (!request.probe && response.totalLength <= chunk.range.end) {
            throw const CdnRangeFailure('CDN 返回的资源范围不一致');
          }
          if (request.probe && response.totalLength == 0) {
            chunk.empty = true;
            chunk.complete = true;
          } else {
            request.headersReady();
            bodyPhase = true;
            unreadBody = null;
            await _consume(response.stream, request, chunk, token, trace);
            chunk.complete = true;
          }
          request.signal();
          outcome = 'success';
          return;
        } catch (cause) {
          trace?.failed(cause);
          if (request.cancelled) request.check();
          if (cause is CdnResourceChanged) {
            failed = cause;
          } else if (request.single) {
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
            } else {
              retire = request.retire(chunk);
              if (!retire && chunk.id != request.readingId) {
                delay = retryJitter();
                serializeDelay = true;
              }
            }
          } else if (bodyPhase &&
              cause is! CdnRangeFailure &&
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
                  concurrency: request.workerLimit);
            }
          }
        } finally {
          token.cancel('CDN attempt finished');
          if (unreadBody != null) await _discard(unreadBody);
          request.attempts.remove(token);
          if (trace != null) diagnostics?.finish(trace, outcome);
        }
        if (failed != null) throw failed;
        if (retire) {
          return; // Requeue the owned buffer; next worker resets budget.
        }
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
              occupiedSlots: budget.occupiedSlots,
              activeReaders: _requests.length);
          request.fail(cause);
        }
      }
    } finally {
      chunk.running = false;
      request.running--;
      request.signal();
      request.pump();
    }
  }

  Future<void> _consume(
    Stream<Uint8List> stream,
    _ReadRequest request,
    _StreamingChunk chunk,
    CancelToken token,
    CdnRangeTrace? trace,
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
      token.cancel('CDN body finished');
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
    if ((_entityTag != null &&
            _entityTag!.headerValue != response.entityTag?.headerValue) ||
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
        occupiedSlots: budget.occupiedSlots, activeReaders: _requests.length);
    onError?.call(_failure!);
  }

  void _closeSource() {
    if (_sourceClosed) return;
    _sourceClosed = true;
    source.close();
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    for (final request in _requests.toList()) {
      request.cancel();
    }
    _closeSource();
    await Future.wait<void>([
      ..._inFlight,
      for (final request in _requests.toList())
        if (request.cleanup != null) request.cleanup!,
    ]);
    _requests.clear();
  }
}

class _IncompleteBody implements Exception {
  const _IncompleteBody();
}
