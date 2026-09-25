import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/ui/features/player/widgets/playback_details_morph.dart';

Widget _wrap(PlaybackDetailsMorph morph) {
  return FluentApp(
    home: Stack(
      children: [morph],
    ),
  );
}

Finder get _hiddenOffstageFinder {
  return find.byWidgetPredicate(
    (widget) => widget is Offstage && widget.offstage,
  );
}

/// The morphing panel body. It collapses to the spawn blob's 34px size rather
/// than disappearing, so "the panel is showing" means a body wider than that.
Finder get _panelBodyFinder => find.byKey(PlaybackDetailsMorph.panelBodyKey);

bool _isPanelVisible(WidgetTester tester, {double minWidth = 50}) {
  final finder = _panelBodyFinder;
  if (finder.evaluate().isEmpty) return false;
  return tester.getSize(finder).width > minWidth;
}

void main() {
  testWidgets('keeps the pre-measure frame offstage', (
    WidgetTester tester,
  ) async {
    final controller = PlaybackDetailsMorphController();

    await tester.pumpWidget(
      _wrap(
        PlaybackDetailsMorph(
          controller: controller,
          maxSize: const Size(560, 530),
          anchor: const Offset(1260, 56),
          spawnRect: const Rect.fromLTWH(1226, 22, 34, 34),
          onSettled: () {},
          child: const SizedBox(width: 100, height: 80),
        ),
      ),
    );

    // The first frame should only measure the content offstage, so the
    // user never sees the parked twin-circle pre-measure state.
    expect(_panelBodyFinder, findsNothing);
    expect(_hiddenOffstageFinder, findsOneWidget);

    // Once the post-frame measurement lands, the visible morph may render.
    await tester.pump();
    expect(_panelBodyFinder, findsOneWidget);
    expect(_hiddenOffstageFinder, findsNothing);
  });

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
    final body = _panelBodyFinder;
    expect(_isPanelVisible(tester), isTrue);
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
    final midBody = _panelBodyFinder;
    expect(_isPanelVisible(tester, minWidth: 40), isTrue);
    final midRect = tester.getRect(midBody);
    expect(midRect.width, lessThan(100));
    expect(midRect.width, greaterThan(34));
    expect(midRect.right, closeTo(1260, 2));
    expect(midRect.top, closeTo(56, 2));

    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(settledCount, 2);
    expect(_isPanelVisible(tester), isFalse);
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
