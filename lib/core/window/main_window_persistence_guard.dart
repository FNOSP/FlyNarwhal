class MainWindowPersistenceGuard {
  const MainWindowPersistenceGuard._();

  static int _suspensionCount = 0;

  static bool get isSuspended => _suspensionCount > 0;

  static void suspend() {
    _suspensionCount += 1;
  }

  static void resume() {
    if (_suspensionCount > 0) {
      _suspensionCount -= 1;
    }
  }
}
