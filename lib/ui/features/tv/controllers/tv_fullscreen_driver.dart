import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/utils/log/app_talker.dart';
import '../../../../core/window/main_window_persistence_guard.dart';
import '../../player/controllers/desktop_pseudo_fullscreen_controller.dart';

/// Drives the window fullscreen form for the TV big-screen mode.
///
/// Platform policy (differs from the player, where Linux also uses pseudo
/// fullscreen): macOS and Linux enter the real system fullscreen via
/// [WindowManager.setFullScreen]; Windows uses the borderless pseudo
/// fullscreen by composing the player's [DesktopPseudoFullscreenController]
/// (which owns its persistence-guard pairing internally).
class TvFullscreenDriver {
  TvFullscreenDriver();

  final DesktopPseudoFullscreenController _pseudo =
      DesktopPseudoFullscreenController();

  bool _isTransitioning = false;
  bool _guardSuspended = false;

  /// True while an enter/exit transition is in flight. The TV screen uses
  /// this to tell its own fullscreen changes apart from user gestures
  /// (e.g. the macOS green traffic-light button).
  bool get isTransitioning => _isTransitioning;

  bool get _usesPseudoFullscreen =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool get _supportsFullscreen =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows);

  Future<void> enter() async {
    if (!_supportsFullscreen || _isTransitioning) {
      return;
    }

    _isTransitioning = true;
    try {
      if (_usesPseudoFullscreen) {
        // The pseudo controller suspends/resumes the persistence guard itself.
        await _pseudo.enter();
      } else {
        MainWindowPersistenceGuard.suspend();
        _guardSuspended = true;
        try {
          await windowManager.setFullScreen(true);
        } catch (_) {
          MainWindowPersistenceGuard.resume();
          _guardSuspended = false;
          rethrow;
        }
      }
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> exit() async {
    if (!_supportsFullscreen || _isTransitioning) {
      return;
    }

    _isTransitioning = true;
    try {
      if (_usesPseudoFullscreen) {
        await _pseudo.exit();
        return;
      }

      try {
        if (await windowManager.isFullScreen()) {
          await windowManager.setFullScreen(false);
          // Wait for the system fullscreen-exit animation to settle before
          // letting window geometry persistence resume, mirroring the
          // player's restore path (<= 15 × 100ms).
          for (var i = 0; i < 15; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            if (!await windowManager.isFullScreen()) {
              break;
            }
          }
        }
      } catch (error, stackTrace) {
        AppTalker.error(
          'TvFullscreen',
          error: error,
          stackTrace: stackTrace,
          message: 'setFullScreen(false) failed',
        );
      } finally {
        if (_guardSuspended) {
          MainWindowPersistenceGuard.resume();
          _guardSuspended = false;
        }
      }
    } finally {
      _isTransitioning = false;
    }
  }

  /// Whether the window is currently in the TV fullscreen form. Used by the
  /// leave-fullscreen fallback so it does not fire for the pseudo path
  /// (Windows has no system leave event) or non-desktop platforms.
  Future<bool> isFullscreenActive() async {
    if (!_supportsFullscreen) {
      return false;
    }
    if (_usesPseudoFullscreen) {
      return _pseudo.syncState();
    }
    try {
      return await windowManager.isFullScreen();
    } catch (_) {
      return false;
    }
  }
}
