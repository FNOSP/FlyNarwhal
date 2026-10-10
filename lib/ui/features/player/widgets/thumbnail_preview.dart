import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';

import '../../../../providers/thumbnail/player_thumbnail_controller.dart';

const playerThumbnailPreviewKey = ValueKey('player-thumbnail-preview');

/// Fixed logical width of the hover preview card; the frame keeps its native
/// 320px sprites at 1:1 (16:9 → 320x180).
const kThumbnailPreviewWidth = 320.0;

/// Renders the hovered frame cropped out of its sprite sheet.
class ThumbnailPreview extends StatelessWidget {
  final SpritePreview preview;

  const ThumbnailPreview({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    final height = kThumbnailPreviewWidth / preview.aspectRatio;
    return Container(
      width: kThumbnailPreviewWidth,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: CustomPaint(
          key: playerThumbnailPreviewKey,
          size: Size(kThumbnailPreviewWidth, height),
          painter: _ThumbnailPreviewPainter(preview: preview),
        ),
      ),
    );
  }
}

class _ThumbnailPreviewPainter extends CustomPainter {
  final SpritePreview preview;

  _ThumbnailPreviewPainter({required this.preview});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      preview.image,
      preview.srcRect,
      Offset.zero & size,
      Paint()..filterQuality = ui.FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(covariant _ThumbnailPreviewPainter oldDelegate) {
    return oldDelegate.preview.image != preview.image ||
        oldDelegate.preview.srcRect != preview.srcRect;
  }
}
