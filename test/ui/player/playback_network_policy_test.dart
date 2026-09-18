import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/data/models/player_models.dart';
import 'package:fly_narwhal/ui/features/player/services/playback_network_policy.dart';

void main() {
  test(
    'Given consecutive standard and Quark sources, when opening each, then the native timeout is applied before open and restored after Quark',
    () async {
      final events = <String>[];
      String? nativeTimeout;
      Future<void> setProperty(String name, String value) async {
        expect(name, 'network-timeout');
        nativeTimeout = value;
        events.add('set:$value');
      }

      for (final transport in [
        PlaybackTransport.standard,
        PlaybackTransport.quarkCdnRange,
        PlaybackTransport.standard,
      ]) {
        await openWithPlaybackNetworkPolicy(
          transport: transport,
          setProperty: setProperty,
          open: () async => events.add('open:$nativeTimeout'),
        );
      }

      expect(
          events, ['set:5', 'open:5', 'set:60', 'open:60', 'set:5', 'open:5']);
    },
  );

  test(
    'Given an asynchronous native property change, when preparing Quark playback, then open waits for the change to finish',
    () async {
      final settingStarted = Completer<void>();
      final settingFinished = Completer<void>();
      var opened = false;
      final opening = openWithPlaybackNetworkPolicy(
        transport: PlaybackTransport.quarkCdnRange,
        setProperty: (name, value) {
          settingStarted.complete();
          return settingFinished.future;
        },
        open: () async => opened = true,
      );

      await settingStarted.future;
      expect(opened, isFalse);
      settingFinished.complete();
      await opening;
      expect(opened, isTrue);
    },
  );

  test(
    'Given native timeout application fails, when opening, then it does not silently continue with the previous timeout',
    () async {
      var opened = false;
      await expectLater(
        openWithPlaybackNetworkPolicy(
          transport: PlaybackTransport.quarkCdnRange,
          setProperty: (_, __) async => throw StateError('property failed'),
          open: () async => opened = true,
        ),
        throwsStateError,
      );
      expect(opened, isFalse);
    },
  );

  test(
    'Given a player without native properties, when opening a standard source, then its existing open behavior remains available',
    () async {
      var opened = false;
      await openWithPlaybackNetworkPolicy(
        transport: PlaybackTransport.standard,
        open: () async => opened = true,
      );
      expect(opened, isTrue);
    },
  );
}
