import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../data/models/movie_detail_models.dart';
import '../../../../data/models/player_models.dart';
import 'subtitle_selection_panel.dart';
import 'package:fly_narwhal/ui/shared/app_button.dart';

const int _subtitleHideDelayMs = 200;
const int subtitleFlyoutAnimationDurationMs = 200;
const double _subtitleFlyoutBridgeOffset = 40;
const double _subtitleFlyoutMinBridgeWidth = 56;
const double _subtitleFlyoutBridgeHorizontalPadding = 12;
const double _estimatedSubtitleFlyoutHeight = subtitleFlyoutPanelHeight;
const double _subtitleSliderCenterSnapThreshold = 0.08;

class SubtitleControlFlyout extends StatefulWidget {
  final List<SubtitleStream> subtitles;
  final String? selectedSubtitleGuid;
  final Map<String, String> iso6391Map;
  final Map<String, String> iso6392Map;
  final SubtitleSettings subtitleSettings;
  final bool canAdjustSubtitle;
  final bool isPositionLocked;
  final int yOffset;
  final bool isActiveControl;
  final void Function(SubtitleSettings) onSubtitleSettingsChanged;
  final void Function(String?) onSubtitleSelected;
  final VoidCallback onOpenSubtitleSearch;
  final VoidCallback onOpenAddNasSubtitle;
  final VoidCallback onOpenAddLocalSubtitle;
  final void Function(bool)? onHoverStateChanged;
  final void Function(SubtitleStream)? onRequestDelete;
  final void Function(SubtitleStream)? onPredownloadSimilar;

  const SubtitleControlFlyout({
    super.key,
    required this.subtitles,
    required this.selectedSubtitleGuid,
    required this.iso6391Map,
    required this.iso6392Map,
    required this.subtitleSettings,
    required this.canAdjustSubtitle,
    this.isPositionLocked = false,
    this.yOffset = 0,
    this.isActiveControl = false,
    required this.onSubtitleSettingsChanged,
    required this.onSubtitleSelected,
    required this.onOpenSubtitleSearch,
    required this.onOpenAddNasSubtitle,
    required this.onOpenAddLocalSubtitle,
    this.onHoverStateChanged,
    this.onRequestDelete,
    this.onPredownloadSimilar,
  });

  @override
  State<SubtitleControlFlyout> createState() => _SubtitleControlFlyoutState();
}

class _SubtitleControlFlyoutState extends State<SubtitleControlFlyout>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isButtonHovered = false;
  bool _popupHovered = false;
  bool _isAdjustmentMode = false;
  late SubtitleSettings _liveSubtitleSettings;
  final GlobalKey _buttonKey = GlobalKey();
  final GlobalKey _flyoutKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Size? _flyoutSize;
  Timer? _hideTimer;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _liveSubtitleSettings = widget.subtitleSettings;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: subtitleFlyoutAnimationDurationMs),
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
  void didUpdateWidget(covariant SubtitleControlFlyout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActiveControl && !widget.isActiveControl) {
      unawaited(_forceCloseFlyout());
      return;
    }

    final shouldSyncLiveSubtitleSettings = _areSubtitleSettingsEqual(
      _liveSubtitleSettings,
      oldWidget.subtitleSettings,
    );
    if (shouldSyncLiveSubtitleSettings &&
        !_areSubtitleSettingsEqual(
          oldWidget.subtitleSettings,
          widget.subtitleSettings,
        )) {
      _liveSubtitleSettings = widget.subtitleSettings;
    }

    final shouldRefreshOverlay = _overlayEntry != null &&
        _isExpanded &&
        (shouldSyncLiveSubtitleSettings &&
                !_areSubtitleSettingsEqual(
                  oldWidget.subtitleSettings,
                  widget.subtitleSettings,
                ) ||
            oldWidget.subtitles != widget.subtitles ||
            oldWidget.selectedSubtitleGuid != widget.selectedSubtitleGuid ||
            oldWidget.canAdjustSubtitle != widget.canAdjustSubtitle ||
            oldWidget.iso6391Map != widget.iso6391Map ||
            oldWidget.iso6392Map != widget.iso6392Map);

    if (shouldRefreshOverlay) {
      _scheduleOverlayRebuild();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hideOverlay();
    _animationController.dispose();
    super.dispose();
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
      _overlayEntry?.markNeedsBuild();
    });
  }

  void _setPopupHovered(bool value) {
    if (_popupHovered == value || !mounted) return;
    setState(() => _popupHovered = value);
  }

  void _updateOverlayState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
    _overlayEntry?.markNeedsBuild();
  }

  void _scheduleOverlayRebuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayEntry == null) return;
      _overlayEntry?.markNeedsBuild();
    });
  }

  bool _areSubtitleSettingsEqual(
    SubtitleSettings left,
    SubtitleSettings right,
  ) {
    return left.offsetSeconds == right.offsetSeconds &&
        left.verticalPosition == right.verticalPosition &&
        left.fontScale == right.fontScale &&
        left.fontSize == right.fontSize &&
        left.fontColor == right.fontColor &&
        left.backgroundColor == right.backgroundColor;
  }

  void _handleSubtitleSettingsChanged(SubtitleSettings settings) {
    _updateOverlayState(() {
      _liveSubtitleSettings = settings;
    });
    widget.onSubtitleSettingsChanged(settings);
  }

  double _calculateBridgeWidth(Size buttonSize) {
    final preferredWidth =
        buttonSize.width + (_subtitleFlyoutBridgeHorizontalPadding * 2);
    return preferredWidth.clamp(
      _subtitleFlyoutMinBridgeWidth,
      subtitleFlyoutWidth,
    );
  }

  double _calculateBridgeLeft(Size buttonSize, double flyoutLeft) {
    final bridgeWidth = _calculateBridgeWidth(buttonSize);
    final buttonCenterX = buttonSize.width / 2 - flyoutLeft;
    final desiredLeft = buttonCenterX - (bridgeWidth / 2);
    return desiredLeft.clamp(0.0, subtitleFlyoutWidth - bridgeWidth);
  }

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final buttonContext = _buttonKey.currentContext;
        if (buttonContext == null) {
          return const SizedBox.shrink();
        }

        final renderObject = buttonContext.findRenderObject();
        if (renderObject is! RenderBox || !renderObject.hasSize) {
          return const SizedBox.shrink();
        }

        final overlaySize = MediaQuery.of(context).size;
        final buttonOffset = renderObject.localToGlobal(Offset.zero);
        final buttonSize = renderObject.size;
        final flyoutHeight =
            _flyoutSize?.height ?? _estimatedSubtitleFlyoutHeight;
        final bridgeHeight = widget.yOffset + _subtitleFlyoutBridgeOffset;
        final flyoutLeft = (buttonSize.width - subtitleFlyoutWidth) / 2;
        final left = (buttonOffset.dx + flyoutLeft)
            .clamp(8.0, overlaySize.width - subtitleFlyoutWidth - 8.0);
        final bridgeWidth = _calculateBridgeWidth(buttonSize);
        final bridgeLeft = _calculateBridgeLeft(
          buttonSize,
          left - buttonOffset.dx,
        );
        final top =
            buttonOffset.dy + buttonSize.height - bridgeHeight - flyoutHeight;

        _updateFlyoutSizeAfterFrame();

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: subtitleFlyoutWidth,
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
                          child: KeyedSubtree(
                            key: _flyoutKey,
                            child: _buildAnimatedFlyout(),
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
      _overlayEntry?.markNeedsBuild();
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
      _overlayEntry?.markNeedsBuild();
      return;
    }

    setState(() {
      _isExpanded = true;
      _liveSubtitleSettings = widget.subtitleSettings;
    });
    _showOverlay();
    _animationController.forward(from: 0);
    widget.onHoverStateChanged?.call(true);
  }

  void _hideFlyoutWithDelay() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: _subtitleHideDelayMs), () {
      if (!_isButtonHovered && !_popupHovered && mounted) {
        unawaited(_closeFlyout());
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
    setState(() {
      _isExpanded = false;
      _isAdjustmentMode = false;
    });
    widget.onHoverStateChanged?.call(false);
  }

  Future<void> _forceCloseFlyout() async {
    _hideTimer?.cancel();
    if (!_isExpanded) return;

    _isButtonHovered = false;
    _popupHovered = false;

    // Close immediately without the reverse animation: `_forceCloseFlyout` is
    // only invoked when another flyout is taking over, and animating the
    // leaving flyout's fade-out stacks it on top of the incoming one for the
    // animation duration — the "two flyouts overlap" bug.
    _animationController.stop();
    _animationController.value = 0;
    _hideOverlay();
    setState(() {
      _isExpanded = false;
      _isAdjustmentMode = false;
    });
    widget.onHoverStateChanged?.call(false);
  }

  void _closeAfterAction() {
    _setPopupHovered(false);
    unawaited(_closeFlyout());
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
        // Match the icon action buttons, whose 30x30 tap area carries 4px of
        // transparent padding per side; the bare 22px icon looked cramped next to them.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SvgPicture.asset(
            'assets/images/subtitle.svg',
            width: 22,
            height: 22,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
      child: _isAdjustmentMode
          ? _SubtitleAdjustmentPanel(
              settings: _liveSubtitleSettings,
              isPositionLocked: widget.isPositionLocked,
              onBack: () =>
                  _updateOverlayState(() => _isAdjustmentMode = false),
              onSettingsChanged: _handleSubtitleSettingsChanged,
            )
          : SubtitleSelectionPanel(
              subtitles: widget.subtitles,
              selectedSubtitleGuid: widget.selectedSubtitleGuid,
              iso6391Map: widget.iso6391Map,
              iso6392Map: widget.iso6392Map,
              canAdjustSubtitle: widget.canAdjustSubtitle,
              onAdjustmentClicked: () => _updateOverlayState(() {
                _liveSubtitleSettings = widget.subtitleSettings;
                _isAdjustmentMode = true;
              }),
              onSubtitleSelected: widget.onSubtitleSelected,
              onOpenSubtitleSearch: () {
                widget.onOpenSubtitleSearch();
                _closeAfterAction();
              },
              onOpenAddNasSubtitle: () {
                widget.onOpenAddNasSubtitle();
                _closeAfterAction();
              },
              onOpenAddLocalSubtitle: () {
                widget.onOpenAddLocalSubtitle();
                _closeAfterAction();
              },
              onRequestDelete: widget.onRequestDelete,
              onPredownloadSimilar: widget.onPredownloadSimilar,
            ),
    );
  }
}

class _SubtitleAdjustmentPanel extends StatelessWidget {
  final SubtitleSettings settings;
  final bool isPositionLocked;
  final ValueChanged<SubtitleSettings> onSettingsChanged;
  final VoidCallback onBack;

  const _SubtitleAdjustmentPanel({
    required this.settings,
    required this.onSettingsChanged,
    required this.onBack,
    this.isPositionLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: subtitleFlyoutWidth,
      height: subtitleFlyoutPanelHeight,
      decoration: BoxDecoration(
        color: subtitleFlyoutBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: subtitleFlyoutBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              children: [
                AppIconButton(
                  icon: const Icon(FluentIcons.back, size: 12),
                  onPressed: onBack,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '调整字幕',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SubtitleHeaderPillButton(
                  label: '重置',
                  onPressed: () => onSettingsChanged(const SubtitleSettings()),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(size: 1),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AdjustmentSliderSection(
                    title: '偏移',
                    value: settings.offsetSeconds,
                    min: -5,
                    max: 5,
                    leftLabel: '-5秒',
                    rightLabel: '+5秒',
                    suffix: '秒',
                    showCenterMarker: true,
                    snapToCenter: true,
                    centerValue: 0,
                    snapThreshold: _subtitleSliderCenterSnapThreshold,
                    onChanged: (value) => onSettingsChanged(
                      settings.copyWith(offsetSeconds: value),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AdjustmentSliderSection(
                    title: '位置',
                    value: settings.verticalPosition,
                    min: 0,
                    max: 1,
                    leftLabel: '底部',
                    rightLabel: '顶部',
                    enabled: !isPositionLocked,
                    disabledHint:
                        isPositionLocked ? '当前字幕为弹幕/特效字幕（含定位标签），位置调整不可用' : null,
                    showCenterMarker: true,
                    snapToCenter: true,
                    centerValue: 0.5,
                    snapThreshold: 0.04,
                    onChanged: (value) => onSettingsChanged(
                      settings.copyWith(verticalPosition: value),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AdjustmentSliderSection(
                    title: '字号',
                    value: settings.fontScale,
                    min: 0.5,
                    max: 1.5,
                    leftLabel: '最小',
                    rightLabel: '最大',
                    showCenterMarker: true,
                    snapToCenter: true,
                    centerValue: 1.0,
                    snapThreshold: 0.04,
                    onChanged: (value) => onSettingsChanged(
                      settings.copyWith(
                        fontScale: value,
                        fontSize: 24.0 * value,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustmentSliderSection extends StatefulWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final String leftLabel;
  final String rightLabel;
  final String? suffix;
  final bool enabled;
  final String? disabledHint;
  final bool showCenterMarker;
  final bool snapToCenter;
  final double? centerValue;
  final double snapThreshold;
  final ValueChanged<double> onChanged;

  const _AdjustmentSliderSection({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.leftLabel,
    required this.rightLabel,
    required this.onChanged,
    this.suffix,
    this.enabled = true,
    this.disabledHint,
    this.showCenterMarker = false,
    this.snapToCenter = false,
    this.centerValue,
    this.snapThreshold = 0,
  });

  @override
  State<_AdjustmentSliderSection> createState() =>
      _AdjustmentSliderSectionState();
}

class _AdjustmentSliderSectionState extends State<_AdjustmentSliderSection> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(covariant _AdjustmentSliderSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = _format(widget.value);
    if (_controller.text != nextText) {
      _controller.text = nextText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _centerValue {
    return widget.centerValue ?? ((widget.min + widget.max) / 2);
  }

  double get _centerMarkerAlignment {
    final range = widget.max - widget.min;
    if (range == 0) return 0;
    final normalized = ((_centerValue - widget.min) / range).clamp(0.0, 1.0);
    return (normalized * 2) - 1;
  }

  String _format(double value) {
    final normalizedValue = _snapValue(value);
    if (normalizedValue == normalizedValue.roundToDouble()) {
      return normalizedValue.round().toString();
    }
    return normalizedValue.toStringAsFixed(1);
  }

  double _clampValue(double value) {
    return value.clamp(widget.min, widget.max);
  }

  double _snapValue(double value) {
    final clampedValue = _clampValue(value);
    if (!widget.snapToCenter || widget.snapThreshold <= 0) {
      return clampedValue;
    }
    if ((clampedValue - _centerValue).abs() <= widget.snapThreshold) {
      return _centerValue;
    }
    return clampedValue;
  }

  void _handleChanged(double value) {
    widget.onChanged(_snapValue(value));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            color: enabled ? Colors.white : const Color(0x66FFFFFF),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Slider(
                    min: widget.min,
                    max: widget.max,
                    value: widget.value.clamp(widget.min, widget.max),
                    onChanged: enabled ? _handleChanged : null,
                  ),
                  if (widget.showCenterMarker)
                    IgnorePointer(
                      child: Align(
                        alignment: Alignment(_centerMarkerAlignment, 0),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.suffix != null) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: TextBox(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  onSubmitted: (text) {
                    final value = double.tryParse(text);
                    if (value == null) {
                      _controller.text = _format(widget.value);
                      return;
                    }
                    widget.onChanged(_snapValue(value));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.suffix!,
                style: const TextStyle(
                  color: subtitleDefaultTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        Row(
          children: [
            Text(
              widget.leftLabel,
              style: const TextStyle(
                color: subtitleDefaultTextColor,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Text(
              widget.rightLabel,
              style: const TextStyle(
                color: subtitleDefaultTextColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        if (!enabled && widget.disabledHint != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.disabledHint!,
            style: const TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}
