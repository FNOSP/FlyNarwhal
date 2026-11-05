import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/ui/shared/celebration_simulation.dart';

/// Steps the simulation forward in chunks small enough that [CelebrationSimulation.seekTo]
/// sub-steps instead of fast-forwarding, sampling [onSample] at each stop.
void _runShow(
  CelebrationSimulation sim,
  double until, {
  double? sampleEvery,
  void Function(double time)? onSample,
}) {
  var nextSample = sampleEvery;
  while (sim.time < until) {
    final target = math.min(sim.time + 0.1, until);
    sim.seekTo(target);
    if (nextSample != null && onSample != null && sim.time >= nextSample) {
      onSample(sim.time);
      nextSample += sampleEvery!;
    }
  }
}

void main() {
  const size = Size(1280, 720);

  CelebrationSimulation newSim() =>
      CelebrationSimulation(size: size, random: math.Random(42));

  test('side cannons fire within the first half second', () {
    final sim = newSim();
    expect(sim.confettiCount, 0);
    sim.seekTo(0.05);
    // Left cannon fired at t=0.
    expect(sim.confettiCount, greaterThan(80));
    _runShow(sim, 0.5);
    // Right cannon (t=0.22) fired as well: ~90–110 pieces per cannon.
    expect(sim.confettiCount, greaterThan(150));
  });

  test('confetti launches upward, falls back and is reaped off-screen', () {
    final sim = newSim();
    sim.seekTo(0.05);
    final maxYLaunch = sim.debugConfettiMaxY;
    expect(maxYLaunch, isNotNull);
    // Pieces spawn just below the bottom edge.
    expect(maxYLaunch!, greaterThan(700));
    // Mid-flight they have climbed the window.
    _runShow(sim, 1.0);
    final maxYRisen = sim.debugConfettiMaxY;
    expect(maxYRisen, isNotNull);
    expect(maxYRisen!, lessThan(maxYLaunch));
    // Gravity brings everything back down and out; dead pieces are reaped.
    // The encore volleys (t≈2.4/2.65) fly until ~6s.
    _runShow(sim, 7.5);
    expect(sim.confettiCount, 0);
    expect(sim.debugConfettiMaxY, isNull);
  });

  test('rockets only launch after the sticker has arrived', () {
    final sim = newSim();
    _runShow(sim, 2.2);
    expect(sim.rocketCount, 0);
    // First launch is scheduled at CelebrationTimeline.fireworksStart (2.3s).
    _runShow(sim, 3.6);
    // A rocket is airborne or has already burst into sparks by now.
    expect(sim.rocketCount + sim.sparkCount, greaterThan(0));
  });

  test('shell bursts spawn sparks and smoke within their lifetimes', () {
    final sim = newSim();
    var sawSparks = false;
    var sawSmoke = false;
    _runShow(
      sim,
      5.0,
      sampleEvery: 0.2,
      onSample: (_) {
        if (sim.sparkCount > 20) sawSparks = true;
        if (sim.smokeCount > 0) sawSmoke = true;
      },
    );
    expect(sawSparks, isTrue, reason: 'a shell should have burst by t=5s');
    expect(sawSmoke, isTrue, reason: 'bursts trail smoke puffs');
  });

  test('spark budget is never exceeded and the show finishes', () {
    final sim = newSim();
    var maxSparks = 0;
    _runShow(
      sim,
      CelebrationTimeline.total + 0.1,
      sampleEvery: 0.25,
      onSample: (_) {
        if (sim.sparkCount > maxSparks) maxSparks = sim.sparkCount;
      },
    );
    expect(maxSparks, lessThanOrEqualTo(2200));
    expect(sim.isFinished, isTrue);
  });

  test('a huge time gap fast-forwards instead of hanging', () {
    final sim = newSim();
    final watch = Stopwatch()..start();
    sim.seekTo(60); // e.g. window was unfocused for a minute
    watch.stop();
    expect(sim.time, 60);
    expect(sim.isFinished, isTrue);
    expect(watch.elapsedMilliseconds, lessThan(1000));
  });

  test('two runs with different seeds launch different shows', () {
    // Randomness: the show must not replay identically every time. Burst
    // timing/count differences surface as different spark populations.
    final a = CelebrationSimulation(size: size, random: math.Random(1));
    final b = CelebrationSimulation(size: size, random: math.Random(2));
    _runShow(a, 5.0);
    _runShow(b, 5.0);
    expect(a.sparkCount == b.sparkCount && a.rocketCount == b.rocketCount,
        isFalse);
  });
}
