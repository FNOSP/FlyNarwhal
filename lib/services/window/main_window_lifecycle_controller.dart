import 'dart:async';
import 'dart:io' show Platform, exit;

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

  /// True once a close has been initiated and is in flight, so a repeated
  /// native close signal never re-enters the interception handshake.
  bool _closeInFlight = false;

  /// True once the app is being torn down for good (the update installer needs
  /// the whole process gone). Unlike a plain window close, this must end the
  /// process even if the native close signal cannot complete.
  bool _shutdownInFlight = false;

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
  void onWindowMaximize() {
    if (_isDisposed || MainWindowPersistenceGuard.isSuspended) {
      return;
    }
    unawaited(_settingsStore.saveMaximized(true));
  }

  @override
  void onWindowUnmaximize() {
    if (_isDisposed || MainWindowPersistenceGuard.isSuspended) {
      return;
    }
    unawaited(_settingsStore.saveMaximized(false));
    _scheduleSave();
  }

  @override
  Future<void> onWindowClose() async {
    if (_closeInFlight) {
      return;
    }
    _closeInFlight = true;
    _saveTimer?.cancel();

    await flush();

    if (!kIsWeb && Platform.isMacOS) {
      await windowManager.hide();
      _closeInFlight = false;
      return;
    }

    // window_manager 0.5.x close() only posts WM_SYSCOMMAND/SC_CLOSE on
    // Windows. Release close interception and post a native close so the
    // window and engine complete their normal destruction lifecycle.
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  /// Terminates the app so a detached installer that waits on this process
  /// (Windows update helper, macOS/Linux helper) can replace it.
  ///
  /// A plain [onWindowClose] is not enough here: closing the window does not
  /// reliably end the process, and the installer blocks until the process
  /// itself disappears. Persist window state first, then end the process for
  /// certain.
  Future<void> requestShutdown() async {
    if (_shutdownInFlight) {
      return;
    }
    _shutdownInFlight = true;
    _closeInFlight = true;
    _saveTimer?.cancel();

    await flush();

    // Best effort: let the window close through the normal path so the engine
    // tears down cleanly. A hang here must not delay the install.
    try {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (error, stackTrace) {
      AppTalker.error(
        'Window',
        error: error,
        stackTrace: stackTrace,
        message: 'Window close during shutdown failed',
      );
    }

    // The installer waits on this process exiting, so guarantee it even when
    // the native close signal did not complete. The window state was already
    // flushed above.
    exit(0);
  }
}
