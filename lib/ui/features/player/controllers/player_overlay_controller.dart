import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/providers.dart';

enum PlayerFlyoutType {
  nextEpisode,
  speed,
  episode,
  quality,
  subtitle,
  danmaku,
  settingsMenu,
  liveChannel,
  cloudPlayMode,
  strmDirectPlay,
}

enum PlayerHoverZone {
  progressBar,
  bottomControls,
  speedControl,
  volumeControl,
  qualityControl,
  settingsMenu,
  subtitleControl,
  episodeControl,
  nextEpisode,
  danmakuControl,
  danmakuSettings,
  pipControl,
  playbackDetails,
  liveChannelControl,
  cloudPlayModeControl,
  strmDirectPlayControl,
}

class PlayerOverlayState {
  final bool isUiVisible;
  final Set<PlayerHoverZone> hoveredZones;
  final PlayerFlyoutType? activeFlyout;
  final bool isAutoPlayEnabled;

  const PlayerOverlayState({
    this.isUiVisible = true,
    this.hoveredZones = const <PlayerHoverZone>{},
    this.activeFlyout,
    this.isAutoPlayEnabled = true,
  });

  PlayerOverlayState copyWith({
    bool? isUiVisible,
    Set<PlayerHoverZone>? hoveredZones,
    Object? activeFlyout = _unset,
    bool? isAutoPlayEnabled,
  }) {
    return PlayerOverlayState(
      isUiVisible: isUiVisible ?? this.isUiVisible,
      hoveredZones: hoveredZones ?? this.hoveredZones,
      activeFlyout: identical(activeFlyout, _unset)
          ? this.activeFlyout
          : activeFlyout as PlayerFlyoutType?,
      isAutoPlayEnabled: isAutoPlayEnabled ?? this.isAutoPlayEnabled,
    );
  }

  static const Object _unset = Object();
}

class PlayerOverlayController extends StateNotifier<PlayerOverlayState> {
  PlayerOverlayController({
    Duration autoHideDuration = const Duration(seconds: 3),
    bool initialAutoPlayEnabled = true,
  })  : _autoHideDuration = autoHideDuration,
        super(PlayerOverlayState(isAutoPlayEnabled: initialAutoPlayEnabled));

  final Duration _autoHideDuration;
  Timer? _hideUiTimer;

  void showUi({required bool isPlaying}) {
    if (!state.isUiVisible) {
      state = state.copyWith(isUiVisible: true);
    }
    _hideUiTimer?.cancel();
    if (!isPlaying) {
      return;
    }

    _hideUiTimer = Timer(_autoHideDuration, () {
      if (_shouldKeepUiVisible(isPlaying: isPlaying)) {
        return;
      }
      state = state.copyWith(isUiVisible: false);
    });
  }

  void setHovered(PlayerHoverZone zone, bool hovered) {
    final nextHoveredZones = {...state.hoveredZones};
    if (hovered) {
      nextHoveredZones.add(zone);
    } else {
      nextHoveredZones.remove(zone);
    }
    state = state.copyWith(hoveredZones: nextHoveredZones);
  }

  void setFlyoutHovered(PlayerFlyoutType type, bool hovered) {
    setHovered(_hoverZoneForFlyout(type), hovered);
    state = state.copyWith(
      activeFlyout: hovered
          ? type
          : (state.activeFlyout == type ? null : state.activeFlyout),
    );
  }

  void setAutoPlayEnabled(bool value) {
    if (state.isAutoPlayEnabled == value) return;
    state = state.copyWith(isAutoPlayEnabled: value);
  }

  void dismissTransientUi() {
    _hideUiTimer?.cancel();
    state = state.copyWith(
      hoveredZones: const <PlayerHoverZone>{},
      activeFlyout: null,
    );
  }

  bool shouldKeepUiVisible({required bool isPlaying}) {
    return _shouldKeepUiVisible(isPlaying: isPlaying);
  }

  PlayerHoverZone _hoverZoneForFlyout(PlayerFlyoutType type) {
    switch (type) {
      case PlayerFlyoutType.nextEpisode:
        return PlayerHoverZone.nextEpisode;
      case PlayerFlyoutType.speed:
        return PlayerHoverZone.speedControl;
      case PlayerFlyoutType.episode:
        return PlayerHoverZone.episodeControl;
      case PlayerFlyoutType.quality:
        return PlayerHoverZone.qualityControl;
      case PlayerFlyoutType.subtitle:
        return PlayerHoverZone.subtitleControl;
      case PlayerFlyoutType.danmaku:
        return PlayerHoverZone.danmakuSettings;
      case PlayerFlyoutType.settingsMenu:
        return PlayerHoverZone.settingsMenu;
      case PlayerFlyoutType.liveChannel:
        return PlayerHoverZone.liveChannelControl;
      case PlayerFlyoutType.cloudPlayMode:
        return PlayerHoverZone.cloudPlayModeControl;
      case PlayerFlyoutType.strmDirectPlay:
        return PlayerHoverZone.strmDirectPlayControl;
    }
  }

  bool _shouldKeepUiVisible({required bool isPlaying}) {
    return !isPlaying || state.hoveredZones.isNotEmpty;
  }

  @override
  void dispose() {
    _hideUiTimer?.cancel();
    super.dispose();
  }
}

final playerOverlayControllerProvider = StateNotifierProvider.autoDispose<
    PlayerOverlayController, PlayerOverlayState>((ref) {
  final settingsManager = ref.watch(playerSettingsManagerProvider);
  final initialAutoPlayEnabled = settingsManager.getAutoPlay();
  return PlayerOverlayController(
    initialAutoPlayEnabled: initialAutoPlayEnabled,
  );
});
