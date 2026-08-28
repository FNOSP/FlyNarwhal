import 'dart:ui' show Offset, PlatformDispatcher, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'window_geometry.dart';

class DesktopDisplayService {
  const DesktopDisplayService();

  static const MethodChannel _channel =
      MethodChannel('fly_narwhal/window_display_frame');

  Future<List<DesktopDisplayGeometry>> getDisplays() async {
    if (kIsWeb) {
      return const [];
    }
    final supportsNativeEnumeration =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
    if (supportsNativeEnumeration) {
      try {
        final result =
            await _channel.invokeMethod<List<Object?>>('getAllDisplays');
        final parsed = result
                ?.whereType<Map<Object?, Object?>>()
                .map(_parseDisplay)
                .whereType<DesktopDisplayGeometry>()
                .toList(growable: false) ??
            const <DesktopDisplayGeometry>[];
        if (parsed.isNotEmpty) {
          return parsed;
        }
      } catch (_) {
        // A stale native binary without getAllDisplays (or a platform that
        // cannot enumerate) must not break startup: fall through to the
        // Flutter-view display below.
      }
    }

    // Fall back to the display the Flutter view is on so window-size
    // clamping still has a screen ceiling instead of resizing unbounded.
    final fallback = flutterViewDisplay();
    return fallback == null ? const [] : [fallback];
  }

  /// The display the app's Flutter view is currently on, derived from the
  /// engine's [PlatformDispatcher]. Used as the clamping ceiling when native
  /// display enumeration is unavailable or fails.
  static DesktopDisplayGeometry? flutterViewDisplay() {
    final view = PlatformDispatcher.instance.implicitView;
    final display = view?.display;
    if (display == null) {
      return null;
    }
    final physicalSize = display.size;
    final scaleFactor = display.devicePixelRatio;
    if (physicalSize.width <= 0 ||
        physicalSize.height <= 0 ||
        scaleFactor <= 0) {
      return null;
    }
    final logicalSize = Size(
      physicalSize.width / scaleFactor,
      physicalSize.height / scaleFactor,
    );
    return DesktopDisplayGeometry(
      id: 'flutter-display-${display.id}',
      monitorBounds: Offset.zero & logicalSize,
      workArea: Offset.zero & logicalSize,
      isPrimary: true,
      scaleFactor: scaleFactor,
    );
  }

  Future<Rect?> getCurrentMonitorBounds() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.windows &&
            defaultTargetPlatform != TargetPlatform.linux)) {
      return null;
    }

    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getCurrentDisplayFrame',
    );
    return result == null ? null : _parseRect(result);
  }

  DesktopDisplayGeometry? _parseDisplay(Map<Object?, Object?> value) {
    final monitorValue = value['monitorBounds'];
    final workAreaValue = value['workArea'];
    if (monitorValue is! Map<Object?, Object?> ||
        workAreaValue is! Map<Object?, Object?>) {
      return null;
    }

    final monitorBounds = _parseRect(monitorValue);
    final workArea = _parseRect(workAreaValue);
    if (!WindowGeometry.isValidBounds(monitorBounds) ||
        !WindowGeometry.isValidBounds(workArea)) {
      return null;
    }

    return DesktopDisplayGeometry(
      id: value['id']?.toString() ?? '',
      monitorBounds: monitorBounds,
      workArea: workArea,
      isPrimary: value['isPrimary'] == true,
      scaleFactor: _readDouble(value, 'scaleFactor', fallback: 1),
    );
  }

  Rect _parseRect(Map<Object?, Object?> value) {
    return Rect.fromLTWH(
      _readDouble(value, 'x'),
      _readDouble(value, 'y'),
      _readDouble(value, 'width'),
      _readDouble(value, 'height'),
    );
  }

  double _readDouble(
    Map<Object?, Object?> value,
    String key, {
    double fallback = 0,
  }) {
    final number = value[key];
    return number is num ? number.toDouble() : fallback;
  }
}
