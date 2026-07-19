import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/player_models.dart';
import '../../../../data/models/movie_detail_models.dart';
import '../controllers/player_manager.dart';

class PlayerViewModel extends StateNotifier<PlayingInfoCache?> {
  final Ref ref;

  PlayerViewModel(this.ref) : super(null);

  void updatePlayingInfo(PlayingInfoCache? playingInfoCache) {
    // When switching video (different guid) or clearing playing info, reset subtitle settings
    if (playingInfoCache?.itemGuid != state?.itemGuid) {
      ref.read(subtitleSettingsProvider.notifier).state =
          const SubtitleSettings();
    }
    state = playingInfoCache;
  }

  void updateSubtitleList(
    List<SubtitleStream> subtitleStreams,
    StreamResponse streamInfo,
  ) {
    state = state?.copyWith(
      currentSubtitleStreamList: subtitleStreams,
      streamInfo: streamInfo,
    );
  }

  void updateSkipConfig(int skipOpening, int skipEnding) {
    final currentInfo = state;
    if (currentInfo == null) return;

    final guid =
        currentInfo.playConfig?.guid ?? currentInfo.parentGuid;
    if (guid == null) return;

    // Create new play config with updated values
    final newConfig = PlayConfig(
      guid: guid,
      skipOpening: skipOpening,
      skipEnding: skipEnding,
    );

    state = currentInfo.copyWith(playConfig: newConfig);
  }

  void updateCurrentVideoStream(VideoStream videoStream) {
    state = state?.copyWith(currentVideoStream: videoStream);
  }

  void updateCurrentAudioStream(AudioStream? audioStream) {
    state = state?.copyWith(currentAudioStream: audioStream);
  }

  void updateCurrentSubtitleStream(SubtitleStream? subtitleStream) {
    state = state?.copyWith(currentSubtitleStream: subtitleStream);
  }

  void updatePlayLink(String playLink, {bool isUseDirectLink = false}) {
    state = state?.copyWith(
      playLink: playLink,
      isUseDirectLink: isUseDirectLink,
    );
  }
}

final playerViewModelProvider =
    StateNotifierProvider<PlayerViewModel, PlayingInfoCache?>((ref) {
  return PlayerViewModel(ref);
});