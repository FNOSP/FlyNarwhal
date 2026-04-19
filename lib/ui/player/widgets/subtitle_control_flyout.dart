import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../data/models/movie_detail_models.dart';

const Color _subtitleFlyoutBackgroundColor = Color(0xE6000000);
const Color _subtitleFlyoutBorderColor = Color(0x80808080);
const Color _subtitleSelectedTextColor = Color(0xFF2073DF);
const Color _subtitleDefaultTextColor = Color(0xC8FFFFFF);
const Color _subtitleHoverBackgroundColor = Color(0x1AFFFFFF);
const int _subtitleHideDelayMs = 200;
const int _subtitleAnimationDurationMs = 200;
const double _subtitleFlyoutWidth = 250;
const double _subtitleFlyoutLeftOffset = -190;
const double _subtitleFlyoutBridgeOffset = 40;
const double _subtitleFlyoutMinBridgeWidth = 56;
const double _subtitleFlyoutBridgeHorizontalPadding = 12;
const double _estimatedSubtitleFlyoutHeight = 220;

class SubtitleControlFlyout extends StatefulWidget {
  final List<SubtitleStream> subtitles;
  final String? selectedSubtitleGuid;
  final int yOffset;
  final bool isActiveControl;
  final void Function(String?) onSubtitleSelected;
  final void Function(bool)? onHoverStateChanged;

  const SubtitleControlFlyout({
    super.key,
    required this.subtitles,
    required this.selectedSubtitleGuid,
    this.yOffset = 0,
    this.isActiveControl = false,
    required this.onSubtitleSelected,
    this.onHoverStateChanged,
  });

  @override
  State<SubtitleControlFlyout> createState() => _SubtitleControlFlyoutState();
}

class _SubtitleControlFlyoutState extends State<SubtitleControlFlyout>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isButtonHovered = false;
  bool _popupHovered = false;
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
    _animationController = AnimationController(
      duration: const Duration(milliseconds: _subtitleAnimationDurationMs),
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
  void didUpdateWidget(SubtitleControlFlyout oldWidget) {
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

  double _calculateBridgeWidth(Size buttonSize) {
    final preferredWidth =
        buttonSize.width + (_subtitleFlyoutBridgeHorizontalPadding * 2);
    return preferredWidth.clamp(
      _subtitleFlyoutMinBridgeWidth,
      _subtitleFlyoutWidth,
    );
  }

  double _calculateBridgeLeft(Size buttonSize) {
    final bridgeWidth = _calculateBridgeWidth(buttonSize);
    final buttonCenterX =
        (-_subtitleFlyoutLeftOffset) + (buttonSize.width / 2);
    final desiredLeft = buttonCenterX - (bridgeWidth / 2);
    return desiredLeft.clamp(0.0, _subtitleFlyoutWidth - bridgeWidth);
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

        final buttonOffset = renderObject.localToGlobal(Offset.zero);
        final buttonSize = renderObject.size;
        final flyoutHeight = _flyoutSize?.height ?? _estimatedSubtitleFlyoutHeight;
        final bridgeHeight = widget.yOffset + _subtitleFlyoutBridgeOffset;
        final bridgeWidth = _calculateBridgeWidth(buttonSize);
        final bridgeLeft = _calculateBridgeLeft(buttonSize);
        final top =
            buttonOffset.dy + buttonSize.height - bridgeHeight - flyoutHeight;

        _updateFlyoutSizeAfterFrame();

        return Stack(
          children: [
            Positioned(
              left: buttonOffset.dx + _subtitleFlyoutLeftOffset,
              top: top,
              child: SizedBox(
                width: _subtitleFlyoutWidth,
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
                          // Keep the flyout open only along the necessary path
                          // between the trigger button and the popup body.
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
    _hideTimer = Timer(const Duration(milliseconds: _subtitleHideDelayMs), () {
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
        child: SvgPicture.asset(
          'assets/images/subtitle.svg',
          width: 22,
          height: 22,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
      child: _SubtitleFlyoutContent(
        subtitles: widget.subtitles,
        selectedSubtitleGuid: widget.selectedSubtitleGuid,
        onSubtitleSelected: (guid) {
          widget.onSubtitleSelected(guid);
          _setPopupHovered(false);
          _closeFlyout();
        },
      ),
    );
  }
}

class _SubtitleFlyoutContent extends StatelessWidget {
  final List<SubtitleStream> subtitles;
  final String? selectedSubtitleGuid;
  final void Function(String?) onSubtitleSelected;

  const _SubtitleFlyoutContent({
    required this.subtitles,
    required this.selectedSubtitleGuid,
    required this.onSubtitleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: _subtitleFlyoutBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _subtitleFlyoutBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SubtitleItem(
              title: '无字幕',
              subtitle: '关闭当前字幕',
              isSelected:
                  selectedSubtitleGuid == null || selectedSubtitleGuid!.isEmpty,
              onTap: () => onSubtitleSelected(null),
            ),
            ...subtitles.map((subtitle) {
              final label = _buildLabel(subtitle);
              return _SubtitleItem(
                title: label,
                subtitle: subtitle.codecName.toUpperCase(),
                isSelected: selectedSubtitleGuid == subtitle.guid,
                onTap: () => onSubtitleSelected(subtitle.guid),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _buildLabel(SubtitleStream subtitle) {
    final language =
        subtitle.language.isNotEmpty ? subtitle.language.toUpperCase() : 'SUB';
    if (subtitle.isExternal == 1) {
      return '$language 外挂';
    }
    return subtitle.title.isNotEmpty ? subtitle.title : language;
  }
}

class _SubtitleItem extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubtitleItem({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SubtitleItem> createState() => _SubtitleItemState();
}

class _SubtitleItemState extends State<_SubtitleItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _isHovered || widget.isSelected
                ? _subtitleHoverBackgroundColor
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.isSelected
                            ? _subtitleSelectedTextColor
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: _subtitleDefaultTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isSelected)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    FluentIcons.check_mark,
                    size: 14,
                    color: _subtitleSelectedTextColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
