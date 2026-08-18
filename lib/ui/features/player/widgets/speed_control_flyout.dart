import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import '../../../../data/models/player_models.dart';

const Color _flyoutBackgroundColor = Color(0xCC000000);
const Color _flyoutBorderColor = Color(0x80808080);
const Color _selectedTextColor = Color(0xFF2073DF);
const Color _defaultTextColor = Color(0xC8FFFFFF);
const Color _hoverBackgroundColor = Color(0x1AFFFFFF);
const BorderRadius _flyoutBorderRadius = BorderRadius.all(Radius.circular(8));
const int _hideDelayMs = 200;
const int _animationDurationMs = 200;
const double _flyoutWidth = 120;
const double _flyoutLeftOffset = -30;
const double _flyoutBridgeOffset = 40;
const double _estimatedFlyoutHeight = 244;

class SpeedControlFlyout extends StatefulWidget {
  final double defaultSpeed;
  final int yOffset;
  final bool isActiveControl;
  final void Function(bool isHovered)? onHoverStateChanged;
  final void Function(SpeedItem speed) onSpeedSelected;

  const SpeedControlFlyout({
    super.key,
    this.defaultSpeed = 1.0,
    this.yOffset = 0,
    this.isActiveControl = false,
    this.onHoverStateChanged,
    required this.onSpeedSelected,
  });

  @override
  State<SpeedControlFlyout> createState() => _SpeedControlFlyoutState();
}

class _SpeedControlFlyoutState extends State<SpeedControlFlyout>
    with SingleTickerProviderStateMixin {
  late SpeedItem _selectedSpeed;
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
    _selectedSpeed = _findSpeedItem(widget.defaultSpeed);
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
  void didUpdateWidget(SpeedControlFlyout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultSpeed != widget.defaultSpeed) {
      _selectedSpeed = _findSpeedItem(widget.defaultSpeed);
    }
    if (oldWidget.isActiveControl && !widget.isActiveControl) {
      _forceCloseFlyout();
    }
  }

  SpeedItem _findSpeedItem(double speed) {
    return SpeedItem.defaults.firstWhere(
      (s) => s.value == speed,
      orElse: () => SpeedItem.defaults[4], // Default to 1.0x
    );
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
        final flyoutHeight = _flyoutSize?.height ?? _estimatedFlyoutHeight;
        final bridgeHeight = widget.yOffset + _flyoutBridgeOffset;
        final top =
            buttonOffset.dy + buttonSize.height - bridgeHeight - flyoutHeight;

        _updateFlyoutSizeAfterFrame();

        return Stack(
          children: [
            Positioned(
              left: buttonOffset.dx + _flyoutLeftOffset,
              top: top,
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
                          cursor: SystemMouseCursors.click,
                          child: KeyedSubtree(
                            key: _flyoutKey,
                            child: _buildAnimatedFlyout(),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: flyoutHeight,
                        child: SizedBox(
                          width: _flyoutWidth,
                          height: bridgeHeight,
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
    });
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
    setState(() {
      _isExpanded = false;
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
    });
    widget.onHoverStateChanged?.call(false);
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
        // Match the icon action buttons, whose 30x30 tap area carries 4px of
        // transparent padding per side; bare text would look cramped next to them.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _selectedSpeed.label == '1.0x' ? '倍速' : _selectedSpeed.label,
            style: TextStyle(
              color: _isButtonHovered ? Colors.white : _defaultTextColor,
              fontSize: 17,
              fontWeight: FontWeight.normal,
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
      child: _SpeedFlyoutContent(
        selectedSpeed: _selectedSpeed,
        onSpeedSelected: (speed) {
          setState(() => _selectedSpeed = speed);
          widget.onSpeedSelected(speed);
          _setPopupHovered(false);
          _closeFlyout();
        },
      ),
    );
  }
}

class _SpeedFlyoutContent extends StatelessWidget {
  final SpeedItem selectedSpeed;
  final void Function(SpeedItem) onSpeedSelected;

  const _SpeedFlyoutContent({
    required this.selectedSpeed,
    required this.onSpeedSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: _flyoutBackgroundColor,
        borderRadius: _flyoutBorderRadius,
        border: Border.all(color: _flyoutBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: SpeedItem.defaults.map((speed) {
            return _SpeedItem(
              key: ValueKey('player-speed-${speed.label}'),
              speed: speed,
              isSelected: speed.value == selectedSpeed.value,
              onClick: () => onSpeedSelected(speed),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SpeedItem extends StatefulWidget {
  final SpeedItem speed;
  final bool isSelected;
  final VoidCallback onClick;

  const _SpeedItem({
    super.key,
    required this.speed,
    required this.isSelected,
    required this.onClick,
  });

  @override
  State<_SpeedItem> createState() => _SpeedItemState();
}

class _SpeedItemState extends State<_SpeedItem> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _isHovered ? _hoverBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.speed.label,
                style: TextStyle(
                  color: widget.isSelected
                      ? _selectedTextColor
                      : _defaultTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.isSelected)
                const Icon(
                  FluentIcons.check_mark,
                  size: 18,
                  color: _defaultTextColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
