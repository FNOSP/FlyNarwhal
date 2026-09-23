import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fly_narwhal/data/storage/preferences_manager.dart';
import 'package:fly_narwhal/providers/providers.dart';
import 'package:fly_narwhal/ui/features/player/player_screen.dart';
import 'package:fly_narwhal/ui/navigation/app_router.dart';

void main() {
  for (final fromBeginning in <String?>[null, '1', '0', 'true', '']) {
    testWidgets(
      'player route ${fromBeginning == null ? 'without from_beginning' : 'with from_beginning=$fromBeginning'} preserves selection and resume intent',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final manager = PreferencesManager(preferences);
        await manager.saveBaseUrl('https://nas.example.test');
        await manager.saveToken('test-session-token');
        final container = ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ]);
        addTearDown(container.dispose);
        final router = container.read(routerProvider);
        addTearDown(router.dispose);
        final uri = Uri(
          path: '/player/item-guid',
          queryParameters: {
            'media_guid': 'media/selected',
            'audio_guid': 'audio-selected',
            'subtitle_guid': 'subtitle & selected',
            if (fromBeginning != null) 'from_beginning': fromBeginning,
          },
        );

        // Exercise the application's real route matching and builder. Inspect
        // its PlayerScreen before mounting so this route contract test cannot
        // initialize media_kit, a native window, or any playback HTTP requests.
        final matches = router.configuration.findMatch(uri);
        expect(matches.isError, isFalse);
        final route = matches.matches.single.route as GoRoute;
        expect(route.path, '/player/:guid');
        final state = router.configuration.buildTopLevelGoRouterState(matches);
        PlayerScreen? player;
        await tester.pumpWidget(FluentApp(
          home: Builder(builder: (context) {
            player = route.builder!(context, state) as PlayerScreen;
            return const SizedBox.shrink();
          }),
        ));

        expect(player, isNotNull);
        expect(player!.guid, 'item-guid');
        expect(player!.mediaGuid, 'media/selected');
        expect(player!.audioGuid, 'audio-selected');
        expect(player!.subtitleGuid, 'subtitle & selected');
        expect(player!.initialPositionMs, fromBeginning == '1' ? 0 : isNull);
        expect(find.byType(PlayerScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
