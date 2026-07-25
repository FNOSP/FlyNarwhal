import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

class MainWindowState {
  const MainWindowState({required this.bounds, required this.isMaximized});

  final Rect bounds;
  final bool isMaximized;
}

class MainWindowSettingsStore {
  MainWindowSettingsStore(this._preferences);

  static const String _leftKey = 'main_window_left';
  static const String _topKey = 'main_window_top';
  static const String _widthKey = 'main_window_width';
  static const String _heightKey = 'main_window_height';
  static const String _maximizedKey = 'main_window_maximized';

  final SharedPreferences _preferences;

  MainWindowState? read() {
    final left = _preferences.getDouble(_leftKey);
    final top = _preferences.getDouble(_topKey);
    final width = _preferences.getDouble(_widthKey);
    final height = _preferences.getDouble(_heightKey);
    if (left == null || top == null || width == null || height == null) {
      return null;
    }

    return MainWindowState(
      bounds: Rect.fromLTWH(left, top, width, height),
      isMaximized: _preferences.getBool(_maximizedKey) ?? false,
    );
  }

  Future<void> saveBounds(Rect bounds) async {
    await Future.wait([
      _preferences.setDouble(_leftKey, bounds.left),
      _preferences.setDouble(_topKey, bounds.top),
      _preferences.setDouble(_widthKey, bounds.width),
      _preferences.setDouble(_heightKey, bounds.height),
    ]);
  }

  Future<void> saveMaximized(bool isMaximized) {
    return _preferences.setBool(_maximizedKey, isMaximized);
  }
}
