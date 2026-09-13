import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:fly_narwhal/ui/features/player/widgets/playback_details_morph.dart';

Widget _wrap(PlaybackDetailsMorph morph) {
  return FluentApp(
    home: Stack(
      children: [morph],
    ),
  );
}

/// The morphing panel body — the glass container whose width tracks the
/// destination size (the spawn blob stays 34 wide).
Finder _panelBodyFinder(double minWidth) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is GlassContainer &&
        widget.width != null &&
        widget.width! > minWidth,
  );
}

void main() {
  testWidgets('sizes to the content and pins the top-right to the anchor', (
    WidgetTester tester,
  ) async {
    var settledCount = 0;
    final controller = PlaybackDetailsMorphController();

    await tester.pumpWidget(
      _wrap(
        PlaybackDetailsMorph(
          controller: controller,
          maxSize: const Size(560, 530),
          anchor: const Offset(1260, 56),
          spawnRect: const Rect.fromLTWH(1226, 22, 34, 34),
          onSettled: () => settledCount++,
          child: const SizedBox(width: 100, height: 80),
        ),
      ),
    );

    // Let the measurement land and the open spring settle.
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(settledCount, 1);

    // The panel body must hug the content (the scroll view forces its width
    // to the available box) instead of filling the maximum size. Height
    // includes the 16px padding on all sides.
    final body = _panelBodyFinder(50);
    expect(body, findsOneWidget);
    expect(tester.getSize(body).height, closeTo(80 + 32, 1));
    final rect = tester.getRect(body);
    expect(rect.right, closeTo(1260, 1));
    expect(rect.top, closeTo(56, 1));

    // Content must be fully visible once the morph settles.
    expect(
      tester
          .widgetList<Opacity>(find.byType(Opacity))
          .any((opacity) => opacity.opacity == 1.0),
      isTrue,
    );

    controller.close();

    // The first frame after close() just seeds the spring simulation; pump a
    // zero frame and then advance into the collapse.
    await tester.pump();

    // Mid-collapse the body must still exist, smaller than the target but
    // larger than the spawn blob, and its top-right corner must stay pinned
    // to the anchor while it shrinks toward it.
    await tester.pump(const Duration(milliseconds: 120));
    final midBody = _panelBodyFinder(40);
    expect(midBody, findsOneWidget);
    final midRect = tester.getRect(midBody);
    expect(midRect.width, lessThan(100));
    expect(midRect.width, greaterThan(34));
    expect(midRect.right, closeTo(1260, 2));
    expect(midRect.top, closeTo(56, 2));

    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(settledCount, 2);
    expect(_panelBodyFinder(50), findsNothing);
  });

  testWidgets('open reports settled only once', (
    WidgetTester tester,
  ) async {
    var settledCount = 0;
    final controller = PlaybackDetailsMorphController();

    await tester.pumpWidget(
      _wrap(
        PlaybackDetailsMorph(
          controller: controller,
          maxSize: const Size(300, 200),
          anchor: const Offset(500, 40),
          spawnRect: const Rect.fromLTWH(466, 6, 34, 34),
          onSettled: () => settledCount++,
          child: const SizedBox(width: 200, height: 120),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(settledCount, 1);

    // Extra frames must not re-fire the settled callback.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(settledCount, 1);
  });
}
