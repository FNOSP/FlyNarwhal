import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/app_fonts.dart';
import '../widgets/player_danmaku_overlay.dart';

/// Drives the native danmaku overlay that the HDR platform view draws above
/// its video layer.
///
/// The HDR render path presents video through a native `CAMetalLayer` mounted
/// in the AppKit view hierarchy, which composites above every Flutter layer.
/// A Flutter-rendered danmaku widget would therefore be hidden behind the
/// picture, so that path draws its comments natively instead.
///
/// The timing, list handling and option maths all stay on this side: this
/// controller is handed to [PlayerDanmakuOverlay] exactly like the canvas one,
/// so the widget's existing dispatch logic drives it unchanged. Only the
/// on-screen drawing and the frame clock live natively — the native overlay
/// polls the player's own position each frame, which is finer-grained than the
/// position this widget is rebuilt with.
class NativePlayerDanmakuRenderController
    implements PlayerDanmakuRenderController {
  NativePlayerDanmakuRenderController({required this.nativeHandle});

  /// The mdk player handle whose native view draws the overlay.
  final int nativeHandle;

  static const MethodChannel _channel = MethodChannel('fvp');

  PlayerDanmakuRenderOptions? _latestOptions;
  bool _shouldRun = true;
  bool _visible = true;
  bool _disposed = false;
  bool _listSent = false;

  @override
  Widget buildView(Key key, PlayerDanmakuRenderOptions options) {
    _latestOptions = options;
    // The overlay is drawn by the native view, not by Flutter: an empty box
    // keeps the player's own layer stack unchanged.
    return const SizedBox.shrink();
  }

  /// The native overlay dispatches off the player's own clock, which runs at
  /// frame rate instead of this widget's rebuild rate, so it takes the whole
  /// list rather than one comment at a time.
  @override
  bool get wantsWholeList => true;

  @override
  void add(PlayerDanmakuRenderItem item) {
    // Nothing to do: the widget hands over the whole list instead.
  }

  @override
  void setDanmakuList(List<PlayerDanmakuListEntry> entries) {
    if (_disposed) return;
    _listSent = true;
    _invoke('SetDanmakuList', {
      'list': [
        for (final entry in entries)
          {
            'time': entry.startMs,
            'text': entry.text,
            'color': entry.argb,
            'type': switch (entry.type) {
              PlayerDanmakuType.scroll => 0,
              PlayerDanmakuType.top => 1,
              PlayerDanmakuType.bottom => 2,
            },
          },
      ],
    });
  }

  @override
  void updateOptions(PlayerDanmakuRenderOptions options) {
    _latestOptions = options;
    if (_disposed) return;
    _invoke('UpdateDanmakuOptions', {
      'fontSize': options.fontSize,
      'area': options.area,
      'opacity': options.opacity,
      'durationMs': (options.durationSeconds * 1000).round(),
      'staticDurationMs': (options.staticDurationSeconds * 1000).round(),
      'fontFamily': AppFonts.primary,
    });
  }

  @override
  void pause() {
    _shouldRun = false;
    if (_disposed) return;
    _invoke('PauseDanmaku', const {});
  }

  @override
  void resume() {
    _shouldRun = true;
    if (_disposed) return;
    _invoke('ResumeDanmaku', const {});
  }

  @override
  void clear() {
    if (_disposed) return;
    _invoke('ClearDanmaku', const {});
  }

  @override
  void dispose() {
    _disposed = true;
    _invoke('ClearDanmaku', const {});
  }

  /// Whether the overlay should currently be advancing.
  bool get shouldRun => _shouldRun;

  bool get isVisible => _visible;

  /// Whether this controller has been disposed and can no longer be driven.
  bool get isDisposed => _disposed;

  /// Whether the overlay has received its rendering options yet.
  bool get hasOptions => _latestOptions != null;

  /// Whether the comment list has been handed to the native overlay.
  bool get hasList => _listSent;

  /// Shows or hides the overlay without discarding the comment list.
  void setVisible(bool visible) {
    _visible = visible;
    if (_disposed) return;
    _invoke('SetDanmakuVisible', {'visible': visible});
  }

  /// Sets the subtitle lines drawn at the bottom of the video area.
  ///
  /// [bottomPadding] is in logical points from the bottom edge; the caller
  /// resolves the user's vertical-position setting into it.
  void setSubtitleLines({
    required List<String> lines,
    required double fontSize,
    required double bottomPadding,
    required double opacity,
  }) {
    if (_disposed) return;
    _invoke('SetSubtitleLines', {
      'lines': lines,
      'fontSize': fontSize,
      'bottomPadding': bottomPadding,
      'opacity': opacity,
    });
  }

  void _invoke(String method, Map<String, Object?> arguments) {
    _channel
        .invokeMethod<void>(method, {'player': nativeHandle, ...arguments})
        // The overlay is cosmetic: a failure to reach it must not take down
        // playback, and there is no user-visible action to take.
        .catchError((Object _) {});
  }
}