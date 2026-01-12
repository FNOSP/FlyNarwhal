import 'dart:async';
import 'package:flutter/material.dart';

class SpeedItem {
  final String label;
  final double value;

  const SpeedItem(this.label, this.value);
}

const List<SpeedItem> speeds = [
  SpeedItem("2.0x", 2.0),
  SpeedItem("1.75x", 1.75),
  SpeedItem("1.5x", 1.5),
  SpeedItem("1.25x", 1.25),
  SpeedItem("1.0x", 1.0),
  SpeedItem("0.75x", 0.75),
  SpeedItem("0.5x", 0.5),
];

class SpeedControlFlyout extends StatefulWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedChanged;

  const SpeedControlFlyout({
    super.key,
    required this.currentSpeed,
    required this.onSpeedChanged,
  });

  @override
  State<SpeedControlFlyout> createState() => _SpeedControlFlyoutState();
}

class _SpeedControlFlyoutState extends State<SpeedControlFlyout> {
  final GlobalKey _buttonKey = GlobalKey();
  Size _buttonSize = Size.zero;
  bool _isExpanded = false;
  bool _isButtonHovered = false;
  bool _isPopupHovered = false;
  Timer? _hideTimer;

  static const int hideDelayMs = 200;
  static const double flyoutWidth = 120;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _updateButtonSizeAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _buttonKey.currentContext;
      if (ctx == null) return;
      final renderObject = ctx.findRenderObject();
      if (renderObject is! RenderBox) return;
      if (!renderObject.hasSize) return;
      final nextSize = renderObject.size;
      if (nextSize == _buttonSize) return;
      setState(() {
        _buttonSize = nextSize;
      });
    });
  }

  void _showFlyout() {
    _hideTimer?.cancel();
    if (!_isExpanded) {
      setState(() {
        _isExpanded = true;
      });
    }
  }

  void _hideFlyoutWithDelay() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: hideDelayMs), () {
      if (mounted && !_isButtonHovered && !_isPopupHovered) {
        _flyoutAnimationKey.currentState?.animateClose();
      }
    });
  }

  final GlobalKey<_FlyoutWithAnimationState> _flyoutAnimationKey = GlobalKey();

  void _onAnimationFinished() {
    if (mounted) {
      setState(() {
        _isExpanded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateButtonSizeAfterFrame();

    String label = "倍速";
    try {
      final item = speeds.firstWhere((s) => (s.value - widget.currentSpeed).abs() < 0.01);
      if (item.label != "1.0x") {
        label = item.label;
      }
    } catch (_) {}

    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        _isButtonHovered = true;
        _showFlyout();
      },
      onExit: (_) {
        _isButtonHovered = false;
        _hideFlyoutWithDelay();
      },
      child: KeyedSubtree(
        key: _buttonKey,
        child: GestureDetector(
          onTap: () {
            if (_isExpanded) {
              _flyoutAnimationKey.currentState?.animateClose();
            } else {
              _showFlyout();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Text(
              label,
              style: TextStyle(
                color: _isButtonHovered || _isExpanded ? Colors.white : Colors.white.withAlpha(200),
                fontSize: 17,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );

    final popup = _isExpanded
        ? Positioned(
            left: (_buttonSize.width - flyoutWidth) / 2,
            bottom: _buttonSize.height,
            child: MouseRegion(
              onEnter: (_) {
                _isPopupHovered = true;
                _hideTimer?.cancel();
              },
              onExit: (_) {
                _isPopupHovered = false;
                _hideFlyoutWithDelay();
              },
              cursor: SystemMouseCursors.basic,
              child: Material(
                color: Colors.transparent,
                elevation: 0,
                child: FlyoutWithAnimation(
                  key: _flyoutAnimationKey,
                  speeds: speeds,
                  selectedSpeed: widget.currentSpeed,
                  onSpeedClick: (speed) {
                    widget.onSpeedChanged(speed);
                    _isPopupHovered = false;
                    _flyoutAnimationKey.currentState?.animateClose();
                  },
                  onAnimationFinished: _onAnimationFinished,
                ),
              ),
            ),
          )
        : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        if (popup != null) popup,
      ],
    );
  }
}

class FlyoutWithAnimation extends StatefulWidget {
  final List<SpeedItem> speeds;
  final double selectedSpeed;
  final ValueChanged<double> onSpeedClick;
  final VoidCallback onAnimationFinished;

  const FlyoutWithAnimation({
    super.key,
    required this.speeds,
    required this.selectedSpeed,
    required this.onSpeedClick,
    required this.onAnimationFinished,
  });

  @override
  State<FlyoutWithAnimation> createState() => _FlyoutWithAnimationState();
}

class _FlyoutWithAnimationState extends State<FlyoutWithAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _alpha;
  late Animation<double> _scale;
  late Animation<double> _offsetY;

  static const int animationDurationMs = 200;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: animationDurationMs),
    );

    _alpha = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _scale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _offsetY = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _controller.forward();
  }

  void animateClose() {
    _controller.reverse().then((_) {
      widget.onAnimationFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _alpha.value,
          child: Transform.translate(
            offset: Offset(0, _offsetY.value),
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(_scale.value, _scale.value, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: FlyoutContent(
        speeds: widget.speeds,
        selectedSpeed: widget.selectedSpeed,
        onSpeedClick: widget.onSpeedClick,
      ),
    );
  }
}

class FlyoutContent extends StatelessWidget {
  final List<SpeedItem> speeds;
  final double selectedSpeed;
  final ValueChanged<double> onSpeedClick;

  const FlyoutContent({
    super.key,
    required this.speeds,
    required this.selectedSpeed,
    required this.onSpeedClick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(230),
        border: Border.all(
          color: const Color(0x809E9E9E),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: speeds.map((speed) {
          final isSelected = (speed.value - selectedSpeed).abs() < 0.01;
          return FlyoutItem(
            speed: speed,
            isSelected: isSelected,
            onClick: () => onSpeedClick(speed.value),
          );
        }).toList(),
      ),
    );
  }
}

class FlyoutItem extends StatefulWidget {
  final SpeedItem speed;
  final bool isSelected;
  final VoidCallback onClick;

  const FlyoutItem({
    super.key,
    required this.speed,
    required this.isSelected,
    required this.onClick,
  });

  @override
  State<FlyoutItem> createState() => _FlyoutItemState();
}

class _FlyoutItemState extends State<FlyoutItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const hoverBackgroundColor = Color(0x1AFFFFFF);
    const selectedTextColor = Color(0xFF2073DF);
    const defaultTextColor = Color(0xC8FFFFFF);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onClick,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? hoverBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.speed.label,
                style: TextStyle(
                  color: widget.isSelected ? selectedTextColor : defaultTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
              if (widget.isSelected)
                const Icon(
                  Icons.check,
                  color: defaultTextColor,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
