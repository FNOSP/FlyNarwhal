import 'player_seek_origin.dart';

enum NextEpisodeLoadPhase {
  idle,
  loading,
  available,
  unavailable,
  failed,
}

sealed class PlayerSkipAction {
  const PlayerSkipAction({required this.sessionGeneration});

  final int sessionGeneration;
}

final class SeekTo extends PlayerSkipAction {
  const SeekTo({
    required super.sessionGeneration,
    required this.milliseconds,
    required this.origin,
  });

  final int milliseconds;
  final PlayerSeekOrigin origin;
}

final class PlayNextEpisode extends PlayerSkipAction {
  const PlayNextEpisode({required super.sessionGeneration});
}

final class PausePlayback extends PlayerSkipAction {
  const PausePlayback({required super.sessionGeneration});
}

final class ShowPlaybackEnd extends PlayerSkipAction {
  const ShowPlaybackEnd({required super.sessionGeneration});
}

final class AwaitNextEpisode extends PlayerSkipAction {
  const AwaitNextEpisode({
    required super.sessionGeneration,
    required this.timeout,
  });

  final Duration timeout;
}
