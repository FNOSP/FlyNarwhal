/// Caps how many calls may happen inside any rolling [window].
///
/// Only the start times of *accepted* calls are kept, so a rejected attempt
/// never extends the window. Call [tryAcquire] immediately before the call it
/// guards — nothing is recorded if the call is refused.
final class SlidingWindowRateLimiter {
  SlidingWindowRateLimiter({
    required this.maxCalls,
    required this.window,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int maxCalls;
  final Duration window;
  final DateTime Function() _now;

  final List<DateTime> _calls = <DateTime>[];

  /// Whether another call fits in the window the next time it is asked.
  bool get canAcquire {
    _prune();
    return _calls.length < maxCalls;
  }

  /// Records a call and returns true, or returns false when the window is full.
  bool tryAcquire() {
    if (!canAcquire) return false;
    _calls.add(_now());
    return true;
  }

  void _prune() {
    final cutoff = _now().subtract(window);
    _calls.removeWhere((at) => !at.isAfter(cutoff));
  }
}
