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
      this.idleTimeout = CdnProxyDefaults.idleTimeout})
      : _source = source;

  final CdnRangeSource _source;
  final CdnRangeBudget? budget;
  final void Function(Object)? onError;
  final Duration idleTimeout;
  final Set<Socket> _sockets = {};
  final String _path = '/${const Uuid().v4()}/media';
  CdnRangeSession? _session;
  HttpServer? _server;
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
          } catch (_) {
            // Already disconnected.
          }
        }
      }
    } finally {
      socket?.destroy();
      await cancelBody();
      try {
        await incoming?.cancel();
      } catch (_) {
        // Already disconnected.
      } finally {
        _sockets.remove(socket);
      }
    }
  }

  @override
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
