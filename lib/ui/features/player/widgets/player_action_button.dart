import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

class PlayerActionButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String? tooltip;
  final String? svgAssetPath;
  final IconData? iconData;
  final String? lottieAssetPath;
  final double? lottieIdleProgress;
  final double size;
  final double iconSize;
  final Color color;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final bool animateLottieOnHover;

  const PlayerActionButton({
    super.key,
    this.onPressed,
    this.tooltip,
    this.svgAssetPath,
    this.iconData,
    this.lottieAssetPath,
    this.lottieIdleProgress,
    this.size = 30,
    this.iconSize = 22,
    this.color = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.padding = const EdgeInsets.all(4),
    this.animateLottieOnHover = true,
  }) : assert(
          (svgAssetPath != null ? 1 : 0) +
                  (iconData != null ? 1 : 0) +
                  (lottieAssetPath != null ? 1 : 0) ==
              1,
          'Exactly one icon source must be provided.',
        );

  const PlayerActionButton.svg({
    super.key,
    required String this.svgAssetPath,
    this.onPressed,
    this.tooltip,
    this.size = 30,
    this.iconSize = 22,
    this.color = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.padding = const EdgeInsets.all(4),
    this.animateLottieOnHover = true,
  })  : iconData = null,
        lottieIdleProgress = null,
        lottieAssetPath = null;

  const PlayerActionButton.icon({
    super.key,
    required IconData this.iconData,
    this.onPressed,
    this.tooltip,
    this.size = 30,
    this.iconSize = 22,
    this.color = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.padding = const EdgeInsets.all(4),
    this.animateLottieOnHover = true,
  })  : svgAssetPath = null,
        lottieIdleProgress = null,
        lottieAssetPath = null;

  const PlayerActionButton.lottie({
    super.key,
    required String this.lottieAssetPath,
    this.onPressed,
    this.tooltip,
    this.lottieIdleProgress,
    this.size = 30,
    this.iconSize = 22,
    this.color = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.padding = const EdgeInsets.all(4),
    this.animateLottieOnHover = true,
  })  : svgAssetPath = null,
        iconData = null;

  @override
  State<PlayerActionButton> createState() => _PlayerActionButtonState();
}

class _PlayerActionButtonState extends State<PlayerActionButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late final AnimationController _animationController;

  double get _idleLottieProgress {
    final configuredProgress = widget.lottieIdleProgress;
    if (configuredProgress != null) {
      return configuredProgress.clamp(0.0, 1.0);
    }
    return widget.animateLottieOnHover ? 0.0 : 1.0;
  }

  void _showIdleLottieFrame() {
    _animationController
      ..stop()
      ..value = _idleLottieProgress;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _showIdleLottieFrame();
  }

  @override
  void didUpdateWidget(covariant PlayerActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lottieAssetPath == null) return;

    final lottieSourceChanged =
        widget.lottieAssetPath != oldWidget.lottieAssetPath;
    final idleFrameChanged =
        widget.lottieIdleProgress != oldWidget.lottieIdleProgress ||
            widget.animateLottieOnHover != oldWidget.animateLottieOnHover;

    if (!lottieSourceChanged && !idleFrameChanged) return;

    if (_isHovered && widget.animateLottieOnHover && lottieSourceChanged) {
      _animationController
        ..reset()
        ..forward();
      return;
    }

    _showIdleLottieFrame();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = MouseRegion(
      cursor: widget.onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
        if (widget.lottieAssetPath != null && widget.animateLottieOnHover) {
          _animationController
            ..reset()
            ..forward();
        }
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        if (widget.lottieAssetPath != null) {
          _showIdleLottieFrame();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: widget.size,
          height: widget.size,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: widget.borderRadius,
          ),
          child: Center(child: _buildIcon()),
        ),
      ),
    );

    if (widget.tooltip == null || widget.tooltip!.isEmpty) {
      return child;
    }
    return Tooltip(message: widget.tooltip!, child: child);
  }

  Widget _buildIcon() {
    if (widget.svgAssetPath != null) {
      return SvgPicture.asset(
        widget.svgAssetPath!,
        width: widget.iconSize,
        height: widget.iconSize,
        colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
      );
    }
    if (widget.lottieAssetPath != null) {
      // Recolor both fill and stroke channels for mixed Lottie assets.
      const lottieKeyPath = ['**'];
      return SizedBox.square(
        dimension: widget.iconSize,
        child: Lottie.asset(
          widget.lottieAssetPath!,
          controller: _animationController,
          repeat: false,
          fit: BoxFit.contain,
          delegates: LottieDelegates(
            values: [
              ValueDelegate.color(
                lottieKeyPath,
                value: widget.color,
              ),
              ValueDelegate.strokeColor(
                lottieKeyPath,
                value: widget.color,
              ),
            ],
          ),
          onLoaded: (composition) {
            _animationController.duration = composition.duration;
            if (!_isHovered) {
              _showIdleLottieFrame();
            }
          },
        ),
      );
    }
    return Icon(
      widget.iconData,
      size: widget.iconSize,
      color: widget.color,
    );
  }
}
