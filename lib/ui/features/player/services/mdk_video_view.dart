import 'dart:async';

import 'package:flutter/widgets.dart';

import 'mdk_player_adapter.dart';

/// Renders the mdk player's video output.
///
/// mdk hands you a Flutter texture instead of a ready-made video widget, so
/// this wraps the [Texture] and reproduces the box-fitting the previous
/// player widget provided:
///
/// - [fillRatio] null: the picture follows the video's own aspect ratio,
///   contain-fitted by default (or cover-fitted when [cover] is set, as in
///   picture-in-picture).
/// - [fillRatio] set: the picture is stretched into a box of that ratio (the
///   "画面比例" 4:3 / 16:9 / 21:9 modes), contain-fitted in the player area —
///   matching the web player.
class MdkVideoView extends StatelessWidget {
  const MdkVideoView({
    super.key,
    required this.controller,
    this.cover = false,
    this.fillRatio,
  });

  final MdkPlayerAdapter controller;

  /// Whether the picture should cover (crop) its box rather than fit inside
  /// it. Used by picture-in-picture mode.
  final bool cover;

  /// Fixed box ratio to stretch the picture into, or null to follow the
  /// video's own aspect ratio.
  final double? fillRatio;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.hdrRenderPathActive,
      builder: (context, hdrActive, _) {
        if (hdrActive) {
          return _HdrPlatformView(
            // A stable key keeps the native view alive across the frequent
            // rebuilds the player screen triggers (the 200ms position ticker).
            // Without it Flutter recreates the platform view every rebuild,
            // which re-attaches the renderer to the player over and over and
            // silences its audio.
            key: const ValueKey<String>('hdr-platform-view'),
            controller: controller,
          );
        }
        return _buildTexture();
      },
    );
  }

  Widget _buildTexture() {
    return ValueListenableBuilder<int?>(
      valueListenable: controller.raw.textureId,
      builder: (context, textureId, _) {
        if (textureId == null || textureId < 0) {
          return const SizedBox.shrink();
        }
        final texture = Texture(
          textureId: textureId,
          filterQuality: FilterQuality.medium,
        );

        final ratio = fillRatio ?? (cover ? null : _videoRatio());
        if (ratio == null) {
          // Cover without a known ratio: crop whatever arrives.
          return _CoverBox(ratio: _fallbackRatio, child: texture);
        }
        if (cover) {
          return _CoverBox(ratio: ratio, child: texture);
        }
        return Center(
          child: AspectRatio(aspectRatio: ratio, child: texture),
        );
      },
    );
  }

  double? _videoRatio() {
    final size = controller.videoSize;
    if (size == null || size.dh <= 0) return null;
    return size.dw / size.dh;
  }

  static const double _fallbackRatio = 16 / 9;
}

/// Renders the HDR platform view.
///
/// The native renderer presents straight into an EDR-enabled CAMetalLayer, so
/// the picture keeps its HDR range. The trade-off is that the native view
/// composites above Flutter's layers: widgets the player stacks over the video
/// area (danmaku, the HLS subtitle overlay) cannot be shown while this is
/// active, which is why the player screen hides them in this mode.
///
/// The view is created only once the decoded frame size is known. A platform
/// view has no size until Flutter is told one, and the native renderer sizes
/// its drawable from the dimensions it is created with, so building it earlier
/// yields a zero-sized, empty layer.
class _HdrPlatformView extends StatefulWidget {
  const _HdrPlatformView({super.key, required this.controller});

  final MdkPlayerAdapter controller;

  @override
  State<_HdrPlatformView> createState() => _HdrPlatformViewState();
}

class _HdrPlatformViewState extends State<_HdrPlatformView> {
  StreamSubscription<VideoSize>? _videoSizeSubscription;
  VideoSize? _size;

  /// The platform view widget, built once.
  ///
  /// Handing back the *same* widget instance on every rebuild keeps Flutter
  /// from re-attaching the native view: the player screen rebuilds on a 200ms
  /// ticker (and on every state change), and a freshly constructed AppKitView
  /// with new creationParams each time makes the platform-view element detach
  /// and re-insert the native view, which repeats teardown/setup on the live
  /// renderer and stalls its output.
  Widget? _platformView;

  @override
  void initState() {
    super.initState();
    _size = widget.controller.videoSize;
    if (_size != null && _size!.w > 0 && _size!.h > 0) {
      _platformView = _createPlatformView(_size!);
    } else {
      _videoSizeSubscription = widget.controller.videoParams.listen((size) {
        if (!mounted) return;
        if (size.w <= 0 || size.h <= 0) return;
        setState(() {
          _size = size;
          _platformView = _createPlatformView(size);
        });
        _videoSizeSubscription?.cancel();
        _videoSizeSubscription = null;
      });
    }
  }

  Widget _createPlatformView(VideoSize size) {
    return widget.controller.raw.buildPlatformView(
      width: size.w,
      height: size.h,
    );
  }

  @override
  void dispose() {
    _videoSizeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    final view = _platformView;
    if (size == null || view == null) {
      return const SizedBox.shrink();
    }
    if (size.dh <= 0) {
      return view;
    }
    return Center(
      child: AspectRatio(
        aspectRatio: size.dw / size.dh,
        child: view,
      ),
    );
  }
}

/// Fits [child] to [ratio] and covers the available box, cropping the
/// overflow. The child is stretched into the ratio box first, so the crop
/// only trims the letterbox rather than distorting the picture.
class _CoverBox extends StatelessWidget {
  const _CoverBox({required this.ratio, required this.child});

  final double ratio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        if (maxWidth <= 0 || maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        double width;
        double height;
        if (maxWidth / maxHeight > ratio) {
          width = maxWidth;
          height = maxWidth / ratio;
        } else {
          height = maxHeight;
          width = maxHeight * ratio;
        }
        return ClipRect(
          child: OverflowBox(
            maxWidth: width,
            maxHeight: height,
            minWidth: width,
            minHeight: height,
            child: SizedBox(width: width, height: height, child: child),
          ),
        );
      },
    );
  }
}
