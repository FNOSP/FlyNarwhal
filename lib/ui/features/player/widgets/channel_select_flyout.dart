import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../../../../data/models/movie_detail_models.dart';
import '../../../../tooling/driver_test_mode.dart';

// Shared dark-flyout palette, identical to the other player control flyouts.
const Color _flyoutBackgroundColor = Color(0xCC000000);
const Color _flyoutBorderColor = Color(0x80808080);
const Color _selectedTextColor = Color(0xFF3B82F6);
const Color _hoverBackgroundColor = Color(0x1AFFFFFF);
const int _hideDelayMs = 200;
const int _animationDurationMs = 200;
const double _bridgeOffset = 12;
const double _flyoutWidth = 168;
const double _flyoutMaxHeight = 320;

/// Live-channel line selector, mirroring the other player control flyouts:
/// the flyout opens on hover over the channel-name button and closes when the
/// cursor leaves both the button and the popup (with a short grace delay and a
/// "bridge" hover zone along the travel path). It also reuses the same
/// `isActiveControl` + `onHoverStateChanged` contract so hovering onto another
/// menu button closes this one synchronously.
class ChannelSelectFlyout extends StatefulWidget {
  final List<LiveChannelSource> channels;
  final int selectedIndex;
  final bool isActiveControl;
  final void Function(bool isHovered)? onHoverStateChanged;
  final void Function(int index) onChannelSelected;

  const ChannelSelectFlyout({
    super.key,
    required this.channels,
    required this.selectedIndex,
    this.isActiveControl = false,
    this.onHoverStateChanged,
    required this.onChannelSelected,
  });

  @override
  State<ChannelSelectFlyout> createState() => _ChannelSelectFlyoutState();
}

class _ChannelSelectFlyoutState extends State<ChannelSelectFlyout>
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
  void didUpdateWidget(ChannelSelectFlyout oldWidget) {
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
      builder: (context) {
        final buttonContext = _buttonKey.currentContext;
        if (buttonContext == null) return const SizedBox.shrink();
        final renderObject = buttonContext.findRenderObject();
        // The button can be deactivated (e.g. bottom bar removed on PiP enter or
        // route leave) before this entry is unmounted; skip positioning then.
        if (renderObject is! RenderBox ||
            !renderObject.hasSize ||
            !renderObject.attached) {
          return const SizedBox.shrink();
        }
        final buttonOffset = renderObject.localToGlobal(Offset.zero);
        final buttonSize = renderObject.size;
        final flyoutHeight = (_flyoutSize?.height ?? _estimatedFlyoutHeight)
            .clamp(0.0, _flyoutMaxHeight);
        final windowWidth = MediaQuery.of(context).size.width;
        // Horizontally centered above the button (like the other player
        // flyouts), clamped to stay inside the window.
        final buttonCenterX = buttonOffset.dx + buttonSize.width / 2;
        final preferredLeft = buttonCenterX - _flyoutWidth / 2;
        final maxLeft = windowWidth - _flyoutWidth - 8.0;
        final left = preferredLeft > maxLeft
            ? maxLeft
            : (preferredLeft < 8.0 ? 8.0 : preferredLeft);
        final bridgeHeight = _bridgeOffset;
        final top = buttonOffset.dy - bridgeHeight - flyoutHeight;

        _updateFlyoutSizeAfterFrame();

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Listener(
                behavior: HitTestBehavior.opaque,
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
                        left: 0,
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
                            width: _flyoutWidth,
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

  double get _estimatedFlyoutHeight {
    // Header + per-item heights (8px vertical padding each) + footer, capped.
    return 32.0 + (widget.channels.length * 34.0) + 6.0;
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

  void _forceCloseFlyout() {
    _hideTimer?.cancel();
    if (!_isExpanded) return;
    _isButtonHovered = false;
    _popupHovered = false;
    // Runs from didUpdateWidget, i.e. during the build phase: only stop the
    // ticker without notifying listeners. Resetting the controller value here
    // would setState the flyout's AnimatedBuilder (mounted in the root
    // overlay, outside the current build scope) and throw mid-build. The
    // value is reset by forward(from: 0) the next time the flyout opens.
    _animationController.stop();
    _hideOverlay();
    setState(() => _isExpanded = false);
    _notifyHoveredAfterFrame(false);
  }

  /// Delivers a hover-state change after the current frame, so consumers can
  /// safely modify providers (force-close runs during the build phase).
  void _notifyHoveredAfterFrame(bool hovered) {
    final callback = widget.onHoverStateChanged;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Skip if the flyout reopened in the meantime; a stale close
      // notification would clobber the fresh hover state.
      if (!mounted || _isExpanded) return;
      callback(hovered);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentChannel = widget.channels.isEmpty
        ? null
        : widget.channels[widget.selectedIndex];

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
          // Hover shows the flyout on desktop; the tap fallback only exists
          // for driver builds, whose synthetic taps carry no hover events.
          onTap: kDriverTestMode
              ? () => _isExpanded ? _closeFlyout() : _showFlyout()
              : null,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _isButtonHovered
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              currentChannel?.fileName ?? '线路',
              style: const TextStyle(color: Colors.white, fontSize: 14),
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
      child: _ChannelFlyoutContent(
        channels: widget.channels,
        selectedIndex: widget.selectedIndex,
        onChannelSelected: (index) {
          _setPopupHovered(false);
          _closeFlyout();
          widget.onChannelSelected(index);
        },
      ),
    );
  }
}

class _ChannelFlyoutContent extends StatelessWidget {
  final List<LiveChannelSource> channels;
  final int selectedIndex;
  final void Function(int index) onChannelSelected;

  const _ChannelFlyoutContent({
    required this.channels,
    required this.selectedIndex,
    required this.onChannelSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _flyoutWidth,
      constraints: const BoxConstraints(maxHeight: _flyoutMaxHeight),
      decoration: BoxDecoration(
        color: _flyoutBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _flyoutBorderColor),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '线路',
                  style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
                ),
              ),
            ),
            ...List.generate(channels.length, (index) {
              final channel = channels[index];
              final isSelected = index == selectedIndex;
              return _ChannelFlyoutItem(
                key: ValueKey('live-channel-item-$index'),
                label: channel.fileName,
                isSelected: isSelected,
                onTap: () => onChannelSelected(index),
              );
            }),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _ChannelFlyoutItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChannelFlyoutItem({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ChannelFlyoutItem> createState() => _ChannelFlyoutItemState();
}

class _ChannelFlyoutItemState extends State<_ChannelFlyoutItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered || widget.isSelected
                ? _hoverBackgroundColor
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isSelected
                        ? _selectedTextColor
                        : Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              if (widget.isSelected)
                const Icon(
                  FluentIcons.check_mark,
                  size: 14,
                  color: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}