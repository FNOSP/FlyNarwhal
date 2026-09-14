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
