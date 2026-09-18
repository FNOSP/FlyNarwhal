import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../../data/datasources/remote/cdn_range_remote_data_source.dart';
import 'cdn_range_policy.dart';

class CdnRangeCancelled implements Exception {
  const CdnRangeCancelled();
}

class CdnRangeFailure implements Exception {
  const CdnRangeFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

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
    if (_occupied < cdnRangeMaxConcurrent) return _grant();
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
  void cancel() {
    if (cancelled) return;
    cancelled = true;
    for (final token in tokens.toList()) {
      token.cancel('CDN range cancelled');
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
    this.idleTimeout = const Duration(seconds: 20),
  })  : headers = Map.unmodifiable(headers),
        budget = budget ?? _sharedBudget;

  static final CdnRangeBudget _sharedBudget = CdnRangeBudget();
  final CdnRangeSource source;
  final Uri uri;
  final Map<String, String> headers;
  final CdnRangeBudget budget;
  final void Function(Object)? onError;
  final Duration idleTimeout;
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
          pending.length < cdnRangeMaxConcurrent &&
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
    final token = CancelToken();
    request.tokens.add(token);
    _RangeLease? lease;
    Stream<Uint8List>? unreadBody;
    try {
      _checkActive();
      if (request.cancelled) throw const CdnRangeCancelled();
      lease = await budget._acquire(token);
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
      String? header(String name) {
        for (final entry in response.headers.entries) {
          if (entry.key.toLowerCase() == name) return entry.value.join(', ');
        }
        return null;
      }

      // An empty resource has no byte 0. It is metadata, never a download.
      if (probe &&
          response.statusCode == 416 &&
          header('content-range')?.trim() == 'bytes */0') {
        token.cancel('Empty source');
        final chunk =
            _DownloadedChunk(Uint8List(0), 0, header('content-type'), lease);
        lease = null;
        request.chunks.add(chunk);
        return _ChunkOutcome.success(chunk);
      }
      if (response.statusCode != 206) {
        throw CdnRangeFailure('CDN 分片请求失败（HTTP ${response.statusCode}）');
      }
      final encoding = header('content-encoding')?.trim().toLowerCase();
      if (encoding != null && encoding != 'identity') {
        throw const CdnRangeFailure('CDN 返回了不支持的压缩数据');
      }
      final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
          .firstMatch(header('content-range')?.trim() ?? '');
      if (match == null) throw const CdnRangeFailure('CDN 缺少有效的资源范围');
      final start = int.tryParse(match[1]!);
      final end = int.tryParse(match[2]!);
      final total = int.tryParse(match[3]!);
      if (start != range.start ||
          end != range.end ||
          total == null ||
          total <= range.end ||
          (!probe && total != _length)) {
        throw const CdnRangeFailure('CDN 返回的资源范围或大小不一致');
      }
      final contentLength = header('content-length');
      if (contentLength != null &&
          int.tryParse(contentLength) != range.length) {
        throw const CdnRangeFailure('CDN 返回的分片长度不一致');
      }
      unreadBody = null;
      final bytes = await _collect(response.stream, range.length, token);
      _checkActive();
      if (request.cancelled) throw const CdnRangeCancelled();
      final chunk =
          _DownloadedChunk(bytes, total, header('content-type'), lease);
      lease = null;
      request.chunks.add(chunk);
      return _ChunkOutcome.success(chunk);
    } catch (error) {
      token.cancel('CDN range stopped');
      return _ChunkOutcome.failure(
        request.cancelled || _closed
            ? const CdnRangeCancelled()
            : error is CdnRangeFailure
                ? error
                : const CdnRangeFailure('CDN 分片读取失败，请重试'),
      );
    } finally {
      // Invalid headers and empty files never enter _collect. Explicitly
      // cancel their bodies before returning the connection's budget slot.
      if (unreadBody != null) {
        try {
          await unreadBody.listen((_) {}, onError: (Object _) {}).cancel();
        } catch (_) {/* Cancellation may race a remote disconnect. */}
      }
      request.tokens.remove(token);
      lease?.release();
    }
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
      fail(const CdnRangeFailure('CDN 分片读取失败或超时'));
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

/// Only binds loopback. An unpredictable per-source path prevents reuse of an
/// old player URL after a quality/episode switch.
class QuarkCdnRangeService {
  QuarkCdnRangeService({CdnRangeSource? source, this.budget, this.onError})
      : _source = source ?? CdnRangeRemoteDataSource();

  final CdnRangeSource _source;
  final CdnRangeBudget? budget;
  final void Function(Object)? onError;
  final Set<Socket> _sockets = {};
  final String _path = '/${const Uuid().v4()}/media';
  CdnRangeSession? _session;
  HttpServer? _server;
  bool _opened = false;
  bool _closed = false;
  Future<void>? _closing;

  Future<Uri> open(
      {required Uri uri, required Map<String, String> headers}) async {
    if (_opened || _closed) throw StateError('CDN service cannot be reopened');
    _opened = true;
    if (!uri.hasAuthority || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const CdnRangeFailure('CDN 直链地址无效');
    }
    final session = CdnRangeSession(
      source: _source,
      uri: uri,
      headers: headers,
      budget: budget,
      onError: onError,
    );
    _session = session;
    await session.initialize();
    if (_closed) throw const CdnRangeCancelled();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    if (_closed) {
      await server.close(force: true);
      throw const CdnRangeCancelled();
    }
    _server = server;
    server.listen((request) => unawaited(_serve(request, session)));
    return Uri(
        scheme: 'http', host: '127.0.0.1', port: server.port, path: _path);
  }

  Future<void> _serve(HttpRequest request, CdnRangeSession session) async {
    final response = request.response;
    Socket? socket;
    StreamIterator<Uint8List>? body;
    StreamSubscription<Uint8List>? incoming;
    Future<void>? cancellingBody;
    Future<void> cancelBody() => cancellingBody ??= () async {
          try {
            await body?.cancel();
          } catch (_) {
            // The session has already reported download failures. A remote
            // disconnect racing that failure must not escape as an unhandled
            // cancellation error from this detached response.
          }
        }();
    try {
      if (_closed || request.uri.path != _path) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
        await response.close();
        return;
      }
      final total = session.totalLength;
      ResolvedCdnRange resolved;
      try {
        resolved = resolveCdnRange(
          request.method == 'HEAD'
              ? null
              : request.headers.value(HttpHeaders.rangeHeader),
          total,
        );
      } on CdnRangeNotSatisfiable {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$total');
        response.contentLength = 0;
        await response.close();
        return;
      }
      response.statusCode =
          resolved.partial ? HttpStatus.partialContent : HttpStatus.ok;
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      response.headers.set(HttpHeaders.contentTypeHeader,
          session.contentType ?? 'application/octet-stream');
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final range = resolved.range;
      response.contentLength = range?.length ?? 0;
      if (resolved.partial && range != null) {
        response.headers.set(HttpHeaders.contentRangeHeader,
            'bytes ${range.start}-${range.end}/$total');
      }
      if (request.method != 'HEAD' && range != null) {
        // FFmpeg keeps its old connection until the new Range response headers
        // arrive. That old reader may hold all three slots, so headers must not
        // wait for the first chunk (or even a free slot). HttpResponse.flush()
        // without body bytes does not write headers in dart:io. Detaching sends
        // and flushes the headers before returning the socket.
        response.persistentConnection = false;
        socket = await response.detachSocket(writeHeaders: true);
        if (_closed) throw const CdnRangeCancelled();
        _sockets.add(socket);
        body = StreamIterator(session.read(range));
        final connectedSocket = socket;
        void disconnect() {
          // A detached socket no longer inherits HttpResponse cancellation.
          // Explicitly stop the reader even while it is awaiting CDN bytes.
          connectedSocket.destroy();
          unawaited(cancelBody());
        }

        incoming = socket.listen((_) {},
            onError: (Object _) => disconnect(), onDone: disconnect);
        while (await body.moveNext()) {
          socket.add(body.current);
          // Preserve backpressure: keep the chunk's lease until it is written.
          await socket.flush();
        }
        await socket.close();
        return;
      }
      await response.close();
    } catch (_) {
      // Abort an already-started response instead of appending error text to
      // media bytes. Session errors reach the existing playback error UI.
      if (socket == null) {
        try {
          socket = await response.detachSocket(writeHeaders: false);
        } catch (_) {
          try {
            await response.close();
          } catch (_) {/* Already disconnected. */}
        }
      }
    } finally {
      socket?.destroy();
      await cancelBody();
      try {
        await incoming?.cancel();
      } catch (_) {/* Already disconnected. */} finally {
        _sockets.remove(socket);
      }
    }
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    final closingSession = _session?.close();
    for (final socket in _sockets.toList()) {
      socket.destroy();
    }
    await _server?.close(force: true);
    await closingSession;
    if (_session == null) _source.close();
  }
}
