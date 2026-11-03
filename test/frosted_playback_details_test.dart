import 'dart:ui' show ImageFilter;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/data/models/player_models.dart';
import 'package:fly_narwhal/l10n/generated/app_localizations.dart';
import 'package:fly_narwhal/ui/features/player/widgets/frosted_playback_details.dart';

Widget _wrap({
  required PlayingInfoCache cache,
  MediaTranscodeResponse? transcodeStatus,
  VoidCallback? onClose,
}) {
  return FluentApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...FluentLocalizations.localizationsDelegates,
    ],
    supportedLocales: const [Locale('zh'), Locale('en')],
    locale: const Locale('zh'),
    home: Stack(
      children: [
        // Mirrors the player's real composition: the panel is returned from a
        // `Positioned.fill` → `LayoutBuilder`, so it receives tight full-size
        // constraints and must anchor itself.
        Positioned.fill(
          child: FrostedPlaybackDetails(
            cache: cache,
            transcodeStatus: transcodeStatus,
            bufferedSeconds: 12.5,
            onClose: onClose ?? () {},
            closeTooltip: '关闭',
          ),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('renders the static frosted surface with panel content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(cache: const PlayingInfoCache()));
    await tester.pumpAndSettle();

    // The frosted surface is a blurred backdrop under a translucent panel,
    // with no liquid glass container and no morph animation.
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(ClipRRect), findsOneWidget);
    final backdrop = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(backdrop.filter, isA<ImageFilter>());

    // Same content widget as the liquid glass style.
    expect(find.text('播放类型： 直接播放'), findsOneWidget);
    expect(find.text('媒体源信息'), findsOneWidget);
    // Close button is pinned to the panel's top-right corner.
    expect(
      find.byKey(const ValueKey('player-playback-details-close')),
      findsOneWidget,
    );
  });

  testWidgets('panel is anchored to the top-right of its parent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(cache: const PlayingInfoCache()));
    await tester.pumpAndSettle();

    final parentRect = tester.getRect(find.byType(Stack).first);
    final panelRect = tester.getRect(find.byType(ClipRRect));
    // Top-offset 56 and right-offset 20 from the player bounds.
    expect((panelRect.top - parentRect.top - 56).abs(), lessThan(1));
    expect((parentRect.right - panelRect.right - 20).abs(), lessThan(1));
    // The panel shrinks to its content instead of filling the whole parent.
    expect(panelRect.width, lessThan(parentRect.width * 0.9));
    expect(panelRect.height, lessThan(parentRect.height * 0.9));
  });

  testWidgets('tapping the close button fires onClose', (
    WidgetTester tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      _wrap(cache: const PlayingInfoCache(), onClose: () => closed = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('player-playback-details-close')),
    );
    await tester.pump();

    expect(closed, isTrue);
  });
}
