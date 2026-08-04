import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/utils/log/app_talker.dart';
import '../../../../core/window/desktop_display_service.dart';
import '../../../../core/window/window_geometry.dart';

/// Applies the player's window aspect ratio setting ("窗口比例") to the main
/// window, mirroring the KMP player's behavior.
///
/// Fixed settings ("4:3", "16:9", "21:9") lock the window to that ratio and
/// perform a one-shot resize based on the KMP expansion strategy: wider
/// targets keep the height and grow the width, narrower targets keep the
/// width and grow the height, with the width clamped to ±50% of the current
/// size so a distorted window cannot explode.
///
/// The "AUTO" setting follows the PiP approach instead: the window aspect
/// ratio is locked to the video's own aspect ratio via
/// [WindowManager.setAspectRatio], so the video frame and the window stay
/// perfectly matched even while the user resizes the window.
class PlayerWindowAspectRatioController {
  static const Map<String, double> _fixedRatios = {
    '4:3': 4 / 3,
    '16:9': 16 / 9,
    '21:9': 21 / 9,
  };
  static const String autoSetting = 'AUTO';
  static const Duration _windowStateTransitionDelay =
      Duration(milliseconds: 16);
  static const Size _normalWindowMinimumSize = Size(1280, 720);
  // Aspect ratios closer than this are considered identical, avoiding
  // redundant window resizing when repeated video-param events arrive.
  static const double _ratioEpsilon = 0.005;

  String? _appliedSetting;
  double? _lockedRatio;

  /// The setting currently locked onto the window, if any.
  String? get appliedSetting => _appliedSetting;

  bool get hasActiveLock => _lockedRatio != null;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Resolves the fixed ratio for settings like "16:9", or null for AUTO.
  static double? fixedRatioOf(String setting) => _fixedRatios[setting];

  /// Applies [setting] to the main window.
  ///
  /// [videoAspectRatio] (width / height) is required for AUTO mode; when it
  /// is not available yet the call is a no-op so callers can retry once the
  /// video size becomes known.
  Future<void> apply({
    required String setting,
    double? videoAspectRatio,
  }) async {
    if (!_isDesktop) {
      return;
    }

    final targetRatio = setting == autoSetting
        ? _normalizeRatio(videoAspectRatio)
        : _fixedRatios[setting];
    if (targetRatio == null) {
      // AUTO without a known video size: keep whatever is locked until the
      // size arrives; a retry is expected once video params are available.
      return;
    }

    final previousLockedRatio = _lockedRatio;
    _appliedSetting = setting;
    _lockedRatio = targetRatio;

    try {
      final alreadyLocked = previousLockedRatio != null &&
          (previousLockedRatio - targetRatio).abs() < _ratioEpsilon;

      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
        await Future<void>.delayed(_windowStateTransitionDelay);
      }

      final bounds = await windowManager.getBounds();
      final currentRatio =
          bounds.height > 0 ? bounds.width / bounds.height : targetRatio;
      final alreadyMatching =
          (currentRatio - targetRatio).abs() < _ratioEpsilon;

      AppTalker.info(
        'WindowRatio',
        'apply($setting): target=${targetRatio.toStringAsFixed(3)} '
        'current=${currentRatio.toStringAsFixed(3)} '
        'bounds=${bounds.width.toStringAsFixed(0)}x${bounds.height.toStringAsFixed(0)} '
        'resize=${!alreadyMatching}',
      );

      if (!alreadyMatching) {
        final targetSize = _calculateTargetSize(
          currentSize: bounds.size,
          currentRatio: currentRatio,
          targetRatio: targetRatio,
        );
        final displays = await _tryGetDisplays();
        final targetBounds = WindowGeometry.normalizeMainWindowBounds(
          Rect.fromLTWH(
            bounds.left,
            bounds.top,
            targetSize.width,
            targetSize.height,
          ),
          displays,
          fallbackSize: _normalWindowMinimumSize,
          minimumSize: _normalWindowMinimumSize,
        );
        await windowManager.setBounds(targetBounds);
      }

      // Lock the ratio last so the resize above is not constrained by a
      // stale lock from a previous setting.
      await windowManager.setAspectRatio(targetRatio);

      if (alreadyLocked && alreadyMatching) {
        AppTalker.info(
          'WindowRatio',
          'apply($setting): already at ratio ${targetRatio.toStringAsFixed(3)}',
        );
      }
    } catch (error, stackTrace) {
      AppTalker.error(
        'WindowRatio',
        error: error,
        stackTrace: stackTrace,
        message: 'apply($setting) failed',
      );
    }
  }

  /// Removes the aspect ratio lock, e.g. when leaving the player route or
  /// entering fullscreen/PiP where the window shape is managed elsewhere.
  Future<void> release() async {
    _appliedSetting = null;
    _lockedRatio = null;
    if (!_isDesktop) {
      return;
    }
    try {
      await windowManager.setAspectRatio(0);
    } catch (error, stackTrace) {
      AppTalker.error(
        'WindowRatio',
        error: error,
        stackTrace: stackTrace,
        message: 'release failed',
      );
    }
  }

  /// KMP expansion strategy: only grow the window toward the target ratio,
  /// never shrink the kept dimension, and clamp the resulting width to
  /// ±50% of the current width.
  Size _calculateTargetSize({
    required Size currentSize,
    required double currentRatio,
    required double targetRatio,
  }) {
    var targetWidth = currentSize.width;
    var targetHeight = currentSize.height;

    if (targetRatio > currentRatio) {
      // Wider target: keep height, expand width (e.g. 16:9 -> 21:9).
      targetWidth = currentSize.height * targetRatio;
    } else {
      // Narrower target: keep width, expand height (e.g. 16:9 -> 4:3).
      targetHeight = currentSize.width / targetRatio;
    }

    final minWidth = currentSize.width * 0.5;
    final maxWidth = currentSize.width * 1.5;
    if (targetWidth < minWidth) {
      targetWidth = minWidth;
    } else if (targetWidth > maxWidth) {
      targetWidth = maxWidth;
    }

    // Keep the final shape at the exact target ratio after any clamping.
    targetHeight = targetWidth / targetRatio;

    return Size(
      targetWidth.roundToDouble(),
      targetHeight.roundToDouble(),
    );
  }

  double? _normalizeRatio(double? ratio) {
    if (ratio == null || !ratio.isFinite || ratio <= 0) {
      return null;
    }
    return ratio;
  }

  Future<List<DesktopDisplayGeometry>> _tryGetDisplays() async {
    try {
      return await const DesktopDisplayService().getDisplays();
    } catch (_) {
      return const [];
    }
  }
}
