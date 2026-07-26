import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/utils/log/app_talker.dart';
import '../../core/window/main_window_persistence_guard.dart';
import '../../data/storage/main_window_settings_store.dart';

class MainWindowLifecycleController with WindowListener {
  MainWindowLifecycleController(SharedPreferences preferences)
      : _settingsStore = MainWindowSettingsStore(preferences);

  static const Duration _saveDebounce = Duration(milliseconds: 500);

  final MainWindowSettingsStore _settingsStore;
  Timer? _saveTimer;
  bool _isDisposed = false;
  bool _isSaving = false;
  bool _isClosing = false;

  void start() {
    windowManager.addListener(this);
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _saveTimer?.cancel();
    windowManager.removeListener(this);
    await flush();
  }

  void _scheduleSave() {
    if (_isDisposed || MainWindowPersistenceGuard.isSuspended) {
      return;
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () => unawaited(flush()));
  }

  Future<void> flush() async {
    if (_isSaving || MainWindowPersistenceGuard.isSuspended) {
      return;
    }
    _isSaving = true;
    try {
      final isMaximized = await windowManager.isMaximized();
      final isFullScreen = await windowManager.isFullScreen();
      await _settingsStore.saveMaximized(isMaximized);
      if (!isMaximized && !isFullScreen) {
        final bounds = await windowManager.getBounds();
        await _settingsStore.saveBounds(bounds);
      }
    } catch (error, stackTrace) {
      AppTalker.error(
        'Window',
        error: error,
        stackTrace: stackTrace,
        message: 'Main window state save failed',
      );
    } finally {
      _isSaving = false;
    }
  }

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowMaximize() => unawaited(_settingsStore.saveMaximized(true));

  @override
  void onWindowUnmaximize() {
    unawaited(_settingsStore.saveMaximized(false));
    _scheduleSave();
  }

  @override
  Future<void> onWindowClose() async {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    _saveTimer?.cancel();

    await flush();

    if (!kIsWeb && Platform.isMacOS) {
      await windowManager.hide();
      _isClosing = false;
      return;
    }

    // window_manager 0.3.9 destroy() only posts WM_QUIT on Windows. Release
    // close interception and post a native close so the window and engine
    // complete their normal destruction lifecycle.
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }
}
