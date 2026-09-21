import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../api_result.dart';
import 'cdn_proxy_constants.dart';
import 'cdn_proxy_errors.dart';
import 'cdn_range_source.dart';
import 'cdn_range_policy.dart';

/// A slot is held until its data is consumed, not merely until HTTP finishes.
/// Consequently active downloads plus queued chunks never exceed three chunks.
class CdnRangeBudget {
  int _occupied = 0;
  int _peak = 0;
  final Queue<_SlotWaiter> _waiters = Queue<_SlotWaiter>();

  int get occupiedSlots => _occupied;
  int get peakOccupiedSlots => _peak;

  Future<_RangeLease> _acquire(CancelToken token) async {
    if (token.isCancelled) throw const CdnRangeCancelled();
    if (_occupied < CdnProxyDefaults.maxConcurrent) return _grant();
    final waiter = _SlotWaiter(token);
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
    if (_occupied > _peak) _peak = _occupied;
    return _RangeLease(() {
      _occupied--;
      while (_waiters.isNotEmpty) {
        final waiter = _waiters.removeFirst();
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
  _SlotWaiter(this.token);
  final CancelToken token;
  final Completer<_RangeLease> result = Completer<_RangeLease>();
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

class _ReadRequest {
  bool cancelled = false;
  final Set<CancelToken> tokens = {};
  final Set<_DownloadedChunk> chunks = {};
  final Set<Completer<void>> _retryWaiters = {};

  Future<void> waitForRetry(Duration delay) async {
    if (cancelled) throw const CdnRangeCancelled();
    final waiter = Completer<void>();
    _retryWaiters.add(waiter);
    final timer = Timer(delay, () {
      if (!waiter.isCompleted) waiter.complete();
    });
    try {
      await waiter.future;
      if (cancelled) throw const CdnRangeCancelled();
    } finally {
      timer.cancel();
      _retryWaiters.remove(waiter);
    }
  }

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    for (final token in tokens.toList()) {
      token.cancel('CDN range cancelled');
    }
    for (final waiter in _retryWaiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    for (final chunk in chunks.toList()) {
      chunk.release();
    }
    chunks.clear();
  }
}

class _DownloadedChunk {
  _DownloadedChunk(this.bytes, this.totalLength, this.contentType, this._lease);
  final Uint8List bytes;
  final int totalLength;
  final String? contentType;
  final _RangeLease _lease;
  void release() => _lease.release();
}

class _ChunkOutcome {
  const _ChunkOutcome.success(this.chunk) : error = null;
  const _ChunkOutcome.failure(this.error) : chunk = null;
  final _DownloadedChunk? chunk;
  final Object? error;
  _DownloadedChunk getOrThrow() {
    if (error != null) throw error!;
    return chunk!;
  }
}

/// Testable byte transport; no sockets or native player are needed to test it.
class CdnRangeSession {
  CdnRangeSession({
    required this.source,
    required this.uri,
    required Map<String, String> headers,
    CdnRangeBudget? budget,
    this.onError,
    this.idleTimeout = CdnProxyDefaults.idleTimeout,
    this.retryDelay = CdnProxyDefaults.retryDelay,
  })  : headers = Map.unmodifiable(headers),
        budget = budget ?? _sharedBudget;

  static final CdnRangeBudget _sharedBudget = CdnRangeBudget();
  final CdnRangeSource source;
  final Uri uri;
  final Map<String, String> headers;
  final CdnRangeBudget budget;
  final void Function(Object)? onError;
  final Duration idleTimeout;
  final Duration retryDelay;
  final Set<_ReadRequest> _requests = {};
  final Set<Future<_ChunkOutcome>> _inFlight = {};
  int? _length;
  String? _contentType;
  Object? _failure;
  bool _closed = false;
  Future<void>? _closing;

  int get totalLength =>
      _length ?? (throw StateError('Source not initialized'));
  String? get contentType => _contentType;

  Future<void> initialize() async {
    _checkActive();
    if (_length != null) return;
    final request = _ReadRequest();
    _requests.add(request);
    try {
      final chunk = (await _fetch(
        const CdnByteRange(start: 0, end: 0),
        request,
        probe: true,
      ))
          .getOrThrow();
      _length = chunk.totalLength;
      _contentType = chunk.contentType;
      chunk.release();
      _checkActive();
    } catch (error) {
      if (!_closed && !request.cancelled) _fail(error);
      rethrow;
    } finally {
      request.cancel();
      _requests.remove(request);
    }
  }

  Stream<Uint8List> read(CdnByteRange range) {
    final request = _ReadRequest();
    StreamSubscription<Uint8List>? subscription;
    late final StreamController<Uint8List> controller;
    controller = StreamController<Uint8List>(
      sync: true,
      onListen: () {
        subscription = _read(range, request).listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        // Cancel HTTP before waiting for the async generator to reach finally.
        request.cancel();
        try {
          await subscription?.cancel();
        } on CdnRangeCancelled {
          // An interrupted await inside an async generator can complete its
          // cancellation future with this expected control-flow exception.
        }
      },
    );
    return controller.stream;
  }

  Stream<Uint8List> _read(CdnByteRange range, _ReadRequest request) async* {
    _checkActive();
    if (range.start < 0 ||
        range.end < range.start ||
        range.end >= totalLength) {
      throw const CdnRangeNotSatisfiable();
    }
    _requests.add(request);
    final pending = Queue<Future<_ChunkOutcome>>();
    final ranges = splitCdnRange(range).iterator;
    void fillWindow() {
      while (!request.cancelled &&
          pending.length < CdnProxyDefaults.maxConcurrent &&
          ranges.moveNext()) {
        pending.add(_fetch(ranges.current, request));
      }
    }

    try {
      fillWindow();
      while (pending.isNotEmpty) {
        final chunk = (await pending.removeFirst()).getOrThrow();
        try {
          _checkActive();
          if (request.cancelled) throw const CdnRangeCancelled();
          yield chunk.bytes;
        } finally {
          request.chunks.remove(chunk);
          chunk.release();
        }
        fillWindow();
      }
    } catch (error) {
      if (!_closed && !request.cancelled) _fail(error);
      rethrow;
    } finally {
      request.cancel();
      for (final future in pending) {
        (await future).chunk?.release();
      }
      _requests.remove(request);
    }
  }

  Future<_ChunkOutcome> _fetch(CdnByteRange range, _ReadRequest request,
      {bool probe = false}) {
    final future = _download(range, request, probe: probe);
    _inFlight.add(future);
    unawaited(future.then((_) => _inFlight.remove(future)));
    return future;
  }

  Future<_ChunkOutcome> _download(CdnByteRange range, _ReadRequest request,
      {required bool probe}) async {
    _RangeLease? lease;
    try {
      while (true) {
        final token = CancelToken();
        request.tokens.add(token);
        Stream<Uint8List>? unreadBody;
        try {
          _checkActive();
          if (request.cancelled) throw const CdnRangeCancelled();
          // Keep this range's slot across retries. Releasing it could allow
          // later ranges to fill the budget and block this ordered reader.
          lease ??= await budget._acquire(token);
          _checkActive();
          if (request.cancelled) throw const CdnRangeCancelled();
          final response = (await source.open(
            uri: uri,
            headers: headers,
            start: range.start,
            end: range.end,
            cancelToken: token,
          ))
              .getOrThrow();
          unreadBody = response.stream;
          // The data source has already cancelled an empty resource's probe body.
          if (probe && response.totalLength == 0) {
            final chunk =
                _DownloadedChunk(Uint8List(0), 0, response.contentType, lease);
            lease = null;
            request.chunks.add(chunk);
            return _ChunkOutcome.success(chunk);
          }
          // Keep cross-request resource consistency in the playback session.
          final total = response.totalLength;
          if (total <= range.end || (!probe && total != _length)) {
            throw const CdnRangeFailure('CDN 返回的资源范围或大小不一致');
          }
          unreadBody = null;
          final bytes = await _collect(response.stream, range.length, token);
          _checkActive();
          if (request.cancelled) throw const CdnRangeCancelled();
          final chunk =
              _DownloadedChunk(bytes, total, response.contentType, lease);
          lease = null;
          request.chunks.add(chunk);
          return _ChunkOutcome.success(chunk);
        } catch (error) {
          token.cancel('CDN range attempt stopped');
          if (request.cancelled || _closed || !_isTimeout(error)) {
            rethrow;
          }
        } finally {
          // Each attempt discards partial bytes and releases its connection
          // before retrying the same range with a fresh cancellation token.
          if (unreadBody != null) {
            try {
              await unreadBody.listen((_) {}, onError: (Object _) {}).cancel();
            } catch (_) {
              // Cancellation may race a remote disconnect.
            }
          }
          request.tokens.remove(token);
        }
        await request.waitForRetry(retryDelay);
      }
    } catch (error) {
      return _ChunkOutcome.failure(
        request.cancelled || _closed
            ? const CdnRangeCancelled()
            : error is CdnRangeFailure
                ? error
                : error is FailureInfo
                    ? CdnRangeFailure(error.displayMessage)
                    : const CdnRangeFailure('CDN 分片读取失败，请重试'),
      );
    } finally {
      lease?.release();
    }
  }

  static bool _isTimeout(Object error) {
    if (error is TimeoutException) return true;
    if (error is CdnRequestFailure) return error.isTimeout;
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          true,
        DioExceptionType.unknown => error.error is TimeoutException,
        _ => false,
      };
    }
    return false;
  }

  Future<Uint8List> _collect(
    Stream<Uint8List> stream,
    int expected,
    CancelToken token,
  ) async {
    final bytes = Uint8List(expected);
    var count = 0;
    final done = Completer<Uint8List>();
    StreamSubscription<Uint8List>? subscription;
    void fail(Object error) {
      if (!done.isCompleted) done.completeError(error);
    }

    subscription = stream.timeout(idleTimeout).listen((data) {
      if (done.isCompleted) return;
      if (count + data.length > expected) {
        fail(const CdnRangeFailure('CDN 分片超过请求范围'));
        return;
      }
      bytes.setRange(count, count + data.length, data);
      count += data.length;
    }, onError: (Object error) {
      if (done.isCompleted) return;
      // Preserve the typed cause until the retry policy has inspected it.
      // The download boundary sanitizes any terminal error before reporting it.
      fail(error);
    }, onDone: () {
      if (done.isCompleted) return;
      if (count != expected) {
        fail(const CdnRangeFailure('CDN 分片数据不完整'));
      } else {
        done.complete(bytes);
      }
    });
    unawaited(token.whenCancel.then((_) => fail(const CdnRangeCancelled())));
    if (token.isCancelled) fail(const CdnRangeCancelled());
    try {
      return await done.future;
    } finally {
      await subscription.cancel();
    }
  }

  void _checkActive() {
    if (_closed) throw const CdnRangeCancelled();
    if (_failure != null) throw _failure!;
  }

  void _fail(Object error) {
    if (_failure != null || _closed || error is CdnRangeCancelled) return;
    // Do not propagate raw HTTP errors, which can contain signed CDN URLs.
    final safeError = error is CdnRangeFailure
        ? error
        : const CdnRangeFailure('CDN 分片读取失败，请重试');
    _failure = safeError;
    for (final request in _requests.toList()) {
      request.cancel();
    }
    onError?.call(safeError);
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    for (final request in _requests.toList()) {
      request.cancel();
    }
    source.close();
    await Future.wait(_inFlight.toList());
    _requests.clear();
  }
}
