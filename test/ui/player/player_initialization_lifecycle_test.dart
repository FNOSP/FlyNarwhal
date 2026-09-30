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

void main() {
  for (final fails in [false, true]) {
    testWidgets(
        'Exit while device lookup is pending ignores its late ${fails ? 'error' : 'result'}',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final device = _Device(PreferencesManager(preferences));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ProviderScope(overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        playerDeviceContextServiceProvider.overrideWithValue(device),
        iTagRepositoryProvider.overrideWithValue(_Tags()),
      ], child: const FluentApp(home: PlayerScreen(guid: 'pending'))));
      await tester.pump();
      expect(device.calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      if (fails) {
        device.lookup.completeError(Exception('Device lookup failed'));
      } else {
        device.lookup.complete(const []);
      }
      await tester.pump();
      await tester.pump();
      expect(find.byType(PlayerScreen), findsNothing);
      expect(tester.takeException(), isNull);
      // No native media engine is initialized; creating a late Player would fail.
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    // The variant avoids desktop window plugins; this verifies widget lifecycle,
    // not playback on an Android device or a Windows native client.
  }
}

class _Device extends PlayerDeviceContextService {
  _Device(super.preferencesManager);
  final lookup = Completer<List<String>>();
  int calls = 0;
  @override
  Future<List<String>> loadSupportedHwdecApis() {
    calls++;
    return lookup.future;
  }
}

class _Tags extends Fake implements ITagRepository {
  @override
  Future<ApiResult<Map<String, String>>> getTag(String tag,
          {String? language, bool force = false}) async =>
      const Success({});
}
