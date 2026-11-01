import 'package:fly_narwhal/core/utils/sliding_window_rate_limiter.dart';
import 'package:fly_narwhal/data/datasources/remote/fly_narwhal_server_release_data_source.dart';
import 'package:fly_narwhal/providers/fly_narwhal_server_update_available_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SlidingWindowRateLimiter', () {
    test('allows up to the limit inside one window', () {
      final limiter = SlidingWindowRateLimiter(
        maxCalls: 2,
        window: const Duration(hours: 1),
        now: () => DateTime(2026, 11, 2, 12),
      );
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isFalse);
      expect(limiter.canAcquire, isFalse);
    });

    test('a refused call does not extend the window', () {
      var now = DateTime(2026, 11, 2, 12);
      final limiter = SlidingWindowRateLimiter(
        maxCalls: 2,
        window: const Duration(hours: 1),
        now: () => now,
      );
      limiter.tryAcquire();
      now = now.add(const Duration(minutes: 50));
      limiter.tryAcquire();
      now = now.add(const Duration(minutes: 5));
      expect(limiter.tryAcquire(), isFalse);

      // 61 minutes after the first call: only the first has left the window,
      // so one slot is free again.
      now = now.add(const Duration(minutes: 6));
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isFalse);
    });
  });

  group('FlyNarwhalServerUpdateAvailableNotifier', () {
    FlyNarwhalServerRelease release(String tag) =>
        FlyNarwhalServerRelease(tagName: tag, assets: const []);

    test('reports the release version without its v prefix', () async {
      final notifier = FlyNarwhalServerUpdateAvailableNotifier(
        fetchLatestRelease: () async => release('v2.1.0'),
        isEnabled: () => true,
      );
      expect(await notifier.check('2.0.3'), '2.1.0');
    });

    test('stays quiet when the server is already current', () async {
      final notifier = FlyNarwhalServerUpdateAvailableNotifier(
        fetchLatestRelease: () async => release('v2.0.3'),
        isEnabled: () => true,
      );
      expect(await notifier.check('2.0.3'), isNull);
    });

    test('asks GitHub at most twice per rolling hour', () async {
      var calls = 0;
      var now = DateTime(2026, 11, 2, 12);
      final notifier = FlyNarwhalServerUpdateAvailableNotifier(
        fetchLatestRelease: () async {
          calls++;
          return release('v2.0.3');
        },
        isEnabled: () => true,
        now: () => now,
      );
      await notifier.check('2.0.3');
      now = now.add(const Duration(minutes: 10));
      await notifier.check('2.0.3');
      now = now.add(const Duration(minutes: 10));
      await notifier.check('2.0.3');
      expect(calls, 2);

      now = now.add(const Duration(minutes: 41));
      await notifier.check('2.0.3');
      expect(calls, 3);
    });
  });
}
