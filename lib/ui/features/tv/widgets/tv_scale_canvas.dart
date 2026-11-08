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
        // Letterbox offset of the scaled canvas inside the window.
        final offsetX = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - TvTheme.canvasWidth * scale) / 2
            : 0.0;
        final offsetY = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - TvTheme.canvasHeight * scale) / 2
            : 0.0;
        return Container(
          color: TvTheme.letterboxBlack,
          // OverflowBox hands the canvas chain unconstrained-by-window tight
          // 1920x1080 constraints (it never asserts on the overflow), then
          // translate(L) ∘ scale(s) maps canvas point c to L + s*c for paint
          // and inverts it exactly for hit tests. Every gate along the chain
          // sees a point inside its own box, so real clicks and driver taps
          // reach the canvas; a window-sized box anywhere here would swallow
          // hits whose canvas coordinate lies outside the window rect.
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: TvTheme.canvasWidth,
            maxWidth: TvTheme.canvasWidth,
            minHeight: TvTheme.canvasHeight,
            maxHeight: TvTheme.canvasHeight,
            child: Transform.translate(
              offset: Offset(offsetX, offsetY),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: TvTheme.canvasWidth,
                  height: TvTheme.canvasHeight,
                  child: ClipRect(
                    child: Container(
                      color: TvTheme.bgBase,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
