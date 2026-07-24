import '../models/player_seek_origin.dart';

abstract interface class PlayerSeekAdapter {
  Future<void> seekTo(int targetMilliseconds);
}

class CallbackPlayerSeekAdapter implements PlayerSeekAdapter {
  const CallbackPlayerSeekAdapter(this._seek);

  final Future<void> Function(int targetMilliseconds) _seek;

  @override
  Future<void> seekTo(int targetMilliseconds) => _seek(targetMilliseconds);
}

class PlayerSeekExecutor {
  const PlayerSeekExecutor({
    required PlayerSeekAdapter playerAdapter,
    required int Function() authoritativeDurationMilliseconds,
    required void Function() resetDanmaku,
    required void Function(int targetMilliseconds) updateDanmakuPosition,
    required void Function(int targetMilliseconds) updatePlayRecord,
    required void Function() notifyUserSeekStarted,
    required void Function() notifyUserSeekCompleted,
  })  : _playerAdapter = playerAdapter,
        _authoritativeDurationMilliseconds = authoritativeDurationMilliseconds,
        _resetDanmaku = resetDanmaku,
        _updateDanmakuPosition = updateDanmakuPosition,
        _updatePlayRecord = updatePlayRecord,
        _notifyUserSeekStarted = notifyUserSeekStarted,
        _notifyUserSeekCompleted = notifyUserSeekCompleted;

  final PlayerSeekAdapter _playerAdapter;
  final int Function() _authoritativeDurationMilliseconds;
  final void Function() _resetDanmaku;
  final void Function(int targetMilliseconds) _updateDanmakuPosition;
  final void Function(int targetMilliseconds) _updatePlayRecord;
  final void Function() _notifyUserSeekStarted;
  final void Function() _notifyUserSeekCompleted;

  Future<void> performSeek({
    required int targetMilliseconds,
    required PlayerSeekOrigin origin,
  }) async {
    final durationMilliseconds = _authoritativeDurationMilliseconds();
    final maximumMilliseconds = durationMilliseconds > 0
        ? durationMilliseconds
        : targetMilliseconds < 0
            ? 0
            : targetMilliseconds;
    final clampedTargetMilliseconds = targetMilliseconds.clamp(
      0,
      maximumMilliseconds,
    );
    final isUserSeek = origin.isUserInitiated;

    if (isUserSeek) {
      _notifyUserSeekStarted();
    }

    _resetDanmaku();
    _updateDanmakuPosition(clampedTargetMilliseconds);
    try {
      await _playerAdapter.seekTo(clampedTargetMilliseconds);
      _updatePlayRecord(clampedTargetMilliseconds);
    } finally {
      if (isUserSeek) {
        _notifyUserSeekCompleted();
      }
    }
  }
}

extension PlayerSeekOriginClassification on PlayerSeekOrigin {
  bool get isUserInitiated {
    return switch (this) {
      PlayerSeekOrigin.progressBar ||
      PlayerSeekOrigin.keyboard ||
      PlayerSeekOrigin.pipProgressBar ||
      PlayerSeekOrigin.pipShortcut ||
      PlayerSeekOrigin.settings =>
        true,
      PlayerSeekOrigin.introAutoSkip ||
      PlayerSeekOrigin.introUndo ||
      PlayerSeekOrigin.outroAutoSkip ||
      PlayerSeekOrigin.resumeCorrection =>
        false,
    };
  }
}
