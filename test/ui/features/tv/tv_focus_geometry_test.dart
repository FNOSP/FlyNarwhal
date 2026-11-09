import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/ui/features/tv/controllers/tv_focus_controller.dart';

void main() {
  Rect rect(double x, double y, [double w = 100, double h = 50]) =>
      Rect.fromLTWH(x, y, w, h);

  group('TvFocusGeometry.pickNext', () {
    test('picks the nearest candidate along the direction', () {
      final current = rect(0, 0);
      final candidates = [rect(300, 0), rect(150, 0)];
      expect(
        TvFocusGeometry.pickNext(
          current: current,
          candidates: candidates,
          direction: TvDirection.right,
        ),
        1, // 150 is closer than 300
      );
    });

    test('skips candidates outside the pressed direction', () {
      final current = rect(200, 0);
      final candidates = [rect(0, 0)]; // only to the left
      expect(
        TvFocusGeometry.pickNext(
          current: current,
          candidates: candidates,
          direction: TvDirection.right,
        ),
        isNull,
      );
      expect(
        TvFocusGeometry.pickNext(
          current: current,
          candidates: candidates,
          direction: TvDirection.left,
        ),
        0,
      );
    });

    test('applies the 8px dead zone', () {
      final current = rect(0, 0);
      // Candidate center at x=54 vs current center x=50: along = 4 < 8.
      final candidates = [rect(4, 0)];
      expect(
        TvFocusGeometry.pickNext(
          current: current,
          candidates: candidates,
          direction: TvDirection.right,
        ),
        isNull,
      );
    });

    test('across weight 2.2 strongly biases same-row movement', () {
      // Same row, farther along: center (350, 25); along 300, across 0.
      // Different row, closer along: center (250, 125); along 200, across 100.
      // Scores: 300 vs 200 + 220 = 420 -> same row wins.
      final current = rect(0, 0);
      final candidates = [rect(200, 100), rect(300, 0)];
      expect(
        TvFocusGeometry.pickNext(
          current: current,
          candidates: candidates,
          direction: TvDirection.right,
        ),
        1,
      );
    });

    test('up/down navigate between shelf rows by column alignment', () {
      // Card in the row below, roughly same column.
      final current = rect(400, 0, 400, 225);
      final candidates = [
        rect(0, 400, 240, 360), // far left, wrong column
        rect(410, 400, 240, 360), // aligned below
      ];
      expect(
        TvFocusGeometry.pickNext(
          current: current,
          candidates: candidates,
          direction: TvDirection.down,
        ),
        1,
      );
      expect(
        TvFocusGeometry.pickNext(
          current: current,
          candidates: candidates,
          direction: TvDirection.up,
        ),
        isNull,
      );
    });
  });

  group('TvFocusGeometry.revealOffset', () {
    const pixels = 500.0;
    const viewport = 1080.0;

    double? reveal({
      double contentLeading = 0,
      double contentTrailing = 100,
      double leadingInset = 0,
      double trailingInset = 0,
      double current = pixels,
      double min = 0,
      double max = 4000,
    }) =>
        TvFocusGeometry.revealOffset(
          pixels: current,
          viewportExtent: viewport,
          contentLeading: contentLeading,
          contentTrailing: contentTrailing,
          leadingInset: leadingInset,
          trailingInset: trailingInset,
          minScrollExtent: min,
          maxScrollExtent: max,
        );

    test('returns null when fully visible inside the insets', () {
      expect(
        reveal(contentLeading: 600, contentTrailing: 700),
        isNull,
      );
    });

    test('reveals upward when the element sits above the viewport', () {
      // Element top at content 100 while viewport shows 500..1580.
      expect(reveal(contentLeading: 100, contentTrailing: 300), 100);
    });

    test('reveals downward when the element sits below the viewport', () {
      // Element bottom at content 2000 while viewport ends at 1580.
      expect(
        reveal(contentLeading: 1800, contentTrailing: 2000),
        2000 - viewport,
      );
    });

    test('respects leading and trailing insets', () {
      // Up: target aligns the element top to the leading inset.
      expect(
        reveal(contentLeading: 300, contentTrailing: 500, leadingInset: 108),
        300 - 108,
      );
      // Down: element bottom lands trailingInset above the viewport end.
      expect(
        reveal(
          contentLeading: 1800,
          contentTrailing: 2000,
          trailingInset: 84,
        ),
        2000 - (viewport - 84),
      );
    });

    test('clamps to the scroll extents', () {
      expect(
        reveal(contentLeading: 10, contentTrailing: 50, min: 100),
        100,
      );
      expect(
        reveal(contentLeading: 5000, contentTrailing: 5200, max: 4000),
        4000,
      );
    });

    test('sub-pixel deltas are ignored', () {
      expect(
        reveal(contentLeading: 499.5, contentTrailing: 700),
        isNull,
      );
    });
  });
}
