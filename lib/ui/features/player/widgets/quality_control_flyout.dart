import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import '../../../../data/models/player_models.dart';

const Color _flyoutBackgroundColor = Color(0xE6000000);
const Color _flyoutBorderColor = Color(0x80808080);
const Color _selectedTextColor = Color(0xFF2073DF);
const Color _defaultTextColor = Color(0xC8FFFFFF);
const Color _hoverBackgroundColor = Color(0x1AFFFFFF);
const int _hideDelayMs = 200;
const int _animationDurationMs = 200;
const double _qualityFlyoutLeftOffset = -60;
const double _qualityFlyoutBridgeOffset = 40;
const double _qualityFlyoutMinBridgeWidth = 56;
const double _qualityFlyoutBridgeHorizontalPadding = 12;
const double _estimatedSimpleQualityFlyoutHeight = 220;
const double _estimatedCustomQualityFlyoutHeight = 365;

// Format bitrate to readable string
String _formatBitrateSimple(int bps) {
  if (bps < 0) return '0 bps';

  const units = ['bps', 'Kbps', 'Mbps', 'Gbps'];
  double bitrate = bps.toDouble();
  int unitIndex = 0;

  while (bitrate >= 1000 && unitIndex < units.length - 1) {
    bitrate /= 1000;
    unitIndex++;
  }

  return '${bitrate.toStringAsFixed(0)}${units[unitIndex]}';
}

String _formatResolution(String resolution) {
  if (resolution.replaceAll(RegExp(r'[0-9]'), '').isEmpty) {
    return '${resolution}p';
  }
  return resolution;
}

class QualityControlFlyout extends StatefulWidget {
  final List<QualityResponse> qualities;
  final String currentResolution;
  final int? currentBitrate;
  final int yOffset;
  final bool isActiveControl;
  final void Function(bool isHovered)? onHoverStateChanged;
  final void Function(QualityResponse quality) onQualitySelected;

  const QualityControlFlyout({
    super.key,
    required this.qualities,
    required this.currentResolution,
    this.currentBitrate,
    this.yOffset = 0,
    this.isActiveControl = false,
    this.onHoverStateChanged,
    required this.onQualitySelected,
  });

  @override
  State<QualityControlFlyout> createState() => _QualityControlFlyoutState();
}

class _QualityControlFlyoutState extends State<QualityControlFlyout>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isButtonHovered = false;
  bool _popupHovered = false;
  final GlobalKey _buttonKey = GlobalKey();
  final GlobalKey _flyoutKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Size? _flyoutSize;
  Timer? _hideTimer;
  bool _isCustomPage = false;
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
  void didUpdateWidget(QualityControlFlyout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActiveControl && !widget.isActiveControl) {
      _forceCloseFlyout();
    }
  }

  double get _currentFlyoutWidth => _isCustomPage ? 360 : 240;

  double get _estimatedFlyoutHeight =>
      _isCustomPage
          ? _estimatedCustomQualityFlyoutHeight
          : _estimatedSimpleQualityFlyoutHeight;

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

  double _calculateBridgeWidth(Size buttonSize, double flyoutWidth) {
    final preferredWidth =
        buttonSize.width + (_qualityFlyoutBridgeHorizontalPadding * 2);
    return preferredWidth.clamp(_qualityFlyoutMinBridgeWidth, flyoutWidth);
  }

  double _calculateBridgeLeft(Size buttonSize, double flyoutWidth) {
    final bridgeWidth = _calculateBridgeWidth(buttonSize, flyoutWidth);
    final buttonCenterX =
        (-_qualityFlyoutLeftOffset) + (buttonSize.width / 2);
    final desiredLeft = buttonCenterX - (bridgeWidth / 2);
    return desiredLeft.clamp(0.0, flyoutWidth - bridgeWidth);
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
        final flyoutWidth = _currentFlyoutWidth;
        final flyoutHeight = _flyoutSize?.height ?? _estimatedFlyoutHeight;
        final bridgeHeight = widget.yOffset + _qualityFlyoutBridgeOffset;
        final bridgeWidth = _calculateBridgeWidth(buttonSize, flyoutWidth);
        final bridgeLeft = _calculateBridgeLeft(buttonSize, flyoutWidth);
        final top =
            buttonOffset.dy + buttonSize.height - bridgeHeight - flyoutHeight;

        _updateFlyoutSizeAfterFrame();

        return Stack(
          children: [
            Positioned(
              left: buttonOffset.dx + _qualityFlyoutLeftOffset,
              top: top,
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
                          // Keep the flyout open only while the cursor is near
                          // the button-to-popup travel path.
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
      _isCustomPage = false;
    });
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
    setState(() {
      _isExpanded = false;
      _isCustomPage = false;
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
    final isOriginal = widget.qualities.isNotEmpty &&
        widget.qualities.first.resolution == widget.currentResolution &&
        widget.currentBitrate == widget.qualities.first.bitrate;

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
        child: Text(
          isOriginal ? '原画质' : _formatResolution(widget.currentResolution),
          style: TextStyle(
            color: _isButtonHovered ? Colors.white : _defaultTextColor,
            fontSize: 17,
            fontWeight: FontWeight.normal,
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
      child: _QualityFlyoutContent(
        qualities: widget.qualities,
        currentResolution: widget.currentResolution,
        currentBitrate: widget.currentBitrate,
        isCustomPage: _isCustomPage,
        onSwitchPage: (isCustom) {
          setState(() => _isCustomPage = isCustom);
          _overlayEntry?.markNeedsBuild();
        },
        onQualitySelected: (quality) {
          if (quality.resolution != widget.currentResolution ||
              quality.bitrate != widget.currentBitrate) {
            widget.onQualitySelected(quality);
          }
          _setPopupHovered(false);
          _closeFlyout();
        },
      ),
    );
  }
}

class _QualityFlyoutContent extends StatelessWidget {
  final List<QualityResponse> qualities;
  final String currentResolution;
  final int? currentBitrate;
  final bool isCustomPage;
  final void Function(bool isCustom) onSwitchPage;
  final void Function(QualityResponse) onQualitySelected;

  const _QualityFlyoutContent({
    required this.qualities,
    required this.currentResolution,
    required this.currentBitrate,
    required this.isCustomPage,
    required this.onSwitchPage,
    required this.onQualitySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isCustomPage ? 360 : 240,
      decoration: BoxDecoration(
        color: _flyoutBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _flyoutBorderColor),
      ),
      child: isCustomPage
          ? _CustomQualityPage(
              qualities: qualities,
              currentResolution: currentResolution,
              currentBitrate: currentBitrate,
              onBack: () => onSwitchPage(false),
              onQualitySelected: onQualitySelected,
            )
          : _SimpleQualityPage(
              qualities: qualities,
              currentResolution: currentResolution,
              currentBitrate: currentBitrate,
              onToCustom: () => onSwitchPage(true),
              onQualitySelected: onQualitySelected,
            ),
    );
  }
}

class _SimpleQualityPage extends StatelessWidget {
  final List<QualityResponse> qualities;
  final String currentResolution;
  final int? currentBitrate;
  final VoidCallback onToCustom;
  final void Function(QualityResponse) onQualitySelected;

  const _SimpleQualityPage({
    required this.qualities,
    required this.currentResolution,
    required this.currentBitrate,
    required this.onToCustom,
    required this.onQualitySelected,
  });

  @override
  Widget build(BuildContext context) {
    final originalQuality = qualities.firstOrNull;
    final grouped = _groupQualitiesByResolution(qualities);
    final distinctResolutions =
        qualities.map((q) => q.resolution).toSet().toList();

    // Check if current selection is "Custom"
    final isCustomSelection = _isCustomSelection(
      originalQuality,
      currentResolution,
      currentBitrate,
      grouped,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '视频质量',
                  style: TextStyle(
                    color: _defaultTextColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onToCustom,
                    child: Row(
                      children: [
                        const Text(
                          '自定义',
                          style:
                              TextStyle(color: _defaultTextColor, fontSize: 14),
                        ),
                        const Icon(
                          FluentIcons.chevron_right,
                          size: 16,
                          color: _defaultTextColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Custom selection item if active
          if (isCustomSelection && currentBitrate != null)
            _QualityItem(
              label: '自定义',
              rightText:
                  '${_formatResolution(currentResolution)} ${_formatBitrateSimple(currentBitrate!)}',
              isSelected: true,
              showCheck: false,
              onClick: () {},
            ),
          // Quality items
          ...distinctResolutions.map((resolution) {
            final isOriginal = originalQuality != null &&
                originalQuality.resolution == resolution &&
                resolution == qualities.first.resolution;

            final targetQuality = isOriginal
                ? qualities.first
                : (grouped[resolution]
                        ?.reduce((a, b) => a.bitrate > b.bitrate ? a : b) ??
                    qualities.first);

            final isSelected = !isCustomSelection &&
                currentResolution == resolution &&
                (isOriginal ? currentBitrate == targetQuality.bitrate : true);

            final label = isOriginal ? '原画质' : _formatResolution(resolution);
            final rightInfo = isOriginal
                ? '${_formatResolution(targetQuality.resolution)} ${_formatBitrateSimple(targetQuality.bitrate)}'
                : null;

            return _QualityItem(
              label: label,
              rightText: rightInfo,
              isSelected: isSelected,
              showCheck: false,
              onClick: () => onQualitySelected(targetQuality),
            );
          }),
        ],
      ),
    );
  }

  Map<String, List<QualityResponse>> _groupQualitiesByResolution(
      List<QualityResponse> qualities) {
    final map = <String, List<QualityResponse>>{};
    for (final q in qualities) {
      map.putIfAbsent(q.resolution, () => []).add(q);
    }
    return map;
  }

  bool _isCustomSelection(
    QualityResponse? originalQuality,
    String currentResolution,
    int? currentBitrate,
    Map<String, List<QualityResponse>> grouped,
  ) {
    if (originalQuality == null) return false;
    if (currentResolution == originalQuality.resolution &&
        currentBitrate == originalQuality.bitrate) {
      return false;
    }
    final highestForCurrentRes = grouped[currentResolution]
        ?.reduce((a, b) => a.bitrate > b.bitrate ? a : b);
    return highestForCurrentRes?.bitrate != currentBitrate;
  }
}

class _CustomQualityPage extends StatefulWidget {
  final List<QualityResponse> qualities;
  final String currentResolution;
  final int? currentBitrate;
  final VoidCallback onBack;
  final void Function(QualityResponse) onQualitySelected;

  const _CustomQualityPage({
    required this.qualities,
    required this.currentResolution,
    required this.currentBitrate,
    required this.onBack,
    required this.onQualitySelected,
  });

  @override
  State<_CustomQualityPage> createState() => _CustomQualityPageState();
}

class _CustomQualityPageState extends State<_CustomQualityPage> {
  late String _selectedResolution;

  @override
  void initState() {
    super.initState();
    _selectedResolution = widget.currentResolution;
  }

  Map<String, List<QualityResponse>> get _grouped {
    final map = <String, List<QualityResponse>>{};
    for (final q in widget.qualities) {
      map.putIfAbsent(q.resolution, () => []).add(q);
    }
    return map;
  }

  List<String> get _resolutions =>
      widget.qualities.map((q) => q.resolution).toSet().toList();

  @override
  Widget build(BuildContext context) {
    final currentQ = widget.qualities
        .where((q) =>
            q.resolution == widget.currentResolution &&
            q.bitrate == widget.currentBitrate)
        .firstOrNull;

    return SizedBox(
      height: 345,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: widget.onBack,
                      child: Row(
                        children: [
                          const Icon(
                            FluentIcons.chevron_left,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '自定义视频质量',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (currentQ != null)
                    Text(
                      '${_formatBitrateSimple(currentQ.bitrate)} - ${currentQ == widget.qualities.first ? '原画质' : _formatResolution(currentQ.resolution)}',
                      style: const TextStyle(
                          color: _selectedTextColor, fontSize: 14),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  // Left: Resolutions
                  SizedBox(
                    width: 100,
                    child: ListView.builder(
                      itemCount: _resolutions.length,
                      itemBuilder: (context, index) {
                        final res = _resolutions[index];
                        final isSelected = res == _selectedResolution;
                        return _QualityItem(
                          label: _formatResolution(res),
                          isSelected: isSelected,
                          showCheck: false,
                          showArrow: true,
                          onClick: () =>
                              setState(() => _selectedResolution = res),
                        );
                      },
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                  // Right: Bitrates
                  Expanded(
                    child: ListView.builder(
                      itemCount: _grouped[_selectedResolution]?.length ?? 0,
                      itemBuilder: (context, index) {
                        final bitrates = _grouped[_selectedResolution]!;
                        final q = bitrates[index];
                        final isOriginal = q == widget.qualities.first;
                        final label = isOriginal
                            ? '${_formatBitrateSimple(q.bitrate)} - 原画质'
                            : _formatBitrateSimple(q.bitrate);
                        final isSelected =
                            widget.currentResolution == q.resolution &&
                                widget.currentBitrate == q.bitrate;
                        return _QualityItem(
                          label: label,
                          isSelected: isSelected,
                          onClick: () => widget.onQualitySelected(q),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityItem extends StatefulWidget {
  final String label;
  final String? rightText;
  final bool isSelected;
  final bool showCheck;
  final bool showArrow;
  final VoidCallback onClick;

  const _QualityItem({
    required this.label,
    this.rightText,
    required this.isSelected,
    this.showCheck = true,
    this.showArrow = false,
    required this.onClick,
  });

  @override
  State<_QualityItem> createState() => _QualityItemState();
}

class _QualityItemState extends State<_QualityItem> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _isHovered || (widget.isSelected && !widget.showCheck)
                ? _hoverBackgroundColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected
                      ? _selectedTextColor
                      : _defaultTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
              Row(
                children: [
                  if (widget.rightText != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        widget.rightText!,
                        style: TextStyle(
                          color: widget.isSelected
                              ? _selectedTextColor
                              : _defaultTextColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  if (widget.isSelected && widget.showCheck)
                    const Icon(
                      FluentIcons.check_mark,
                      size: 20,
                      color: _selectedTextColor,
                    ),
                  if (widget.showArrow)
                    Icon(
                      FluentIcons.chevron_right,
                      size: 20,
                      color: widget.isSelected
                          ? _selectedTextColor
                          : _defaultTextColor,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
