import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../../../../providers/danmaku_controller.dart';
import 'player_action_button.dart';

enum DanmakuSettingsPage {
  main,
  advanced,
}

const Color _flyoutBackgroundColor = Color(0xD91D2323);
const Color _flyoutBorderColor = Color(0x33FFFFFF);
const int _hideDelayMs = 200;
const int _animationDurationMs = 200;
const double _flyoutWidth = 340;
const double _flyoutBridgeOffset = 40;
const double _flyoutMinBridgeWidth = 48;
const double _flyoutBridgeHorizontalPadding = 12;

class DanmakuSettingsFlyout extends StatefulWidget {
  final DanmakuSettings settings;
  final DanmakuLoadStatus loadStatus;
  final double popupBottomOffset;
  final bool isActiveControl;
  final ValueChanged<double> onAreaChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onFontSizeScaleChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<bool> onSyncPlaybackSpeedChanged;
  final ValueChanged<bool> onDebugEnabledChanged;
  final ValueChanged<bool>? onHoverStateChanged;

  const DanmakuSettingsFlyout({
    super.key,
    required this.settings,
    required this.loadStatus,
    required this.popupBottomOffset,
    this.isActiveControl = false,
    required this.onAreaChanged,
    required this.onOpacityChanged,
    required this.onFontSizeScaleChanged,
    required this.onSpeedChanged,
    required this.onSyncPlaybackSpeedChanged,
    required this.onDebugEnabledChanged,
    this.onHoverStateChanged,
  });

  @override
  State<DanmakuSettingsFlyout> createState() => _DanmakuSettingsFlyoutState();
}

class _DanmakuSettingsFlyoutState extends State<DanmakuSettingsFlyout>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isButtonHovered = false;
  bool _popupHovered = false;
  final GlobalKey _buttonKey = GlobalKey();
  final GlobalKey _flyoutKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Size? _flyoutSize;
  Timer? _hideTimer;
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

  @override
  void didUpdateWidget(DanmakuSettingsFlyout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActiveControl && !widget.isActiveControl) {
      _forceCloseFlyout();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hideOverlay();
    _animationController.dispose();
    super.dispose();
  }

  void _requestOverlayRebuild() {
    _overlayEntry?.markNeedsBuild();
  }

  void _setPopupHovered(bool value) {
    if (_popupHovered == value || !mounted) return;
    setState(() => _popupHovered = value);
  }

  void _updateFlyoutSizeAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final flyoutContext = _flyoutKey.currentContext;
      if (flyoutContext == null) return;
      final renderObject = flyoutContext.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      final nextSize = renderObject.size;
      if (nextSize == _flyoutSize) return;
      _flyoutSize = nextSize;
      _overlayEntry?.markNeedsBuild();
    });
  }

  double _calculateBridgeWidth(Size buttonSize) {
    final preferredWidth =
        buttonSize.width + (_flyoutBridgeHorizontalPadding * 2);
    return preferredWidth.clamp(_flyoutMinBridgeWidth, _flyoutWidth);
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

        final overlaySize = MediaQuery.of(overlayContext).size;
        final buttonOffset = renderObject.localToGlobal(Offset.zero);
        final buttonSize = renderObject.size;
        final flyoutHeight = _flyoutSize?.height ?? 380.0;
        final bridgeHeight = widget.popupBottomOffset + _flyoutBridgeOffset;
        final top =
            (buttonOffset.dy + buttonSize.height - bridgeHeight - flyoutHeight)
                .clamp(8.0, overlaySize.height - flyoutHeight - bridgeHeight);
        final left =
            (buttonOffset.dx + (buttonSize.width - _flyoutWidth) / 2)
                .clamp(8.0, overlaySize.width - _flyoutWidth - 8.0);
        final bridgeWidth = _calculateBridgeWidth(buttonSize);
        final buttonCenterX =
            buttonOffset.dx + (buttonSize.width / 2) - left;
        final bridgeLeft = (buttonCenterX - bridgeWidth / 2)
            .clamp(0.0, _flyoutWidth - bridgeWidth);

        _updateFlyoutSizeAfterFrame();

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: SizedBox(
                width: _flyoutWidth,
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
        _closeFlyout();
      }
    });
  }

  Future<void> _closeFlyout() async {
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
    setState(() => _isExpanded = false);
    widget.onHoverStateChanged?.call(false);
  }

  Future<void> _forceCloseFlyout() async {
    _hideTimer?.cancel();
    if (!_isExpanded) return;

    _isButtonHovered = false;
    _popupHovered = false;

    if (_animationController.status != AnimationStatus.dismissed) {
      await _animationController.reverse();
    }

    if (!mounted) return;
    _hideOverlay();
    setState(() => _isExpanded = false);
    widget.onHoverStateChanged?.call(false);
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
        child: PlayerActionButton.svg(
          key: const ValueKey('player-danmaku-settings'),
          svgAssetPath: 'assets/images/danmu_setting.svg',
          onPressed: _toggleFlyout,
          tooltip: '弹幕设置',
          size: 30,
          iconSize: 20,
        ),
      ),
    );
  }

  void _toggleFlyout() {
    if (_isExpanded) {
      _closeFlyout();
      return;
    }
    _showFlyout();
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
      child: _DanmakuSettingsFlyoutContent(
        settings: widget.settings,
        loadStatus: widget.loadStatus,
        onPageChanged: (_) => _requestOverlayRebuild(),
        onAreaChanged: widget.onAreaChanged,
        onOpacityChanged: widget.onOpacityChanged,
        onFontSizeScaleChanged: widget.onFontSizeScaleChanged,
        onSpeedChanged: widget.onSpeedChanged,
        onSyncPlaybackSpeedChanged: widget.onSyncPlaybackSpeedChanged,
        onDebugEnabledChanged: widget.onDebugEnabledChanged,
      ),
    );
  }
}

class _DanmakuSettingsFlyoutContent extends StatefulWidget {
  final DanmakuSettings settings;
  final DanmakuLoadStatus loadStatus;
  final ValueChanged<DanmakuSettingsPage> onPageChanged;
  final ValueChanged<double> onAreaChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onFontSizeScaleChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<bool> onSyncPlaybackSpeedChanged;
  final ValueChanged<bool> onDebugEnabledChanged;

  const _DanmakuSettingsFlyoutContent({
    required this.settings,
    required this.loadStatus,
    required this.onPageChanged,
    required this.onAreaChanged,
    required this.onOpacityChanged,
    required this.onFontSizeScaleChanged,
    required this.onSpeedChanged,
    required this.onSyncPlaybackSpeedChanged,
    required this.onDebugEnabledChanged,
  });

  @override
  State<_DanmakuSettingsFlyoutContent> createState() =>
      _DanmakuSettingsFlyoutContentState();
}

class _DanmakuSettingsFlyoutContentState
    extends State<_DanmakuSettingsFlyoutContent> {
  DanmakuSettingsPage _page = DanmakuSettingsPage.main;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('player-danmaku-settings-flyout'),
      width: _flyoutWidth,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _flyoutBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _flyoutBorderColor),
      ),
      child: _page == DanmakuSettingsPage.main
          ? _buildMainPage()
          : _buildAdvancedPage(),
    );
  }

  Widget _buildMainPage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader('弹幕设置'),
        if (_statusText != null) ...[
          const SizedBox(height: 4),
          Text(
            _statusText!,
            style: const TextStyle(color: Color(0xBFFFFFFF), fontSize: 13),
          ),
        ],
        const SizedBox(height: 18),
        const Text('显示区域', style: TextStyle(color: Color(0xE6FFFFFF))),
        const SizedBox(height: 8),
        Wrap(
          key: const ValueKey('player-danmaku-area-control'),
          spacing: 8,
          children: [0.1, 0.25, 0.5, 0.75, 1.0].map((area) {
            return Button(
              onPressed: () => widget.onAreaChanged(area),
              child: Text('${(area * 100).round()}%'),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _buildSlider(
          key: const ValueKey('player-danmaku-opacity-slider'),
          label: '不透明度 ${(widget.settings.opacity * 100).round()}%',
          value: widget.settings.opacity,
          minimum: 0,
          maximum: 1,
          onChanged: widget.onOpacityChanged,
        ),
        _buildSlider(
          key: const ValueKey('player-danmaku-font-size-slider'),
          label: '字号 ${(widget.settings.fontSizeScale * 100).round()}%',
          value: widget.settings.fontSizeScale,
          minimum: 0.5,
          maximum: 1.7,
          onChanged: widget.onFontSizeScaleChanged,
        ),
        _buildSlider(
          key: const ValueKey('player-danmaku-speed-slider'),
          label: '速度 ${_speedLabel(widget.settings.speed)}',
          value: widget.settings.speed,
          minimum: 0.5,
          maximum: 2.0,
          onChanged: widget.onSpeedChanged,
        ),
        const SizedBox(height: 4),
        Button(
          onPressed: () {
            setState(() => _page = DanmakuSettingsPage.advanced);
            widget.onPageChanged(DanmakuSettingsPage.advanced);
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('高级设置'), Icon(FluentIcons.chevron_right)],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedPage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(FluentIcons.chevron_left),
              onPressed: () {
                setState(() => _page = DanmakuSettingsPage.main);
                widget.onPageChanged(DanmakuSettingsPage.main);
              },
            ),
            const SizedBox(width: 8),
            _buildHeader('高级设置'),
          ],
        ),
        const SizedBox(height: 18),
        ToggleSwitch(
          key: const ValueKey('player-danmaku-sync-speed-switch'),
          checked: widget.settings.syncPlaybackSpeed,
          onChanged: widget.onSyncPlaybackSpeedChanged,
          content: const Text('弹幕速度同步播放倍速'),
        ),
        const SizedBox(height: 16),
        ToggleSwitch(
          key: const ValueKey('player-danmaku-debug-switch'),
          checked: widget.settings.debugEnabled,
          onChanged: widget.onDebugEnabledChanged,
          content: const Text('显示弹幕调试信息'),
        ),
      ],
    );
  }

  Widget _buildHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSlider({
    required Key key,
    required String label,
    required double value,
    required double minimum,
    required double maximum,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xE6FFFFFF))),
          const SizedBox(height: 6),
          Slider(
            key: key,
            value: value,
            min: minimum,
            max: maximum,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String? get _statusText {
    return switch (widget.loadStatus) {
      DanmakuLoadStatus.loading => '加载弹幕中',
      DanmakuLoadStatus.empty => '暂无弹幕',
      DanmakuLoadStatus.failure => '弹幕加载失败',
      DanmakuLoadStatus.idle || DanmakuLoadStatus.loaded => null,
    };
  }

  String _speedLabel(double speed) {
    const labels = <(double, String)>[
      (0.5, '极慢'),
      (0.875, '较慢'),
      (1.25, '适中'),
      (1.625, '较快'),
      (2.0, '极快'),
    ];
    var nearest = labels.first;
    for (final label in labels.skip(1)) {
      if ((label.$1 - speed).abs() < (nearest.$1 - speed).abs()) {
        nearest = label;
      }
    }
    return '${nearest.$2} ${speed.toStringAsFixed(2)}x';
  }
}
