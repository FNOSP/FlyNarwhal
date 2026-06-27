import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/scheduler.dart';
import '../../../../data/models/player_models.dart';
import '../../../../data/models/movie_detail_models.dart';
import 'player_action_button.dart';

const Color _flyoutBackgroundColor = Color(0xE6000000);
const Color _flyoutBorderColor = Color(0x80808080);
const Color _selectedTextColor = Color(0xFF2073DF);
const Color _defaultTextColor = Color(0xC8FFFFFF);
const Color _hoverBackgroundColor = Color(0x1AFFFFFF);
const int _hideDelayMs = 200;
const int _animationDurationMs = 200;
const double _settingsFlyoutLeftOffset = -145;
const double _settingsFlyoutBridgeOffset = 40;
const double _settingsFlyoutWidth = 320;
const double _settingsFlyoutMinBridgeWidth = 56;
const double _settingsFlyoutBridgeHorizontalPadding = 12;
const double _estimatedSettingsFlyoutHeight = 300;

class PlayerSettingsMenu extends StatefulWidget {
  final PlayingInfoCache? playingInfoCache;
  final int currentPositionMillis;
  final int totalDurationMillis;
  final double popupBottomOffset;
  final void Function(AudioStream) onAudioSelected;
  final void Function(String) onWindowAspectRatioChanged;
  final void Function(int skipOpening, int skipEnding) onSkipConfigChanged;
  final void Function(bool isHovered)? onHoverStateChanged;
  final bool smartSkipEnabled;
  final void Function(bool enabled)? onSmartSkipEnabledChanged;
  final bool isSmartAnalysisGloballyEnabled;
  final bool isAutoPlay;
  final void Function(bool enabled)? onAutoPlayChanged;
  final Map<String, String>? iso6391Map;

  const PlayerSettingsMenu({
    super.key,
    required this.playingInfoCache,
    this.iso6391Map,
    required this.currentPositionMillis,
    required this.totalDurationMillis,
    this.popupBottomOffset = 70,
    required this.onAudioSelected,
    required this.onWindowAspectRatioChanged,
    required this.onSkipConfigChanged,
    this.onHoverStateChanged,
    this.smartSkipEnabled = true,
    this.onSmartSkipEnabledChanged,
    this.isSmartAnalysisGloballyEnabled = false,
    this.isAutoPlay = true,
    this.onAutoPlayChanged,
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
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
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
    _hideTimer = Timer(const Duration(milliseconds: _hideDelayMs), () {
      if (!_isButtonHovered && !_popupHovered && mounted) {
        _closeMenu();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PlayerSettingsMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.popupBottomOffset != widget.popupBottomOffset) {
      _requestOverlayRebuild();
    }
  }

  double get _safePopupBottomOffset =>
      widget.popupBottomOffset < 0 ? 0 : widget.popupBottomOffset;

  void _requestOverlayRebuild() {
    if (_overlayEntry == null) return;

    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    final canRebuildNow = schedulerPhase == SchedulerPhase.idle ||
        schedulerPhase == SchedulerPhase.postFrameCallbacks;
    if (canRebuildNow) {
      _overlayEntry?.markNeedsBuild();
      return;
    }

    if (_overlayRebuildScheduled) return;
    _overlayRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
                        cursor: SystemMouseCursors.basic,
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
                        cursor: SystemMouseCursors.basic,
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
        key: _buttonKey,
        child: const PlayerActionButton.lottie(
          lottieAssetPath: 'assets/lottie/settings_lottie.json',
          size: 30,
          iconSize: 22,
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
        currentPositionMillis: widget.currentPositionMillis,
        totalDurationMillis: widget.totalDurationMillis,
        currentScreen: _currentScreen,
        onNavigate: (screen) {
          setState(() => _currentScreen = screen);
          _requestOverlayRebuild();
        },
        onAudioSelected: (audio) {
          _setPopupHovered(false);
          widget.onAudioSelected(audio);
          _closeMenu();
        },
        onWindowAspectRatioChanged: (ratio) {
          _setPopupHovered(false);
          widget.onWindowAspectRatioChanged(ratio);
          _closeMenu();
        },
        onSkipConfigChanged: widget.onSkipConfigChanged,
        smartSkipEnabled: widget.smartSkipEnabled,
        onSmartSkipEnabledChanged: widget.onSmartSkipEnabledChanged,
        isSmartAnalysisGloballyEnabled: widget.isSmartAnalysisGloballyEnabled,
        isAutoPlay: widget.isAutoPlay,
        onAutoPlayChanged: widget.onAutoPlayChanged,
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
}

class _SettingsFlyoutContent extends StatelessWidget {
  final PlayingInfoCache? playingInfoCache;
  final Map<String, String>? iso6391Map;
  final int currentPositionMillis;
  final int totalDurationMillis;
  final String currentScreen;
  final void Function(String) onNavigate;
  final void Function(AudioStream) onAudioSelected;
  final void Function(String) onWindowAspectRatioChanged;
  final void Function(int, int) onSkipConfigChanged;
  final bool smartSkipEnabled;
  final void Function(bool)? onSmartSkipEnabledChanged;
  final bool isSmartAnalysisGloballyEnabled;
  final bool isAutoPlay;
  final void Function(bool)? onAutoPlayChanged;

  const _SettingsFlyoutContent({
    super.key,
    required this.playingInfoCache,
    required this.iso6391Map,
    required this.currentPositionMillis,
    required this.totalDurationMillis,
    required this.currentScreen,
    required this.onNavigate,
    required this.onAudioSelected,
    required this.onWindowAspectRatioChanged,
    required this.onSkipConfigChanged,
    required this.smartSkipEnabled,
    required this.onSmartSkipEnabledChanged,
    required this.isSmartAnalysisGloballyEnabled,
    required this.isAutoPlay,
    required this.onAutoPlayChanged,
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
      case 'Audio':
        return _AudioSettingsScreen(
          playingInfoCache: playingInfoCache,
          iso6391Map: iso6391Map,
          onBack: () => onNavigate('Main'),
          onAudioSelected: onAudioSelected,
        );
      case 'WindowAspectRatio':
        return _WindowAspectRatioSettingsScreen(
          onBack: () => onNavigate('Main'),
          onAspectRatioSelected: onWindowAspectRatioChanged,
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
        );
      default:
        return _MainSettingsScreen(
          playingInfoCache: playingInfoCache,
          iso6391Map: iso6391Map,
          smartSkipEnabled: smartSkipEnabled,
          isSmartAnalysisGloballyEnabled: isSmartAnalysisGloballyEnabled,
          isAutoPlay: isAutoPlay,
          onAutoPlayChanged: onAutoPlayChanged,
          onNavigateToAudio: () => onNavigate('Audio'),
          onNavigateToWindowAspectRatio: () => onNavigate('WindowAspectRatio'),
          onNavigateToSkipConfig: () => onNavigate('SkipConfig'),
        );
    }
  }
}

class _MainSettingsScreen extends StatelessWidget {
  final PlayingInfoCache? playingInfoCache;
  final Map<String, String>? iso6391Map;
  final bool smartSkipEnabled;
  final bool isSmartAnalysisGloballyEnabled;
  final bool isAutoPlay;
  final void Function(bool)? onAutoPlayChanged;
  final VoidCallback onNavigateToAudio;
  final VoidCallback onNavigateToWindowAspectRatio;
  final VoidCallback onNavigateToSkipConfig;

  const _MainSettingsScreen({
    required this.playingInfoCache,
    required this.iso6391Map,
    required this.smartSkipEnabled,
    required this.isSmartAnalysisGloballyEnabled,
    required this.isAutoPlay,
    required this.onAutoPlayChanged,
    required this.onNavigateToAudio,
    required this.onNavigateToWindowAspectRatio,
    required this.onNavigateToSkipConfig,
  });

  @override
  Widget build(BuildContext context) {
    final currentAudio = playingInfoCache?.currentAudioStream;
    final language = currentAudio != null
        ? _getLanguageName(currentAudio.language, iso6391Map)
        : '未知';
    final audioDetails = currentAudio != null
        ? '${currentAudio.codecName} ${currentAudio.channelLayout}'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '设置',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        _SettingsToggleItem(
          title: '自动连播',
          checked: isAutoPlay,
          onChanged: onAutoPlayChanged,
        ),
        // Skip config for episodes
        if (playingInfoCache?.isEpisode == true ||
            playingInfoCache?.item?.type == 'Episode')
          _SettingsMenuItem(
            title: '跳过片头/片尾',
            value: _getSkipText(playingInfoCache?.playConfig),
            onClick: onNavigateToSkipConfig,
          ),
        _SettingsMenuItem(
          title: '窗口比例',
          value: '自动',
          onClick: onNavigateToWindowAspectRatio,
        ),
        _SettingsMenuItem(
          title: '音频',
          value: '$language $audioDetails',
          onClick: onNavigateToAudio,
        ),
      ],
    );
  }

  String _getLanguageName(String? code, Map<String, String>? isoMap) {
    if (code == null || code.isEmpty) return '未知';
    return isoMap?[code] ?? code;
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

class _SettingsToggleItem extends StatefulWidget {
  final String title;
  final bool checked;
  final void Function(bool)? onChanged;

  const _SettingsToggleItem({
    required this.title,
    required this.checked,
    required this.onChanged,
  });

  @override
  State<_SettingsToggleItem> createState() => _SettingsToggleItemState();
}

class _SettingsToggleItemState extends State<_SettingsToggleItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onChanged == null
            ? null
            : () => widget.onChanged?.call(!widget.checked),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: _isHovered ? _hoverBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(color: _defaultTextColor, fontSize: 14),
              ),
              ToggleSwitch(
                checked: widget.checked,
                onChanged: widget.onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsMenuItem extends StatefulWidget {
  final String title;
  final String? value;
  final VoidCallback onClick;

  const _SettingsMenuItem({
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(color: _defaultTextColor, fontSize: 14),
              ),
              Row(
                children: [
                  if (widget.value != null)
                    Text(
                      widget.value!,
                      style: const TextStyle(
                          color: _defaultTextColor, fontSize: 14),
                    ),
                  const SizedBox(width: 4),
                  const Icon(
                    FluentIcons.chevron_right,
                    size: 16,
                    color: _defaultTextColor,
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

class _AudioSettingsScreen extends StatelessWidget {
  final PlayingInfoCache? playingInfoCache;
  final Map<String, String>? iso6391Map;
  final VoidCallback onBack;
  final void Function(AudioStream) onAudioSelected;

  const _AudioSettingsScreen({
    required this.playingInfoCache,
    required this.iso6391Map,
    required this.onBack,
    required this.onAudioSelected,
  });

  @override
  Widget build(BuildContext context) {
    final audioList = playingInfoCache?.currentAudioStreamList ?? [];
    final currentAudioStream = playingInfoCache?.currentAudioStream;

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
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                const Text(
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
        const SizedBox(height: 8),
        ...audioList.map((audio) {
          final isSelected = currentAudioStream?.index == audio.index;
          final language = _getLanguageName(audio.language, iso6391Map);
          final label = '$language ${audio.codecName} ${audio.channelLayout}';

          return _AudioItem(
            label: label,
            isSelected: isSelected,
            onClick: () => onAudioSelected(audio),
          );
        }),
      ],
    );
  }

  String _getLanguageName(String? code, Map<String, String>? isoMap) {
    if (code == null || code.isEmpty) return '未知';
    return isoMap?[code] ?? code;
  }
}

class _AudioItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onClick;

  const _AudioItem({
    required this.label,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onClick,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: _isHovered ? _hoverBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected
                      ? _selectedTextColor
                      : _defaultTextColor,
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

class _WindowAspectRatioSettingsScreen extends StatelessWidget {
  final VoidCallback onBack;
  final void Function(String) onAspectRatioSelected;

  const _WindowAspectRatioSettingsScreen({
    required this.onBack,
    required this.onAspectRatioSelected,
  });

  @override
  Widget build(BuildContext context) {
    const options = ['AUTO', '4:3', '16:9', '21:9'];
    const optionLabels = {
      'AUTO': '自动',
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
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                const Text(
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
            label: label,
            onClick: () => onAspectRatioSelected(option),
          );
        }),
      ],
    );
  }
}

class _AspectRatioItem extends StatefulWidget {
  final String label;
  final VoidCallback onClick;

  const _AspectRatioItem({
    required this.label,
    required this.onClick,
  });

  @override
  State<_AspectRatioItem> createState() => _AspectRatioItemState();
}

class _AspectRatioItemState extends State<_AspectRatioItem> {
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
                style: const TextStyle(
                  color: _defaultTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
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

  const _SkipConfigSettingsScreen({
    required this.playingInfoCache,
    required this.currentPositionMillis,
    required this.totalDurationMillis,
    required this.onBack,
    required this.onConfigChanged,
    required this.smartSkipEnabled,
    required this.onSmartSkipEnabledChanged,
    required this.isSmartAnalysisGloballyEnabled,
  });

  @override
  State<_SkipConfigSettingsScreen> createState() =>
      _SkipConfigSettingsScreenState();
}

class _SkipConfigSettingsScreenState extends State<_SkipConfigSettingsScreen> {
  late int _skipOpening;
  late int _skipEnding;

  @override
  void initState() {
    super.initState();
    _skipOpening = widget.playingInfoCache?.playConfig?.skipOpening ?? 0;
    _skipEnding = widget.playingInfoCache?.playConfig?.skipEnding ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final manualEnabled =
        !widget.isSmartAnalysisGloballyEnabled || !widget.smartSkipEnabled;

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
                child: Row(
                  children: [
                    const Icon(
                      FluentIcons.chevron_left,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    const Text(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('智能跳过片头/片尾',
                  style: TextStyle(color: _defaultTextColor, fontSize: 14)),
              ToggleSwitch(
                checked: widget.smartSkipEnabled,
                onChanged: widget.onSmartSkipEnabledChanged,
              ),
            ],
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
