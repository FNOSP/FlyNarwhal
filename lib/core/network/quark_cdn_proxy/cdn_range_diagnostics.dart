import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'cdn_proxy_errors.dart';

/// Enable in a diagnostic build without changing transport or retry policy.
const cdnRangeDiagnosticsEnabled =
    bool.fromEnvironment('FLYNARWHAL_CDN_DIAGNOSTICS');

/// Bounded in-memory recorder of request attempts. Range and session failures
/// send recent context to the injected logger; successful attempts stay in memory.
/// Never retain URLs, headers, exception messages or response bodies.
class CdnRangeDiagnostics {
  CdnRangeDiagnostics({required this.writeLog});

  final void Function(String message, {required bool failure}) writeLog;
  final String sessionId = DateTime.now().microsecondsSinceEpoch.toString();
  final Stopwatch _clock = Stopwatch()..start();
  final Queue<Map<String, Object?>> _recent = Queue();
  int _nextId = 0;
  bool _reported = false;

  CdnRangeTrace begin(
      {required int start, required int end, required bool probe}) {
    return CdnRangeTrace._(
        ++_nextId, start, end, probe, _clock.elapsedMilliseconds);
  }

  void finish(CdnRangeTrace trace, String outcome) {
    _recent.add(trace.snapshot(outcome));
    while (_recent.length > 32) {
      _recent.removeFirst();
    }
  }

  void initialized(int totalLength) => _emit({
        'event': 'session_started',
        'totalBytes': totalLength,
      });

  void retrying(CdnRangeTrace trace,
          {required int attempt,
          required Duration delay,
          int? acceptedBytes,
          int? deliveredBytes,
          int? remainingBytes,
          int? concurrency}) =>
      _emit({
        'event': 'chunk_retry',
        'attempt': attempt,
        'retryDelayMs': delay.inMilliseconds,
        if (acceptedBytes != null) 'acceptedBytes': acceptedBytes,
        if (deliveredBytes != null) 'deliveredBytes': deliveredBytes,
        if (remainingBytes != null) 'remainingBytes': remainingBytes,
        if (concurrency != null) 'concurrency': concurrency,
        'chunk': trace.snapshot('retrying'),
      });

  void rangeFailed({required int occupiedSlots, required int activeReaders}) =>
      _emit({
        'event': 'range_failed',
        'occupiedSlots': occupiedSlots,
        'activeReaders': activeReaders,
        'recentChunks': _recent.toList(),
      }, failure: true);

  void failed({required int occupiedSlots, required int activeReaders}) {
    if (_reported) return;
    _reported = true;
    _emit({
      'event': 'session_failed',
      'occupiedSlots': occupiedSlots,
      'activeReaders': activeReaders,
      'recentChunks': _recent.toList(),
    }, failure: true);
  }

  void _emit(Map<String, Object?> event, {bool failure = false}) {
    try {
      writeLog(
          jsonEncode({
            'schema': 3,
            'session': sessionId,
            'elapsedMs': _clock.elapsedMilliseconds,
            ...event,
          }),
          failure: failure);
    } catch (_) {
      // Logging must never replace a playback result or delay cancellation.
    }
  }
}

class CdnRangeTrace {
  CdnRangeTrace._(this.id, this.start, this.end, this.probe, this.startedMs);

  final int id;
  final int start;
  final int end;
  final bool probe;
  final int startedMs;
  final Stopwatch _clock = Stopwatch()..start();
  // Traces begin after buffer admission, while awaiting response headers.
  String stage = 'headers';
  int? headersMs;
  int? totalBytes;
  int receivedBytes = 0;
  int? _lastDataMs;
  Map<String, Object?>? _error;

  void headersReceived(int length) {
    headersMs = _clock.elapsedMilliseconds;
    totalBytes = length;
    stage = 'body';
  }

  void received(int bytes) {
    receivedBytes += bytes;
    _lastDataMs = _clock.elapsedMilliseconds;
  }

  void failed(Object error) {
    // Preserve the original stream exception before the public error is
    // replaced with a safe, translated CdnRangeFailure.
    _error ??= describeCdnDiagnosticError(error);
  }

  Map<String, Object?> snapshot(String outcome) => {
        'id': id,
        'start': start,
        'end': end,
        'probe': probe,
        'startedMs': startedMs,
        'elapsedMs': _clock.elapsedMilliseconds,
        'headersMs': headersMs,
        'stage': stage,
        'outcome': outcome,
        'totalBytes': totalBytes,
        'expectedBytes': end - start + 1,
        'receivedBytes': receivedBytes,
        'idleMs': headersMs == null
            ? null
            : _clock.elapsedMilliseconds - (_lastDataMs ?? headersMs!),
        if (_error != null) 'error': _error,
      };
}

/// Extract only typed codes. Dio/Socket exception strings can include signed
/// URLs, cookies, addresses and server-supplied text, even after host masking.
Map<String, Object?> describeCdnDiagnosticError(Object error) {
  final cause = error is DioException ? error.error : error;
  return {
    'type': error.runtimeType.toString(),
    if (error is CdnRequestFailure) ...{
      'kind': error.kind.name,
      'phase': error.phase.name,
      if (error.statusCode != null) 'httpStatus': error.statusCode,
      'isTimeout': error.isTimeout,
    },
    if (error is DioException) ...{
      'dioType': error.type.name,
      if (error.response?.statusCode != null)
        'httpStatus': error.response!.statusCode,
      if (cause != null) 'causeType': cause.runtimeType.toString(),
    },
    if (cause is SocketException && cause.osError != null)
      'osErrorCode': cause.osError!.errorCode,
    if (cause is TlsException && cause.osError != null)
      'osErrorCode': cause.osError!.errorCode,
    if (cause is TimeoutException && cause.duration != null)
      'timeoutMs': cause.duration!.inMilliseconds,
  };
}
