import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/utils/log/app_talker.dart';
import '../../../../core/window/desktop_display_service.dart';
import '../../../../core/window/window_geometry.dart';

/// Applies the player's window aspect ratio setting ("窗口比例") to the main
/// window.
///
/// Every setting ("AUTO", "4:3", "16:9", "21:9") locks the window to its
/// ratio via [WindowManager.setAspectRatio] and resizes from a session-stable
/// baseline area captured on the first apply (the window geometry the user
/// entered the player with). The target size keeps the window area constant
/// while adopting the target ratio, so alternating between videos or settings
/// with different ratios oscillates between fixed sizes instead of growing
/// the window. Resizes are anchored at the window's geometric center.
///
/// The "AUTO" setting follows the video's own aspect ratio so the video frame
/// and the window stay perfectly matched even while the user resizes the
/// window. A user resize under the ratio lock updates the baseline area via
/// [observeSettledBounds], so subsequent ratio changes scale from the size
/// the user chose.
class PlayerWindowAspectRatioController {
  static const Map<String, double> _fixedRatios = {
    '4:3': 4 / 3,
    '16:9': 16 / 9,
    '21:9': 21 / 9,
  };
  static const String autoSetting = 'AUTO';
  static const Size _normalWindowMinimumSize = Size(1280, 720);
  // Area of [_normalWindowMinimumSize]; kept as literals because Size
  // properties are not accessible in const expressions.
  static const double _fallbackBaselineArea = 1280 * 720;
  // Aspect ratios closer than this are considered identical, avoiding
  // redundant window resizing when repeated video-param events arrive.
  static const double _ratioEpsilon = 0.005;
  // Width/height tolerance when recognizing programmatic setBounds echoes in
  // [observeSettledBounds]; covers DPI scaling and OS rounding.
  static const double _sizeEpsilonPx = 2.0;

  String? _appliedSetting;
  double? _lockedRatio;
  // Session-stable window area anchoring all ratio resizes. Captured on the
  // first apply (before any programmatic resize) and only updated by genuine
  // user resizes; deliberately NOT cleared by [release] so fullscreen/PiP
  // round-trips restore the exact same size.
  double? _baselineArea;
  // Actual size after the latest programmatic setBounds, used to tell our own
  // resize echoes apart from user gestures in [observeSettledBounds].
  Size? _lastProgrammaticSize;

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

  /// Smallest window size that satisfies both the global minimum
  /// ([_normalWindowMinimumSize]) and [ratio], so the OS minimum-size clamp
  /// can never fight the ratio lock. The axis violating the ratio is grown
  /// (never shrinking the other below the global minimum); [workArea] caps
  /// the result with a uniform downscale so the ratio stays exact even on
  /// small displays.
  static Size minimumSizeForRatio(double ratio, Rect? workArea) {
    var width = _normalWindowMinimumSize.width;
    var height = _normalWindowMinimumSize.height;
    // Grow width for ratios wider than 16:9, otherwise grow height.
    if (width / height < ratio) {
      width = (height * ratio).ceilToDouble();
    } else {
      height = (width / ratio).ceilToDouble();
    }
    if (workArea != null) {
      final scale = math.min(
        math.min(workArea.width / width, workArea.height / height),
        1.0,
      );
      width *= scale;
      height *= scale;
    }
    return Size(width.roundToDouble(), height.roundToDouble());
  }

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

      // The user may have maximized the window during playback (e.g. by
      // double-clicking the title bar). Maximize owns the window shape just
      // like fullscreen/PiP do, so leave the maximized window untouched and
      // drop the ratio lock; it is re-applied when the user un-maximizes.
      final isMaximized = await windowManager.isMaximized();
      if (isMaximized) {
        await release();
        return;
      }

      final bounds = await windowManager.getBounds();
      // Capture the session baseline once, before any programmatic resize:
      // the window currently holds the user's chosen geometry (restored
      // player bounds or the app window size), whose area anchors every
      // ratio resize for the rest of this player session.
      _baselineArea ??= WindowGeometry.isValidBounds(bounds)
          ? bounds.width * bounds.height
          : null;
      final currentRatio =
          bounds.height > 0 ? bounds.width / bounds.height : targetRatio;
      final alreadyMatching =
          (currentRatio - targetRatio).abs() < _ratioEpsilon;
      final displays = await _tryGetDisplays();
      final workArea =
          WindowGeometry.selectDisplay(bounds, displays)?.workArea;

      // Keep the OS minimum size consistent with the locked ratio. A plain
      // 1280x720 minimum fights the ratio lock for wide videos: the clamp
      // lets the window settle at an off-ratio size, and the plugin's
      // WM_SIZING handler then re-derives the dragged edge from the locked
      // ratio and shifts the window before the clamp snaps the size back.
      final minimumSize = minimumSizeForRatio(targetRatio, workArea);
      await windowManager.setMinimumSize(minimumSize);

      AppTalker.info(
        'WindowRatio',
        'apply($setting): target=${targetRatio.toStringAsFixed(3)} '
            'current=${currentRatio.toStringAsFixed(3)} '
            'bounds=${bounds.width.toStringAsFixed(0)}x${bounds.height.toStringAsFixed(0)} '
            'baseline=${(_baselineArea ?? 0).toStringAsFixed(0)} '
            'resize=${!alreadyMatching}',
      );

      if (!alreadyMatching) {
        final targetSize = _calculateTargetSize(
          baselineArea: _baselineArea ?? _fallbackBaselineArea,
          targetRatio: targetRatio,
          workArea: workArea,
        );
        // Anchor the resize at the window's geometric center so the window
        // grows/shrinks symmetrically around where the user is looking.
        final targetBounds = WindowGeometry.normalizeMainWindowBounds(
          Rect.fromCenter(
            center: bounds.center,
            width: targetSize.width,
            height: targetSize.height,
          ),
          displays,
          fallbackSize: _normalWindowMinimumSize,
          minimumSize: _normalWindowMinimumSize,
        );
        await windowManager.setBounds(targetBounds);
        _lastProgrammaticSize = await _measureSettledSize(targetBounds.size);
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

  /// Observes the window's settled bounds after move/resize gestures settle
  /// (called from the player screen's debounced persistence callback).
  ///
  /// Programmatic setBounds echoes are recognized via [_lastProgrammaticSize]
  /// and ignored; a genuine user resize under the ratio lock updates the
  /// baseline area so subsequent ratio changes scale from the user's size.
  void observeSettledBounds(Rect bounds) {
    if (_lockedRatio == null) {
      // No active ratio lock: the window shape is owned by fullscreen/PiP
      // transitions or the plain app window; never touch the baseline.
      return;
    }
    if (!WindowGeometry.isValidBounds(bounds)) {
      return;
    }
    final lastProgrammaticSize = _lastProgrammaticSize;
    if (lastProgrammaticSize != null &&
        (bounds.width - lastProgrammaticSize.width).abs() < _sizeEpsilonPx &&
        (bounds.height - lastProgrammaticSize.height).abs() < _sizeEpsilonPx) {
      // Echo of our own setBounds, not a user gesture.
      return;
    }
    _baselineArea = bounds.width * bounds.height;
    _lastProgrammaticSize = bounds.size;
    AppTalker.info(
      'WindowRatio',
      'baseline updated from user resize: '
          '${bounds.width.toStringAsFixed(0)}x${bounds.height.toStringAsFixed(0)}',
    );
  }

  /// Removes the aspect ratio lock, e.g. when leaving the player route or
  /// entering fullscreen/PiP where the window shape is managed elsewhere.
  ///
  /// The baseline area is intentionally preserved so leaving and re-entering
  /// a mode restores the exact same window size.
  Future<void> release() async {
    _appliedSetting = null;
    _lockedRatio = null;
    if (!_isDesktop) {
      return;
    }
    try {
      await windowManager.setAspectRatio(0);
      // Restore the global minimum size once the ratio lock is released so
      // other routes (and fullscreen/maximized transitions) get the normal
      // window limits back.
      await windowManager.setMinimumSize(_normalWindowMinimumSize);
    } catch (error, stackTrace) {
      AppTalker.error(
        'WindowRatio',
        error: error,
        stackTrace: stackTrace,
        message: 'release failed',
      );
    }
  }

  /// Computes the target window size for [targetRatio] from the session's
  /// stable [baselineArea]: width/height follow the ratio while the window's
  /// on-screen area stays constant, so switching between ratios oscillates
  /// between fixed sizes instead of growing. Target size is a pure function
  /// of (area, ratio) — there is no feedback from the current window size.
  ///
  /// Clamping keeps the ratio exact by scaling uniformly: fit inside the
  /// display work area, then scale up to satisfy the minimum window size;
  /// when the two conflict (extreme ratios on small displays) the work area
  /// wins and the OS minimum-size clamp may apply to one axis.
  Size _calculateTargetSize({
    required double baselineArea,
    required double targetRatio,
    required Rect? workArea,
  }) {
    var width = math.sqrt(baselineArea * targetRatio);
    var height = baselineArea / width;

    double fitScale() {
      final workAreaRect = workArea!;
      return math.min(
        math.min(workAreaRect.width / width, workAreaRect.height / height),
        1.0,
      );
    }

    if (workArea != null) {
      final scale = fitScale();
      width *= scale;
      height *= scale;
    }

    final minimumScale = math.max(
      math.max(
        _normalWindowMinimumSize.width / width,
        _normalWindowMinimumSize.height / height,
      ),
      1.0,
    );
    width *= minimumScale;
    height *= minimumScale;

    if (workArea != null) {
      final scale = fitScale();
      width *= scale;
      height *= scale;
    }

    return Size(
      width.roundToDouble(),
      height.roundToDouble(),
    );
  }

  /// Reads back the actual window size after a programmatic setBounds so the
  /// echo comparison in [observeSettledBounds] accounts for any OS-side
  /// clamping (e.g. the window's minimum size).
  Future<Size> _measureSettledSize(Size requestedSize) async {
    try {
      final settledBounds = await windowManager.getBounds();
      if (WindowGeometry.isValidBounds(settledBounds)) {
        return settledBounds.size;
      }
    } catch (_) {
      // Fall back to the requested size below.
    }
    return requestedSize;
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
