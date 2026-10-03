import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fly_narwhal/ui/features/player/widgets/player_action_button.dart';
import 'package:fly_narwhal/ui/shared/window_caption.dart';

void main() {
  testWidgets('refresh button exposes semantics and blocks repeated taps',
      (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    final completer = Completer<void>();
    var pressCount = 0;

    await tester.pumpWidget(
      FluentApp(
        home: Center(
          child: WindowCaptionRefreshButton(
            key: const ValueKey('refresh-button'),
            brightness: Brightness.dark,
            onPressed: () async {
              pressCount += 1;
              await completer.future;
            },
          ),
        ),
      ),
    );

    final refreshButton = find.byKey(const ValueKey('refresh-button'));
    final initialSemantics = tester.getSemantics(refreshButton);
    final initialData = initialSemantics.getSemanticsData();
    expect(initialData.label, contains('刷新'));
    expect(initialData.hasAction(SemanticsAction.tap), isTrue);

    await tester.tap(refreshButton);
    await tester.pump();
    await tester.tap(refreshButton);
    await tester.pump();

    expect(pressCount, 1);
    final disabledSemantics = tester.getSemantics(refreshButton);
    final disabledData = disabledSemantics.getSemanticsData();
    expect(disabledData.label, contains('刷新'));
    expect(disabledData.hasAction(SemanticsAction.tap), isFalse);

    completer.complete();
    await tester.pumpAndSettle();

    await tester.tap(refreshButton);
    await tester.pump();

    expect(pressCount, 2);
    semantics.dispose();
  });

  testWidgets('window caption places refresh button before minimize button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: WindowCaption(
          brightness: Brightness.dark,
          showRefreshAction: true,
          onRefreshPressed: () async {},
        ),
      ),
    );

    final refreshButton =
        find.byKey(const ValueKey('window-caption-refresh-button'));
    final minimizeButton =
        find.byKey(const ValueKey('window-caption-minimize-button'));

    expect(refreshButton, findsOneWidget);
    expect(minimizeButton, findsOneWidget);
    expect(
      tester.getCenter(refreshButton).dx,
      lessThan(tester.getCenter(minimizeButton).dx),
    );
  });

  testWidgets('player controls expose native Windows window actions',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    try {
      await tester.pumpWidget(
        const FluentApp(
          home: Center(
            child: PlayerWindowCaptionControls(
              keyPrefix: 'player-window',
            ),
          ),
        ),
      );

      final minimizeButton =
          find.byKey(const ValueKey('player-window-minimize-button'));
      final maximizeButton =
          find.byKey(const ValueKey('player-window-maximize-button'));
      final closeButton =
          find.byKey(const ValueKey('player-window-close-button'));

      expect(minimizeButton, findsOneWidget);
      expect(maximizeButton, findsOneWidget);
      expect(closeButton, findsOneWidget);
      expect(
        tester.getCenter(minimizeButton).dx,
        lessThan(tester.getCenter(maximizeButton).dx),
      );
      expect(
        tester.getCenter(maximizeButton).dx,
        lessThan(tester.getCenter(closeButton).dx),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Windows player top buttons have square hover backgrounds',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    try {
      await tester.pumpWidget(
        FluentApp(
          home: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                WindowCaptionPinButton(
                  key: const ValueKey('player-pin'),
                  brightness: Brightness.dark,
                  compact: true,
                  buttonSize: 34,
                  iconSize: 16,
                  borderRadius: playerTopBarActionBorderRadius,
                ),
                PlayerActionButton.icon(
                  key: const ValueKey('player-details'),
                  iconData: FluentIcons.info,
                  size: 34,
                  iconSize: 16,
                  borderRadius: playerTopBarActionBorderRadius,
                ),
                const PlayerWindowCaptionControls(keyPrefix: 'player-window'),
              ],
            ),
          ),
        ),
      );

      final pin = find.byKey(const ValueKey('player-pin'));
      final details = find.byKey(const ValueKey('player-details'));
      final minimize =
          find.byKey(const ValueKey('player-window-minimize-button'));
      expect(tester.getSize(pin), const Size(34, 34));
      expect(tester.getSize(details), tester.getSize(minimize));
      expect(
        tester.widget<SvgPicture>(
          find.descendant(of: pin, matching: find.byType(SvgPicture)),
        ).width,
        16,
      );
      expect(tester.widget<PlayerActionButton>(details).iconSize, 16);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer();

      // Hover both player actions and inspect their rendered decorations.
      await mouse.moveTo(tester.getCenter(pin));
      await tester.pump();
      final pinContainer = tester.widget<Container>(
        find.descendant(of: pin, matching: find.byType(Container)).first,
      );
      final pinDecoration = pinContainer.decoration! as BoxDecoration;
      expect(pinDecoration.borderRadius, BorderRadius.zero);
      expect(pinDecoration.color, isNot(Colors.transparent));

      await mouse.moveTo(tester.getCenter(details));
      await tester.pumpAndSettle();
      final detailsContainer = tester.widget<AnimatedContainer>(
        find.descendant(of: details, matching: find.byType(AnimatedContainer)),
      );
      final detailsDecoration = detailsContainer.decoration! as BoxDecoration;
      expect(detailsDecoration.borderRadius, BorderRadius.zero);
      expect(detailsDecoration.color, isNot(Colors.transparent));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('player top buttons retain rounded corners outside Windows', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      expect(playerTopBarActionBorderRadius, BorderRadius.circular(15));
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(playerTopBarActionBorderRadius, BorderRadius.circular(17));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
