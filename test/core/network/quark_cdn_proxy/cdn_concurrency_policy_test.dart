import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_concurrency_policy.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_constants.dart';

void main() {
  const bitrate = 14037992; // ~14 Mbps, the reported test film's estimate.

  test('Given ample throughput, it never raises concurrency', () {
    final decision = decideConcurrency(
      concurrency: CdnProxyDefaults.initialChunksPerReader,
      bitrate: bitrate,
      measured: bitrate ~/ 8 * 4,
      probePending: false,
      unproductiveProbes: 0,
      preProbeThroughput: 0,
    );
    expect(decision.concurrency, CdnProxyDefaults.initialChunksPerReader);
    expect(decision.probePending, isFalse);
  });

  test('Given low throughput, it probes one step up', () {
    final decision = decideConcurrency(
      concurrency: 1,
      bitrate: bitrate,
      measured: bitrate / 16,
      probePending: false,
      unproductiveProbes: 0,
      preProbeThroughput: 0,
    );
    expect(decision.concurrency, 2);
    expect(decision.probePending, isTrue);
    expect(decision.preProbeThroughput, bitrate / 16);
  });

  test('Given an unproductive probe, it rolls the increase back', () {
    final decision = decideConcurrency(
      concurrency: 2,
      bitrate: bitrate,
      measured: bitrate / 16,
      probePending: true,
      unproductiveProbes: 0,
      preProbeThroughput: bitrate / 16,
    );
    expect(decision.concurrency, 1);
    expect(decision.probePending, isFalse);
    expect(decision.unproductiveProbes, 1);
  });

  test('Given too many unproductive probes, it stops climbing', () {
    final decision = decideConcurrency(
      concurrency: 1,
      bitrate: bitrate,
      measured: bitrate / 16,
      probePending: false,
      unproductiveProbes: CdnProxyDefaults.maxUnproductiveProbes,
      preProbeThroughput: 0,
    );
    expect(decision.concurrency, 1);
    expect(decision.probePending, isFalse);
  });

  test('Given a clear surplus, it drops one step', () {
    final decision = decideConcurrency(
      concurrency: 3,
      bitrate: bitrate,
      measured: bitrate ~/ 8 * 8,
      probePending: false,
      unproductiveProbes: 0,
      preProbeThroughput: 0,
    );
    expect(decision.concurrency, 2);
    expect(decision.unproductiveProbes, 0);
  });
}
