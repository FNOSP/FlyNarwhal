import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fly_narwhal/services/watch_time_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WatchTimeTracker', () {
    test('only accrues time while playing and persists per user scope',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final tracker = WatchTimeTracker(prefs);

      expect(tracker.totalSeconds(userGuid: 'u1'), 0);
      expect(tracker.hasReachedThreshold(userGuid: 'u1'), isFalse);

      tracker.onPlaybackChanged(true, userGuid: 'u1');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      tracker.onPlaybackChanged(false, userGuid: 'u1');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final accrued = tracker.totalSeconds(userGuid: 'u1');
      expect(accrued, greaterThanOrEqualTo(1));
      // Paused time must not count.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(tracker.totalSeconds(userGuid: 'u1'), accrued);
      // Scopes are isolated.
      expect(tracker.totalSeconds(userGuid: 'u2'), 0);
      expect(tracker.totalSeconds(), 0);
    });

    test('stopSession flushes an in-flight playing session', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final tracker = WatchTimeTracker(prefs);

      tracker.onPlaybackChanged(true);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      tracker.stopSession();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(tracker.totalSeconds(), greaterThanOrEqualTo(1));
    });

    test('threshold flips at exactly three hours', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final tracker = WatchTimeTracker(prefs);

      await prefs.setInt(
        'watch_time_seconds',
        WatchTimeTracker.supportAuthorThreshold.inSeconds - 1,
      );
      expect(tracker.hasReachedThreshold(), isFalse);

      await prefs.setInt(
        'watch_time_seconds',
        WatchTimeTracker.supportAuthorThreshold.inSeconds,
      );
      expect(tracker.hasReachedThreshold(), isTrue);
    });
  });
}
