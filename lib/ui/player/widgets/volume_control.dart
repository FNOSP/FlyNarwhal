import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';

const Color _flyoutBackgroundColor = Color(0xE6000000);
const Color _flyoutBorderColor = Color(0x80808080);
const int _hideDelayMs = 200;
const int _animationDurationMs = 200;

class VolumeControl extends StatefulWidget {
  final double volume;
  final void Function(double volume) onVolumeChange;
  final void Function(bool isHovered)? onHoverStateChanged;

  const VolumeControl({
    super.key,
    required this.volume,
    required this.onVolumeChange,
    this.onHoverStateChanged,
  });

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _showPopup = false;
  bool _isButtonHovered = false;
  bool _popupHovered = false;
  Timer? _hideTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  int get _volumeLevel {
    if (widget.volume > 0.5) return 2;
    if (widget.volume > 0) return 1;
    return 0;
  }

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
          _buildVolumeIcon(),
          if (_showPopup)
            Positioned(
              bottom: 48,
              left: -8,
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

  Widget _buildVolumeIcon() {
    // Use fluent icons as fallback if lottie is not available
    final iconData = switch (_volumeLevel) {
      2 => FluentIcons.volume2,
      1 => FluentIcons.volume1,
      _ => FluentIcons.volume0,
    };

    return Icon(
      iconData,
      size: 24,
      color: Colors.white,
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
      child: _VolumeSliderFlyout(
        volume: widget.volume,
        onVolumeChange: widget.onVolumeChange,
      ),
    );
  }
}

class _VolumeSliderFlyout extends StatelessWidget {
  final double volume;
  final void Function(double) onVolumeChange;

  const _VolumeSliderFlyout({
    required this.volume,
    required this.onVolumeChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _flyoutBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _flyoutBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Volume percentage
            Text(
              '${(volume * 100).round()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Vertical slider
            SizedBox(
              width: 40,
              height: 120,
              child: _VerticalVolumeSlider(
                volume: volume,
                onVolumeChange: onVolumeChange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalVolumeSlider extends StatefulWidget {
  final double volume;
  final void Function(double) onVolumeChange;

  const _VerticalVolumeSlider({
    required this.volume,
    required this.onVolumeChange,
  });

  @override
  State<_VerticalVolumeSlider> createState() => _VerticalVolumeSliderState();
}

class _VerticalVolumeSliderState extends State<_VerticalVolumeSlider> {
  double _dragVolume = 0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final displayVolume = _isDragging ? _dragVolume : widget.volume;

    return GestureDetector(
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localPosition = details.localPosition;
        final newVolume = (1 - localPosition.dy / box.size.height).clamp(0.0, 1.0);
        widget.onVolumeChange(newVolume);
      },
      onVerticalDragStart: (details) {
        setState(() {
          _isDragging = true;
          _dragVolume = widget.volume;
        });
      },
      onVerticalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localPosition = details.localPosition;
        final newVolume = (1 - localPosition.dy / box.size.height).clamp(0.0, 1.0);
        setState(() => _dragVolume = newVolume);
        widget.onVolumeChange(newVolume);
      },
      onVerticalDragEnd: (details) {
        setState(() => _isDragging = false);
      },
      child: CustomPaint(
        size: const Size(40, 120),
        painter: _VerticalSliderPainter(
          volume: displayVolume,
        ),
      ),
    );
  }
}

class _VerticalSliderPainter extends CustomPainter {
  final double volume;

  _VerticalSliderPainter({required this.volume});

  @override
  void paint(Canvas canvas, Size size) {
    final trackXCenter = size.width / 2;
    final trackWidth = 4.0;
    final thumbRadius = 6.0;

    // Background track
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = trackWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(trackXCenter, 0),
      Offset(trackXCenter, size.height),
      bgPaint,
    );

    // Active track (blue)
    final activeHeight = volume.clamp(0.0, 1.0) * size.height;
    final activeStartY = size.height - activeHeight;

    if (activeHeight > 0) {
      final activePaint = Paint()
        ..color = const Color(0xFF3B82F6)
        ..strokeWidth = trackWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(trackXCenter, size.height),
        Offset(trackXCenter, activeStartY),
        activePaint,
      );
    }

    // Thumb (white circle)
    final thumbPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(trackXCenter, activeStartY),
      thumbRadius,
      thumbPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _VerticalSliderPainter oldDelegate) {
    return volume != oldDelegate.volume;
  }
}