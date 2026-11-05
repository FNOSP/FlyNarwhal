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
/// after the user has watched at least [supportAuthorThreshold] in total,
/// then re-fires per [laterRepromptInterval] / [donatedRepromptInterval] of
/// additional watch time depending on the user's last dialog response.
///
/// A running session is flushed to disk at most every [checkpointInterval]
/// (and immediately on pause or when the session stops), so a process that
/// dies while the user never pauses loses only the tail since the last
/// checkpoint instead of the whole playback stretch.
class WatchTimeTracker {
  WatchTimeTracker(
    this._prefs, {
    this.checkpointInterval = const Duration(minutes: 1),
  });

  /// 累计观看满 3 小时后，退出播放器时触发「支持作者」弹框。
  static const Duration supportAuthorThreshold = Duration(hours: 3);

  /// 弹框被「稍后再说」（或未经「我已赞赏」关闭）后，
  /// 之后每多累计观看 10 小时再次弹框。
  static const Duration laterRepromptInterval = Duration(hours: 10);

  /// 弹框被「我已赞赏」确认后，之后每多累计观看 20 小时再次弹框。
  static const Duration donatedRepromptInterval = Duration(hours: 20);

  static const _keyWatchSeconds = 'watch_time_seconds';

  /// How often a continuously running session is checkpointed to disk.
  /// Injectable so tests can drive it without waiting a real minute.
  final Duration checkpointInterval;

  final SharedPreferences _prefs;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _checkpointTimer;
  String? _activeScopeKey;
  // Seconds already persisted for the current session, so a checkpoint only
  // writes the delta since the previous flush.
  int _flushedSeconds = 0;

  /// Reports a play/pause transition from a player screen.
  void onPlaybackChanged(bool isPlaying, {String? userGuid}) {
    if (isPlaying) {
      if (!_stopwatch.isRunning) {
        _activeScopeKey = _scopeKey(userGuid);
        _flushedSeconds = 0;
        _stopwatch
          ..reset()
          ..start();
        _startCheckpointTimer();
      }
      return;
    }
    _flush(endSession: true);
  }

  /// Stops the running session (player leaving the route, dispose). Safe to
  /// call when nothing is running.
  void stopSession() => _flush(endSession: true);

  /// Persists whatever the running session has accumulated so far without
  /// ending it — used when the app is backgrounded or closing, where the
  /// process may be torn down before the player reports a pause.
  void checkpoint() => _flush(endSession: false);

  /// The persisted accumulated watch time for a user scope, in seconds.
  int totalSeconds({String? userGuid}) =>
      _prefs.getInt(_scopeKey(userGuid)) ?? 0;

  /// Whether the accumulated watch time has reached the support-author
  /// threshold for a user scope.
  bool hasReachedThreshold({String? userGuid}) =>
      totalSeconds(userGuid: userGuid) >= supportAuthorThreshold.inSeconds;

  void _startCheckpointTimer() {
    _checkpointTimer?.cancel();
    _checkpointTimer = Timer.periodic(
      checkpointInterval,
      (_) => _flush(endSession: false),
    );
  }

  /// Writes the seconds accumulated since the last flush. With [endSession]
  /// the stopwatch stops and is reset; otherwise the session keeps running
  /// and only the delta is persisted.
  void _flush({required bool endSession}) {
    if (!_stopwatch.isRunning) {
      if (endSession) _stopCheckpointTimer();
      return;
    }
    final elapsedSeconds = _stopwatch.elapsed.inSeconds;
    final delta = elapsedSeconds - _flushedSeconds;
    final scopeKey = _activeScopeKey;

    if (endSession) {
      _stopwatch
        ..stop()
        ..reset();
      _flushedSeconds = 0;
      _activeScopeKey = null;
      _stopCheckpointTimer();
    } else {
      _flushedSeconds = elapsedSeconds;
    }

    if (scopeKey == null || delta <= 0) return;
    final previous = _prefs.getInt(scopeKey) ?? 0;
    final total = previous + delta;
    unawaited(_prefs.setInt(scopeKey, total));
    AppTalker.info(
      'WatchTime',
      '${endSession ? 'flushed' : 'checkpoint'} +${delta}s (total=${total}s '
      '~${(total / 3600).toStringAsFixed(2)}h, key=$scopeKey)',
    );
  }

  void _stopCheckpointTimer() {
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
  }

  void dispose() => _stopCheckpointTimer();

  String _scopeKey(String? userGuid) {
    final normalized = userGuid?.trim() ?? '';
    return normalized.isEmpty ? _keyWatchSeconds : '$normalized::$_keyWatchSeconds';
  }
}
