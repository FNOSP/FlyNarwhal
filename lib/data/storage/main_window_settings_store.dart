import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import 'centered_window_bounds_codec.dart';

class MainWindowState {
  const MainWindowState({required this.bounds, required this.isMaximized});

  final Rect bounds;
  final bool isMaximized;
}

class MainWindowSettingsStore {
  MainWindowSettingsStore(this._preferences);

  // Geometry is persisted as geometric center + size (see
  // CenteredWindowBoundsCodec); the legacy top-left keys live under the same
  // prefix and are kept in sync for downgrade compatibility.
  static const String _boundsPrefix = 'main_window';
  static const String _maximizedKey = 'main_window_maximized';

  final SharedPreferences _preferences;

  MainWindowState? read() {
    final bounds = CenteredWindowBoundsCodec.read(_preferences, _boundsPrefix);
    if (bounds == null) {
      return null;
    }

    return MainWindowState(
      bounds: bounds,
      isMaximized: _preferences.getBool(_maximizedKey) ?? false,
    );
  }

  Future<void> saveBounds(Rect bounds) {
    return CenteredWindowBoundsCodec.write(_preferences, _boundsPrefix, bounds);
  }

  Future<void> saveMaximized(bool isMaximized) {
    return _preferences.setBool(_maximizedKey, isMaximized);
  }
}
