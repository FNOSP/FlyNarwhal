import 'dart:async';

abstract interface class UpdateRetryHandle {
  void cancel();
}

abstract interface class UpdateRetryScheduler {
  UpdateRetryHandle schedule(
    Duration delay,
    Future<void> Function() callback,
  );
}

final class TimerUpdateRetryScheduler implements UpdateRetryScheduler {
  const TimerUpdateRetryScheduler();

  @override
  UpdateRetryHandle schedule(
    Duration delay,
    Future<void> Function() callback,
  ) {
    return _TimerUpdateRetryHandle(Timer(delay, callback));
  }
}

final class _TimerUpdateRetryHandle implements UpdateRetryHandle {
  const _TimerUpdateRetryHandle(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

final class NoopUpdateRetryHandle implements UpdateRetryHandle {
  const NoopUpdateRetryHandle();

  @override
  void cancel() {}
}
