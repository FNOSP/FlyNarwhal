import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'cdn_proxy.dart';
import 'cdn_proxy_constants.dart';
import 'cdn_range_policy.dart';
import 'cdn_range_session.dart';

/// Only binds loopback. An unpredictable per-source path prevents reuse of an
/// old player URL after a quality/episode switch.
class CdnProxyService implements CdnProxy {
  CdnProxyService(
      {required CdnRangeSource source,
      this.budget,
      this.onError,
      this.idleTimeout = CdnProxyDefaults.idleTimeout,
      this.retryDelay = CdnProxyDefaults.retryDelay,
      this.socketFlush,
      this.socketDetach})
      : _source = source;

  final CdnRangeSource _source;
  final CdnRangeBudget? budget;
  final void Function(Object)? onError;
  final Duration idleTimeout;
  final Duration retryDelay;

  /// Overrides only the downstream flush for deterministic cancellation tests.
  final Future<void> Function(Socket)? socketFlush;

  /// Allows a test to defer transferring ownership of a detached socket.
  final Future<Socket> Function(HttpResponse, bool writeHeaders)? socketDetach;
  final Set<_ResponseWriter> _writers = {};

  int get activeWriterCount => _writers.length;
  final String _path = '/${const Uuid().v4()}/media';
  CdnRangeSession? _session;
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _requestsSubscription;
  bool _opened = false;
  bool _closed = false;
  Future<void>? _closing;

  @override
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
      idleTimeout: idleTimeout,
      retryDelay: retryDelay,
      onError: (error) {
        for (final writer in _writers.toList()) {
          writer.cancel();
        }
        onError?.call(error);
      },
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
    _requestsSubscription =
        server.listen((request) => unawaited(_serve(request, session)));
    return Uri(
        scheme: 'http', host: '127.0.0.1', port: server.port, path: _path);
  }

  Future<void> _serve(HttpRequest request, CdnRangeSession session) async {
    final response = request.response;
    final writer = _ResponseWriter();
    _writers.add(writer);
    if (_closed) writer.cancel();
    Socket? socket;
    var detaching = false;
    try {
      writer.checkActive();
      if (request.uri.path != _path) {
        response.statusCode = HttpStatus.notFound;
        await writer.waitFor(response.close());
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
        await writer.waitFor(response.close());
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
        await writer.waitFor(response.close());
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
        detaching = true;
        final detached = socketDetach?.call(response, true) ??
            response.detachSocket(writeHeaders: true);
        socket = await writer.waitFor<Socket>(detached.then((socket) {
          // The underlying future may finish after cancellation won the race.
          // Transfer ownership even then so the late socket is destroyed.
          writer.attachSocket(socket);
          return socket;
        }));
        writer.checkActive();
        final body = StreamIterator(session.read(range));
        writer.attachBody(body);
        writer.incoming = socket.listen((_) {},
            onError: (Object _) => writer.cancel(), onDone: writer.cancel);
        while (await writer.waitFor(body.moveNext())) {
          writer.checkActive();
          socket.add(body.current);
          // Keep the lease until bytes are flushed, but let cancellation
          // release the reader without depending on a socket flush callback.
          await writer.waitFor(socketFlush?.call(socket) ?? socket.flush());
        }
        await writer.waitFor(socket.close());
        return;
      }
      await writer.waitFor(response.close());
    } catch (_) {
      // Abort an already-started response instead of appending error text to
      // media bytes. Session errors reach the existing playback error UI.
      if (socket == null && !detaching) {
        try {
          socket = await response.detachSocket(writeHeaders: false);
          writer.attachSocket(socket);
        } catch (_) {
          try {
            await writer.waitFor(response.close());
          } catch (_) {
            // Already disconnected.
          }
        }
      }
    } finally {
      await writer.finish();
      _writers.remove(writer);
      writer.done.complete();
    }
  }

  @override
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    // Stop dispatch before taking the writer snapshot. Detached responses must
    // be cancelled explicitly; HttpServer.close only owns attached sockets.
    final stopRequests = _requestsSubscription?.cancel();
    final writers = _writers.toList();
    for (final writer in writers) {
      writer.cancel();
    }
    final closingSession = _session?.close();
    final closingServer = _server?.close(force: true);
    if (_session == null) _source.close();
    await Future.wait<void>([
      if (stopRequests != null) stopRequests,
      if (closingSession != null) closingSession,
      if (closingServer != null) closingServer.then((_) {}),
      for (final writer in writers) writer.done.future,
    ]);
  }
}

/// Owns one response's downstream work independently of upstream downloads.
class _ResponseWriter {
  final done = Completer<void>();
  final _cancelled = Completer<void>();
  Socket? _socket;
  StreamIterator<Uint8List>? _body;
  StreamSubscription<Uint8List>? incoming;
  Future<void>? _cancellingBody;

  void checkActive() {
    if (_cancelled.isCompleted) throw const CdnRangeCancelled();
  }

  void attachSocket(Socket socket) {
    _socket = socket;
    if (_cancelled.isCompleted) socket.destroy();
  }

  void attachBody(StreamIterator<Uint8List> body) {
    _body = body;
    if (_cancelled.isCompleted) unawaited(_cancelBody());
  }

  Future<T> waitFor<T>(Future<T> operation) async {
    // Future.any keeps an error handler on operation after cancellation wins,
    // so a late flush error cannot escape into the application's zone.
    final result = await Future.any<T>([
      operation,
      _cancelled.future.then<T>((_) => throw const CdnRangeCancelled()),
    ]);
    checkActive();
    return result;
  }

  void cancel() {
    if (_cancelled.isCompleted) return;
    _cancelled.complete();
    unawaited(_cancelBody());
    _socket?.destroy();
  }

  Future<void> _cancelBody() {
    final body = _body;
    // Do not memoize a no-op: cancellation can precede attaching the reader.
    if (body == null) return Future<void>.value();
    return _cancellingBody ??= () async {
      try {
        await body.cancel();
      } catch (_) {
        // The session reports terminal errors; cancellation can race them.
      }
    }();
  }

  Future<void> finish() async {
    cancel();
    await _cancelBody();
    try {
      await incoming?.cancel();
    } catch (_) {
      // A peer disconnect can race cancellation of its incoming stream.
    }
  }
}
