import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../../../../tooling/driver_test_mode.dart';
import 'player_action_button.dart';

// Shared dark-flyout palette, identical to the other player control flyouts.
const Color _flyoutBackgroundColor = Color(0xCC000000);
const Color _flyoutBorderColor = Color(0x80808080);
const Color _defaultTextColor = Color(0xC8FFFFFF);
const int _hideDelayMs = 200;
const int _animationDurationMs = 200;
const double _bridgeOffset = 40;
const double _minBridgeWidth = 56;
const double _bridgeHorizontalPadding = 12;

// Matches the web player's STRM hover tip box (234×62, text-lg).
const double _tipsFlyoutWidth = 234;
const double _tipsFlyoutHeight = 62;

/// Control-bar cloud icon for STRM media. Mirrors the web player: hovering
/// the icon shows a static tip "正在直连播放 STRM 文件" instead of the
/// 网盘 播放方式 selector (STRM has no direct/proxy switch).
class StrmPlayTipsFlyout extends StatefulWidget {
  final int yOffset;
  final bool isActiveControl;
  final void Function(bool isHovered)? onHoverStateChanged;

  const StrmPlayTipsFlyout({
    super.key,
    this.yOffset = 0,
    this.isActiveControl = false,
    this.onHoverStateChanged,
  });

  @override
  State<StrmPlayTipsFlyout> createState() => _StrmPlayTipsFlyoutState();
}

class _StrmPlayTipsFlyoutState extends State<StrmPlayTipsFlyout>
    with SingleTickerProviderStateMixin {
  bool _isButtonHovered = false;
  bool _isExpanded = false;
  bool _popupHovered = false;
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
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
  void didUpdateWidget(StrmPlayTipsFlyout oldWidget) {
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

  void _setPopupHovered(bool value) {
    if (_popupHovered == value || !mounted) return;
    setState(() => _popupHovered = value);
  }

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final buttonContext = _buttonKey.currentContext;
        if (buttonContext == null) return const SizedBox.shrink();
        final renderObject = buttonContext.findRenderObject();
        if (renderObject is! RenderBox || !renderObject.hasSize) {
          return const SizedBox.shrink();
        }
        final buttonOffset = renderObject.localToGlobal(Offset.zero);
        final buttonSize = renderObject.size;
        const flyoutWidth = _tipsFlyoutWidth;
        const flyoutHeight = _tipsFlyoutHeight;
        final windowWidth = MediaQuery.of(context).size.width;
        final buttonCenterX = buttonOffset.dx + buttonSize.width / 2;
        final preferredLeft = buttonCenterX - flyoutWidth / 2;
        final maxLeft = windowWidth - flyoutWidth - 8.0;
        final left = preferredLeft > maxLeft
            ? maxLeft
            : (preferredLeft < 8.0 ? 8.0 : preferredLeft);
        final bridgeHeight = (widget.yOffset +
                _bridgeOffset -
                buttonSize.height)
            .clamp(0.0, double.infinity);
        final bridgeWidth = (buttonSize.width + _bridgeHorizontalPadding * 2)
            .clamp(_minBridgeWidth, flyoutWidth);
        final bridgeLeft = (buttonCenterX - left - (bridgeWidth / 2))
            .clamp(0.0, flyoutWidth - bridgeWidth);
        final top = buttonOffset.dy - bridgeHeight - flyoutHeight;

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: flyoutWidth,
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
                            if (!_popupHovered) _setPopupHovered(true);
                          },
                          onExit: (_) {
                            _setPopupHovered(false);
                            _hideFlyoutWithDelay();
                          },
                          child: _buildAnimatedFlyout(),
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
    // Close immediately without the reverse animation when another flyout is
    // taking over, so the leaving flyout doesn't stack on the incoming one.
    _animationController.stop();
    _animationController.value = 0;
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: kDriverTestMode
              ? () => _isExpanded ? _closeFlyout() : _showFlyout()
              : null,
          child: PlayerActionButton.svg(
            svgAssetPath: 'assets/images/strm_cloud.svg',
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
      child: Container(
        width: _tipsFlyoutWidth,
        height: _tipsFlyoutHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _flyoutBackgroundColor,
          border: Border.all(color: _flyoutBorderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '正在直连播放 STRM 文件',
          style: TextStyle(
            color: _defaultTextColor,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
