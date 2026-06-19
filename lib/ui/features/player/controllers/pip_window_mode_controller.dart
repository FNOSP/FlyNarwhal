import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/utils/log/app_talker.dart';
import '../../../../data/storage/player_settings_store.dart';

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
  static const double _defaultPipWidth = 320;
  static const double _minimumPipWidth = 280;
  static const double _fallbackAspectRatio = 16 / 9;

  _PipWindowSnapshot? _snapshot;
  bool _isPipMode = false;
  double? _currentAspectRatio;

  bool get isPipMode => _isPipMode;

  bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  bool get _isWindowsOrLinux =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);
  bool get _isDesktop => _isMacOS || _isWindowsOrLinux;

  /// Switches the main window into PiP form. Returns the applied PiP bounds.
  ///
  /// [videoAspectRatio] (width / height) makes the PiP window match the video
  /// so there are no letterbox bars, and locks edge resizing to that ratio.
  Future<Rect> enter({Rect? preferredBounds, double? videoAspectRatio}) async {
    final ratio = _normalizeAspectRatio(videoAspectRatio);
    _currentAspectRatio = ratio;
    if (!_isDesktop || _isPipMode) {
      return preferredBounds ?? _defaultBounds(null, ratio);
    }

    // Capture the current window state and resolve target bounds in parallel,
    // so that independent queries don't wait on each other serially.
    final snapshotFuture = Future.wait([
      windowManager.getBounds(),
      windowManager.isMaximized(),
      windowManager.isFullScreen(),
      _safeGetMinimumSize(),
    ]);
    final targetBoundsFuture = _resolvePipBounds(preferredBounds, ratio);

    final snapshot = await snapshotFuture;
    final bounds = snapshot[0] as Rect;
    final wasMaximized = snapshot[1] as bool;
    final wasFullScreen = snapshot[2] as bool;
    final previousMinimumSize = snapshot[3] as Size?;
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
    await _setMacOSWindowButtonVisibility(false);
    await windowManager.setAlwaysOnTop(true);

    // Keep edge resizing available in PiP form.
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(_minimumSizeForRatio(ratio));

    final target = await targetBoundsFuture;
    await windowManager.setBounds(target);

    // Lock edge resizing to the video aspect ratio after the resize border is
    // restored by setResizable, so dragging keeps the same shape.
    await windowManager.setAspectRatio(ratio);
    _isPipMode = true;
    return target;
  }

  /// Re-applies a new video aspect ratio while already in PiP form, e.g. after
  /// a resolution or track switch changes the video dimensions.
  Future<void> updateAspectRatio(double videoAspectRatio) async {
    final ratio = _normalizeAspectRatio(videoAspectRatio);
    _currentAspectRatio = ratio;
    if (!_isDesktop || !_isPipMode) {
      return;
    }
    try {
      await windowManager.setMinimumSize(_minimumSizeForRatio(ratio));
      await windowManager.setAspectRatio(ratio);
      final bounds = await windowManager.getBounds();
      await windowManager.setSize(
        Size(bounds.width, (bounds.width / ratio).roundToDouble()),
      );
    } catch (error, stackTrace) {
      AppTalker.error(
        'PiP',
        error: error,
        stackTrace: stackTrace,
        message: 'updateAspectRatio failed',
      );
    }
  }

  /// Restores the window to its pre-PiP geometry and chrome.
  Future<void> exit() async {
    if (!_isDesktop || !_isPipMode) {
      return;
    }

    final snapshot = _snapshot;
    _snapshot = null;
    _isPipMode = false;
    _currentAspectRatio = null;

    // Release the ratio lock so the restored window can resize freely.
    await windowManager.setAspectRatio(0);
    await _setWindowBorderless(false);
    await _setMacOSWindowButtonVisibility(true);
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

  Future<Rect> _resolvePipBounds(Rect? preferredBounds, double ratio) async {
    if (preferredBounds != null) {
      return preferredBounds;
    }
    final saved = await PlayerSettingsStore.getPipWindowBounds();
    if (saved != null) {
      // Normalize a previously saved size to the current video ratio so the
      // window stays letterbox-free across sessions.
      final height = (saved.width / ratio).roundToDouble();
      return Rect.fromLTWH(saved.left, saved.top, saved.width, height);
    }
    return _defaultBounds(await _tryGetDisplayFrame(), ratio);
  }

  Rect _defaultBounds([Rect? displayFrame, double? aspectRatio]) {
    final ratio = aspectRatio ?? _currentAspectRatio ?? _fallbackAspectRatio;
    const width = _defaultPipWidth;
    final height = (width / ratio).roundToDouble();
    if (displayFrame == null) {
      return Rect.fromLTWH(_cornerMargin, _cornerMargin, width, height);
    }
    // Anchor to the bottom-right corner of the current display.
    final left = displayFrame.right - width - _cornerMargin;
    final top = displayFrame.bottom - height - _cornerMargin;
    return Rect.fromLTWH(left, top, width, height);
  }

  double _normalizeAspectRatio(double? ratio) {
    if (ratio == null || !ratio.isFinite || ratio <= 0) {
      return _fallbackAspectRatio;
    }
    return ratio;
  }

  Size _minimumSizeForRatio(double ratio) {
    const width = _minimumPipWidth;
    final height = (width / ratio).roundToDouble();
    return Size(width, height);
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

  Future<void> _setMacOSWindowButtonVisibility(bool visible) async {
    if (!_isMacOS) {
      return;
    }
    try {
      // Keep the hidden title bar mode unchanged and only toggle the macOS
      // traffic-light buttons for the PiP window lifecycle.
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: visible,
      );
    } catch (error, stackTrace) {
      AppTalker.error(
        'PiP',
        error: error,
        stackTrace: stackTrace,
        message: 'set macOS window button visibility failed: $visible',
      );
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
