import 'dart:async';

import 'cdn_proxy_errors.dart';

/// Internal cancellation scope with registrations owned by each pending wait.
/// Completed waits must not remain attached to a long-lived cancellation future.
final class CdnCancellation {
  final Set<void Function()> _listeners = {};
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  /// Resource observation for focused cancellation tests.
  int get listenerCount => _listeners.length;

  /// Registers one callback and returns an idempotent way to detach it.
  void Function() onCancel(void Function() callback) {
    // A separate registration lets the same callback be subscribed more than once.
    void listener() => callback();
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
    return () => _listeners.remove(listener);
  }

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    final listeners = _listeners.toList();
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  Future<T> wait<T>(Future<T> operation) async {
    // Observe both futures before registering cancellation, including when the
    // scope has already ended. A late operation error still needs an owner.
    final cancelled = Completer<T>();
    final result = Future.any<T>([operation, cancelled.future]);
    final unregister =
        onCancel(() => cancelled.completeError(const CdnRangeCancelled()));
    try {
      final value = await result;
      // Cancellation may happen after operation completes but before we resume.
      if (_isCancelled) throw const CdnRangeCancelled();
      return value;
    } finally {
      // The losing future is private to this wait and can now be collected.
      unregister();
    }
  }
}
