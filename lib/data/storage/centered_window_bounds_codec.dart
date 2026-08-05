import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists window geometry as "center point + size" instead of
/// "top-left + size".
///
/// window_manager's getBounds/setBounds are natively top-left based and stay
/// that way; this codec performs the center conversion at the storage layer so
/// callers keep passing and receiving plain [Rect]s. Saving the geometric
/// center keeps the restored window anchored around the spot the user last
/// looked at, even when its size changes between saves (e.g. the player's
/// aspect-ratio-driven resizes).
///
/// Key layout per [prefix]:
/// - current: `{prefix}_center_x`, `{prefix}_center_y`,
///   `{prefix}_width`, `{prefix}_height` (width/height keys reuse the
///   pre-existing names, whose meaning never changed)
/// - legacy fallback: `{prefix}_left`, `{prefix}_top`
///
/// Migration is lazy: [read] falls back to the legacy top-left keys when the
/// center keys are absent, and [write] mirrors the legacy keys so an app
/// downgrade still sees consistent data. Legacy keys are never deleted.
class CenteredWindowBoundsCodec {
  const CenteredWindowBoundsCodec._();

  static String _centerXKey(String prefix) => '${prefix}_center_x';
  static String _centerYKey(String prefix) => '${prefix}_center_y';
  static String _widthKey(String prefix) => '${prefix}_width';
  static String _heightKey(String prefix) => '${prefix}_height';
  static String _legacyLeftKey(String prefix) => '${prefix}_left';
  static String _legacyTopKey(String prefix) => '${prefix}_top';

  /// Reads the stored bounds, preferring the center-based keys and falling
  /// back to legacy top-left keys. Returns null when nothing valid is stored.
  static Rect? read(SharedPreferences preferences, String prefix) {
    final width = preferences.getDouble(_widthKey(prefix));
    final height = preferences.getDouble(_heightKey(prefix));
    if (!_isValidSize(width, height)) {
      return null;
    }

    final centerX = preferences.getDouble(_centerXKey(prefix));
    final centerY = preferences.getDouble(_centerYKey(prefix));
    if (centerX != null && centerY != null && centerX.isFinite && centerY.isFinite) {
      return Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: width!,
        height: height!,
      );
    }

    // Legacy fallback: top-left coordinates from older app versions.
    final left = preferences.getDouble(_legacyLeftKey(prefix));
    final top = preferences.getDouble(_legacyTopKey(prefix));
    if (left == null || top == null || !left.isFinite || !top.isFinite) {
      return null;
    }
    return Rect.fromLTWH(left, top, width!, height!);
  }

  /// Writes the bounds as center point + size and mirrors the legacy
  /// top-left keys for downgrade compatibility.
  static Future<void> write(
    SharedPreferences preferences,
    String prefix,
    Rect bounds,
  ) {
    return Future.wait([
      preferences.setDouble(_centerXKey(prefix), bounds.center.dx),
      preferences.setDouble(_centerYKey(prefix), bounds.center.dy),
      preferences.setDouble(_widthKey(prefix), bounds.width),
      preferences.setDouble(_heightKey(prefix), bounds.height),
      preferences.setDouble(_legacyLeftKey(prefix), bounds.left),
      preferences.setDouble(_legacyTopKey(prefix), bounds.top),
    ]);
  }

  static bool _isValidSize(double? width, double? height) {
    return width != null &&
        height != null &&
        width.isFinite &&
        height.isFinite &&
        width > 0 &&
        height > 0;
  }
}
