import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/data/storage/preferences_manager.dart';
import 'package:fly_narwhal/domain/repositories/i_tag_repository.dart';
import 'package:fly_narwhal/providers/providers.dart';
import 'package:fly_narwhal/ui/features/player/player_screen.dart';
import 'package:fly_narwhal/ui/features/player/services/player_device_context_service.dart';

class _PendingDeviceContext extends PlayerDeviceContextService {
  _PendingDeviceContext(super.preferencesManager);

  final result = Completer<List<String>>();
  var requests = 0;

  @override
  Future<List<String>> loadSupportedHwdecApis() {
    requests++;
    return result.future;
  }
}

class _EmptyTags extends Fake implements ITagRepository {
  @override
  Future<ApiResult<Map<String, String>>> getTag(String tag,
          {String? language, bool force = false}) async =>
      const Success(<String, String>{});
}

void main() {
  for (final fail in [false, true]) {
    testWidgets(
      'disposed player does not initialize when pending device lookup ${fail ? 'fails' : 'completes'}',
      (tester) async {
        // Isolate this lifecycle regression from native window plugins. No
        // media_kit initialization is provided: creating a Player after exit
        // would fail this test, even without a native media engine installed.
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final device = _PendingDeviceContext(PreferencesManager(preferences));

        await tester.pumpWidget(ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            playerDeviceContextServiceProvider.overrideWithValue(device),
            iTagRepositoryProvider.overrideWithValue(_EmptyTags()),
          ],
          child: const FluentApp(home: PlayerScreen(guid: 'initializing')),
        ));
        await tester.pump();
        expect(device.requests, 1);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        if (fail) {
          device.result.completeError(StateError('Delayed device lookup'));
        } else {
          device.result.complete(const []);
        }
        await tester.pump();
        await tester.pump();

        expect(find.byType(PlayerScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
