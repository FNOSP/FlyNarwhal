import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/log/app_talker.dart';

/// Accumulates how long the user actually spends watching video, across all
/// player sessions, in the background.
///
/// The player reports play/pause transitions via [onPlaybackChanged]; time
/// only accrues while a stream is playing (buffering/paused/menu time is not
/// counted). The running total is persisted per user
/// (`<guid>::watch_time_seconds`, global key when logged out) so it survives
/// app restarts, and is consumed by the support-author prompt that fires
/// after the user has watched at least [supportAuthorThreshold] in total.
class WatchTimeTracker {
  WatchTimeTracker(this._prefs);

  /// 累计观看满 3 小时后，退出播放器时触发「支持作者」弹框。
  static const Duration supportAuthorThreshold = Duration(hours: 3);

  static const _keyWatchSeconds = 'watch_time_seconds';

  final SharedPreferences _prefs;

  final Stopwatch _stopwatch = Stopwatch();
  String? _activeScopeKey;

  /// Reports a play/pause transition from a player screen.
  void onPlaybackChanged(bool isPlaying, {String? userGuid}) {
    if (isPlaying) {
      if (!_stopwatch.isRunning) {
        _activeScopeKey = _scopeKey(userGuid);
        _stopwatch.start();
      }
      return;
    }
    _flush();
  }

  /// Stops the running session (player leaving the route, dispose). Safe to
  /// call when nothing is running.
  void stopSession() => _flush();

  /// The persisted accumulated watch time for a user scope, in seconds.
  int totalSeconds({String? userGuid}) =>
      _prefs.getInt(_scopeKey(userGuid)) ?? 0;

  /// Whether the accumulated watch time has reached the support-author
  /// threshold for a user scope.
  bool hasReachedThreshold({String? userGuid}) =>
      totalSeconds(userGuid: userGuid) >= supportAuthorThreshold.inSeconds;

  void _flush() {
    if (!_stopwatch.isRunning) return;
    _stopwatch.stop();
    final elapsedSeconds = _stopwatch.elapsed.inSeconds;
    _stopwatch.reset();
    final scopeKey = _activeScopeKey;
    _activeScopeKey = null;
    if (scopeKey == null || elapsedSeconds <= 0) return;
    final previous = _prefs.getInt(scopeKey) ?? 0;
    final total = previous + elapsedSeconds;
    unawaited(_prefs.setInt(scopeKey, total));
    AppTalker.info(
      'WatchTime',
      'flushed +${elapsedSeconds}s (total=${total}s '
      '~${(total / 3600).toStringAsFixed(2)}h, key=$scopeKey)',
    );
  }

  String _scopeKey(String? userGuid) {
    final normalized = userGuid?.trim() ?? '';
    return normalized.isEmpty ? _keyWatchSeconds : '$normalized::$_keyWatchSeconds';
  }
}
