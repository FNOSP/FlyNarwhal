import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/media_type.dart';
import '../../../../data/utils/fn_data_convertor.dart';
import '../../../../data/models/player_models.dart';
import '../../../../data/models/movie_detail_models.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../providers/providers.dart';
import '../../../../tooling/driver_test_mode.dart';
import '../../../shared/tip_box.dart';
import '../models/resolved_skip_segments.dart';
import 'player_action_button.dart';
import 'player_settings_components.dart';

const Color _flyoutBackgroundColor = Color(0xCC000000);
const Color _flyoutBorderColor = Color(0x80808080);
const Color _selectedTextColor = Color(0xFF2073DF);
const Color _defaultTextColor = Color(0xC8FFFFFF);
const Color _hoverBackgroundColor = Color(0x1AFFFFFF);
const int _hideDelayMs = 200;
const int _animationDurationMs = 200;
// Keep these in sync: the flyout is horizontally centered on the settings
// button, so the left offset must be -(_settingsFlyoutWidth / 2).
const double _settingsFlyoutLeftOffset = -170;
const double _settingsFlyoutBridgeOffset = 40;
const double _settingsFlyoutWidth = 330;
const double _settingsFlyoutMinBridgeWidth = 56;
const double _settingsFlyoutBridgeHorizontalPadding = 12;
const double _estimatedSettingsFlyoutHeight = 300;
// Keep the audio flyout no taller than the subtitle selection panel; the
// track list scrolls once its items exceed the remaining space.
const double _audioPanelHeaderHeight = 46;
const double _audioPanelMaxListHeight = 330;

// Skip intro/outro panel palette and metrics, mirroring the web player's
// manual skip settings (semi-design dark theme).
const Color _skipTrackColor = Color(0x1FFFFFFF); // rgba(255,255,255,0.12)
const Color _skipActiveColor = Color(0xFF0066FF);
const Color _skipInputBorderColor = Color(0x1AFFFFFF); // rgba(255,255,255,0.1)
const Color _skipInputFillColor = Color(0x1A010101); // rgba(1,1,1,0.1)
const Color _skipCaptionColor = Color(0x99FFFFFF); // rgba(255,255,255,0.6)
const double _skipThumbSize = 14;
const double _skipSliderHeight = 20;
const double _skipTimeInputWidth = 50;
const double _skipTimeInputHeight = 28;

// A hardware decoder API that mpv probed as usable for the current file,
// shown in the 指定硬件解码器 sub-menu. [api] is the value passed to
// `hwdec=...`; [label] is its human-readable name.
class HwdecOption {
  final String api;
  final String label;

  const HwdecOption({required this.api, required this.label});
}

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
  Map<String, String>? iso6392Map, {
  String unknownLabel = '',
  String defaultSuffixTemplate = '{language}',
}) {
  if (audio == null) {
    final unknownTexts = PlayerAudioDisplayTexts(
      summaryText: unknownLabel,
      primaryText: unknownLabel,
      secondaryLeadingText: '',
      secondaryTrailingText: '',
    );
    return unknownTexts;
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
  final primaryText = audio.isDefault == 1
      ? defaultSuffixTemplate.replaceFirst('{language}', languageName)
      : languageName;

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

// Chinese label for a decode mode value. Values are the mpv hwdec options
// "auto" / "no" / "auto-copy" plus a concrete hardware-decoder API name chosen
// from the probed list (e.g. "videotoolbox"). `availableHwdec` maps an api to
// its display label so a concrete selection renders its friendly name.
String decodeModeLabel(
  AppLocalizations l10n,
  String mode,
  List<HwdecOption> availableHwdec,
) {
  switch (mode) {
    case 'no':
      return l10n.playerSettingsSoftwareDecode;
    case 'auto-copy':
      return l10n.playerSettingsCopyBackMode;
    case 'auto':
      return l10n.playerSettingsAuto;
    default:
      for (final option in availableHwdec) {
        if (option.api == mode) {
          return option.label;
        }
      }
      return mode;
  }
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
  final Future<bool> Function(bool enabled)? onSmartSkipEnabledChanged;
  final bool isSmartAnalysisGloballyEnabled;

  /// Whether the server exposes the smart-skip config endpoint. Servers below
  /// 0.7.0 analyze segments but have no config API, so the entry stays hidden
  /// there while smart skip itself remains usable.
  final bool isSmartSkipConfigAvailable;
  final bool isSavingSkipConfig;
  final bool isAutoPlay;
  final void Function(bool enabled)? onAutoPlayChanged;
  final bool forceH264;
  final void Function(bool enabled)? onForceH264Changed;
  final String? forceH264DisabledReason;
  final bool forceSdrColor;
  final void Function(bool enabled)? onForceSdrColorChanged;
  final String? forceSdrDisabledReason;

  /// Quark netdisk direct-play transport: on routes the raw CDN link through the
  /// local range proxy (分片直连), off lets mpv open the NAS /media/range link.
  final bool directLinkCdnRange;
  final void Function(bool enabled)? onDirectLinkCdnRangeChanged;
  final String? directLinkCdnRangeDisabledReason;
  // Current decode mode: 'auto' | 'no' | 'auto-copy' | '<api>'.
  final String decodeMode;
  final void Function(String) onDecodeModeChanged;
  // Hardware decoder APIs probed as usable, shown in 指定硬件解码器 sub-menu.
  final List<HwdecOption> availableHwdec;
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
    this.isSmartSkipConfigAvailable = false,
    this.isSavingSkipConfig = false,
    this.isAutoPlay = true,
    this.onAutoPlayChanged,
    this.forceH264 = false,
    this.onForceH264Changed,
    this.forceH264DisabledReason,
    this.forceSdrColor = false,
    this.onForceSdrColorChanged,
    this.forceSdrDisabledReason,
    this.directLinkCdnRange = true,
    this.onDirectLinkCdnRangeChanged,
    this.directLinkCdnRangeDisabledReason,
    this.decodeMode = 'auto',
    required this.onDecodeModeChanged,
    this.availableHwdec = const [],
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
  double? _mainSettingsMeasuredHeight;
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
        oldWidget.decodeMode != widget.decodeMode ||
        oldWidget.forceH264DisabledReason != widget.forceH264DisabledReason ||
        oldWidget.forceSdrDisabledReason != widget.forceSdrDisabledReason ||
        autoPlayChanged) {
      _requestOverlayRebuild();
    }
    // The skip-settings shortcut buttons display the live playback position,
    // so keep the open flyout in sync with position ticks.
    if (_currentScreen == 'SkipConfig' &&
        (oldWidget.currentPositionMillis != widget.currentPositionMillis ||
            oldWidget.totalDurationMillis != widget.totalDurationMillis)) {
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
        minContentHeight: _mainSettingsMeasuredHeight,
        onMainSettingsHeightMeasured: (height) {
          if (_mainSettingsMeasuredHeight != height) {
            setState(() => _mainSettingsMeasuredHeight = height);
            _requestOverlayRebuild();
          }
        },
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
        isSmartSkipConfigAvailable: widget.isSmartSkipConfigAvailable,
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
        directLinkCdnRange: widget.directLinkCdnRange,
        onDirectLinkCdnRangeChanged: (value) {
          _setPopupHovered(false);
          widget.onDirectLinkCdnRangeChanged?.call(value);
          _closeMenu();
        },
        directLinkCdnRangeDisabledReason:
            widget.directLinkCdnRangeDisabledReason,
        decodeMode: widget.decodeMode,
        onDecodeModeChanged: (mode) {
          _setPopupHovered(false);
          widget.onDecodeModeChanged(mode);
          _closeMenu();
        },
        availableHwdec: widget.availableHwdec,
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
  final double? minContentHeight;
  final void Function(double)? onMainSettingsHeightMeasured;
  final void Function(String) onNavigate;
  final void Function(AudioStream) onAudioSelected;
  final String windowAspectRatio;
  final void Function(String) onWindowAspectRatioChanged;
  final String videoFillMode;
  final void Function(String) onVideoFillModeChanged;
  final void Function(int, int) onSkipConfigChanged;
  final bool smartSkipEnabled;
  final Future<bool> Function(bool)? onSmartSkipEnabledChanged;
  final bool isSmartAnalysisGloballyEnabled;

  /// Whether the server exposes the smart-skip config endpoint (>= 0.7.0).
  final bool isSmartSkipConfigAvailable;
  final bool isSavingSkipConfig;
  final bool isAutoPlay;
  final void Function(bool)? onAutoPlayChanged;
  final bool forceH264;
  final void Function(bool)? onForceH264Changed;
  final String? forceH264DisabledReason;
  final bool forceSdrColor;
  final void Function(bool)? onForceSdrColorChanged;
  final String? forceSdrDisabledReason;
  final bool directLinkCdnRange;
  final void Function(bool)? onDirectLinkCdnRangeChanged;
  final String? directLinkCdnRangeDisabledReason;
  final String decodeMode;
  final void Function(String) onDecodeModeChanged;
  final List<HwdecOption> availableHwdec;
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
    required this.minContentHeight,
    required this.onMainSettingsHeightMeasured,
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
    required this.directLinkCdnRange,
    required this.onDirectLinkCdnRangeChanged,
    required this.directLinkCdnRangeDisabledReason,
    required this.decodeMode,
    required this.onDecodeModeChanged,
    required this.availableHwdec,
    required this.isFlyNarwhalServerAvailable,
    required this.onFlyNarwhalConfigMissing,
    required this.isSmartSkipConfigAvailable,
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
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: minContentHeight ?? 0,
          ),
          child: _buildCurrentScreen(),
        ),
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
          directLinkCdnRange: directLinkCdnRange,
          directLinkCdnRangeDisabledReason: directLinkCdnRangeDisabledReason,
          onDirectLinkCdnRangeChanged: onDirectLinkCdnRangeChanged,
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
      case 'DecodeMode':
        return _DecodeModeSettingsScreen(
          currentMode: decodeMode,
          availableHwdec: availableHwdec,
          onBack: () => onNavigate('Main'),
          onDecodeModeSelected: onDecodeModeChanged,
          onNavigateToSpecify: () => onNavigate('DecodeApi'),
        );
      case 'DecodeApi':
        return _SpecifyDecodeScreen(
          currentApi: decodeMode,
          availableHwdec: availableHwdec,
          onBack: () => onNavigate('DecodeMode'),
          onApiSelected: onDecodeModeChanged,
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
          isSmartSkipConfigAvailable: isSmartSkipConfigAvailable,
          isSavingSkipConfig: isSavingSkipConfig,
          isFlyNarwhalServerAvailable: isFlyNarwhalServerAvailable,
          onFlyNarwhalConfigMissing: onFlyNarwhalConfigMissing,
          onNavigateToSmartSkipConfig: () => onNavigate('SmartSkipConfig'),
        );
      case 'SmartSkipConfig':
        return _SmartSkipConfigSettingsScreen(
          onBack: () => onNavigate('SkipConfig'),
        );
      default:
        return MeasureSize(
          onChange: (size) => onMainSettingsHeightMeasured?.call(size.height),
          child: _MainSettingsScreen(
            playingInfoCache: playingInfoCache,
            iso6391Map: iso6391Map,
            iso6392Map: iso6392Map,
            smartSkipEnabled: smartSkipEnabled,
            isSmartAnalysisGloballyEnabled: isSmartAnalysisGloballyEnabled,
            isAutoPlay: isAutoPlay,
            onAutoPlayChanged: onAutoPlayChanged,
            windowAspectRatio: windowAspectRatio,
            videoFillMode: videoFillMode,
            decodeMode: decodeMode,
            availableHwdec: availableHwdec,
            onNavigateToAudio: () => onNavigate('Audio'),
            onNavigateToWindowAspectRatio: () =>
                onNavigate('WindowAspectRatio'),
            onNavigateToVideoFillMode: () => onNavigate('VideoFillMode'),
            onNavigateToDecodeMode: () => onNavigate('DecodeMode'),
            onNavigateToSkipConfig: () => onNavigate('SkipConfig'),
            onNavigateToAdvanced: () => onNavigate('Advanced'),
          ),
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
  final String decodeMode;
  final List<HwdecOption> availableHwdec;
  final VoidCallback onNavigateToAudio;
  final VoidCallback onNavigateToWindowAspectRatio;
  final VoidCallback onNavigateToVideoFillMode;
  final VoidCallback onNavigateToDecodeMode;
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
    required this.decodeMode,
    required this.availableHwdec,
    required this.onNavigateToAudio,
    required this.onNavigateToWindowAspectRatio,
    required this.onNavigateToVideoFillMode,
    required this.onNavigateToDecodeMode,
    required this.onNavigateToSkipConfig,
    required this.onNavigateToAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentAudio = playingInfoCache?.currentAudioStream;
    final audioDisplayTexts = buildPlayerAudioDisplayTexts(
      currentAudio,
      iso6391Map,
      iso6392Map,
      unknownLabel: l10n.playerUnknown,
      defaultSuffixTemplate: l10n.playerAudioDefaultSuffix('{language}'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlayerSettingsHeader(
          title: l10n.settingsTitle,
          actionLabel: l10n.playerSettingsAdvanced,
          onAction: onNavigateToAdvanced,
        ),
        const SizedBox(height: 8),
        PlayerSettingsToggleRow(
          key: const ValueKey('player-settings-autoplay-toggle'),
          title: l10n.playerSettingsAutoNext,
          checked: isAutoPlay,
          onChanged: onAutoPlayChanged,
        ),
        // Skip config for episodes
        if (playingInfoCache?.isEpisode == true ||
            MediaType.tryParse(playingInfoCache?.item?.type) ==
                MediaType.episode)
          _SettingsMenuItem(
            key: const ValueKey('player-settings-skip-config'),
            title: l10n.playerSettingsSkipIntroOutro,
            value: _getSkipText(l10n, playingInfoCache?.playConfig),
            onClick: onNavigateToSkipConfig,
          ),
        _SettingsMenuItem(
          key: const ValueKey('player-settings-window-ratio'),
          title: l10n.playerSettingsWindowRatio,
          value: windowAspectRatio == 'AUTO'
              ? l10n.playerSettingsWindowAspectRatioFollowVideo
              : windowAspectRatio,
          onClick: onNavigateToWindowAspectRatio,
        ),
        _SettingsMenuItem(
          key: const ValueKey('player-settings-video-fill-mode'),
          title: l10n.playerSettingsAspectRatio,
          value: videoFillMode == 'default'
              ? l10n.playerSettingsAspectRatioDefault
              : videoFillMode,
          onClick: onNavigateToVideoFillMode,
        ),
        _SettingsMenuItem(
          key: const ValueKey('player-settings-decode-mode'),
          title: l10n.playerSettingsClientDecodeMode,
          value: decodeModeLabel(l10n, decodeMode, availableHwdec),
          onClick: onNavigateToDecodeMode,
        ),
        _SettingsMenuItem(
          key: const ValueKey('player-settings-audio'),
          title: l10n.playerSettingsAudio,
          value: audioDisplayTexts.summaryText,
          onClick: onNavigateToAudio,
        ),
      ],
    );
  }

  String _getSkipText(AppLocalizations l10n, PlayConfig? config) {
    final skipOpening = config?.skipOpening ?? 0;
    final skipEnding = config?.skipEnding ?? 0;

    if (isSmartAnalysisGloballyEnabled && smartSkipEnabled) {
      return l10n.playerSettingsSmartSkip;
    }
    if (skipOpening > 0 && skipEnding > 0) {
      return l10n.playerSettingsSkipIntroOutroBoth;
    }
    if (skipOpening > 0) {
      return l10n.playerSettingsIntroConfigured;
    }
    if (skipEnding > 0) {
      return l10n.playerSettingsOutroConfigured;
    }
    return l10n.playerSettingsNotSet;
  }
}

class _AdvancedSettingsScreen extends StatelessWidget {
  final bool forceH264;
  final String? forceH264DisabledReason;
  final void Function(bool)? onForceH264Changed;
  final bool forceSdrColor;
  final String? forceSdrDisabledReason;
  final void Function(bool)? onForceSdrColorChanged;
  final bool directLinkCdnRange;
  final String? directLinkCdnRangeDisabledReason;
  final void Function(bool)? onDirectLinkCdnRangeChanged;
  final VoidCallback onBack;

  const _AdvancedSettingsScreen({
    required this.forceH264,
    required this.forceH264DisabledReason,
    required this.onForceH264Changed,
    required this.forceSdrColor,
    required this.forceSdrDisabledReason,
    required this.onForceSdrColorChanged,
    required this.directLinkCdnRange,
    required this.directLinkCdnRangeDisabledReason,
    required this.onDirectLinkCdnRangeChanged,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlayerSettingsHeader(
          title: l10n.playerSettingsAdvancedTitle,
          onBack: onBack,
        ),
        const SizedBox(height: 8),
        PlayerSettingsToggleRow(
          key: const ValueKey('player-advanced-force-h264'),
          title: l10n.playerSettingsHevcToH264,
          description: l10n.playerSettingsHevcToH264Description,
          checked: forceH264,
          onChanged: onForceH264Changed,
          disabledReason: forceH264DisabledReason,
        ),
        PlayerSettingsToggleRow(
          key: const ValueKey('player-advanced-force-sdr'),
          title: l10n.playerSettingsForceSdr,
          description: l10n.playerSettingsForceSdrDescription,
          checked: forceSdrColor,
          onChanged: onForceSdrColorChanged,
          disabledReason: forceSdrDisabledReason,
        ),
        PlayerSettingsToggleRow(
          key: const ValueKey('player-advanced-direct-link-cdn-range'),
          title: l10n.playerSettingsQuarkCdnSegment,
          description: l10n.playerSettingsQuarkCdnSegmentDescription,
          checked: directLinkCdnRange,
          onChanged: onDirectLinkCdnRangeChanged,
          disabledReason: directLinkCdnRangeDisabledReason,
        ),
      ],
    );
  }
}

class _SettingsMenuItem extends StatefulWidget {
  final String title;
  final String? value;

  /// When null the row renders disabled (greyed out, no hover, no tap).
  /// Used e.g. for 指定硬件解码器 when no hardware decoder was probed.
  final VoidCallback? onClick;

  const _SettingsMenuItem({
    super.key,
    required this.title,
    this.value,
    this.onClick,
  });

  @override
  State<_SettingsMenuItem> createState() => _SettingsMenuItemState();
}

class _SettingsMenuItemState extends State<_SettingsMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onClick != null;
    final textColor =
        enabled ? _defaultTextColor : _defaultTextColor.withValues(alpha: 0.4);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: enabled ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTap: widget.onClick,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: _isHovered && enabled
                ? _hoverBackgroundColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Text(
                widget.title,
                style: TextStyle(color: textColor, fontSize: 14),
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
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        FluentIcons.chevron_right,
                        size: 12,
                        color: textColor,
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
  final ScrollController _scrollController = ScrollController();

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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final audioList = widget.playingInfoCache?.currentAudioStreamList ?? [];
    final currentAudioStream =
        _selectedAudioStream ?? widget.playingInfoCache?.currentAudioStream;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _audioPanelHeaderHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onBack,
                  child: Row(
                    children: [
                      const Icon(
                        FluentIcons.chevron_left,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.playerSettingsAudio,
                        style: const TextStyle(
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
            ],
          ),
        ),
        ConstrainedBox(
          constraints:
              const BoxConstraints(maxHeight: _audioPanelMaxListHeight),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: ListView(
              key: const ValueKey('player-audio-list'),
              controller: _scrollController,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                ...audioList.map((audio) {
                  final isSelected =
                      _isSameAudioStream(currentAudioStream, audio);
                  final audioDisplayTexts = buildPlayerAudioDisplayTexts(
                    audio,
                    widget.iso6391Map,
                    widget.iso6392Map,
                    unknownLabel: l10n.playerUnknown,
                    defaultSuffixTemplate:
                        l10n.playerAudioDefaultSuffix('{language}'),
                  );

                  return KeyedSubtree(
                    key: ValueKey(
                      audio.guid.isNotEmpty
                          ? 'player-audio-option-${audio.guid}'
                          : 'player-audio-option-index-${audio.index}',
                    ),
                    child: _AudioItem(
                      primaryText: audioDisplayTexts.primaryText,
                      secondaryLeadingText:
                          audioDisplayTexts.secondaryLeadingText,
                      secondaryTrailingText:
                          audioDisplayTexts.secondaryTrailingText,
                      isSelected: isSelected,
                      onClick: () {
                        // Update selection immediately before async state
                        // flows back.
                        setState(() => _selectedAudioStream = audio);
                        widget.onAudioSelected(audio);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
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
    final l10n = AppLocalizations.of(context);
    const options = ['AUTO', '4:3', '16:9', '21:9'];
    final optionLabels = {
      'AUTO': l10n.playerSettingsWindowAspectRatioFollowVideo,
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
            child: Row(
              children: [
                const Icon(
                  FluentIcons.chevron_left,
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.playerSettingsWindowRatio,
                  style: const TextStyle(
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
    final l10n = AppLocalizations.of(context);
    const options = ['default', '4:3', '16:9', '21:9'];
    final optionLabels = {
      'default': l10n.playerSettingsAspectRatioDefault,
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
            child: Row(
              children: [
                const Icon(
                  FluentIcons.chevron_left,
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.playerSettingsAspectRatio,
                  style: const TextStyle(
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

class _DecodeModeSettingsScreen extends StatelessWidget {
  final String currentMode;
  final List<HwdecOption> availableHwdec;
  final VoidCallback onBack;
  final void Function(String) onDecodeModeSelected;
  final VoidCallback onNavigateToSpecify;

  const _DecodeModeSettingsScreen({
    required this.currentMode,
    required this.availableHwdec,
    required this.onBack,
    required this.onDecodeModeSelected,
    required this.onNavigateToSpecify,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 回拷模式暂时不展示在菜单里,保留映射以便日后恢复。
    const baseOptions = ['auto', 'no' /* , 'auto-copy' */];
    final optionLabels = {
      'auto': l10n.playerSettingsAuto,
      'no': l10n.playerSettingsSoftwareDecode,
      'auto-copy': l10n.playerSettingsCopyBackMode,
    };
    final optionTips = {
      'auto': l10n.playerSettingsDecodeAutoTip,
      'no': l10n.playerSettingsDecodeSoftwareTip,
      'auto-copy': l10n.playerSettingsDecodeCopyTip,
    };
    // A concrete hardware-decoder API from the probed list is stored in
    // decodeMode when 指定硬件解码器 is active.
    final isSpecifySelected = currentMode != 'auto' &&
        currentMode != 'no' &&
        currentMode != 'auto-copy' &&
        currentMode != 'auto-unsafe';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onBack,
            child: Row(
              children: [
                const Icon(
                  FluentIcons.chevron_left,
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.playerSettingsClientDecodeMode,
                  style: const TextStyle(
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
        // Base modes: 自动 / 软件解码(回拷模式暂不展示).
        ...baseOptions.map((option) {
          final label = optionLabels[option] ?? option;
          // Show a tips box briefly explaining the decode mode on hover.
          return TipBox(
            message: optionTips[option] ?? label,
            // Anchor to the option row instead of the cursor, and float the
            // tips box above it so the hovered option stays visible.
            // verticalOffset is measured from the row center, so it must
            // exceed half the row height (~18) to clear the row entirely.
            verticalOffset: 28,
            child: _AspectRatioItem(
              key: ValueKey('player-decode-mode-$option'),
              label: label,
              isSelected: option == currentMode,
              onClick: () => onDecodeModeSelected(option),
            ),
          );
        }),
        // 指定硬件解码器 opens a third-level list of probed APIs. It follows
        // the "entry into a sub-menu" style (selected value + chevron); the
        // value only shows the decoder picked inside that sub-menu and stays
        // empty otherwise. Greyed out when no hardware decoder was probed.
        _SettingsMenuItem(
          key: const ValueKey('player-decode-mode-specify'),
          title: l10n.playerSettingsSpecifyHwdec,
          value: isSpecifySelected
              ? decodeModeLabel(l10n, currentMode, availableHwdec)
              : null,
          onClick: availableHwdec.isEmpty ? null : onNavigateToSpecify,
        ),
      ],
    );
  }
}

class _SpecifyDecodeScreen extends StatelessWidget {
  final String currentApi;
  final List<HwdecOption> availableHwdec;
  final VoidCallback onBack;
  final void Function(String) onApiSelected;

  const _SpecifyDecodeScreen({
    required this.currentApi,
    required this.availableHwdec,
    required this.onBack,
    required this.onApiSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onBack,
            child: Row(
              children: [
                const Icon(
                  FluentIcons.chevron_left,
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.playerSettingsSpecifyHwdec,
                  style: const TextStyle(
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
        if (availableHwdec.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              l10n.playerSettingsNoHwdecAvailable,
              style: const TextStyle(color: _defaultTextColor, fontSize: 14),
            ),
          )
        else
          ...availableHwdec.map((option) {
            return _AspectRatioItem(
              key: ValueKey('player-decode-api-${option.api}'),
              label: option.label,
              isSelected: option.api == currentApi,
              onClick: () => onApiSelected(option.api),
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
  final Future<bool> Function(bool)? onSmartSkipEnabledChanged;
  final bool isSmartAnalysisGloballyEnabled;
  final bool isSavingSkipConfig;
  // Whether the FlyNarwhal server is fully configured (URL + auth code)
  final bool isFlyNarwhalServerAvailable;
  // Called when user tries to enable smart skip without full config
  final VoidCallback? onFlyNarwhalConfigMissing;
  // Whether the server exposes the smart-skip config endpoint (>= 0.7.0).
  final bool isSmartSkipConfigAvailable;
  // Opens the server-side smart skip analysis configuration screen.
  final VoidCallback? onNavigateToSmartSkipConfig;

  const _SkipConfigSettingsScreen({
    required this.playingInfoCache,
    required this.currentPositionMillis,
    required this.totalDurationMillis,
    required this.onBack,
    required this.onConfigChanged,
    required this.smartSkipEnabled,
    required this.onSmartSkipEnabledChanged,
    required this.isSmartAnalysisGloballyEnabled,
    required this.isSmartSkipConfigAvailable,
    required this.isSavingSkipConfig,
    required this.isFlyNarwhalServerAvailable,
    required this.onFlyNarwhalConfigMissing,
    this.onNavigateToSmartSkipConfig,
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

  // Mirrors the web player's skip-settings shortcut: the opening button's
  // visibility is gated on floor(current) within (0, 600] while its value
  // rounds the current position up; the ending button shows the floored
  // remaining time and hides once that leaves (0, 600].
  int get _currentSecondsFloor => widget.currentPositionMillis ~/ 1000;

  int get _currentSecondsCeil => (widget.currentPositionMillis + 999) ~/ 1000;

  int get _remainingSeconds {
    final remaining = widget.totalDurationMillis - widget.currentPositionMillis;
    final seconds = (remaining < 0 ? 0 : remaining) ~/ 1000;
    return seconds;
  }

  bool _isValidShortcutSeconds(int seconds) => seconds > 0 && seconds <= 600;

  bool get _openingShortcutVisible =>
      _isValidShortcutSeconds(_currentSecondsFloor);

  int get _openingShortcutSeconds => _currentSecondsCeil;

  bool get _endingShortcutVisible => _isValidShortcutSeconds(_remainingSeconds);

  int get _endingShortcutSeconds => _remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final manualEnabled = !widget.isSavingSkipConfig &&
        (!widget.isSmartAnalysisGloballyEnabled || !_smartSkipEnabled);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: widget.onBack,
                      child: Row(
                        children: [
                          const Icon(
                            FluentIcons.chevron_left,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.playerSettingsSkipIntroOutro,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.playerSettingsSkipScope(
                      widget.playingInfoCache?.item?.tvTitle ??
                          l10n.playerUnknown,
                      '${widget.playingInfoCache?.item?.seasonNumber ?? 0}',
                    ),
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ],
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
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: manualEnabled
                          ? _skipInputBorderColor
                          : _skipInputBorderColor.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    l10n.filterReset,
                    style: TextStyle(
                      color: manualEnabled
                          ? const Color(0xCCFFFFFF)
                          : const Color(0x66FFFFFF),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.isSmartAnalysisGloballyEnabled)
          PlayerSettingsToggleRow(
            key: const ValueKey('player-settings-smart-skip-toggle'),
            title: l10n.playerSettingsSmartSkipIntroOutro,
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
                    final onChanged = widget.onSmartSkipEnabledChanged;
                    if (onChanged == null) return;
                    // Roll back the local switch state when the requested enable
                    // did not take effect (e.g. re-request failed). Without this,
                    // the switch would stay ON while the feature is actually off,
                    // until the screen is re-entered.
                    unawaited(
                      onChanged(value).then((ok) {
                        if (!ok && mounted && value) {
                          setState(() => _smartSkipEnabled = false);
                        }
                      }),
                    );
                  },
          ),
        if (widget.isSmartAnalysisGloballyEnabled &&
            widget.isSmartSkipConfigAvailable &&
            _smartSkipEnabled) ...[
          const SizedBox(height: 4),
          _SettingsMenuItem(
            key: const ValueKey('player-settings-smart-skip-config-entry'),
            title: l10n.playerSettingsSmartSkipConfig,
            onClick: widget.onNavigateToSmartSkipConfig,
          ),
        ],
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),
        // Skip opening
        _SkipSlider(
          label: l10n.playerSettingsIntroDuration,
          value: _skipOpening.toDouble(),
          maxValue: 600,
          enabled: manualEnabled,
          isReverse: false,
          setCurrentTimeSeconds:
              _openingShortcutVisible ? _openingShortcutSeconds : null,
          onSetCurrentTime: () {
            setState(() =>
                _skipOpening = _openingShortcutSeconds.clamp(0, 600).toInt());
            widget.onConfigChanged(_skipOpening, _skipEnding);
          },
          onChanged: (value) {
            setState(() => _skipOpening = value.round());
          },
          onChangeEnd: (value) {
            widget.onConfigChanged(_skipOpening, _skipEnding);
          },
        ),
        const SizedBox(height: 32),
        // Skip ending
        _SkipSlider(
          label: l10n.playerSettingsOutroDuration,
          value: _skipEnding.toDouble(),
          maxValue: 600,
          enabled: manualEnabled,
          isReverse: true,
          setCurrentTimeSeconds:
              _endingShortcutVisible ? _endingShortcutSeconds : null,
          onSetCurrentTime: () {
            setState(() =>
                _skipEnding = _endingShortcutSeconds.clamp(0, 600).toInt());
            widget.onConfigChanged(_skipOpening, _skipEnding);
          },
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
  final bool isReverse;
  // Seconds shown in the one-click shortcut button; null hides the button.
  final int? setCurrentTimeSeconds;
  final VoidCallback? onSetCurrentTime;
  final void Function(double) onChanged;
  final void Function(double) onChangeEnd;

  const _SkipSlider({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.enabled,
    required this.isReverse,
    this.setCurrentTimeSeconds,
    this.onSetCurrentTime,
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
    final l10n = AppLocalizations.of(context);
    final shortcutSeconds = setCurrentTimeSeconds;
    final showShortcut = enabled && shortcutSeconds != null;
    final shortcutLabel = isReverse
        ? l10n.playerSettingsSetOutroToRemaining(
            _formatDuration(shortcutSeconds ?? 0))
        : l10n.playerSettingsSetIntroToCurrent(
            _formatDuration(shortcutSeconds ?? 0));
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: _skipTimeInputWidth,
                height: _skipTimeInputHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _skipInputFillColor,
                  border: Border.all(color: _skipInputBorderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDuration(value.round()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              if (showShortcut) ...[
                const Spacer(),
                _SetCurrentTimeButton(
                  key: ValueKey(isReverse
                      ? 'player-skip-set-ending'
                      : 'player-skip-set-opening'),
                  label: shortcutLabel,
                  onTap: onSetCurrentTime,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          _SkipSliderBar(
            value: value,
            maxValue: maxValue,
            enabled: enabled,
            isReverse: isReverse,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isReverse
                    ? l10n.playerSettingsTenMinutes
                    : l10n.playerSettingsSliderStart,
                style: const TextStyle(
                  color: _skipCaptionColor,
                  fontSize: 12,
                ),
              ),
              Text(
                isReverse
                    ? l10n.playerSettingsSliderEnd
                    : l10n.playerSettingsTenMinutes,
                style: const TextStyle(
                  color: _skipCaptionColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// One-click shortcut mirroring the web player's borderless brand button:
// sets the opening/ending to the current position (or remaining time).
class _SetCurrentTimeButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  const _SetCurrentTimeButton({super.key, required this.label, this.onTap});

  @override
  State<_SetCurrentTimeButton> createState() => _SetCurrentTimeButtonState();
}

class _SetCurrentTimeButtonState extends State<_SetCurrentTimeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered && enabled ? const Color(0x0AFFFFFF) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _skipActiveColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipSliderBar extends StatelessWidget {
  final double value;
  final double maxValue;
  final bool enabled;
  final bool isReverse;
  final void Function(double) onChanged;
  final void Function(double) onChangeEnd;

  const _SkipSliderBar({
    required this.value,
    required this.maxValue,
    required this.enabled,
    required this.isReverse,
    required this.onChanged,
    required this.onChangeEnd,
  });

  double _valueFromX(double x, double trackWidth) {
    if (trackWidth <= 0) return value;
    final fraction = (x / trackWidth).clamp(0.0, 1.0);
    return (isReverse ? 1 - fraction : fraction) * maxValue;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _skipSliderHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          final fraction = (value / maxValue).clamp(0.0, 1.0);
          // The thumb slides within [0, width - thumbSize] (same as the web
          // player) while the active bar spans the full fraction of the
          // track. For the ending slider the thumb sits mirrored so the blue
          // bar between thumb and right edge represents the skipped duration.
          final usable = trackWidth - _skipThumbSize;
          final thumbPosition = isReverse ? 1 - fraction : fraction;
          final thumbLeft = thumbPosition * (usable > 0 ? usable : 0);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: enabled
                ? (details) {
                    final v = _valueFromX(details.localPosition.dx, trackWidth);
                    onChanged(v);
                    onChangeEnd(v);
                  }
                : null,
            onHorizontalDragStart: enabled
                ? (details) =>
                    onChanged(_valueFromX(details.localPosition.dx, trackWidth))
                : null,
            onHorizontalDragUpdate: enabled
                ? (details) =>
                    onChanged(_valueFromX(details.localPosition.dx, trackWidth))
                : null,
            onHorizontalDragEnd: enabled ? (_) => onChangeEnd(value) : null,
            child: CustomPaint(
              size: Size(trackWidth, _skipSliderHeight),
              painter: _SkipSliderPainter(
                fraction: fraction,
                thumbLeft: thumbLeft,
                isReverse: isReverse,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SkipSliderPainter extends CustomPainter {
  final double fraction;
  final double thumbLeft;
  final bool isReverse;

  const _SkipSliderPainter({
    required this.fraction,
    required this.thumbLeft,
    required this.isReverse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const trackHeight = 4.0;
    final trackRect = Rect.fromLTWH(
      0,
      (size.height - trackHeight) / 2,
      size.width,
      trackHeight,
    );
    final trackRRect =
        RRect.fromRectAndRadius(trackRect, const Radius.circular(2));

    canvas.drawRRect(trackRRect, Paint()..color = _skipTrackColor);

    // Active portion, clipped to the rounded track. Mirrored for the ending
    // slider: the bar runs from the thumb boundary to the right edge.
    final activeBoundary = (isReverse ? 1 - fraction : fraction) * size.width;
    final activeRect = isReverse
        ? Rect.fromLTRB(
            activeBoundary, trackRect.top, size.width, trackRect.bottom)
        : Rect.fromLTRB(0, trackRect.top, activeBoundary, trackRect.bottom);
    canvas
      ..save()
      ..clipRRect(trackRRect)
      ..drawRect(activeRect, Paint()..color = _skipActiveColor)
      ..restore();

    // Thumb: 14px white circle with a 1px primary-blue border and a subtle
    // drop shadow, matching the web player.
    final thumbCenter = Offset(thumbLeft + _skipThumbSize / 2, size.height / 2);
    canvas.drawCircle(
      thumbCenter + const Offset(0, 1),
      _skipThumbSize / 2,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    canvas.drawCircle(
      thumbCenter,
      _skipThumbSize / 2,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      thumbCenter,
      _skipThumbSize / 2 - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _skipActiveColor,
    );
  }

  @override
  bool shouldRepaint(covariant _SkipSliderPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.thumbLeft != thumbLeft ||
      oldDelegate.isReverse != isReverse;
}

/// Reports the size of [child] after it has been laid out.
///
/// Used to keep the advanced settings panel the same height as the main
/// settings panel even when their intrinsic content heights differ.
class MeasureSize extends StatefulWidget {
  final Widget child;
  final void Function(Size size) onChange;

  const MeasureSize({
    super.key,
    required this.child,
    required this.onChange,
  });

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  Size? _size;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifySize());
  }

  @override
  void didUpdateWidget(covariant MeasureSize oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifySize());
  }

  void _notifySize() {
    if (!mounted) return;
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final size = renderObject.size;
      if (_size != size) {
        _size = size;
        widget.onChange(size);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Per-user playback skip switches (intro/credits/recap/preview), persisted
/// locally per user. The server-side analysis configuration lives in the
/// settings page dialog; this screen only controls skip behavior.
class _SmartSkipConfigSettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const _SmartSkipConfigSettingsScreen({required this.onBack});

  @override
  ConsumerState<_SmartSkipConfigSettingsScreen> createState() =>
      _SmartSkipConfigSettingsScreenState();
}

class _SmartSkipConfigSettingsScreenState
    extends ConsumerState<_SmartSkipConfigSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(skipSwitchesControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onBack,
            child: Row(
              children: [
                Icon(FluentIcons.chevron_left, size: 12, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  l10n.playerSettingsSmartSkipConfig,
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
        _switchRow(
          title: l10n.playerSettingsSkipIntroOnly,
          checked: state.skipIntro,
          onChanged: (value) => _setSwitch(SkipSegmentKind.intro, value),
        ),
        _switchRow(
          title: l10n.playerSettingsSkipOutroOnly,
          checked: state.skipCredits,
          onChanged: (value) => _setSwitch(SkipSegmentKind.credits, value),
        ),
        _switchRow(
          title: l10n.playerSettingsSkipRecap,
          checked: state.skipRecap,
          onChanged: (value) => _setSwitch(SkipSegmentKind.recap, value),
        ),
        _switchRow(
          title: l10n.playerSettingsSkipPreview,
          checked: state.skipPreview,
          onChanged: (value) => _setSwitch(SkipSegmentKind.preview, value),
        ),
        _switchRow(
          title: l10n.playerSettingsSkipCommercial,
          checked: state.skipCommercial,
          onChanged: (value) => _setSwitch(SkipSegmentKind.commercial, value),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _setSwitch(SkipSegmentKind kind, bool value) {
    unawaited(
      ref.read(skipSwitchesControllerProvider.notifier).setSwitch(kind, value),
    );
  }

  Widget _switchRow({
    required String title,
    required bool checked,
    required ValueChanged<bool> onChanged,
  }) {
    return PlayerSettingsToggleRow(
      title: title,
      checked: checked,
      onChanged: onChanged,
    );
  }
}
