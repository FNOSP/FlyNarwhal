import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/core/network/cdn_proxy/cdn_http_transport.dart';
import 'package:fly_narwhal/core/network/cdn_proxy/cdn_proxy_service.dart';
import 'package:fly_narwhal/core/network/cdn_proxy/cdn_range_session.dart';
import 'package:fly_narwhal/core/network/cdn_proxy/cdn_range_source.dart';
import 'package:fly_narwhal/data/datasources/remote/cdn_range_remote_data_source.dart';

import '../../../tool/support/cdn_proxy_http_fixture.dart';

// These are real socket/timer regressions: fake time cannot establish whether
// Dio interprets receiveTimeout as idle time or the whole response duration.
void main() {
  for (final rateMiB in [1, 2]) {
    test(
      'Given one shared $rateMiB MiB/s link, when three ranges download, '
      'then complete bodies arrive in order without timeout retries',
      () async {
        final result = await _exercise(
          totalBytes: 30 * fixtureMiB,
          sharedBytesPerSecond: rateMiB * fixtureMiB,
        );
        final expectedSeconds = 30 ~/ rateMiB;
        expect(result.statusCode, HttpStatus.partialContent);
        expect(result.contentRange,
            'bytes 0-${30 * fixtureMiB - 1}/${30 * fixtureMiB}');
        expect(result.receivedBytes, 30 * fixtureMiB);
        expect(result.payloadErrors, 0,
            reason: 'Check every byte across ranges.');
        expect(result.bodyAttempts, hasLength(3));
        expect(result.upstreamRequests, 3, reason: 'No range was retried.');
        expect(result.peakUpstreamRequests, 3);
        expect(result.peakBudget, 3);
        expect(result.headersLatency, lessThan(const Duration(seconds: 3)));
        expect(result.firstBodyLatency,
            greaterThan(Duration(seconds: expectedSeconds - 1)));
        expect(result.firstBodyLatency,
            lessThan(Duration(seconds: expectedSeconds + 15)));
        // At 1 MiB/s each of three 10 MiB responses takes more than 20 seconds,
        // while repeated progress prevents both the 10 s and 20 s idle timers.
        if (rateMiB == 1) {
          expect(result.firstBodyLatency,
              greaterThan(const Duration(seconds: 20)));
        }
        _expectReleased(result);
      },
      timeout: const Timeout(Duration(seconds: 75)),
    );
  }

  test(
    'Given a partial body followed by real idle, when the default HTTP timeout '
    'fires, then the complete original range is retried after one second',
    () async {
      final result =
          await _exercise(totalBytes: fixtureMiB, stallFirstBody: true);
      _expectIdleRetry(result, const Duration(seconds: 10));
      expect(
          result.bodyAttempts.first.errorType, DioExceptionType.receiveTimeout);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'Given HTTP idle timeout is longer than service idle timeout, when the body '
    'stalls for twenty seconds, then the complete original range is retried',
    () async {
      final result = await _exercise(
        totalBytes: fixtureMiB,
        stallFirstBody: true,
        receiveTimeout: const Duration(seconds: 60),
      );
      _expectIdleRetry(result, const Duration(seconds: 20));
      expect(result.bodyAttempts.first.errorType, isNull);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );
}

void _expectIdleRetry(_SlowLinkResult result, Duration expectedIdle) {
  expect(result.receivedBytes, fixtureMiB);
  expect(result.payloadErrors, 0,
      reason: 'The invalid first-attempt prefix must never reach the client.');
  expect(result.upstreamRequests, 2);
  expect(result.bodyAttempts, hasLength(2));
  for (final attempt in result.bodyAttempts) {
    expect((attempt.start, attempt.end), (0, fixtureMiB - 1));
  }
  final first = result.bodyAttempts.first;
  final retry = result.bodyAttempts.last;
  expect(first.receivedBytes, 64 * 1024);
  expect(first.cancelledAt, isNotNull);
  final idle = first.cancelledAt! - first.lastDataAt!;
  expect(
      idle.inMilliseconds,
      inInclusiveRange(expectedIdle.inMilliseconds - 500,
          expectedIdle.inMilliseconds + 3000));
  final retryDelay = retry.openedAt - first.cancelledAt!;
  expect(retryDelay.inMilliseconds, inInclusiveRange(900, 2500));
  _expectReleased(result);
}

void _expectReleased(_SlowLinkResult result) {
  expect(result.serviceErrors, isEmpty);
  expect(result.upstreamErrors, isEmpty);
  expect(result.occupiedAfterClose, 0);
  expect(result.writersAfterClose, 0);
}

Future<_SlowLinkResult> _exercise({
  required int totalBytes,
  int? sharedBytesPerSecond,
  bool stallFirstBody = false,
  Duration receiveTimeout = const Duration(seconds: 10),
}) async {
  final fixture = await CdnProxyHttpFixture.start(
    totalBytes: totalBytes,
    sharedBytesPerSecond: sharedBytesPerSecond,
    stallFirstBody: stallFirstBody,
  );
  final watch = Stopwatch()..start();
  final source = _RecordingSource(
    CdnRangeRemoteDataSource(
      transport: CdnHttpTransport(receiveTimeout: receiveTimeout),
    ),
    watch,
  );
  final budget = CdnRangeBudget();
  final serviceErrors = <Object>[];
  final service = CdnProxyService(
    source: source,
    budget: budget,
    onError: serviceErrors.add,
  );
  final client = HttpClient()..findProxy = (_) => 'DIRECT';
  try {
    final uri = await service.open(uri: fixture.uri, headers: const {});
    final requestStarted = watch.elapsed;
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
    final response = await request.close();
    final headersLatency = watch.elapsed - requestStarted;
    Duration? firstBodyLatency;
    var receivedBytes = 0;
    var payloadErrors = 0;
    await for (final data in response) {
      firstBodyLatency ??= watch.elapsed - requestStarted;
      for (var i = 0; i < data.length; i++) {
        if (data[i] != fixtureByteAt(receivedBytes + i)) payloadErrors++;
      }
      receivedBytes += data.length;
    }
    await service.close().timeout(const Duration(seconds: 5));
    final attempts = source.attempts
        .where((attempt) => attempt.start != 0 || attempt.end != 0)
        .toList();
    final result = _SlowLinkResult(
      statusCode: response.statusCode,
      contentRange: response.headers.value(HttpHeaders.contentRangeHeader),
      receivedBytes: receivedBytes,
      payloadErrors: payloadErrors,
      bodyAttempts: attempts,
      headersLatency: headersLatency,
      firstBodyLatency: firstBodyLatency!,
      upstreamRequests: fixture.bodyRequests.length,
      peakUpstreamRequests: fixture.peakActiveBodyRequests,
      peakBudget: budget.peakOccupiedSlots,
      occupiedAfterClose: budget.occupiedSlots,
      writersAfterClose: service.activeWriterCount,
      serviceErrors: serviceErrors,
      upstreamErrors: fixture.errors,
    );
    stdout.writeln(jsonEncode({
      'sharedBytesPerSecond': sharedBytesPerSecond,
      'receiveTimeoutMs': receiveTimeout.inMilliseconds,
      'headersMs': result.headersLatency.inMilliseconds,
      'firstBodyMs': result.firstBodyLatency.inMilliseconds,
      'bodyRequests': attempts.length,
      'verifiedBytes': receivedBytes,
      'occupiedAfterClose': result.occupiedAfterClose,
      'writersAfterClose': result.writersAfterClose,
    }));
    return result;
  } finally {
    await service.close();
    client.close(force: true);
    await fixture.close();
    watch.stop();
  }
}

class _Attempt {
  _Attempt(this.start, this.end, this.openedAt);
  final int start;
  final int end;
  final Duration openedAt;
  Duration? lastDataAt;
  Duration? cancelledAt;
  int receivedBytes = 0;
  DioExceptionType? errorType;
}

class _RecordingSource implements CdnRangeSource {
  _RecordingSource(this.delegate, this.watch);
  final CdnRangeSource delegate;
  final Stopwatch watch;
  final List<_Attempt> attempts = [];

  @override
  Future<ApiResult<CdnRangeResponse>> open({
    required Uri uri,
    required Map<String, String> headers,
    required int start,
    required int end,
    required CancelToken cancelToken,
  }) async {
    final attempt = _Attempt(start, end, watch.elapsed);
    attempts.add(attempt);
    unawaited(cancelToken.whenCancel.then((_) {
      attempt.cancelledAt = watch.elapsed;
    }));
    final result = await delegate.open(
        uri: uri,
        headers: headers,
        start: start,
        end: end,
        cancelToken: cancelToken);
    return result.map((response) => CdnRangeResponse(
          totalLength: response.totalLength,
          contentType: response.contentType,
          stream: response.stream.transform(
            StreamTransformer<Uint8List, Uint8List>.fromHandlers(
              handleData: (data, sink) {
                attempt.lastDataAt = watch.elapsed;
                attempt.receivedBytes += data.length;
                sink.add(data);
              },
              handleError: (error, stack, sink) {
                if (error is DioException) attempt.errorType = error.type;
                sink.addError(error, stack);
              },
            ),
          ),
        ));
  }

  @override
  void close() => delegate.close();
}

class _SlowLinkResult {
  _SlowLinkResult(
      {required this.statusCode,
      required this.contentRange,
      required this.receivedBytes,
      required this.payloadErrors,
      required this.bodyAttempts,
      required this.headersLatency,
      required this.firstBodyLatency,
      required this.upstreamRequests,
      required this.peakUpstreamRequests,
      required this.peakBudget,
      required this.occupiedAfterClose,
      required this.writersAfterClose,
      required this.serviceErrors,
      required this.upstreamErrors});
  final int statusCode;
  final String? contentRange;
  final int receivedBytes;
  final int payloadErrors;
  final List<_Attempt> bodyAttempts;
  final Duration headersLatency;
  final Duration firstBodyLatency;
  final int upstreamRequests;
  final int peakUpstreamRequests;
  final int peakBudget;
  final int occupiedAfterClose;
  final int writersAfterClose;
  final List<Object> serviceErrors;
  final List<String> upstreamErrors;
}
