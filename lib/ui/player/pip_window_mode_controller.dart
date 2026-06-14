import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/utils/log/app_talker.dart';
import '../../data/storage/player_settings_store.dart';

/// Controls switching the main player window in and out of a compact
/// picture-in-picture (PiP) form factor while reusing the same window and the
/// same media_kit player instance.
///
/// Entering captures the current window geometry, removes the window frame,
/// pins the window on top, shrinks it to a corner, and keeps it resizable so
/// the user can still drag the window edges. Exiting restores the original
/// geometry, frame, and maximized state.
class PipWindowModeController {
  static const MethodChannel _displayFrameChannel =
      MethodChannel('fly_narwhal/window_display_frame');
  static const Duration _windowStateTransitionDelay =
      Duration(milliseconds: 16);

  static const Size defaultPipSize = Size(320, 180);
  static const Size minimumPipSize = Size(280, 158);
  static const double _cornerMargin = 24;

  _PipWindowSnapshot? _snapshot;
  bool _isPipMode = false;

  bool get isPipMode => _isPipMode;

  bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  bool get _isWindowsOrLinux =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);
  bool get _isDesktop => _isMacOS || _isWindowsOrLinux;

  /// Switches the main window into PiP form. Returns the applied PiP bounds.
  Future<Rect> enter({Rect? preferredBounds}) async {
    if (!_isDesktop || _isPipMode) {
      return preferredBounds ?? _defaultBounds();
    }

    // Capture the current window state so it can be restored on exit.
    final bounds = await windowManager.getBounds();
    final wasMaximized = await windowManager.isMaximized();
    final wasFullScreen = await windowManager.isFullScreen();
    final previousMinimumSize = await _safeGetMinimumSize();
    _snapshot = _PipWindowSnapshot(
      bounds: bounds,
      wasMaximized: wasMaximized,
      wasFullScreen: wasFullScreen,
      minimumSize: previousMinimumSize,
    );

    if (wasFullScreen) {
      await windowManager.setFullScreen(false);
      await Future<void>.delayed(_windowStateTransitionDelay);
    }

    if (wasMaximized) {
      await windowManager.unmaximize();
      await Future<void>.delayed(_windowStateTransitionDelay);
    }

    // Drop the window frame so the compact player fills the small window.
    await _setWindowBorderless(true);
    await windowManager.setAlwaysOnTop(true);

    // Keep edge resizing available in PiP form.
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(minimumPipSize);

    final target = await _resolvePipBounds(preferredBounds);
    await windowManager.setBounds(target);
    _isPipMode = true;
    return target;
  }

  /// Restores the window to its pre-PiP geometry and chrome.
  Future<void> exit() async {
    if (!_isDesktop || !_isPipMode) {
      return;
    }

    final snapshot = _snapshot;
    _snapshot = null;
    _isPipMode = false;

    await _setWindowBorderless(false);
    await windowManager.setAlwaysOnTop(false);

    if (snapshot == null) {
      return;
    }

    if (snapshot.minimumSize != null) {
      await windowManager.setMinimumSize(snapshot.minimumSize!);
    }

    await windowManager.setBounds(snapshot.bounds);
    if (snapshot.wasMaximized) {
      await Future<void>.delayed(_windowStateTransitionDelay);
      await windowManager.maximize();
    }
  }

  /// Persists the current window geometry so the next PiP session reopens at
  /// the same place and size.
  Future<void> persistCurrentBounds() async {
    if (!_isDesktop || !_isPipMode) {
      return;
    }
    try {
      final bounds = await windowManager.getBounds();
      await PlayerSettingsStore.setPipWindowBounds(bounds);
    } catch (error, stackTrace) {
      AppTalker.error(
        'PiP',
        error: error,
        stackTrace: stackTrace,
        message: 'persistCurrentBounds failed',
      );
    }
  }

  Future<Rect> _resolvePipBounds(Rect? preferredBounds) async {
    if (preferredBounds != null) {
      return preferredBounds;
    }
    final saved = await PlayerSettingsStore.getPipWindowBounds();
    if (saved != null) {
      return saved;
    }
    return _defaultBounds(await _tryGetDisplayFrame());
  }

  Rect _defaultBounds([Rect? displayFrame]) {
    final size = defaultPipSize;
    if (displayFrame == null) {
      return Rect.fromLTWH(_cornerMargin, _cornerMargin, size.width, size.height);
    }
    // Anchor to the bottom-right corner of the current display.
    final left = displayFrame.right - size.width - _cornerMargin;
    final top = displayFrame.bottom - size.height - _cornerMargin;
    return Rect.fromLTWH(left, top, size.width, size.height);
  }

  Future<Size?> _safeGetMinimumSize() async {
    try {
      // window_manager does not expose a getter; default back to a sane min.
      return const Size(640, 360);
    } catch (_) {
      return null;
    }
  }

  Future<void> _setWindowBorderless(bool borderless) async {
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
          'PiP',
          error: error,
          stackTrace: stackTrace,
          message: 'setWindowBorderless($borderless) failed on Windows',
        );
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
          'PiP',
          error: error,
          stackTrace: stackTrace,
          message: 'Linux borderless toggle failed',
        );
      }
    }
  }

  Future<Rect?> _tryGetDisplayFrame() async {
    if (!_isWindowsOrLinux) {
      return null;
    }
    try {
      final result =
          await _displayFrameChannel.invokeMethod<Map<Object?, Object?>>(
        'getCurrentDisplayFrame',
      );
      if (result == null) {
        return null;
      }
      return Rect.fromLTWH(
        _readDouble(result, 'x'),
        _readDouble(result, 'y'),
        _readDouble(result, 'width'),
        _readDouble(result, 'height'),
      );
    } catch (_) {
      return null;
    }
  }

  double _readDouble(Map<Object?, Object?> result, String key) {
    final value = result[key];
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }
}

class _PipWindowSnapshot {
  const _PipWindowSnapshot({
    required this.bounds,
    required this.wasMaximized,
    required this.wasFullScreen,
    required this.minimumSize,
  });

  final Rect bounds;
  final bool wasMaximized;
  final bool wasFullScreen;
  final Size? minimumSize;
}
