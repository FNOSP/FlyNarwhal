import 'dart:math';

import 'cdn_proxy_constants.dart';

/// Result of one concurrency adjustment decision.
class CdnConcurrencyDecision {
  const CdnConcurrencyDecision({
    required this.concurrency,
    required this.probePending,
    required this.unproductiveProbes,
    required this.preProbeThroughput,
  });

  final int concurrency;
  final bool probePending;
  final int unproductiveProbes;
  final double preProbeThroughput;
}

/// Decides the next concurrency from the previous state and one measured
/// aggregate throughput.
///
/// Pure and independent of time accounting so the scheduler behavior can be
/// tested without an HTTP source. [bitrate] is in bits per second, [measured]
/// is aggregate bytes per second.
CdnConcurrencyDecision decideConcurrency({
  required int concurrency,
  required int bitrate,
  required double measured,
  required bool probePending,
  required int unproductiveProbes,
  required double preProbeThroughput,
}) {
  if (probePending) {
    // Settle the pending step: keep it if it bought throughput, otherwise
    // roll the probe back so an unproductive increase is not retained.
    if (measured > preProbeThroughput * 1.15) {
      return CdnConcurrencyDecision(
        concurrency: concurrency,
        probePending: false,
        unproductiveProbes: 0,
        preProbeThroughput: preProbeThroughput,
      );
    }
    return CdnConcurrencyDecision(
      concurrency: max(
          concurrency - 1, CdnProxyDefaults.minChunksPerReader),
      probePending: false,
      unproductiveProbes: unproductiveProbes + 1,
      preProbeThroughput: preProbeThroughput,
    );
  }

  // bits/s to bytes/s, with headroom so playback is not riding the edge.
  final required = bitrate ~/ 8 * CdnProxyDefaults.throughputHeadroomFactor;
  final atFloor = concurrency <= CdnProxyDefaults.minChunksPerReader;
  final atCeiling = concurrency >= CdnProxyDefaults.maxChunksPerReader;

  if (measured < required && !atCeiling) {
    if (unproductiveProbes >= CdnProxyDefaults.maxUnproductiveProbes) {
      return CdnConcurrencyDecision(
        concurrency: concurrency,
        probePending: false,
        unproductiveProbes: unproductiveProbes,
        preProbeThroughput: preProbeThroughput,
      );
    }
    return CdnConcurrencyDecision(
      concurrency: concurrency + 1,
      probePending: true,
      unproductiveProbes: unproductiveProbes,
      preProbeThroughput: measured,
    );
  }

  // Drop only on a clear surplus, so a link sitting near the required rate
  // does not oscillate between two counts.
  if (measured > required * 2 && !atFloor) {
    return CdnConcurrencyDecision(
      concurrency: concurrency - 1,
      probePending: false,
      unproductiveProbes: 0,
      preProbeThroughput: preProbeThroughput,
    );
  }

  return CdnConcurrencyDecision(
    concurrency: concurrency,
    probePending: false,
    unproductiveProbes: unproductiveProbes,
    preProbeThroughput: preProbeThroughput,
  );
}

/// Starting concurrency for a media bitrate, before any throughput sample.
int initialConcurrency(int bitrate) {
  if (bitrate <= 0) return CdnProxyDefaults.initialChunksPerReader;
  final required = bitrate ~/ 8 * CdnProxyDefaults.throughputHeadroomFactor;
  return required <= CdnProxyDefaults.assumedBytesPerConnectionPerSecond
      ? CdnProxyDefaults.minChunksPerReader
      : CdnProxyDefaults.initialChunksPerReader;
}
