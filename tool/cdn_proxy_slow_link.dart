import 'dart:convert';
import 'dart:io';

import 'support/cdn_proxy_experiment.dart';
import 'support/cdn_proxy_http_fixture.dart';

/// `dart run tool/cdn_proxy_slow_link.dart` measures real 1/2 MiB/s aggregate
/// bandwidth plus disconnect/deadline recovery. `--faults-only` skips throttling.
/// These HTTP results do not establish native playback or startup performance.
Future<void> main(List<String> arguments) async {
  if (arguments.any((value) => value != '--faults-only')) {
    throw ArgumentError('Supported option: --faults-only');
  }
  if (!arguments.contains('--faults-only')) {
    for (final rate in [1, 2]) {
      final result = await runCdnProxyExperiment(
        totalBytes: 30 * fixtureMiB,
        sharedBytesPerSecond: rate * fixtureMiB,
      );
      _report('shared_${rate}_MiB_per_second', result);
      _requireComplete(result);
      _require(result.bodyAttempts.length == 3 && result.retryReports.isEmpty,
          'A healthy slow link unexpectedly retried.');
      _require(result.peakBudget == 3 && result.peakUpstreamRequests == 3,
          'The slow-link run did not exercise three concurrent ranges.');
      _require(
          result.firstBodyAt != null &&
              result.bodyAttempts.every((attempt) =>
                  attempt.completedAt != null &&
                  result.firstBodyAt! < attempt.completedAt!),
          'First body waited for a complete chunk.');
    }
  }
  final resumed = await runCdnProxyExperiment(
    totalBytes: 23 * fixtureMiB,
    disconnectFirstBody: true,
  );
  _report('disconnect_and_resume_suffix', resumed);
  _requireComplete(resumed);
  _requireSuffix(resumed);

  final deadline = await runCdnProxyExperiment(
    totalBytes: 11 * fixtureMiB,
    stallFirstBody: true,
    requestTimeout: const Duration(seconds: 2),
  );
  _report('request_deadline_and_resume_suffix', deadline);
  _requireComplete(deadline);
  _requireSuffix(deadline);

  final single = await runCdnProxyExperiment(
    totalBytes: fixtureMiB,
    disconnectFirstBody: true,
    recoverAfterBodyError: true,
  );
  _report('single_part_failure_isolation', single);
  _require(
      single.bodyErrorType != null &&
          single.attemptsBeforeRecovery == 1 &&
          single.retryReports.isEmpty &&
          single.receivedBytes == 64 * 1024 &&
          single.recoveredBytes == fixtureMiB,
      'A single-part failure retried or prevented a later Range request.');
  _requireReleased(single);
  stdout.writeln(
      jsonEncode({'result': 'passed', 'nativePlaybackVerified': false}));
}

void _requireSuffix(CdnProxyExperimentResult result) {
  _require(
      result.retryReports.length == 1 &&
          result.bodyAttempts.where((attempt) => attempt.start == 0).length ==
              1 &&
          result.bodyAttempts.any((attempt) =>
              attempt.start == 64 * 1024 && attempt.end == 5 * fixtureMiB - 1),
      'Retry did not request exactly the missing suffix.');
  _require(
      result.bodyAttempts.fold<int>(0, (n, a) => n + a.sentBytes) ==
          result.totalBytes,
      'The upstream sent duplicated payload bytes.');
}

void _requireComplete(CdnProxyExperimentResult result) {
  _require(
      result.statusCode == HttpStatus.partialContent &&
          result.receivedBytes == result.totalBytes &&
          result.bodyErrorType == null,
      'The ranged body did not complete.');
  _requireReleased(result);
}

void _requireReleased(CdnProxyExperimentResult result) {
  _require(
      result.payloadErrors == 0 &&
          result.serviceErrors.isEmpty &&
          result.upstreamErrors.isEmpty &&
          result.occupiedAfterClose == 0 &&
          result.writersAfterClose == 0 &&
          result.downloadsAfterClose == 0 &&
          result.attemptsAfterClose == 0 &&
          result.allocatedAfterClose == 0 &&
          result.bufferedAfterClose == 0,
      'Payload or cleanup verification failed.');
}

void _report(String experiment, CdnProxyExperimentResult result) =>
    stdout.writeln(jsonEncode({'experiment': experiment, ...result.toJson()}));

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}
