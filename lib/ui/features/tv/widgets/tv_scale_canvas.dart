import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';

import '../tv_theme.dart';

/// Letterboxed 1920×1080 design canvas: scales the fixed-size child by
/// `min(w/1920, h/1080)` and centers it on a black background, mirroring the
/// design's `fitScreen()` transform. All descendants lay out in design px.
class TvScaleCanvas extends StatelessWidget {
  const TvScaleCanvas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var scale = 1.0;
        if (constraints.maxWidth.isFinite && constraints.maxHeight.isFinite) {
          scale = math.min(
            constraints.maxWidth / TvTheme.canvasWidth,
            constraints.maxHeight / TvTheme.canvasHeight,
          );
          if (!scale.isFinite || scale <= 0) {
            scale = 1.0;
          }
        }
        return Container(
          color: TvTheme.letterboxBlack,
          alignment: Alignment.center,
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: TvTheme.canvasWidth,
              height: TvTheme.canvasHeight,
              child: ClipRect(child: child),
            ),
          ),
        );
      },
    );
  }
}
