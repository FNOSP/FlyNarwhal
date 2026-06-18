import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/scheduler.dart';
import 'player_action_button.dart';

const Color _flyoutBackgroundColor = Color(0xE6000000);
const Color _flyoutBorderColor = Color(0x80808080);
const int _hideDelayMs = 200;
const int _animationDurationMs = 200;
const double _flyoutLeftOffset = -8;
const double _flyoutBridgeOffset = 40;
const double _flyoutWidth = 46;
const double _estimatedFlyoutHeight = 166;

class VolumeControl extends StatefulWidget {
  final double volume;
  final double popupBottomOffset;
  final void Function(double volume) onVolumeChange;
  final void Function(bool isHovered)? onHoverStateChanged;

  const VolumeControl({
    super.key,
    required this.volume,
    this.popupBottomOffset = 48,
    required this.onVolumeChange,
    this.onHoverStateChanged,
  });

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isButtonHovered = false;
  bool _popupHovered = false;
  final GlobalKey _buttonKey = GlobalKey();
  final GlobalKey _flyoutKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Size? _flyoutSize;
  Timer? _hideTimer;
  bool _overlayRebuildScheduled = false;
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

  @override
  void didUpdateWidget(VolumeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volume != widget.volume ||
        oldWidget.popupBottomOffset != widget.popupBottomOffset) {
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
        final bridgeHeight = _safePopupBottomOffset + _flyoutBridgeOffset;
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

    _hideOverlay();
    if (!mounted) return;

    setState(() => _isExpanded = false);
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _buildVolumeIcon(),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeIcon() {
    final assetPath = switch (_volumeLevel) {
      2 => 'assets/lottie/volume_high_lottie.json',
      1 => 'assets/lottie/volume_low_lottie.json',
      _ => 'assets/lottie/volume_off_lottie.json',
    };

    return PlayerActionButton.lottie(
      key: ValueKey(assetPath),
      lottieAssetPath: assetPath,
      lottieIdleProgress: 0.5,
      size: 30,
      iconSize: 22,
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
              key: const ValueKey('player-volume-slider'),
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
  bool _isWaitingForExternalSync = false;

  @override
  void didUpdateWidget(covariant _VerticalVolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDragging && widget.volume != oldWidget.volume) {
      _dragVolume = widget.volume;
    }
    if (_isWaitingForExternalSync &&
        (widget.volume - _dragVolume).abs() < 0.0001) {
      _isWaitingForExternalSync = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayVolume = (_isDragging || _isWaitingForExternalSync)
        ? _dragVolume
        : widget.volume;

    return GestureDetector(
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localPosition = details.localPosition;
        final newVolume =
            (1 - localPosition.dy / box.size.height).clamp(0.0, 1.0);
        widget.onVolumeChange(newVolume);
      },
      onVerticalDragStart: (details) {
        setState(() {
          _isDragging = true;
          _isWaitingForExternalSync = false;
          _dragVolume = widget.volume;
        });
      },
      onVerticalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localPosition = details.localPosition;
        final newVolume =
            (1 - localPosition.dy / box.size.height).clamp(0.0, 1.0);
        setState(() => _dragVolume = newVolume);
        widget.onVolumeChange(newVolume);
      },
      onVerticalDragEnd: (details) {
        setState(() {
          _isDragging = false;
          _isWaitingForExternalSync = true;
        });
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
    const trackWidth = 4.0;
    const thumbRadius = 6.0;

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
