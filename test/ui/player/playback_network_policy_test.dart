import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/ui/features/player/models/playback_source_spec.dart';
import 'package:fly_narwhal/ui/features/player/services/playback_network_policy.dart';

void main() {
  group('stalled playback startup', () {
    test(
        'standard startup fails after the grace period only without video or cache',
        () {
      bool abort({
        Duration elapsed = const Duration(seconds: 8),
        Duration duration = const Duration(minutes: 10),
        bool hasVideo = false,
        Duration buffered = Duration.zero,
      }) =>
          shouldAbortStalledPlaybackStart(
            transport: PlaybackTransport.standard,
            elapsed: elapsed,
            mediaDuration: duration,
            hasVideo: hasVideo,
            buffered: buffered,
          );
      expect(abort(elapsed: const Duration(milliseconds: 7999)), isFalse);
      expect(abort(), isTrue);
      expect(abort(duration: Duration.zero), isFalse);
      expect(abort(hasVideo: true), isFalse);
      expect(abort(buffered: const Duration(milliseconds: 1)), isFalse);
    });

    test(
        'Quark CDN startup keeps waiting for timeout recovery beyond the standard deadline',
        () {
      for (final elapsed in [
        const Duration(seconds: 8),
        const Duration(minutes: 1),
        const Duration(days: 1),
      ]) {
        expect(
            shouldAbortStalledPlaybackStart(
              transport: PlaybackTransport.quarkCdnRange,
              elapsed: elapsed,
              mediaDuration: const Duration(minutes: 10),
              hasVideo: false,
              buffered: Duration.zero,
            ),
            isFalse);
      }
    });
  });

  test(
    'Given consecutive standard and Quark sources, when opening each, then the native timeout is disabled for Quark before open and restored afterward',
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

      expect(events, ['set:5', 'open:5', 'set:0', 'open:0', 'set:5', 'open:5']);
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
