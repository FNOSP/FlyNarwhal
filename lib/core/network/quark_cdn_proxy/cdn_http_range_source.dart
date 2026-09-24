import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../api_result.dart';
import 'cdn_proxy_constants.dart';
import 'cdn_proxy_errors.dart';
import 'cdn_range_source.dart';
import 'cdn_request_headers.dart';

/// An isolated range transport. The scheduler alone decides whether to retry.
class CdnHttpRangeSource implements CdnRangeSource {
  CdnHttpRangeSource({
    this.requestTimeout = CdnProxyDefaults.requestTimeout,
    HttpClientAdapter? adapter,
  }) : _dio = Dio(BaseOptions(
          responseType: ResponseType.stream,
          followRedirects: true,
        )) {
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(requestTimeout, 'requestTimeout');
    }
    // Range offsets describe wire bytes; transparent decompression changes them.
    _dio.httpClientAdapter = adapter ??
        IOHttpClientAdapter(
          createHttpClient: () => HttpClient()..autoUncompress = false,
        );
  }

  final Dio _dio;
  final Duration requestTimeout;
  final Set<_HttpAttempt> _attempts = {};
  bool _closed = false;

  /// Configuration and resource counts for focused transport tests.
  Dio get dio => _dio;
  int get activeAttemptCount => _attempts.length;

  @override
  Future<ApiResult<CdnRangeResponse>> open({
    required Uri uri,
    required Map<String, String> headers,
    required int start,
    required int end,
    required CancelToken cancelToken,
    String? ifRangeEtag,
  }) async {
    if (_closed || cancelToken.isCancelled) {
      return ResultFailure(_cancelled(CdnRequestFailurePhase.request));
    }
    if ((uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
      return ResultFailure(_protocol('Invalid CDN URL'));
    }
    if (start < 0 || end < start || end - start >= CdnProxyDefaults.chunkSize) {
      return ResultFailure(_protocol('Invalid CDN byte range'));
    }
    if (ifRangeEtag != null &&
        (_parseEntityTag(ifRangeEtag)?.strongValue != ifRangeEtag)) {
      return ResultFailure(_protocol('Invalid CDN If-Range validator'));
    }
    final requestHeaders = normalizeCdnRequestHeaders(headers)
      ..['range'] = 'bytes=$start-$end'
      ..['accept-encoding'] = 'identity';
    if (ifRangeEtag != null) requestHeaders['if-range'] = ifRangeEtag;
    late final _HttpAttempt attempt;
    attempt = _HttpAttempt(
        cancelToken, requestTimeout, () => _attempts.remove(attempt));
    _attempts.add(attempt);
    try {
      final options = Options(
        method: 'GET',
        headers: requestHeaders,
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
      ).compose(_dio.options, uri.toString(), cancelToken: attempt.token);
      // Dio's default streamed-response transformer eagerly listens without
      // propagating pause to the socket. Own the adapter stream directly so
      // downstream backpressure cannot create a second unbounded body queue.
      final pending = _dio.httpClientAdapter
          .fetch(options, null, attempt.token.whenCancel)
          .then((body) {
        if (attempt.ended) {
          unawaited(_discardResponse(body));
        } else {
          attempt.response = body;
        }
        return body;
      });
      final result =
          await Future.any<Object>([pending, attempt.stopped.future]);
      if (cancelToken.isCancelled) throw _cancelled(attempt.phase);
      if (attempt.ended) throw await attempt.stopped.future;
      if (result is CdnRequestFailure) throw result;
      attempt.phase = CdnRequestFailurePhase.headers;
      final body = result as ResponseBody;
      final parsed = _parseResponse(body, start: start, end: end);
      if (parsed.totalLength == 0) {
        await attempt.finish();
        return Success(parsed);
      }
      return Success(CdnRangeResponse(
        totalLength: parsed.totalLength,
        contentType: parsed.contentType,
        entityTag: parsed.entityTag,
        lastModified: parsed.lastModified,
        stream: attempt.readBody(),
      ));
    } catch (error) {
      final failure = attempt.failureFor(error);
      await attempt.finish();
      return ResultFailure(failure);
    }
  }

  CdnRangeResponse _parseResponse(ResponseBody response,
      {required int start, required int end}) {
    String? header(String name) {
      final values = response.headers.entries
          .where((entry) => entry.key.toLowerCase() == name)
          .expand((entry) => entry.value)
          .toList();
      return values.isEmpty ? null : values.join(', ');
    }

    final contentType = header('content-type');
    if (start == 0 &&
        end == 0 &&
        response.statusCode == 416 &&
        header('content-range')?.trim() == 'bytes */0') {
      return CdnRangeResponse(
          totalLength: 0,
          contentType: contentType,
          stream: const Stream<Uint8List>.empty());
    }
    if (response.statusCode != 206) {
      final message = 'CDN 分片请求失败（HTTP ${response.statusCode}）';
      throw CdnRequestFailure(
        message: message,
        displayMessage: message,
        kind: response.statusCode >= 400
            ? CdnRequestFailureKind.httpStatus
            : CdnRequestFailureKind.protocol,
        phase: CdnRequestFailurePhase.headers,
        statusCode: response.statusCode,
      );
    }
    final encoding = header('content-encoding')?.trim().toLowerCase();
    if (encoding != null && encoding != 'identity') {
      throw _protocol('CDN 返回了不支持的压缩数据');
    }
    final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
        .firstMatch(header('content-range')?.trim() ?? '');
    if (match == null) throw _protocol('CDN 缺少有效的资源范围');
    final responseStart = int.tryParse(match[1]!);
    final responseEnd = int.tryParse(match[2]!);
    final total = int.tryParse(match[3]!);
    if (responseStart != start ||
        responseEnd != end ||
        total == null ||
        total <= end) {
      throw _protocol('CDN 返回的资源范围或大小不一致');
    }
    final contentLength = header('content-length');
    if (contentLength != null &&
        int.tryParse(contentLength) != end - start + 1) {
      throw _protocol('CDN 返回的分片长度不一致');
    }
    // Error-page validators never reach this point. Only validated media
    // responses can establish or challenge the session's resource identity.
    final etagValue = header('etag');
    final entityTag =
        etagValue == null ? null : _parseEntityTag(etagValue.trim());
    if (etagValue != null && entityTag == null) {
      throw _protocol('CDN 返回了无效的资源标识');
    }
    DateTime? lastModified;
    final modified = header('last-modified');
    if (modified != null) {
      try {
        lastModified = HttpDate.parse(modified).toUtc();
      } catch (_) {
        throw _protocol('CDN 返回了无效的资源修改时间');
      }
    }
    return CdnRangeResponse(
      totalLength: total,
      contentType: contentType,
      entityTag: entityTag,
      lastModified: lastModified,
      stream: response.stream,
    );
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final attempt in _attempts.toList()) {
      attempt.stop(_cancelled(attempt.phase));
    }
    _dio.close(force: true);
  }
}

CdnEntityTag? _parseEntityTag(String value) {
  final match =
      RegExp(r'^(W/)?"([\x21\x23-\x7e\x80-\xff]*)"$').firstMatch(value);
  if (match == null) return null;
  return CdnEntityTag(opaqueValue: match[2]!, isWeak: match[1] != null);
}

CdnRequestFailure _protocol(String message) => CdnRequestFailure(
    message: message,
    displayMessage: message,
    kind: CdnRequestFailureKind.protocol,
    phase: CdnRequestFailurePhase.headers);

CdnRequestFailure _cancelled(CdnRequestFailurePhase phase) => CdnRequestFailure(
    message: 'Request was cancelled',
    displayMessage: '请求已取消',
    kind: CdnRequestFailureKind.cancelled,
    phase: phase);

void _closeResponse(ResponseBody response) {
  try {
    // We own the raw adapter response instead of Dio's response transformer.
    // Dio exposes the adapter's onClose hook only through this internal method;
    // subscription.cancel alone does not invoke that hook for custom adapters.
    // ignore: invalid_use_of_internal_member
    response.close();
  } catch (_) {
    // Stream cancellation below must still release the response if its hook fails.
  }
}

Future<void> _discardResponse(ResponseBody response) async {
  _closeResponse(response);
  try {
    await response.stream.listen((_) {}, onError: (Object _) {}).cancel();
  } catch (_) {
    // A cancellation may race the peer closing or an already-owned stream.
  }
}

/// One deadline covers obtaining headers and the entire (possibly paused) body.
class _HttpAttempt {
  _HttpAttempt(this.caller, Duration timeout, this.onFinished) {
    _deadline = Timer(timeout, () {
      stop(caller.isCancelled
          ? _cancelled(phase)
          : CdnRequestFailure(
              message: 'CDN request deadline exceeded',
              displayMessage: 'CDN 请求超时',
              phase: phase,
              isTimeout: true,
            ));
    });
    _callerCancellation = caller.whenCancel.asStream().listen((_) {
      stop(_cancelled(phase));
    });
    if (caller.isCancelled) stop(_cancelled(phase));
  }

  final CancelToken caller;
  final CancelToken token = CancelToken();
  final void Function() onFinished;
  final Completer<CdnRequestFailure> stopped = Completer();
  CdnRequestFailurePhase phase = CdnRequestFailurePhase.request;
  ResponseBody? response;
  late final Timer _deadline;
  StreamSubscription<DioException>? _callerCancellation;
  StreamSubscription<Uint8List>? _subscription;
  StreamController<Uint8List>? _controller;
  Future<void>? _finishing;
  bool ended = false;

  CdnRequestFailure failureFor(Object error) {
    if (caller.isCancelled) return _cancelled(phase);
    if (error is CdnRequestFailure) return error;
    if (error is DioException && error.type == DioExceptionType.cancel) {
      return _cancelled(phase);
    }
    final isTimeout = error is TimeoutException ||
        error is DioException &&
            (error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.sendTimeout ||
                error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.unknown &&
                    error.error is TimeoutException);
    return CdnRequestFailure(
      message: 'CDN network request failed',
      displayMessage: 'CDN 网络请求失败',
      phase: phase,
      isTimeout: isTimeout,
    );
  }

  Stream<Uint8List> readBody() {
    phase = CdnRequestFailurePhase.body;
    final body = response!;
    late final StreamController<Uint8List> controller;
    controller = StreamController<Uint8List>(
      sync: true,
      onListen: () {
        if (ended) return;
        _subscription = body.stream.listen((bytes) {
          if (!ended) controller.add(bytes);
        }, onError: (Object error) {
          stop(failureFor(error));
        }, onDone: () {
          if (ended) return;
          unawaited(finish());
          unawaited(controller.close());
        });
      },
      onPause: () => _subscription?.pause(),
      onResume: () => _subscription?.resume(),
      onCancel: () => finish(),
    );
    _controller = controller;
    return controller.stream;
  }

  void stop(CdnRequestFailure failure) {
    if (ended) return;
    ended = true;
    if (caller.isCancelled) failure = _cancelled(phase);
    if (!stopped.isCompleted) stopped.complete(failure);
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      controller.addError(failure);
      unawaited(controller.close());
    }
    unawaited(finish());
  }

  Future<void> finish() => _finishing ??= _finish();
  Future<void> _finish() async {
    ended = true;
    _deadline.cancel();
    token.cancel('CDN attempt finished');
    onFinished();
    await _callerCancellation?.cancel();
    final subscription = _subscription;
    if (subscription != null) {
      if (response case final body?) _closeResponse(body);
      try {
        await subscription.cancel();
      } catch (_) {
        // All source errors are handled before disconnecting the stream.
      }
    } else if (response case final body?) {
      await _discardResponse(body);
    }
  }
}
