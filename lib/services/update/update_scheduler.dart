import 'dart:async';

/// Supplies wall-clock time to the automatic update scheduler.
abstract interface class UpdateSchedulerClock {
  DateTime now();
}

/// Represents a cancellable one-shot scheduler timer.
abstract interface class UpdateSchedulerTimer {
  bool get isActive;

  void cancel();
}

/// Creates one-shot timers without coupling tests to real time.
abstract interface class UpdateSchedulerTimerFactory {
  UpdateSchedulerTimer create(Duration delay, void Function() callback);
}

/// Creates production timers backed by [Timer].
final class SystemUpdateSchedulerTimerFactory
    implements UpdateSchedulerTimerFactory {
  const SystemUpdateSchedulerTimerFactory();

  @override
  UpdateSchedulerTimer create(Duration delay, void Function() callback) {
    return _SystemUpdateSchedulerTimer(Timer(delay, callback));
  }
}

final class _SystemUpdateSchedulerTimer implements UpdateSchedulerTimer {
  const _SystemUpdateSchedulerTimer(this._timer);

  final Timer _timer;

  @override
  bool get isActive => _timer.isActive;

  @override
  void cancel() => _timer.cancel();
}

/// Supplies production wall-clock time.
final class SystemUpdateSchedulerClock implements UpdateSchedulerClock {
  const SystemUpdateSchedulerClock();

  @override
  DateTime now() => DateTime.now();
}

enum UpdateSchedulerLifecycleState { foreground, background }

/// Schedules desktop automatic checks independently from UI lifecycles.
final class UpdateScheduler {
  UpdateScheduler({
    required Future<void> Function() checkForUpdates,
    required Duration startupDelay,
    required Duration interval,
    UpdateSchedulerClock clock = const SystemUpdateSchedulerClock(),
    UpdateSchedulerTimerFactory timerFactory =
        const SystemUpdateSchedulerTimerFactory(),
    bool isSupportedPlatform = true,
  })  : _checkForUpdates = checkForUpdates,
        _startupDelay = startupDelay,
        _interval = interval,
        _clock = clock,
        _timerFactory = timerFactory,
        _isSupportedPlatform = isSupportedPlatform;

  final Future<void> Function() _checkForUpdates;
  final Duration _startupDelay;
  final Duration _interval;
  final UpdateSchedulerClock _clock;
  final UpdateSchedulerTimerFactory _timerFactory;
  final bool _isSupportedPlatform;

  UpdateSchedulerTimer? _timer;
  DateTime? _nextAutomaticCheckAt;
  DateTime? _lastAutomaticCheckStartedAt;
  bool _isStarted = false;
  bool _isForeground = true;
  bool _isAutomaticCheckRunning = false;
  bool _isDisposed = false;

  DateTime? get nextAutomaticCheckAt => _nextAutomaticCheckAt;

  DateTime? get lastAutomaticCheckStartedAt => _lastAutomaticCheckStartedAt;

  bool get isDisposed => _isDisposed;

  void start() {
    if (_isStarted || _isDisposed || !_isSupportedPlatform) return;
    _isStarted = true;
    _nextAutomaticCheckAt = _clock.now().add(_startupDelay);
    if (_isForeground) {
      _scheduleNextTimer();
    }
  }

  void handleLifecycleState(UpdateSchedulerLifecycleState state) {
    if (_isDisposed || !_isStarted || !_isSupportedPlatform) return;
    final shouldBeForeground =
        state == UpdateSchedulerLifecycleState.foreground;
    if (_isForeground == shouldBeForeground) return;
    _isForeground = shouldBeForeground;

    if (!_isForeground) {
      _cancelTimer();
      return;
    }

    // Resume against the existing deadline so elapsed time is not discarded.
    _scheduleNextTimer();
  }

  Future<void> stop() async {
    _cancelTimer();
    _isStarted = false;
    _nextAutomaticCheckAt = null;
    _lastAutomaticCheckStartedAt = null;
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    await stop();
    _isDisposed = true;
  }

  void _scheduleNextTimer() {
    _cancelTimer();
    if (!_isStarted || !_isForeground || _isDisposed) return;
    final deadline = _nextAutomaticCheckAt;
    if (deadline == null) return;
    final remaining = deadline.difference(_clock.now());
    final delay = remaining.isNegative ? Duration.zero : remaining;
    _timer = _timerFactory.create(delay, _handleTimer);
  }

  void _handleTimer() {
    _timer = null;
    if (!_isStarted || !_isForeground || _isDisposed) return;

    // A late wake-up represents all missed intervals with one automatic tick.
    final automaticCheckStartedAt = _clock.now();
    _nextAutomaticCheckAt = automaticCheckStartedAt.add(_interval);
    _scheduleNextTimer();

    // Skip a conflicting tick without queueing work behind the active check.
    if (_isAutomaticCheckRunning) return;
    _isAutomaticCheckRunning = true;
    _lastAutomaticCheckStartedAt = automaticCheckStartedAt;
    unawaited(
      _checkForUpdates().whenComplete(() {
        _isAutomaticCheckRunning = false;
      }),
    );
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
