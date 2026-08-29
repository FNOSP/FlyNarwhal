import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/utils/log/app_talker.dart';
import '../../../../core/window/desktop_display_service.dart';
import '../../../../core/window/main_window_persistence_guard.dart';
import '../../../../core/window/window_geometry.dart';
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
  // The smallest the normal (non-PiP) player window may be shrunk to. Used to
  // restore the window on PiP exit without growing a user-chosen small size.
  static const Size _playerWindowMinimumSize = Size(640, 360);
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
    final wasBorderless = await _isWindowBorderless();
    _snapshot = _PipWindowSnapshot(
      bounds: bounds,
      wasMaximized: wasMaximized,
      wasFullScreen: wasFullScreen,
      wasBorderless: wasBorderless,
      minimumSize: previousMinimumSize,
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
      await _setMacOSWindowButtonVisibility(false);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(_minimumSizeForRatio(ratio));

      final target = await targetBoundsFuture;
      await windowManager.setBounds(target);
      await windowManager.setAspectRatio(ratio);
      _isPipMode = true;
      return target;
    } catch (_) {
      MainWindowPersistenceGuard.resume();
      rethrow;
    }
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

    try {
      await windowManager.setAspectRatio(0);
      if (snapshot != null) {
        await _setWindowBorderless(snapshot.wasBorderless);
      }
      await _setMacOSWindowButtonVisibility(true);
      await windowManager.setAlwaysOnTop(false);

      if (snapshot == null) {
        return;
      }

      final restoredMinimumSize = _normalMinimumSizeForSnapshot(snapshot);
      await windowManager.setMinimumSize(restoredMinimumSize);
      final displays = await _tryGetDisplays();
      final restoredBounds = WindowGeometry.normalizeMainWindowBounds(
        snapshot.bounds,
        displays,
        fallbackSize: _playerWindowMinimumSize,
        minimumSize: _playerWindowMinimumSize,
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

  /// Persists the current window geometry so the next PiP session reopens at
  /// the same place and size.
  Future<void> persistCurrentBounds() async {
    if (!_isDesktop || !_isPipMode) {
      return;
    }
    try {
      final bounds = await windowManager.getBounds();
      final displays = await _tryGetDisplays();
      final normalizedBounds = WindowGeometry.normalizePipBounds(
        bounds,
        displays,
        margin: _cornerMargin,
        fallbackSize: defaultPipSize,
      );
      if (normalizedBounds != bounds) {
        await windowManager.setBounds(normalizedBounds);
      }
      await PlayerSettingsStore.setPipWindowBounds(normalizedBounds);
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
    final savedBounds =
        preferredBounds ?? await PlayerSettingsStore.getPipWindowBounds();
    // Rebuild around the saved geometric center so the PiP window stays put
    // when the video ratio changes between sessions.
    final requestedBounds = savedBounds == null
        ? _defaultBounds(null, ratio)
        : Rect.fromCenter(
            center: savedBounds.center,
            width: savedBounds.width,
            height: (savedBounds.width / ratio).roundToDouble(),
          );
    final displays = await _tryGetDisplays();
    return WindowGeometry.normalizePipBounds(
      requestedBounds,
      displays,
      margin: _cornerMargin,
      fallbackSize: Size(
        _defaultPipWidth,
        (_defaultPipWidth / ratio).roundToDouble(),
      ),
    );
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

  Size _normalMinimumSizeForSnapshot(_PipWindowSnapshot snapshot) {
    final snapshotMinimumSize = snapshot.minimumSize;
    if (snapshotMinimumSize == null) {
      return _playerWindowMinimumSize;
    }
    final restoredWidth =
        snapshotMinimumSize.width < _playerWindowMinimumSize.width
            ? _playerWindowMinimumSize.width
            : snapshotMinimumSize.width;
    final restoredHeight =
        snapshotMinimumSize.height < _playerWindowMinimumSize.height
            ? _playerWindowMinimumSize.height
            : snapshotMinimumSize.height;
    return Size(restoredWidth, restoredHeight);
  }

  Future<bool> _isWindowBorderless() async {
    if (defaultTargetPlatform != TargetPlatform.windows) {
      return false;
    }

    try {
      return await _displayFrameChannel.invokeMethod<bool>(
            'isWindowBorderless',
          ) ??
          false;
    } catch (error, stackTrace) {
      AppTalker.error(
        'PiP',
        error: error,
        stackTrace: stackTrace,
        message: 'isWindowBorderless failed on Windows',
      );
      return false;
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

  Future<List<DesktopDisplayGeometry>> _tryGetDisplays() async {
    try {
      return await const DesktopDisplayService().getDisplays();
    } catch (_) {
      return const [];
    }
  }
}

class _PipWindowSnapshot {
  const _PipWindowSnapshot({
    required this.bounds,
    required this.wasMaximized,
    required this.wasFullScreen,
    required this.wasBorderless,
    required this.minimumSize,
  });

  final Rect bounds;
  final bool wasMaximized;
  final bool wasFullScreen;
  final bool wasBorderless;
  final Size? minimumSize;
}
