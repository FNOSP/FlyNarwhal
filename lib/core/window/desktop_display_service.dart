import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'window_geometry.dart';

class DesktopDisplayService {
  const DesktopDisplayService();

  static const MethodChannel _channel =
      MethodChannel('fly_narwhal/window_display_frame');

  Future<List<DesktopDisplayGeometry>> getDisplays() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return const [];
    }

    final result = await _channel.invokeMethod<List<Object?>>('getAllDisplays');
    if (result == null) {
      return const [];
    }

    return result
        .whereType<Map<Object?, Object?>>()
        .map(_parseDisplay)
        .whereType<DesktopDisplayGeometry>()
        .toList(growable: false);
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
