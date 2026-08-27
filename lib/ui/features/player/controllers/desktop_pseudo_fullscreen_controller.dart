import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/utils/log/app_talker.dart';
import '../../../../core/window/desktop_display_service.dart';
import '../../../../core/window/main_window_persistence_guard.dart';
import '../../../../core/window/window_geometry.dart';

class DesktopPseudoFullscreenController {
  static const MethodChannel _displayFrameChannel =
      MethodChannel('fly_narwhal/window_display_frame');
  static const Duration _windowStateTransitionDelay =
      Duration(milliseconds: 16);

  _WindowSnapshot? _snapshot;
  bool _isPseudoFullscreen = false;

  bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  bool get _isWindowsOrLinux =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  Future<bool> toggle() async {
    if (_isMacOS) {
      final nextFullscreenState = !await windowManager.isFullScreen();

      // Keep macOS on the system fullscreen path as requested.
      await windowManager.setFullScreen(nextFullscreenState);
      return nextFullscreenState;
    }

    if (_isWindowsOrLinux) {
      if (_isPseudoFullscreen) {
        await exit();
        return false;
      }

      await enter();
      return true;
    }

    return false;
  }

  Future<void> enter() async {
    if (!_isWindowsOrLinux || _isPseudoFullscreen) {
      return;
    }

    // Capture the current window state before switching to pseudo fullscreen.
    final bounds = await windowManager.getBounds();
    final wasMaximized = await windowManager.isMaximized();
    final wasFullScreen = await windowManager.isFullScreen();
    _snapshot = _WindowSnapshot(
      bounds: bounds,
      wasMaximized: wasMaximized,
      wasFullScreen: wasFullScreen,
    );

    MainWindowPersistenceGuard.suspend();
    try {
      if (wasFullScreen) {
        await windowManager.setFullScreen(false);
        await Future<void>.delayed(_windowStateTransitionDelay);
      }

      if (wasMaximized) {
        await windowManager.unmaximize();
        await Future<void>.delayed(_windowStateTransitionDelay);
      }

      await _setWindowBorderless(true);
      final targetFrame = await _getCurrentDisplayFrame();
      await windowManager.setBounds(targetFrame);
      _isPseudoFullscreen = true;
    } catch (_) {
      MainWindowPersistenceGuard.resume();
      rethrow;
    }
  }

  Future<void> exit() async {
    if (!_isWindowsOrLinux || !_isPseudoFullscreen) {
      return;
    }

    final snapshot = _snapshot;
    _snapshot = null;
    _isPseudoFullscreen = false;
    if (snapshot == null) {
      return;
    }

    try {
      await _setWindowBorderless(false);
      final displays = await _tryGetDisplays();
      final restoredBounds = WindowGeometry.normalizeMainWindowBounds(
        snapshot.bounds,
        displays,
        fallbackSize: const Size(640, 360),
        minimumSize: const Size(640, 360),
      );
      await windowManager.setBounds(restoredBounds);
      if (snapshot.wasMaximized) {
        await Future<void>.delayed(_windowStateTransitionDelay);
        await windowManager.maximize();
      }
    } finally {
      MainWindowPersistenceGuard.resume();
    }
  }

  Future<bool> exitForRouteLeave() async {
    if (_isMacOS) {
      final isFullscreen = await windowManager.isFullScreen();
      if (isFullscreen) {
        await windowManager.setFullScreen(false);
      }
      return false;
    }

    if (_isWindowsOrLinux && _isPseudoFullscreen) {
      await exit();
    }

    return false;
  }

  Future<bool> syncState() async {
    if (_isMacOS) {
      return windowManager.isFullScreen();
    }

    if (_isWindowsOrLinux) {
      return _isPseudoFullscreen;
    }

    return false;
  }

  Future<void> _setWindowBorderless(bool borderless) async {
    // Borderless toggling is only meaningful on Windows/Linux pseudo-fullscreen
    // paths; macOS uses the system fullscreen API which already hides borders.
    if (_isMacOS) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      try {
        await _displayFrameChannel.invokeMethod(
          'setWindowBorderless',
          <String, dynamic>{'borderless': borderless},
        );
      } catch (error, stackTrace) {
        AppTalker.error(
          'Fullscreen',
          error: error,
          stackTrace: stackTrace,
          message: 'setWindowBorderless($borderless) failed on Windows',
        );
        // Non-fatal: pseudo-fullscreen still works, just with visible borders.
      }
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.linux) {
      try {
        if (borderless) {
          await windowManager.setAsFrameless();
        } else {
          await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        }
      } catch (error, stackTrace) {
        AppTalker.error(
          'Fullscreen',
          error: error,
          stackTrace: stackTrace,
          message: 'Linux borderless toggle failed',
        );
      }
    }
  }

  Future<Rect> _getCurrentDisplayFrame() async {
    final result =
        await _displayFrameChannel.invokeMethod<Map<Object?, Object?>>(
      'getCurrentDisplayFrame',
    );
    if (result == null) {
      throw PlatformException(
        code: 'display_frame_unavailable',
        message: 'Current display frame is unavailable.',
      );
    }

    return Rect.fromLTWH(
      _readDouble(result, 'x'),
      _readDouble(result, 'y'),
      _readDouble(result, 'width'),
      _readDouble(result, 'height'),
    );
  }

  Future<List<DesktopDisplayGeometry>> _tryGetDisplays() async {
    try {
      return await const DesktopDisplayService().getDisplays();
    } catch (_) {
      return const [];
    }
  }

  double _readDouble(Map<Object?, Object?> result, String key) {
    final value = result[key];
    if (value is num) {
      return value.toDouble();
    }

    throw PlatformException(
      code: 'invalid_display_frame',
      message: 'Missing numeric "$key" in display frame response.',
    );
  }
}

class _WindowSnapshot {
  const _WindowSnapshot({
    required this.bounds,
    required this.wasMaximized,
    required this.wasFullScreen,
  });

  final Rect bounds;
  final bool wasMaximized;
  final bool wasFullScreen;
}
