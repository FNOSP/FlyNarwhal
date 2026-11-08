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
}
