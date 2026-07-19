/// Explicit cancellation primitive shared by update repository operations.
abstract interface class CancellationToken {
  bool get isCancelled;

  void throwIfCancelled();

  void addCancellationListener(void Function() listener);

  void removeCancellationListener(void Function() listener);
}

/// Mutable cancellation source used by application workflows and tests.
final class CancellationTokenSource implements CancellationToken {
  bool _isCancelled = false;
  final Set<void Function()> _listeners = <void Function()>{};

  @override
  bool get isCancelled => _isCancelled;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  @override
  void addCancellationListener(void Function() listener) {
    if (_isCancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  @override
  void removeCancellationListener(void Function() listener) {
    _listeners.remove(listener);
  }

  @override
  void throwIfCancelled() {
    if (_isCancelled) {
      throw const UpdateOperationCancelledException();
    }
  }
}

/// A token suitable for short-lived operations which cannot be cancelled.
final class NonCancellableToken implements CancellationToken {
  const NonCancellableToken();

  @override
  bool get isCancelled => false;

  @override
  void addCancellationListener(void Function() listener) {}

  @override
  void removeCancellationListener(void Function() listener) {}

  @override
  void throwIfCancelled() {}
}

/// Internal signal converted into the stable repository cancellation error.
final class UpdateOperationCancelledException implements Exception {
  const UpdateOperationCancelledException();
}
