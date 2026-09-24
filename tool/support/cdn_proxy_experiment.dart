import 'dart:convert';
import 'dart:io';

import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_http_range_source.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_service.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_diagnostics.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_session.dart';

import 'cdn_proxy_http_fixture.dart';

/// Runs a real HTTP experiment without Flutter, application state or login.
Future<CdnProxyExperimentResult> runCdnProxyExperiment({
  required int totalBytes,
  int? sharedBytesPerSecond,
  bool disconnectFirstBody = false,
  bool stallFirstBody = false,
  Duration requestTimeout = const Duration(hours: 48),
  bool recoverAfterBodyError = false,
}) async {
  final fixture = await CdnProxyHttpFixture.start(
    totalBytes: totalBytes,
    sharedBytesPerSecond: sharedBytesPerSecond,
    disconnectFirstBody: disconnectFirstBody,
    stallFirstBody: stallFirstBody,
  );
  final budget = CdnRangeBudget();
  final serviceErrors = <Object>[];
  final retryReports = <Map<String, dynamic>>[];
  final source = CdnHttpRangeSource(requestTimeout: requestTimeout);
  final service = CdnProxyService(
    source: source,
    budget: budget,
    onError: serviceErrors.add,
    diagnostics: CdnRangeDiagnostics(writeLog: (message, {required failure}) {
      final report = jsonDecode(message) as Map<String, dynamic>;
      if (report['event'] == 'chunk_retry') retryReports.add(report);
    }),
  );
  final client = HttpClient()..findProxy = (_) => 'DIRECT';
  try {
    final uri = await service.open(uri: fixture.uri, headers: const {});
    final requestStarted = fixture.clock.elapsed;
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
    final response = await request.close();
    final headersLatency = fixture.clock.elapsed - requestStarted;
    Duration? firstBodyAt;
    var receivedBytes = 0;
    var payloadErrors = 0;
    String? bodyErrorType;
    try {
      await for (final data in response) {
        firstBodyAt ??= fixture.clock.elapsed;
        for (var i = 0; i < data.length; i++) {
          if (data[i] != fixtureByteAt(receivedBytes + i)) payloadErrors++;
        }
        receivedBytes += data.length;
      }
    } catch (error) {
      bodyErrorType = error.runtimeType.toString();
    }
    final attemptsBeforeRecovery = fixture.bodyRequests.length;
    var recoveredBytes = 0;
    if (recoverAfterBodyError && bodyErrorType != null) {
      final recoveryRequest = await client.getUrl(uri);
      recoveryRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
      final recovered = await recoveryRequest.close();
      if (recovered.statusCode != HttpStatus.partialContent) {
        throw StateError('A later Range request could not reuse the proxy.');
      }
      await for (final data in recovered) {
        for (var i = 0; i < data.length; i++) {
          if (data[i] != fixtureByteAt(recoveredBytes + i)) payloadErrors++;
        }
        recoveredBytes += data.length;
      }
    }
    await service.close().timeout(const Duration(seconds: 5));
    return CdnProxyExperimentResult(
      totalBytes: totalBytes,
      sharedBytesPerSecond: sharedBytesPerSecond,
      requestTimeout: requestTimeout,
      statusCode: response.statusCode,
      contentRange: response.headers.value(HttpHeaders.contentRangeHeader),
      receivedBytes: receivedBytes,
      payloadErrors: payloadErrors,
      bodyErrorType: bodyErrorType,
      recoveredBytes: recoveredBytes,
      attemptsBeforeRecovery: attemptsBeforeRecovery,
      bodyAttempts: List.unmodifiable(fixture.bodyRequests),
      retryReports: retryReports,
      headersLatency: headersLatency,
      firstBodyAt: firstBodyAt,
      firstBodyLatency:
          firstBodyAt == null ? null : firstBodyAt - requestStarted,
      peakUpstreamRequests: fixture.peakActiveBodyRequests,
      peakBudget: budget.peakOccupiedSlots,
      occupiedAfterClose: budget.occupiedSlots,
      writersAfterClose: service.activeWriterCount,
      downloadsAfterClose: service.activeDownloadCount,
      attemptsAfterClose: source.activeAttemptCount,
      allocatedAfterClose: service.allocatedBufferBytes,
      bufferedAfterClose: service.bufferedBytes,
      serviceErrors:
          serviceErrors.map((e) => e.runtimeType.toString()).toList(),
      upstreamErrors: List.unmodifiable(fixture.errors),
    );
  } finally {
    await service.close();
    client.close(force: true);
    await fixture.close();
  }
}

class CdnProxyExperimentResult {
  CdnProxyExperimentResult({
    required this.totalBytes,
    required this.sharedBytesPerSecond,
    required this.requestTimeout,
    required this.statusCode,
    required this.contentRange,
    required this.receivedBytes,
    required this.payloadErrors,
    required this.bodyErrorType,
    required this.recoveredBytes,
    required this.attemptsBeforeRecovery,
    required this.bodyAttempts,
    required this.retryReports,
    required this.headersLatency,
    required this.firstBodyAt,
    required this.firstBodyLatency,
    required this.peakUpstreamRequests,
    required this.peakBudget,
    required this.occupiedAfterClose,
    required this.writersAfterClose,
    required this.downloadsAfterClose,
    required this.attemptsAfterClose,
    required this.allocatedAfterClose,
    required this.bufferedAfterClose,
    required this.serviceErrors,
    required this.upstreamErrors,
  });

  final int totalBytes;
  final int? sharedBytesPerSecond;
  final Duration requestTimeout;
  final int statusCode;
  final String? contentRange;
  final int receivedBytes;
  final int payloadErrors;
  final String? bodyErrorType;
  final int recoveredBytes;
  final int attemptsBeforeRecovery;
  final List<FixtureRangeRequest> bodyAttempts;
  final List<Map<String, dynamic>> retryReports;
  final Duration headersLatency;
  final Duration? firstBodyAt;
  final Duration? firstBodyLatency;
  final int peakUpstreamRequests;
  final int peakBudget;
  final int occupiedAfterClose;
  final int writersAfterClose;
  final int downloadsAfterClose;
  final int attemptsAfterClose;
  final int allocatedAfterClose;
  final int bufferedAfterClose;
  final List<String> serviceErrors;
  final List<String> upstreamErrors;

  Map<String, Object?> toJson() => {
        'totalBytes': totalBytes,
        'sharedBytesPerSecond': sharedBytesPerSecond,
        'requestTimeoutMs': requestTimeout.inMilliseconds,
        'status': statusCode,
        'headersMs': headersLatency.inMilliseconds,
        'firstBodyMs': firstBodyLatency?.inMilliseconds,
        'firstBodyBeforeFirstChunkCompleted': firstBodyAt != null &&
            bodyAttempts.first.completedAt != null &&
            firstBodyAt! < bodyAttempts.first.completedAt!,
        'retryCount': retryReports.length,
        'bodyRequests':
            bodyAttempts.map((attempt) => attempt.toJson()).toList(),
        'upstreamBytes':
            bodyAttempts.fold<int>(0, (sum, a) => sum + a.sentBytes),
        'verifiedBytes': receivedBytes,
        'payloadErrors': payloadErrors,
        'bodyErrorType': bodyErrorType,
        'recoveredBytes': recoveredBytes,
        'peakUpstreamRequests': peakUpstreamRequests,
        'peakBudget': peakBudget,
        'occupiedAfterClose': occupiedAfterClose,
        'writersAfterClose': writersAfterClose,
        'downloadsAfterClose': downloadsAfterClose,
        'attemptsAfterClose': attemptsAfterClose,
        'allocatedAfterClose': allocatedAfterClose,
        'bufferedAfterClose': bufferedAfterClose,
        'serviceErrors': serviceErrors,
        'upstreamErrors': upstreamErrors,
      };
}
