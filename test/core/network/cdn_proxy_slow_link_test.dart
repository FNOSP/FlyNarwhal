import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/support/cdn_proxy_experiment.dart';
import '../../../tool/support/cdn_proxy_http_fixture.dart';

// Real loopback sockets and clocks verify aggregate bandwidth, streaming order,
// body disconnects and injected request deadlines independently of mpv.
void main() {
  for (final rateMiB in [1, 2]) {
    test(
      'Given one shared $rateMiB MiB/s link, when three ranges download, '
      'then the first prefix arrives before a chunk completes',
      () async {
        final result = await runCdnProxyExperiment(
          totalBytes: 30 * fixtureMiB,
          sharedBytesPerSecond: rateMiB * fixtureMiB,
        );
        _report(result);
        expect(result.statusCode, HttpStatus.partialContent);
        expect(result.contentRange,
            'bytes 0-${30 * fixtureMiB - 1}/${30 * fixtureMiB}');
        expect(result.receivedBytes, 30 * fixtureMiB);
        expect(result.payloadErrors, 0);
        expect(result.bodyErrorType, isNull);
        expect(result.bodyAttempts, hasLength(3));
        expect(result.retryReports, isEmpty);
        expect(result.peakUpstreamRequests, 3);
        expect(result.peakBudget, 3);
        expect(result.bodyAttempts.map((a) => (a.start, a.end)), [
          (0, 10 * fixtureMiB - 1),
          (10 * fixtureMiB, 20 * fixtureMiB - 1),
          (20 * fixtureMiB, 30 * fixtureMiB - 1),
        ]);
        expect(result.headersLatency, lessThan(const Duration(seconds: 3)));
        expect(result.firstBodyAt, isNotNull);
        expect(result.firstBodyLatency, lessThan(const Duration(seconds: 3)));
        for (final attempt in result.bodyAttempts) {
          expect(attempt.completedAt, isNotNull);
          expect(result.firstBodyAt, lessThan(attempt.completedAt!),
              reason: 'Output must not wait for any complete 10 MiB chunk.');
        }
        expect(result.bodyAttempts.fold<int>(0, (n, a) => n + a.sentBytes),
            30 * fixtureMiB);
        _expectReleased(result);
      },
      timeout: const Timeout(Duration(seconds: 75)),
    );
  }

  test(
    'Given 23 MiB and a broken first body, when downloading, '
    'then split 5+8+10 MiB and resume only the missing suffix',
    () async {
      final result = await runCdnProxyExperiment(
        totalBytes: 23 * fixtureMiB,
        disconnectFirstBody: true,
      );
      _report(result);
      _expectSuffixRetry(result, 23 * fixtureMiB, 5 * fixtureMiB - 1);
      final ranges = result.bodyAttempts.map((a) => (a.start, a.end)).toList();
      expect(ranges, contains((5 * fixtureMiB, 13 * fixtureMiB - 1)));
      expect(ranges, contains((13 * fixtureMiB, 23 * fixtureMiB - 1)));
      expect(result.bodyAttempts, hasLength(4));
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  test(
    'Given a stalled valid prefix, when an injected request deadline expires, '
    'then retain the prefix and request the remaining range',
    () async {
      final result = await runCdnProxyExperiment(
        totalBytes: 11 * fixtureMiB,
        stallFirstBody: true,
        requestTimeout: const Duration(seconds: 2),
      );
      _report(result);
      _expectSuffixRetry(result, 11 * fixtureMiB, 5 * fixtureMiB - 1);
      expect(result.bodyAttempts, hasLength(3));
      final retry =
          result.bodyAttempts.singleWhere((a) => a.start == 64 * 1024);
      final elapsed = retry.openedAt - result.bodyAttempts.first.openedAt;
      expect(elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 1800)));
      expect(elapsed, lessThan(const Duration(seconds: 6)));
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  test(
    'Given a broken single-part response, when the body ends early, '
    'then do not retry and let a later Range reuse the service',
    () async {
      final result = await runCdnProxyExperiment(
        totalBytes: fixtureMiB,
        disconnectFirstBody: true,
        recoverAfterBodyError: true,
      );
      _report(result);
      expect(result.bodyErrorType, isNotNull);
      expect(result.receivedBytes, 64 * 1024);
      expect(result.payloadErrors, 0);
      expect(result.retryReports, isEmpty);
      expect(result.attemptsBeforeRecovery, 1);
      expect(result.bodyAttempts, hasLength(2));
      expect(result.recoveredBytes, fixtureMiB);
      _expectReleased(result);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}

void _expectSuffixRetry(
    CdnProxyExperimentResult result, int total, int firstEnd) {
  expect(result.receivedBytes, total);
  expect(result.payloadErrors, 0,
      reason: 'The retained prefix and resumed suffix must match every byte.');
  expect(result.bodyErrorType, isNull);
  expect(result.retryReports, hasLength(1));
  expect((result.bodyAttempts.first.start, result.bodyAttempts.first.end),
      (0, firstEnd));
  expect(result.bodyAttempts.first.sentBytes, 64 * 1024);
  expect(result.bodyAttempts.where((a) => a.start == 0), hasLength(1),
      reason: 'Never redownload the prefix of the first chunk.');
  expect(result.bodyAttempts.map((a) => (a.start, a.end)),
      contains((64 * 1024, firstEnd)));
  expect(result.bodyAttempts.fold<int>(0, (n, a) => n + a.sentBytes), total);
  _expectReleased(result);
}

void _expectReleased(CdnProxyExperimentResult result) {
  expect(result.serviceErrors, isEmpty);
  expect(result.upstreamErrors, isEmpty);
  expect(result.occupiedAfterClose, 0);
  expect(result.writersAfterClose, 0);
  expect(result.downloadsAfterClose, 0);
  expect(result.attemptsAfterClose, 0);
  expect(result.allocatedAfterClose, 0);
  expect(result.bufferedAfterClose, 0);
}

void _report(CdnProxyExperimentResult result) =>
    stdout.writeln(jsonEncode(result.toJson()));
