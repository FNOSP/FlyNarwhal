import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the display hosting the window can present extended dynamic range
/// content.
///
/// EDR capability belongs to the display, not the machine: the same window is
/// HDR-capable on an XDR panel and SDR-only on an external monitor. The player
/// uses this to decide whether an HDR stream can be presented natively or must
/// fall back to tone-mapped SDR output.
class HdrDisplayCapability {
  const HdrDisplayCapability({required this.isAvailable});

  final bool isAvailable;

  static const HdrDisplayCapability unavailable =
      HdrDisplayCapability(isAvailable: false);
}

/// Queries the native EDR capability and notifies listeners when it changes
/// (the window moving between displays, or the user toggling HDR in System
/// Settings).
class HdrDisplayCapabilityNotifier extends ChangeNotifier {
  HdrDisplayCapabilityNotifier();

  static const MethodChannel _channel = MethodChannel('fly_narwhal/window');

  HdrDisplayCapability _capability = HdrDisplayCapability.unavailable;

  HdrDisplayCapability get capability => _capability;

  bool get isAvailable => _capability.isAvailable;

  Future<void> refresh() async {
    if (!_supportsEdrQuery) {
      return;
    }
    bool available;
    try {
      available = await _channel.invokeMethod<bool>('isEdrAvailable') ?? false;
    } catch (_) {
      // A platform without the method (or a stale native binary) simply has
      // no EDR path; the texture renderer stays in use.
      available = false;
    }
    if (available == _capability.isAvailable) {
      return;
    }
    _capability = HdrDisplayCapability(isAvailable: available);
    notifyListeners();
  }

  /// EDR presentation is a macOS concept; IINA's equivalent check uses
  /// `NSScreen.maximumPotentialExtendedDynamicRangeColorComponentValue`.
  bool get _supportsEdrQuery =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
}

final hdrDisplayCapabilityProvider =
    ChangeNotifierProvider<HdrDisplayCapabilityNotifier>((ref) {
  final notifier = HdrDisplayCapabilityNotifier();
  // Resolve the initial value immediately so the first stream already knows
  // whether the native renderer is usable.
  notifier.refresh();
  return notifier;
});
