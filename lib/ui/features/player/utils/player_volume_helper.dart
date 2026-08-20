import 'package:flutter/foundation.dart';

/// Gain applied to the volume sent to mpv on macOS.
///
/// On macOS the perceived volume is lower than on other platforms, so we boost
/// the value passed to mpv while keeping the UI volume (0.0 - 1.0) unchanged.
const double _kMacOSVolumeGain = 1.7;

/// Converts a UI volume value (0.0 - 1.0) to the value that should be sent to
/// mpv via [Player.setVolume].
///
/// On macOS the value is boosted by [_kMacOSVolumeGain] and clamped to the
/// mpv range (0.0 - 100.0). Other platforms keep the existing linear mapping.
double uiVolumeToMpvVolume(double volume) {
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    return (volume * 100.0 * _kMacOSVolumeGain).clamp(0.0, 100.0);
  }
  return volume * 100.0;
}
