import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/scheduler.dart';

import '../../../../domain/entities/media_type.dart';
import '../../../../data/utils/fn_data_convertor.dart';
import '../../../../data/models/player_models.dart';
import '../../../../data/models/movie_detail_models.dart';
import '../../../../tooling/driver_test_mode.dart';
import 'player_action_button.dart';
import 'player_settings_components.dart';

const Color _flyoutBackgroundColor = Color(0xCC000000);
const Color _flyoutBorderColor = Color(0x80808080);
const Color _selectedTextColor = Color(0xFF2073DF);
const Color _defaultTextColor = Color(0xC8FFFFFF);
const Color _hoverBackgroundColor = Color(0x1AFFFFFF);
const int _hideDelayMs = 200;
const int _animationDurationMs = 200;
const double _settingsFlyoutLeftOffset = -160;
const double _settingsFlyoutBridgeOffset = 40;
const double _settingsFlyoutWidth = 320;
const double _settingsFlyoutMinBridgeWidth = 56;
const double _settingsFlyoutBridgeHorizontalPadding = 12;
const double _estimatedSettingsFlyoutHeight = 300;

class PlayerAudioDisplayTexts {
  final String summaryText;
  final String primaryText;
  final String secondaryLeadingText;
  final String secondaryTrailingText;

  const PlayerAudioDisplayTexts({
    required this.summaryText,
    required this.primaryText,
    required this.secondaryLeadingText,
    required this.secondaryTrailingText,
  });
}

// Build consistent summary and detail texts for audio tracks.
PlayerAudioDisplayTexts buildPlayerAudioDisplayTexts(
  AudioStream? audio,
  Map<String, String>? iso6391Map,
  Map<String, String>? iso6392Map,
) {
  if (audio == null) {
    return const PlayerAudioDisplayTexts(
      summaryText: '未知',
      primaryText: '未知',
      secondaryLeadingText: '',
      secondaryTrailingText: '',
    );
  }

  final languageName = _getPlayerAudioLanguageName(
    audio.language,
    iso6391Map,
    iso6392Map,
  );
  final technicalSummary = _joinAudioParts([
    audio.codecName,
    audio.channelLayout,
  ]);
  final readableTitle = audio.title.trim().isNotEmpty
      ? audio.title.trim()
      : _buildPlayerAudioReadableTitle(languageName, audio);
  final primaryText =
      audio.isDefault == 1 ? '$languageName - 默认' : languageName;

  return PlayerAudioDisplayTexts(
    summaryText: _joinAudioParts([languageName, technicalSummary]),
    primaryText: primaryText,
    secondaryLeadingText: technicalSummary,
    secondaryTrailingText: readableTitle,
  );
}

String _getPlayerAudioLanguageName(
  String? code,
  Map<String, String>? iso6391Map,
  Map<String, String>? iso6392Map,
) {
  return FnDataConvertor.getLanguageName(
    code,
    iso6391Map ?? const <String, String>{},
    iso6392Map ?? const <String, String>{},
  );
}

String _buildPlayerAudioReadableTitle(String languageName, AudioStream audio) {
  final readableProfile = _joinAudioParts([
    audio.profile,
    audio.channelLayout,
  ]);
  final trailing = readableProfile.isNotEmpty
      ? readableProfile
      : _joinAudioParts([
          audio.audioType,
          audio.channelLayout,
        ]);

  if (trailing.isEmpty) {
    return languageName;
  }

  return '$languageName ($trailing)';
}

String _joinAudioParts(List<String?> parts) {
  return parts
      .map((part) => part?.trim() ?? '')
      .where((part) => part.isNotEmpty)
      .join(' ');
}

class PlayerSettingsMenu extends StatefulWidget {
  final PlayingInfoCache? playingInfoCache;
  final int currentPositionMillis;
  final int totalDurationMillis;
  final double popupBottomOffset;
  final void Function(AudioStream) onAudioSelected;
  /// Current window aspect ratio setting ("AUTO", "4:3", "16:9", "21:9").
  final String windowAspectRatio;
  final void Function(String) onWindowAspectRatioChanged;
  /// Current video fill mode ("default", "4:3", "16:9", "21:9").
  final String videoFillMode;
  final void Function(String) onVideoFillModeChanged;
  final void Function(int skipOpening, int skipEnding) onSkipConfigChanged;
  final void Function(bool isHovered)? onHoverStateChanged;
  final bool smartSkipEnabled;
  final void Function(bool enabled)? onSmartSkipEnabledChanged;
  final bool isSmartAnalysisGloballyEnabled;
  final bool isSavingSkipConfig;
  final bool isAutoPlay;
  final void Function(bool enabled)? onAutoPlayChanged;
  final bool forceH264;
  final void Function(bool enabled)? onForceH264Changed;
  final String? forceH264DisabledReason;
  final bool forceSdrColor;
  final void Function(bool enabled)? onForceSdrColorChanged;
  final String? forceSdrDisabledReason;
  final Map<String, String>? iso6391Map;
  final Map<String, String>? iso6392Map;
  // Whether the FlyNarwhal server is fully configured (URL + auth code)
  final bool isFlyNarwhalServerAvailable;
  // Called when user tries to enable smart skip without full config
  final VoidCallback? onFlyNarwhalConfigMissing;
  // Whether this flyout is the currently-active one in the player overlay.
  final bool isActiveControl;

  const PlayerSettingsMenu({
    super.key,
    required this.playingInfoCache,
    this.iso6391Map,
    this.iso6392Map,
    required this.currentPositionMillis,
    required this.totalDurationMillis,
    this.popupBottomOffset = 70,
    required this.onAudioSelected,
    this.windowAspectRatio = 'AUTO',
    required this.onWindowAspectRatioChanged,
    this.videoFillMode = 'default',
    required this.onVideoFillModeChanged,
    required this.onSkipConfigChanged,
    this.onHoverStateChanged,
    this.smartSkipEnabled = true,
    this.onSmartSkipEnabledChanged,
    this.isSmartAnalysisGloballyEnabled = false,
    this.isSavingSkipConfig = false,
    this.isAutoPlay = true,
    this.onAutoPlayChanged,
    this.forceH264 = false,
    this.onForceH264Changed,
    this.forceH264DisabledReason,
    this.forceSdrColor = false,
    this.onForceSdrColorChanged,
    this.forceSdrDisabledReason,
    this.isFlyNarwhalServerAvailable = false,
    this.onFlyNarwhalConfigMissing,
    this.isActiveControl = false,
  });

  @override
  State<PlayerSettingsMenu> createState() => _PlayerSettingsMenuState();
}

class _PlayerSettingsMenuState extends State<PlayerSettingsMenu>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isButtonHovered = false;
  bool _popupHovered = false;
  final GlobalKey _buttonKey = GlobalKey();
  final GlobalKey _flyoutKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Size? _flyoutSize;
  Timer? _hideTimer;
  String _currentScreen = 'Main';
  bool _overlayRebuildScheduled = false;
  late bool _isAutoPlay;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _isAutoPlay = widget.isAutoPlay;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: _animationDurationMs),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  void _showFlyout() {
    _hideTimer?.cancel();
    if (_isExpanded) {
      if (_animationController.status == AnimationStatus.reverse) {
        _animationController.forward();
      }
      _requestOverlayRebuild();
      return;
    }

    setState(() => _isExpanded = true);
    _showOverlay();
    _animationController.forward(from: 0);
    widget.onHoverStateChanged?.call(true);
  }

  void _hideFlyoutWithDelay() {
    _hideTimer?.cancel();
    final delay = kDriverTestMode ? 10000 : _hideDelayMs;
    _hideTimer = Timer(Duration(milliseconds: delay), () {
      if (!_isButtonHovered && !_popupHovered && mounted) {
        _closeMenu();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PlayerSettingsMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActiveControl && !widget.isActiveControl) {
      unawaited(_forceCloseMenu());
      return;
    }
    final autoPlayChanged = oldWidget.isAutoPlay != widget.isAutoPlay;
    if (autoPlayChanged) {
      _isAutoPlay = widget.isAutoPlay;
    }
    if (oldWidget.popupBottomOffset != widget.popupBottomOffset ||
        oldWidget.windowAspectRatio != widget.windowAspectRatio ||
        oldWidget.videoFillMode != widget.videoFillMode ||
        oldWidget.forceH264 != widget.forceH264 ||
        oldWidget.forceSdrColor != widget.forceSdrColor ||
        oldWidget.forceH264DisabledReason != widget.forceH264DisabledReason ||
        oldWidget.forceSdrDisabledReason != widget.forceSdrDisabledReason ||
        autoPlayChanged) {
      _requestOverlayRebuild();
    }
  }

  double get _safePopupBottomOffset =>
      widget.popupBottomOffset < 0 ? 0 : widget.popupBottomOffset;

  void _requestOverlayRebuild() {
    if (_overlayEntry == null || _overlayRebuildScheduled) return;

    _overlayRebuildScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _overlayRebuildScheduled = false;
      if (!mounted || _overlayEntry == null) return;
      _overlayEntry?.markNeedsBuild();
    });
  }

  void _updateFlyoutSizeAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _flyoutKey.currentContext;
      if (context == null) return;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      final nextSize = renderObject.size;
      if (nextSize == _flyoutSize) return;
      _flyoutSize = nextSize;
      _requestOverlayRebuild();
    });
  }

  void _setPopupHovered(bool value) {
    if (_popupHovered == value || !mounted) return;
    setState(() => _popupHovered = value);
  }

  double _calculateBridgeWidth(Size buttonSize) {
    final preferredWidth =
        buttonSize.width + (_settingsFlyoutBridgeHorizontalPadding * 2);
    return preferredWidth.clamp(
      _settingsFlyoutMinBridgeWidth,
      _settingsFlyoutWidth,
    );
  }

  double _calculateBridgeLeft(Size buttonSize) {
    final bridgeWidth = _calculateBridgeWidth(buttonSize);
    final buttonCenterX = (-_settingsFlyoutLeftOffset) + (buttonSize.width / 2);
    final desiredLeft = buttonCenterX - (bridgeWidth / 2);
    return desiredLeft.clamp(0.0, _settingsFlyoutWidth - bridgeWidth);
  }

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (overlayContext) {
        final buttonContext = _buttonKey.currentContext;
        if (buttonContext == null) {
          return const SizedBox.shrink();
        }

        final renderObject = buttonContext.findRenderObject();
        if (renderObject is! RenderBox || !renderObject.hasSize) {
          return const SizedBox.shrink();
        }

        final buttonOffset = renderObject.localToGlobal(Offset.zero);
        final buttonSize = renderObject.size;
        final flyoutHeight =
            _flyoutSize?.height ?? _estimatedSettingsFlyoutHeight;
        final bridgeHeight =
            _safePopupBottomOffset + _settingsFlyoutBridgeOffset;
        final bridgeWidth = _calculateBridgeWidth(buttonSize);
        final bridgeLeft = _calculateBridgeLeft(buttonSize);
        final top =
            buttonOffset.dy + buttonSize.height - bridgeHeight - flyoutHeight;

        _updateFlyoutSizeAfterFrame();

        return Stack(
          children: [
            Positioned(
              left: buttonOffset.dx + _settingsFlyoutLeftOffset,
              top: top,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: _settingsFlyoutWidth,
                  height: flyoutHeight + bridgeHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        child: MouseRegion(
                          opaque: false,
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) {
                            _setPopupHovered(true);
                            _hideTimer?.cancel();
                          },
                          onHover: (_) {
                            if (!_popupHovered) {
                              _setPopupHovered(true);
                            }
                          },
                          onExit: (_) {
                            _setPopupHovered(false);
                            _hideFlyoutWithDelay();
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: KeyedSubtree(
                              key: _flyoutKey,
                              child: _buildAnimatedFlyout(),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: bridgeLeft,
                        top: flyoutHeight,
                        child: MouseRegion(
                          opaque: false,
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) {
                            _setPopupHovered(true);
                            _hideTimer?.cancel();
                          },
                          onExit: (_) {
                            _setPopupHovered(false);
                            _hideFlyoutWithDelay();
                          },
                          child: SizedBox(
                            width: bridgeWidth,
                            height: bridgeHeight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _requestOverlayRebuild();
      return;
    }
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _flyoutSize = null;
    _overlayRebuildScheduled = false;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hideOverlay();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isButtonHovered = true);
        _showFlyout();
      },
      onExit: (_) {
        setState(() => _isButtonHovered = false);
        _hideFlyoutWithDelay();
      },
      child: KeyedSubtree(
        key: const ValueKey('player-settings-menu'),
        child: KeyedSubtree(
          key: _buttonKey,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Hover shows the flyout on desktop; the tap fallback only exists
            // for driver builds, whose synthetic taps carry no hover events.
            onTap: kDriverTestMode
                ? () => _isExpanded ? _closeMenu() : _showFlyout()
                : null,
            child: const PlayerActionButton.lottie(
              lottieAssetPath: 'assets/lottie/settings_lottie.json',
              size: 30,
              iconSize: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedFlyout() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      child: _SettingsFlyoutContent(
        key: ValueKey(_currentScreen),
        playingInfoCache: widget.playingInfoCache,
        iso6391Map: widget.iso6391Map,
        iso6392Map: widget.iso6392Map,
        currentPositionMillis: widget.currentPositionMillis,
        totalDurationMillis: widget.totalDurationMillis,
        currentScreen: _currentScreen,
        onNavigate: (screen) {
          setState(() => _currentScreen = screen);
          _requestOverlayRebuild();
        },
        // Keep the audio flyout open for continuous track switching.
        onAudioSelected: (audio) {
          widget.onAudioSelected(audio);
        },
        onWindowAspectRatioChanged: (ratio) {
          _setPopupHovered(false);
          widget.onWindowAspectRatioChanged(ratio);
          _closeMenu();
        },
        windowAspectRatio: widget.windowAspectRatio,
        onVideoFillModeChanged: (mode) {
          _setPopupHovered(false);
          widget.onVideoFillModeChanged(mode);
          _closeMenu();
        },
        videoFillMode: widget.videoFillMode,
        onSkipConfigChanged: widget.onSkipConfigChanged,
        smartSkipEnabled: widget.smartSkipEnabled,
        onSmartSkipEnabledChanged: widget.onSmartSkipEnabledChanged,
        isSmartAnalysisGloballyEnabled: widget.isSmartAnalysisGloballyEnabled,
        isSavingSkipConfig: widget.isSavingSkipConfig,
        isAutoPlay: _isAutoPlay,
        onAutoPlayChanged: (value) {
          _isAutoPlay = value;
          _requestOverlayRebuild();
          widget.onAutoPlayChanged?.call(value);
        },
        forceH264: widget.forceH264,
        onForceH264Changed: widget.onForceH264Changed,
        forceH264DisabledReason: widget.forceH264DisabledReason,
        forceSdrColor: widget.forceSdrColor,
        onForceSdrColorChanged: widget.onForceSdrColorChanged,
        forceSdrDisabledReason: widget.forceSdrDisabledReason,
        isFlyNarwhalServerAvailable: widget.isFlyNarwhalServerAvailable,
        onFlyNarwhalConfigMissing: widget.onFlyNarwhalConfigMissing,
      ),
    );
  }

  Future<void> _closeMenu() async {
    _hideTimer?.cancel();
    if (!_isExpanded) return;

    if (_animationController.status != AnimationStatus.dismissed) {
      await _animationController.reverse();
    }

    if (!mounted) return;
    if (_isButtonHovered || _popupHovered) {
      _animationController.forward();
      return;
    }

    _hideOverlay();
    setState(() {
      _isExpanded = false;
      _currentScreen = 'Main';
    });
    widget.onHoverStateChanged?.call(false);
  }

  // Force-close regardless of hover state, used when this flyout loses
  // active control (e.g. another flyout opens or the overlay auto-hides).
  Future<void> _forceCloseMenu() async {
    _hideTimer?.cancel();
    if (!_isExpanded) return;

    _isButtonHovered = false;
    _popupHovered = false;

    if (_animationController.status != AnimationStatus.dismissed) {
      await _animationController.reverse();
    }

    if (!mounted) return;
    _hideOverlay();
    setState(() {
      _isExpanded = false;
      _currentScreen = 'Main';
    });
    widget.onHoverStateChanged?.call(false);
  }
}

class _SettingsFlyoutContent extends StatelessWidget {
  final PlayingInfoCache? playingInfoCache;
  final Map<String, String>? iso6391Map;
  final Map<String, String>? iso6392Map;
  final int currentPositionMillis;
  final int totalDurationMillis;
  final String currentScreen;
  final void Function(String) onNavigate;
  final void Function(AudioStream) onAudioSelected;
  final String windowAspectRatio;
  final void Function(String) onWindowAspectRatioChanged;
  final String videoFillMode;
  final void Function(String) onVideoFillModeChanged;
  final void Function(int, int) onSkipConfigChanged;
  final bool smartSkipEnabled;
  final void Function(bool)? onSmartSkipEnabledChanged;
  final bool isSmartAnalysisGloballyEnabled;
  final bool isSavingSkipConfig;
  final bool isAutoPlay;
  final void Function(bool)? onAutoPlayChanged;
  final bool forceH264;
  final void Function(bool)? onForceH264Changed;
  final String? forceH264DisabledReason;
  final bool forceSdrColor;
  final void Function(bool)? onForceSdrColorChanged;
  final String? forceSdrDisabledReason;
  // Whether the FlyNarwhal server is fully configured (URL + auth code)
  final bool isFlyNarwhalServerAvailable;
  // Called when user tries to enable smart skip without full config
  final VoidCallback? onFlyNarwhalConfigMissing;

  const _SettingsFlyoutContent({
    super.key,
    required this.playingInfoCache,
    required this.iso6391Map,
    required this.iso6392Map,
    required this.currentPositionMillis,
    required this.totalDurationMillis,
    required this.currentScreen,
    required this.onNavigate,
    required this.onAudioSelected,
    required this.windowAspectRatio,
    required this.onWindowAspectRatioChanged,
    required this.videoFillMode,
    required this.onVideoFillModeChanged,
    required this.onSkipConfigChanged,
    required this.smartSkipEnabled,
    required this.onSmartSkipEnabledChanged,
    required this.isSmartAnalysisGloballyEnabled,
    required this.isSavingSkipConfig,
    required this.isAutoPlay,
    required this.onAutoPlayChanged,
    required this.forceH264,
    required this.onForceH264Changed,
    required this.forceH264DisabledReason,
    required this.forceSdrColor,
    required this.onForceSdrColorChanged,
    required this.forceSdrDisabledReason,
    required this.isFlyNarwhalServerAvailable,
    required this.onFlyNarwhalConfigMissing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _settingsFlyoutWidth,
      decoration: BoxDecoration(
        color: _flyoutBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _flyoutBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 8, top: 16, bottom: 16, right: 8),
        child: _buildCurrentScreen(),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (currentScreen) {
      case 'Advanced':
        return _AdvancedSettingsScreen(
          forceH264: forceH264,
          forceH264DisabledReason: forceH264DisabledReason,
          onForceH264Changed: onForceH264Changed,
          forceSdrColor: forceSdrColor,
          forceSdrDisabledReason: forceSdrDisabledReason,
          onForceSdrColorChanged: onForceSdrColorChanged,
          onBack: () => onNavigate('Main'),
        );
      case 'Audio':
        return _AudioSettingsScreen(
          playingInfoCache: playingInfoCache,
          iso6391Map: iso6391Map,
          iso6392Map: iso6392Map,
          onBack: () => onNavigate('Main'),
          onAudioSelected: onAudioSelected,
        );
      case 'WindowAspectRatio':
        return _WindowAspectRatioSettingsScreen(
          currentRatio: windowAspectRatio,
          onBack: () => onNavigate('Main'),
          onAspectRatioSelected: onWindowAspectRatioChanged,
        );
      case 'VideoFillMode':
        return _VideoFillModeSettingsScreen(
          currentMode: videoFillMode,
          onBack: () => onNavigate('Main'),
          onFillModeSelected: onVideoFillModeChanged,
        );
      case 'SkipConfig':
        return _SkipConfigSettingsScreen(
          playingInfoCache: playingInfoCache,
          currentPositionMillis: currentPositionMillis,
          totalDurationMillis: totalDurationMillis,
          onBack: () => onNavigate('Main'),
          onConfigChanged: onSkipConfigChanged,
          smartSkipEnabled: smartSkipEnabled,
          onSmartSkipEnabledChanged: onSmartSkipEnabledChanged,
          isSmartAnalysisGloballyEnabled: isSmartAnalysisGloballyEnabled,
          isSavingSkipConfig: isSavingSkipConfig,
          isFlyNarwhalServerAvailable: isFlyNarwhalServerAvailable,
          onFlyNarwhalConfigMissing: onFlyNarwhalConfigMissing,
        );
      default:
        return _MainSettingsScreen(
          playingInfoCache: playingInfoCache,
          iso6391Map: iso6391Map,
          iso6392Map: iso6392Map,
          smartSkipEnabled: smartSkipEnabled,
          isSmartAnalysisGloballyEnabled: isSmartAnalysisGloballyEnabled,
          isAutoPlay: isAutoPlay,
          onAutoPlayChanged: onAutoPlayChanged,
          windowAspectRatio: windowAspectRatio,
          videoFillMode: videoFillMode,
          onNavigateToAudio: () => onNavigate('Audio'),
          onNavigateToWindowAspectRatio: () => onNavigate('WindowAspectRatio'),
          onNavigateToVideoFillMode: () => onNavigate('VideoFillMode'),
          onNavigateToSkipConfig: () => onNavigate('SkipConfig'),
          onNavigateToAdvanced: () => onNavigate('Advanced'),
        );
    }
  }
}

class _MainSettingsScreen extends StatelessWidget {
  final PlayingInfoCache? playingInfoCache;
  final Map<String, String>? iso6391Map;
  final Map<String, String>? iso6392Map;
  final bool smartSkipEnabled;
  final bool isSmartAnalysisGloballyEnabled;
  final bool isAutoPlay;
  final void Function(bool)? onAutoPlayChanged;
  final String windowAspectRatio;
  final String videoFillMode;
  final VoidCallback onNavigateToAudio;
  final VoidCallback onNavigateToWindowAspectRatio;
  final VoidCallback onNavigateToVideoFillMode;
  final VoidCallback onNavigateToSkipConfig;
  final VoidCallback onNavigateToAdvanced;

  const _MainSettingsScreen({
    required this.playingInfoCache,
    required this.iso6391Map,
    required this.iso6392Map,
    required this.smartSkipEnabled,
    required this.isSmartAnalysisGloballyEnabled,
    required this.isAutoPlay,
    required this.onAutoPlayChanged,
    required this.windowAspectRatio,
    required this.videoFillMode,
    required this.onNavigateToAudio,
    required this.onNavigateToWindowAspectRatio,
    required this.onNavigateToVideoFillMode,
    required this.onNavigateToSkipConfig,
    required this.onNavigateToAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    final currentAudio = playingInfoCache?.currentAudioStream;
    final audioDisplayTexts =
        buildPlayerAudioDisplayTexts(currentAudio, iso6391Map, iso6392Map);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlayerSettingsHeader(
          title: '设置',
          actionLabel: '高级',
          onAction: onNavigateToAdvanced,
        ),
        const SizedBox(height: 8),
        PlayerSettingsToggleRow(
          key: const ValueKey('player-settings-autoplay-toggle'),
          title: '自动连播',
          checked: isAutoPlay,
          onChanged: onAutoPlayChanged,
        ),
        // Skip config for episodes
        if (playingInfoCache?.isEpisode == true ||
            MediaType.tryParse(playingInfoCache?.item?.type) ==
                MediaType.episode)
          _SettingsMenuItem(
            title: '跳过片头/片尾',
            value: _getSkipText(playingInfoCache?.playConfig),
            onClick: onNavigateToSkipConfig,
          ),
        _SettingsMenuItem(
          key: const ValueKey('player-settings-window-ratio'),
          title: '窗口比例',
          value: windowAspectRatio == 'AUTO' ? '跟随视频比例' : windowAspectRatio,
          onClick: onNavigateToWindowAspectRatio,
        ),
        _SettingsMenuItem(
          key: const ValueKey('player-settings-video-fill-mode'),
          title: '画面比例',
          value: videoFillMode == 'default' ? '默认' : videoFillMode,
          onClick: onNavigateToVideoFillMode,
        ),
        _SettingsMenuItem(
          key: const ValueKey('player-settings-audio'),
          title: '音频',
          value: audioDisplayTexts.summaryText,
          onClick: onNavigateToAudio,
        ),
      ],
    );
  }

  String _getSkipText(PlayConfig? config) {
    final skipOpening = config?.skipOpening ?? 0;
    final skipEnding = config?.skipEnding ?? 0;

    if (isSmartAnalysisGloballyEnabled && smartSkipEnabled) {
      return '智能跳过';
    }
    if (skipOpening > 0 && skipEnding > 0) {
      return '跳过片头片尾';
    }
    if (skipOpening > 0) {
      return '已设置片头';
    }
    if (skipEnding > 0) {
      return '已设置片尾';
    }
    return '未设置';
  }
}

class _AdvancedSettingsScreen extends StatelessWidget {
  final bool forceH264;
  final String? forceH264DisabledReason;
  final void Function(bool)? onForceH264Changed;
  final bool forceSdrColor;
  final String? forceSdrDisabledReason;
  final void Function(bool)? onForceSdrColorChanged;
  final VoidCallback onBack;

  const _AdvancedSettingsScreen({
    required this.forceH264,
    required this.forceH264DisabledReason,
    required this.onForceH264Changed,
    required this.forceSdrColor,
    required this.forceSdrDisabledReason,
    required this.onForceSdrColorChanged,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlayerSettingsHeader(title: '高级设置', onBack: onBack),
        const SizedBox(height: 8),
        PlayerSettingsToggleRow(
          key: const ValueKey('player-advanced-force-h264'),
          title: 'HEVC 转为 H.264',
          description: '播放有声音无画面时可尝试开启',
          checked: forceH264,
          onChanged: onForceH264Changed,
          disabledReason: forceH264DisabledReason,
        ),
        PlayerSettingsToggleRow(
          key: const ValueKey('player-advanced-force-sdr'),
          title: '色调强制映射为 SDR',
          description: '画面偏暗时可尝试开启，适用于不支持 HDR 的设备',
          checked: forceSdrColor,
          onChanged: onForceSdrColorChanged,
          disabledReason: forceSdrDisabledReason,
        ),
      ],
    );
  }
}

class _SettingsMenuItem extends StatefulWidget {
  final String title;
  final String? value;
  final VoidCallback onClick;

  const _SettingsMenuItem({
    super.key,
    required this.title,
    this.value,
    required this.onClick,
  });

  @override
  State<_SettingsMenuItem> createState() => _SettingsMenuItemState();
}

class _SettingsMenuItemState extends State<_SettingsMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onClick,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: _isHovered ? _hoverBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Text(
                widget.title,
                style: const TextStyle(color: _defaultTextColor, fontSize: 14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.value != null)
                        Flexible(
                          child: Text(
                            widget.value!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: _defaultTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      const Icon(
                        FluentIcons.chevron_right,
                        size: 16,
                        color: _defaultTextColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioSettingsScreen extends StatefulWidget {
  final PlayingInfoCache? playingInfoCache;
  final Map<String, String>? iso6391Map;
  final Map<String, String>? iso6392Map;
  final VoidCallback onBack;
  final void Function(AudioStream) onAudioSelected;

  const _AudioSettingsScreen({
    required this.playingInfoCache,
    required this.iso6391Map,
    required this.iso6392Map,
    required this.onBack,
    required this.onAudioSelected,
  });

  @override
  State<_AudioSettingsScreen> createState() => _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends State<_AudioSettingsScreen> {
  AudioStream? _selectedAudioStream;

  @override
  void initState() {
    super.initState();
    _selectedAudioStream = widget.playingInfoCache?.currentAudioStream;
  }

  @override
  void didUpdateWidget(covariant _AudioSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSelectedAudio = widget.playingInfoCache?.currentAudioStream;
    final previousSelectedAudio =
        oldWidget.playingInfoCache?.currentAudioStream;
    if (!_isSameAudioStream(previousSelectedAudio, nextSelectedAudio)) {
      _selectedAudioStream = nextSelectedAudio;
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioList = widget.playingInfoCache?.currentAudioStreamList ?? [];
    final currentAudioStream =
        _selectedAudioStream ?? widget.playingInfoCache?.currentAudioStream;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onBack,
            child: const Row(
              children: [
                Icon(
                  FluentIcons.chevron_left,
                  size: 16,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Text(
                  '音频',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 10),
        ...audioList.map((audio) {
          final isSelected = _isSameAudioStream(currentAudioStream, audio);
          final audioDisplayTexts = buildPlayerAudioDisplayTexts(
            audio,
            widget.iso6391Map,
            widget.iso6392Map,
          );

          return KeyedSubtree(
            key: ValueKey(
              audio.guid.isNotEmpty
                  ? 'player-audio-option-${audio.guid}'
                  : 'player-audio-option-index-${audio.index}',
            ),
            child: _AudioItem(
              primaryText: audioDisplayTexts.primaryText,
              secondaryLeadingText: audioDisplayTexts.secondaryLeadingText,
              secondaryTrailingText: audioDisplayTexts.secondaryTrailingText,
              isSelected: isSelected,
              onClick: () {
                // Update selection immediately before async state flows back.
                setState(() => _selectedAudioStream = audio);
                widget.onAudioSelected(audio);
              },
            ),
          );
        }),
      ],
    );
  }

  bool _isSameAudioStream(AudioStream? left, AudioStream? right) {
    if (left == null || right == null) {
      return false;
    }
    if (left.guid.isNotEmpty && right.guid.isNotEmpty) {
      return left.guid == right.guid;
    }
    return left.index == right.index;
  }
}

class _AudioItem extends StatefulWidget {
  final String primaryText;
  final String secondaryLeadingText;
  final String secondaryTrailingText;
  final bool isSelected;
  final VoidCallback onClick;

  const _AudioItem({
    required this.primaryText,
    required this.secondaryLeadingText,
    required this.secondaryTrailingText,
    required this.isSelected,
    required this.onClick,
  });

  @override
  State<_AudioItem> createState() => _AudioItemState();
}

class _AudioItemState extends State<_AudioItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textColor =
        widget.isSelected ? _selectedTextColor : _defaultTextColor;
    final secondaryOpacity = widget.isSelected ? 1.0 : 0.82;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onClick,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: _isHovered || widget.isSelected
                ? _hoverBackgroundColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.primaryText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (widget.secondaryLeadingText.isNotEmpty)
                    Flexible(
                      flex: 3,
                      child: Text(
                        widget.secondaryLeadingText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor.withValues(alpha: secondaryOpacity),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (widget.secondaryLeadingText.isNotEmpty &&
                      widget.secondaryTrailingText.isNotEmpty)
                    const SizedBox(width: 16),
                  if (widget.secondaryTrailingText.isNotEmpty)
                    Flexible(
                      flex: 5,
                      child: Text(
                        widget.secondaryTrailingText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor.withValues(alpha: secondaryOpacity),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowAspectRatioSettingsScreen extends StatelessWidget {
  final String currentRatio;
  final VoidCallback onBack;
  final void Function(String) onAspectRatioSelected;

  const _WindowAspectRatioSettingsScreen({
    required this.currentRatio,
    required this.onBack,
    required this.onAspectRatioSelected,
  });

  @override
  Widget build(BuildContext context) {
    const options = ['AUTO', '4:3', '16:9', '21:9'];
    const optionLabels = {
      'AUTO': '跟随视频比例',
      '4:3': '4:3',
      '16:9': '16:9',
      '21:9': '21:9',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onBack,
            child: const Row(
              children: [
                Icon(
                  FluentIcons.chevron_left,
                  size: 16,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Text(
                  '窗口比例',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        ...options.map((option) {
          final label = optionLabels[option] ?? option;
          return _AspectRatioItem(
            key: ValueKey('player-window-ratio-$option'),
            label: label,
            isSelected: option == currentRatio,
            onClick: () => onAspectRatioSelected(option),
          );
        }),
      ],
    );
  }
}

class _VideoFillModeSettingsScreen extends StatelessWidget {
  final String currentMode;
  final VoidCallback onBack;
  final void Function(String) onFillModeSelected;

  const _VideoFillModeSettingsScreen({
    required this.currentMode,
    required this.onBack,
    required this.onFillModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    const options = ['default', '4:3', '16:9', '21:9'];
    const optionLabels = {
      'default': '默认',
      '4:3': '4:3',
      '16:9': '16:9',
      '21:9': '21:9',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onBack,
            child: const Row(
              children: [
                Icon(
                  FluentIcons.chevron_left,
                  size: 16,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Text(
                  '画面比例',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        ...options.map((option) {
          final label = optionLabels[option] ?? option;
          return _AspectRatioItem(
            key: ValueKey('player-video-fill-mode-$option'),
            label: label,
            isSelected: option == currentMode,
            onClick: () => onFillModeSelected(option),
          );
        }),
      ],
    );
  }
}

class _AspectRatioItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onClick;

  const _AspectRatioItem({
    super.key,
    required this.label,
    this.isSelected = false,
    required this.onClick,
  });

  @override
  State<_AspectRatioItem> createState() => _AspectRatioItemState();
}

class _AspectRatioItemState extends State<_AspectRatioItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textColor =
        widget.isSelected ? _selectedTextColor : _defaultTextColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onClick,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: _isHovered ? _hoverBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.isSelected)
                const Icon(
                  FluentIcons.check_mark,
                  size: 16,
                  color: _selectedTextColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkipConfigSettingsScreen extends StatefulWidget {
  final PlayingInfoCache? playingInfoCache;
  final int currentPositionMillis;
  final int totalDurationMillis;
  final VoidCallback onBack;
  final void Function(int, int) onConfigChanged;
  final bool smartSkipEnabled;
  final void Function(bool)? onSmartSkipEnabledChanged;
  final bool isSmartAnalysisGloballyEnabled;
  final bool isSavingSkipConfig;
  // Whether the FlyNarwhal server is fully configured (URL + auth code)
  final bool isFlyNarwhalServerAvailable;
  // Called when user tries to enable smart skip without full config
  final VoidCallback? onFlyNarwhalConfigMissing;

  const _SkipConfigSettingsScreen({
    required this.playingInfoCache,
    required this.currentPositionMillis,
    required this.totalDurationMillis,
    required this.onBack,
    required this.onConfigChanged,
    required this.smartSkipEnabled,
    required this.onSmartSkipEnabledChanged,
    required this.isSmartAnalysisGloballyEnabled,
    required this.isSavingSkipConfig,
    required this.isFlyNarwhalServerAvailable,
    required this.onFlyNarwhalConfigMissing,
  });

  @override
  State<_SkipConfigSettingsScreen> createState() =>
      _SkipConfigSettingsScreenState();
}

class _SkipConfigSettingsScreenState extends State<_SkipConfigSettingsScreen> {
  late int _skipOpening;
  late int _skipEnding;
  late bool _smartSkipEnabled;

  @override
  void initState() {
    super.initState();
    _skipOpening = widget.playingInfoCache?.playConfig?.skipOpening ?? 0;
    _skipEnding = widget.playingInfoCache?.playConfig?.skipEnding ?? 0;
    _smartSkipEnabled = widget.smartSkipEnabled;
  }

  @override
  void didUpdateWidget(covariant _SkipConfigSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.smartSkipEnabled != widget.smartSkipEnabled) {
      _smartSkipEnabled = widget.smartSkipEnabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final manualEnabled = !widget.isSavingSkipConfig &&
        (!widget.isSmartAnalysisGloballyEnabled || !_smartSkipEnabled);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onBack,
                child: const Row(
                  children: [
                    Icon(
                      FluentIcons.chevron_left,
                      size: 16,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '跳过片头/片尾',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Reset button
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: manualEnabled
                    ? () {
                        setState(() {
                          _skipOpening = 0;
                          _skipEnding = 0;
                        });
                        widget.onConfigChanged(0, 0);
                      }
                    : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: manualEnabled
                          ? _defaultTextColor
                          : _defaultTextColor.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    '重置',
                    style: TextStyle(
                      color: manualEnabled
                          ? _defaultTextColor
                          : _defaultTextColor.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '生效范围: ${widget.playingInfoCache?.item?.tvTitle ?? '未知'} 第 ${widget.playingInfoCache?.item?.seasonNumber ?? 0} 季',
          style: const TextStyle(color: _defaultTextColor, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (widget.isSmartAnalysisGloballyEnabled)
          PlayerSettingsToggleRow(
            key: const ValueKey('player-settings-smart-skip-toggle'),
            title: '智能跳过片头/片尾',
            checked: _smartSkipEnabled,
            onChanged: widget.isSavingSkipConfig ||
                    widget.onSmartSkipEnabledChanged == null
                ? null
                : (value) {
                    // Guard: block enabling smart skip when config is incomplete
                    if (value && !widget.isFlyNarwhalServerAvailable) {
                      widget.onFlyNarwhalConfigMissing?.call();
                      return;
                    }
                    setState(() => _smartSkipEnabled = value);
                    widget.onSmartSkipEnabledChanged?.call(value);
                  },
          ),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),
        // Skip opening
        _SkipSlider(
          label: '跳过片头',
          value: _skipOpening.toDouble(),
          maxValue: 600,
          enabled: manualEnabled,
          currentPositionSeconds: widget.currentPositionMillis ~/ 1000,
          isReverse: false,
          onChanged: (value) {
            setState(() => _skipOpening = value.round());
          },
          onChangeEnd: (value) {
            widget.onConfigChanged(_skipOpening, _skipEnding);
          },
        ),
        const SizedBox(height: 16),
        // Skip ending
        _SkipSlider(
          label: '跳过片尾',
          value: _skipEnding.toDouble(),
          maxValue: 600,
          enabled: manualEnabled,
          currentPositionSeconds: widget.currentPositionMillis ~/ 1000,
          totalDurationSeconds: widget.totalDurationMillis ~/ 1000,
          isReverse: true,
          onChanged: (value) {
            setState(() => _skipEnding = value.round());
          },
          onChangeEnd: (value) {
            widget.onConfigChanged(_skipOpening, _skipEnding);
          },
        ),
      ],
    );
  }
}

class _SkipSlider extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final bool enabled;
  final int currentPositionSeconds;
  final int totalDurationSeconds;
  final bool isReverse;
  final void Function(double) onChanged;
  final void Function(double) onChangeEnd;

  const _SkipSlider({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.enabled,
    required this.currentPositionSeconds,
    this.totalDurationSeconds = 0,
    required this.isReverse,
    required this.onChanged,
    required this.onChangeEnd,
  });

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: _defaultTextColor, fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(_formatDuration(value.round()),
                      style: const TextStyle(
                          color: _defaultTextColor, fontSize: 14)),
                ],
              ),
              if (!isReverse && currentPositionSeconds <= maxValue.toInt())
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: enabled
                        ? () {
                            onChanged(currentPositionSeconds.toDouble());
                            onChangeEnd(currentPositionSeconds.toDouble());
                          }
                        : null,
                    child: Text(
                      '将当前时间 ${_formatDuration(currentPositionSeconds)} 设为片头',
                      style: const TextStyle(
                          color: _selectedTextColor, fontSize: 12),
                    ),
                  ),
                ),
              if (isReverse &&
                  totalDurationSeconds > currentPositionSeconds) ...[
                Builder(builder: (context) {
                  final remaining =
                      totalDurationSeconds - currentPositionSeconds;
                  if (remaining > maxValue.toInt()) {
                    return const SizedBox.shrink();
                  }
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: enabled
                          ? () {
                              onChanged(remaining.toDouble());
                              onChangeEnd(remaining.toDouble());
                            }
                          : null,
                      child: Text(
                        '将剩余时长 ${_formatDuration(remaining)} 设为片尾',
                        style: const TextStyle(
                            color: _selectedTextColor, fontSize: 12),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            max: maxValue,
            onChanged: enabled ? onChanged : null,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}
