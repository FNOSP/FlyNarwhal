import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/player_models.dart';
import '../widgets/toast.dart';

class PlayerManager extends StateNotifier<PlayerState> {
  final ToastManager toastManager;
  int keyFocusRequestSerial = 0;
  bool isPipMode = false;
  int danmakuResetNonce = 0;
  
  // Initial resume target in player timeline (history progress)
  int? initialResumePositionMs;
  
  // Auto-skipped intro segment decided during startup/resume
  (int, int)? startupAutoSkippedIntroSegmentMillis;
  
  int? initialSeekTargetMs;
  bool initialSeekCommandSent = false;
  int initialSeekCommandWallTimeMs = 0;
  int initialSeekStableSinceWallTimeMs = 0;
  int initialSeekLastObservedPositionMs = 0;
  bool initialSeekCompleted = true;

  PlayerManager({ToastManager? toastManager})
      : toastManager = toastManager ?? ToastManager(),
        super(const PlayerState());

  void requestKeyFocus() {
    keyFocusRequestSerial++;
  }

  void showPlayer({
    required String itemGuid,
    required String mediaTitle,
    String subhead = '',
    int duration = 0,
    bool isEpisode = false,
    bool isLoading = false,
  }) {
    state = PlayerState(
      isVisible: true,
      isUiVisible: true,
      isLoading: isLoading,
      itemGuid: itemGuid,
      mediaTitle: mediaTitle,
      subhead: subhead,
      duration: duration,
      isEpisode: isEpisode,
    );
  }

  void hidePlayer() {
    state = state.copyWith(isVisible: false);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setUiVisible(bool visible) {
    if (state.isVisible && state.isUiVisible != visible) {
      state = state.copyWith(isUiVisible: visible);
    }
  }

  void updateDuration(int duration) {
    state = state.copyWith(duration: duration);
  }
}

// Provider for PlayerManager
final playerManagerProvider =
    StateNotifierProvider<PlayerManager, PlayerState>((ref) {
  return PlayerManager(toastManager: ToastManager());
});

// Provider for PlayingInfoCache
final playingInfoCacheProvider =
    StateProvider<PlayingInfoCache?>((ref) => null);

// Provider for SubtitleSettings
final subtitleSettingsProvider =
    StateProvider<SubtitleSettings>((ref) => const SubtitleSettings());

// Provider for current speed
final playbackSpeedProvider = StateProvider<double>((ref) => 1.0);

// Provider for volume
final volumeProvider = StateProvider<double>((ref) => 1.0);

// Provider for auto play
final autoPlayProvider = StateProvider<bool>((ref) => true);

// Provider for fullscreen state
final isFullScreenProvider = StateProvider<bool>((ref) => false);