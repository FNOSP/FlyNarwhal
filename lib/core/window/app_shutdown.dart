typedef AppShutdownHandler = Future<void> Function();

/// Bridges the app's window lifecycle to callers that must terminate the
/// process (the update installer), without making either side import the other.
///
/// `app.dart` registers the handler at bootstrap; the update providers invoke
/// it. When nothing is registered the caller falls back to a raw process exit.
class AppShutdown {
  const AppShutdown._();

  static AppShutdownHandler? _handler;

  static void register(AppShutdownHandler handler) {
    _handler = handler;
  }

  static void unregister() {
    _handler = null;
  }

  static AppShutdownHandler? get handler => _handler;
}