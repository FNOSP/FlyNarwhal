import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import '../../../data/models/player_models.dart';

const Color _flyoutBackgroundColor = Color(0xE6000000);
const Color _flyoutBorderColor = Color(0x80808080);
const Color _selectedTextColor = Color(0xFF2073DF);
const Color _defaultTextColor = Color(0xC8FFFFFF);
const Color _hoverBackgroundColor = Color(0x1AFFFFFF);
const BorderRadius _flyoutBorderRadius = BorderRadius.all(Radius.circular(8));
const int _hideDelayMs = 200;
const int _animationDurationMs = 200;

class SpeedControlFlyout extends StatefulWidget {
  final double defaultSpeed;
  final int yOffset;
  final void Function(bool isHovered)? onHoverStateChanged;
  final void Function(SpeedItem speed) onSpeedSelected;

  const SpeedControlFlyout({
    super.key,
    this.defaultSpeed = 1.0,
    this.yOffset = 0,
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
  bool _showPopup = false;
  bool _isButtonHovered = false;
  bool _popupHovered = false;
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
  }

  SpeedItem _findSpeedItem(double speed) {
    return SpeedItem.defaults.firstWhere(
      (s) => s.value == speed,
      orElse: () => SpeedItem.defaults[4], // Default to 1.0x
    );
  }

  void _showFlyout() {
    _hideTimer?.cancel();
    setState(() {
      _isExpanded = true;
      _showPopup = true;
    });
    _animationController.forward();
    widget.onHoverStateChanged?.call(true);
  }

  void _hideFlyoutWithDelay() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: _hideDelayMs), () {
      if (!_isButtonHovered && !_popupHovered && mounted) {
        _animationController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _isExpanded = false;
              _showPopup = false;
            });
          }
        });
        widget.onHoverStateChanged?.call(false);
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Button text
          Text(
            _selectedSpeed.label == '1.0x' ? '倍速' : _selectedSpeed.label,
            style: TextStyle(
              color: _isButtonHovered ? Colors.white : _defaultTextColor,
              fontSize: 17,
              fontWeight: FontWeight.normal,
            ),
          ),
          // Popup
          if (_showPopup)
            Positioned(
               bottom: 0,
              left: -30,
              child: MouseRegion(
                opaque: false,
                onEnter: (_) {
                  setState(() => _popupHovered = true);
                  _hideTimer?.cancel();
                },
                onExit: (_) {
                  setState(() => _popupHovered = false);
                  _hideFlyoutWithDelay();
                },
                child: SizedBox(
                  width: 120,
                  height: widget.yOffset + 40,
                ),
              ),
            ),
          if (_showPopup)
            Positioned(
              bottom: widget.yOffset + 40,
              left: -30,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) {
                  setState(() => _popupHovered = true);
                  _hideTimer?.cancel();
                },
                onExit: (_) {
                  setState(() => _popupHovered = false);
                  _hideFlyoutWithDelay();
                },
                child: _buildAnimatedFlyout(),
              ),
            ),
        ],
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
          _animationController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _isExpanded = false;
                _showPopup = false;
              });
            }
          });
          if (!_isButtonHovered) {
            widget.onHoverStateChanged?.call(false);
          }
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
