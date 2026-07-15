import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../data/models/movie_detail_models.dart';
import '../../../../data/models/player_models.dart';
import '../../../../data/utils/fn_data_convertor.dart';

const Color _subtitleFlyoutBackgroundColor = Color(0xCC000000);
const Color _subtitleFlyoutBorderColor = Color(0x80808080);
const Color _subtitleSelectedTextColor = Color(0xFF2073DF);
const Color _subtitleDefaultTextColor = Color(0xC8FFFFFF);
const Color _subtitleHoverBackgroundColor = Color(0x1AFFFFFF);
const int _subtitleHideDelayMs = 200;
const int _subtitleAnimationDurationMs = 200;
const double _subtitleFlyoutWidth = 320;
const double _subtitleFlyoutBridgeOffset = 40;
const double _subtitleFlyoutMinBridgeWidth = 56;
const double _subtitleFlyoutBridgeHorizontalPadding = 12;
const double _subtitleFlyoutPanelHeight = 390;
const double _estimatedSubtitleFlyoutHeight = _subtitleFlyoutPanelHeight;
const double _subtitleFlyoutItemExtent = 72;
const double _subtitleSliderCenterSnapThreshold = 0.08;

class SubtitleControlFlyout extends StatefulWidget {
  final List<SubtitleStream> subtitles;
  final String? selectedSubtitleGuid;
  final Map<String, String> iso6391Map;
  final Map<String, String> iso6392Map;
  final SubtitleSettings subtitleSettings;
  final bool canAdjustSubtitle;
  final bool isPositionLocked;
  final int yOffset;
  final bool isActiveControl;
  final void Function(SubtitleSettings) onSubtitleSettingsChanged;
  final void Function(String?) onSubtitleSelected;
  final VoidCallback onOpenSubtitleSearch;
  final VoidCallback onOpenAddNasSubtitle;
  final VoidCallback onOpenAddLocalSubtitle;
  final void Function(bool)? onHoverStateChanged;
  final void Function(SubtitleStream)? onRequestDelete;

  const SubtitleControlFlyout({
    super.key,
    required this.subtitles,
    required this.selectedSubtitleGuid,
    required this.iso6391Map,
    required this.iso6392Map,
    required this.subtitleSettings,
    required this.canAdjustSubtitle,
    this.isPositionLocked = false,
    this.yOffset = 0,
    this.isActiveControl = false,
    required this.onSubtitleSettingsChanged,
    required this.onSubtitleSelected,
    required this.onOpenSubtitleSearch,
    required this.onOpenAddNasSubtitle,
    required this.onOpenAddLocalSubtitle,
    this.onHoverStateChanged,
    this.onRequestDelete,
  });

  @override
  State<SubtitleControlFlyout> createState() => _SubtitleControlFlyoutState();
}

class _SubtitleControlFlyoutState extends State<SubtitleControlFlyout>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isButtonHovered = false;
  bool _popupHovered = false;
  bool _isAdjustmentMode = false;
  bool _isAddMenuExpanded = false;
  late SubtitleSettings _liveSubtitleSettings;
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
    _liveSubtitleSettings = widget.subtitleSettings;
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
  void didUpdateWidget(covariant SubtitleControlFlyout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActiveControl && !widget.isActiveControl) {
      unawaited(_forceCloseFlyout());
      return;
    }

    final shouldSyncLiveSubtitleSettings = _areSubtitleSettingsEqual(
      _liveSubtitleSettings,
      oldWidget.subtitleSettings,
    );
    if (shouldSyncLiveSubtitleSettings &&
        !_areSubtitleSettingsEqual(
          oldWidget.subtitleSettings,
          widget.subtitleSettings,
        )) {
      _liveSubtitleSettings = widget.subtitleSettings;
    }

    final shouldRefreshOverlay = _overlayEntry != null &&
        _isExpanded &&
        (shouldSyncLiveSubtitleSettings &&
                !_areSubtitleSettingsEqual(
                  oldWidget.subtitleSettings,
                  widget.subtitleSettings,
                ) ||
            oldWidget.subtitles != widget.subtitles ||
            oldWidget.selectedSubtitleGuid != widget.selectedSubtitleGuid ||
            oldWidget.canAdjustSubtitle != widget.canAdjustSubtitle ||
            oldWidget.iso6391Map != widget.iso6391Map ||
            oldWidget.iso6392Map != widget.iso6392Map);

    if (shouldRefreshOverlay) {
      _scheduleOverlayRebuild();
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

  void _updateOverlayState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
    _overlayEntry?.markNeedsBuild();
  }

  void _scheduleOverlayRebuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayEntry == null) return;
      _overlayEntry?.markNeedsBuild();
    });
  }

  bool _areSubtitleSettingsEqual(
    SubtitleSettings left,
    SubtitleSettings right,
  ) {
    return left.offsetSeconds == right.offsetSeconds &&
        left.verticalPosition == right.verticalPosition &&
        left.fontScale == right.fontScale &&
        left.fontSize == right.fontSize &&
        left.fontColor == right.fontColor &&
        left.backgroundColor == right.backgroundColor;
  }

  void _handleSubtitleSettingsChanged(SubtitleSettings settings) {
    _updateOverlayState(() {
      _liveSubtitleSettings = settings;
    });
    widget.onSubtitleSettingsChanged(settings);
  }

  double _calculateBridgeWidth(Size buttonSize) {
    final preferredWidth =
        buttonSize.width + (_subtitleFlyoutBridgeHorizontalPadding * 2);
    return preferredWidth.clamp(
      _subtitleFlyoutMinBridgeWidth,
      _subtitleFlyoutWidth,
    );
  }

  double _calculateBridgeLeft(Size buttonSize, double flyoutLeft) {
    final bridgeWidth = _calculateBridgeWidth(buttonSize);
    final buttonCenterX = buttonSize.width / 2 - flyoutLeft;
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

        final overlaySize = MediaQuery.of(context).size;
        final buttonOffset = renderObject.localToGlobal(Offset.zero);
        final buttonSize = renderObject.size;
        final flyoutHeight =
            _flyoutSize?.height ?? _estimatedSubtitleFlyoutHeight;
        final bridgeHeight = widget.yOffset + _subtitleFlyoutBridgeOffset;
        final flyoutLeft = (buttonSize.width - _subtitleFlyoutWidth) / 2;
        final left = (buttonOffset.dx + flyoutLeft)
            .clamp(8.0, overlaySize.width - _subtitleFlyoutWidth - 8.0);
        final bridgeWidth = _calculateBridgeWidth(buttonSize);
        final bridgeLeft = _calculateBridgeLeft(
          buttonSize,
          left - buttonOffset.dx,
        );
        final top =
            buttonOffset.dy + buttonSize.height - bridgeHeight - flyoutHeight;

        _updateFlyoutSizeAfterFrame();

        return Stack(
          children: [
            Positioned(
              left: left,
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
                        child: KeyedSubtree(
                          key: _flyoutKey,
                          child: _buildAnimatedFlyout(),
                        ),
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
      _liveSubtitleSettings = widget.subtitleSettings;
    });
    _showOverlay();
    _animationController.forward(from: 0);
    widget.onHoverStateChanged?.call(true);
  }

  void _hideFlyoutWithDelay() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: _subtitleHideDelayMs), () {
      if (!_isButtonHovered && !_popupHovered && mounted) {
        unawaited(_closeFlyout());
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
      _isAdjustmentMode = false;
      _isAddMenuExpanded = false;
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
      _isAdjustmentMode = false;
      _isAddMenuExpanded = false;
    });
    widget.onHoverStateChanged?.call(false);
  }

  void _closeAfterAction() {
    _setPopupHovered(false);
    unawaited(_closeFlyout());
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
      child: _isAdjustmentMode
          ? _SubtitleAdjustmentPanel(
              settings: _liveSubtitleSettings,
              isPositionLocked: widget.isPositionLocked,
              onBack: () =>
                  _updateOverlayState(() => _isAdjustmentMode = false),
              onSettingsChanged: _handleSubtitleSettingsChanged,
            )
          : _SubtitleFlyoutContent(
              subtitles: widget.subtitles,
              selectedSubtitleGuid: widget.selectedSubtitleGuid,
              iso6391Map: widget.iso6391Map,
              iso6392Map: widget.iso6392Map,
              canAdjustSubtitle: widget.canAdjustSubtitle,
              isAddMenuExpanded: _isAddMenuExpanded,
              onAddMenuExpandedChanged: (expanded) =>
                  _updateOverlayState(() => _isAddMenuExpanded = expanded),
              onAdjustmentClicked: () => _updateOverlayState(() {
                _liveSubtitleSettings = widget.subtitleSettings;
                _isAdjustmentMode = true;
                _isAddMenuExpanded = false;
              }),
              onSubtitleSelected: (guid) {
                widget.onSubtitleSelected(guid);
              },
              onOpenSubtitleSearch: () {
                widget.onOpenSubtitleSearch();
                _closeAfterAction();
              },
              onOpenAddNasSubtitle: () {
                widget.onOpenAddNasSubtitle();
                _closeAfterAction();
              },
              onOpenAddLocalSubtitle: () {
                widget.onOpenAddLocalSubtitle();
                _closeAfterAction();
              },
              onRequestDelete: widget.onRequestDelete,
            ),
    );
  }
}

class _SubtitleFlyoutContent extends StatefulWidget {
  final List<SubtitleStream> subtitles;
  final String? selectedSubtitleGuid;
  final Map<String, String> iso6391Map;
  final Map<String, String> iso6392Map;
  final bool canAdjustSubtitle;
  final bool isAddMenuExpanded;
  final ValueChanged<bool> onAddMenuExpandedChanged;
  final VoidCallback onAdjustmentClicked;
  final ValueChanged<String?> onSubtitleSelected;
  final VoidCallback onOpenSubtitleSearch;
  final VoidCallback onOpenAddNasSubtitle;
  final VoidCallback onOpenAddLocalSubtitle;
  final ValueChanged<SubtitleStream>? onRequestDelete;

  const _SubtitleFlyoutContent({
    required this.subtitles,
    required this.selectedSubtitleGuid,
    required this.iso6391Map,
    required this.iso6392Map,
    required this.canAdjustSubtitle,
    required this.isAddMenuExpanded,
    required this.onAddMenuExpandedChanged,
    required this.onAdjustmentClicked,
    required this.onSubtitleSelected,
    required this.onOpenSubtitleSearch,
    required this.onOpenAddNasSubtitle,
    required this.onOpenAddLocalSubtitle,
    required this.onRequestDelete,
  });

  @override
  State<_SubtitleFlyoutContent> createState() => _SubtitleFlyoutContentState();
}

class _SubtitleFlyoutContentState extends State<_SubtitleFlyoutContent> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleScrollToSelection();
  }

  @override
  void didUpdateWidget(covariant _SubtitleFlyoutContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubtitleGuid != widget.selectedSubtitleGuid ||
        oldWidget.subtitles != widget.subtitles) {
      _scheduleScrollToSelection();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollToSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final selectedIndex = widget.selectedSubtitleGuid == null ||
              widget.selectedSubtitleGuid!.isEmpty
          ? 0
          : widget.subtitles.indexWhere(
                (subtitle) => subtitle.guid == widget.selectedSubtitleGuid,
              ) +
              1;
      final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;
      final targetOffset = safeIndex * _subtitleFlyoutItemExtent;
      final maxOffset = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(targetOffset.clamp(0.0, maxOffset));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _subtitleFlyoutWidth,
      height: _subtitleFlyoutPanelHeight,
      decoration: BoxDecoration(
        color: _subtitleFlyoutBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _subtitleFlyoutBorderColor),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                _SubtitleFlyoutHeader(
                  canAdjustSubtitle: widget.canAdjustSubtitle,
                  isAddMenuExpanded: widget.isAddMenuExpanded,
                  onAdjustmentClicked: widget.onAdjustmentClicked,
                  onAddMenuExpandedChanged: widget.onAddMenuExpandedChanged,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(size: 1),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      itemExtent: _subtitleFlyoutItemExtent,
                      itemCount: widget.subtitles.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _SubtitleItem(
                            title: '关闭',
                            subtitle: '',
                            isSelected: widget.selectedSubtitleGuid == null ||
                                widget.selectedSubtitleGuid!.isEmpty,
                            onTap: () => widget.onSubtitleSelected(null),
                          );
                        }

                        final subtitle = widget.subtitles[index - 1];
                        return _SubtitleItem(
                          title: _buildTitle(subtitle),
                          subtitle: _buildSubtitle(subtitle),
                          isSelected:
                              widget.selectedSubtitleGuid == subtitle.guid,
                          isExternal: subtitle.isExternal == 1,
                          onDelete: widget.onRequestDelete == null
                              ? null
                              : () => widget.onRequestDelete!.call(subtitle),
                          onTap: () => widget.onSubtitleSelected(subtitle.guid),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.isAddMenuExpanded)
            Positioned(
              top: 48,
              right: 12,
              child: _SubtitleAddMenu(
                onSearch: widget.onOpenSubtitleSearch,
                onAddNas: widget.onOpenAddNasSubtitle,
                onAddLocal: widget.onOpenAddLocalSubtitle,
              ),
            ),
        ],
      ),
    );
  }

  String _buildTitle(SubtitleStream subtitle) {
    final languageName = FnDataConvertor.getLanguageName(
      subtitle.language,
      widget.iso6391Map,
      widget.iso6392Map,
    );
    final buffer = StringBuffer(languageName);
    if (subtitle.isExternal == 1) {
      buffer.write(' - 外挂');
    }
    if (subtitle.isDefault == 1) {
      buffer.write(' - 默认');
    }
    return buffer.toString();
  }

  String _buildSubtitle(SubtitleStream subtitle) {
    final parts = <String>[
      subtitle.format.toUpperCase(),
      if (subtitle.title.isNotEmpty) subtitle.title,
    ];
    return parts.join('  ');
  }
}

class _SubtitleFlyoutHeader extends StatelessWidget {
  final bool canAdjustSubtitle;
  final bool isAddMenuExpanded;
  final VoidCallback onAdjustmentClicked;
  final ValueChanged<bool> onAddMenuExpandedChanged;

  const _SubtitleFlyoutHeader({
    required this.canAdjustSubtitle,
    required this.isAddMenuExpanded,
    required this.onAdjustmentClicked,
    required this.onAddMenuExpandedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '字幕',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _HeaderPillButton(
          label: '调整',
          enabled: canAdjustSubtitle,
          onPressed: onAdjustmentClicked,
        ),
        const SizedBox(width: 8),
        _HeaderPillButton(
          label: '添加',
          trailing: Icon(
            isAddMenuExpanded
                ? FluentIcons.chevron_up_small
                : FluentIcons.chevron_down_small,
            size: 12,
            color: _subtitleDefaultTextColor,
          ),
          onPressed: () => onAddMenuExpandedChanged(!isAddMenuExpanded),
        ),
      ],
    );
  }
}

class _HeaderPillButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final Widget? trailing;
  final VoidCallback onPressed;

  const _HeaderPillButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.trailing,
  });

  @override
  State<_HeaderPillButton> createState() => _HeaderPillButtonState();
}

class _HeaderPillButtonState extends State<_HeaderPillButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1 : 0.4,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onPressed : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isHovered
                  ? _subtitleHoverBackgroundColor
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _subtitleFlyoutBorderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: _subtitleDefaultTextColor,
                    fontSize: 12,
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 4),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtitleAddMenu extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onAddNas;
  final VoidCallback onAddLocal;

  const _SubtitleAddMenu({
    required this.onSearch,
    required this.onAddNas,
    required this.onAddLocal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: _subtitleFlyoutBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _subtitleFlyoutBorderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SubtitleAddMenuItem(
            label: '搜索字幕',
            icon: FluentIcons.search,
            onTap: onSearch,
          ),
          _SubtitleAddMenuItem(
            label: '添加 NAS 字幕文件',
            icon: FluentIcons.storage_optical,
            onTap: onAddNas,
          ),
          _SubtitleAddMenuItem(
            label: '添加电脑字幕文件',
            icon: FluentIcons.devices3,
            onTap: onAddLocal,
          ),
        ],
      ),
    );
  }
}

class _SubtitleAddMenuItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SubtitleAddMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_SubtitleAddMenuItem> createState() => _SubtitleAddMenuItemState();
}

class _SubtitleAddMenuItemState extends State<_SubtitleAddMenuItem> {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                _isHovered ? _subtitleHoverBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtitleAdjustmentPanel extends StatelessWidget {
  final SubtitleSettings settings;
  final bool isPositionLocked;
  final ValueChanged<SubtitleSettings> onSettingsChanged;
  final VoidCallback onBack;

  const _SubtitleAdjustmentPanel({
    required this.settings,
    required this.onSettingsChanged,
    required this.onBack,
    this.isPositionLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _subtitleFlyoutWidth,
      height: _subtitleFlyoutPanelHeight,
      decoration: BoxDecoration(
        color: _subtitleFlyoutBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _subtitleFlyoutBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(FluentIcons.back, size: 12),
                  onPressed: onBack,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '调整字幕',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _HeaderPillButton(
                  label: '重置',
                  onPressed: () => onSettingsChanged(const SubtitleSettings()),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(size: 1),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AdjustmentSliderSection(
                    title: '偏移',
                    value: settings.offsetSeconds,
                    min: -5,
                    max: 5,
                    leftLabel: '-5秒',
                    rightLabel: '+5秒',
                    suffix: '秒',
                    showCenterMarker: true,
                    snapToCenter: true,
                    centerValue: 0,
                    snapThreshold: _subtitleSliderCenterSnapThreshold,
                    onChanged: (value) => onSettingsChanged(
                      settings.copyWith(offsetSeconds: value),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AdjustmentSliderSection(
                    title: '位置',
                    value: settings.verticalPosition,
                    min: 0,
                    max: 1,
                    leftLabel: '底部',
                    rightLabel: '顶部',
                    enabled: !isPositionLocked,
                    disabledHint:
                        isPositionLocked ? '当前字幕为弹幕/特效字幕（含定位标签），位置调整不可用' : null,
                    showCenterMarker: true,
                    snapToCenter: true,
                    centerValue: 0.5,
                    snapThreshold: 0.04,
                    onChanged: (value) => onSettingsChanged(
                      settings.copyWith(verticalPosition: value),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AdjustmentSliderSection(
                    title: '字号',
                    value: settings.fontScale,
                    min: 0.5,
                    max: 1.5,
                    leftLabel: '最小',
                    rightLabel: '最大',
                    showCenterMarker: true,
                    snapToCenter: true,
                    centerValue: 1.0,
                    snapThreshold: 0.04,
                    onChanged: (value) => onSettingsChanged(
                      settings.copyWith(
                        fontScale: value,
                        fontSize: 24.0 * value,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustmentSliderSection extends StatefulWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final String leftLabel;
  final String rightLabel;
  final String? suffix;
  final bool enabled;
  final String? disabledHint;
  final bool showCenterMarker;
  final bool snapToCenter;
  final double? centerValue;
  final double snapThreshold;
  final ValueChanged<double> onChanged;

  const _AdjustmentSliderSection({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.leftLabel,
    required this.rightLabel,
    required this.onChanged,
    this.suffix,
    this.enabled = true,
    this.disabledHint,
    this.showCenterMarker = false,
    this.snapToCenter = false,
    this.centerValue,
    this.snapThreshold = 0,
  });

  @override
  State<_AdjustmentSliderSection> createState() =>
      _AdjustmentSliderSectionState();
}

class _AdjustmentSliderSectionState extends State<_AdjustmentSliderSection> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(covariant _AdjustmentSliderSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = _format(widget.value);
    if (_controller.text != nextText) {
      _controller.text = nextText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _centerValue {
    return widget.centerValue ?? ((widget.min + widget.max) / 2);
  }

  double get _centerMarkerAlignment {
    final range = widget.max - widget.min;
    if (range == 0) return 0;
    final normalized = ((_centerValue - widget.min) / range).clamp(0.0, 1.0);
    return (normalized * 2) - 1;
  }

  String _format(double value) {
    final normalizedValue = _snapValue(value);
    if (normalizedValue == normalizedValue.roundToDouble()) {
      return normalizedValue.round().toString();
    }
    return normalizedValue.toStringAsFixed(1);
  }

  double _clampValue(double value) {
    return value.clamp(widget.min, widget.max);
  }

  double _snapValue(double value) {
    final clampedValue = _clampValue(value);
    if (!widget.snapToCenter || widget.snapThreshold <= 0) {
      return clampedValue;
    }
    if ((clampedValue - _centerValue).abs() <= widget.snapThreshold) {
      return _centerValue;
    }
    return clampedValue;
  }

  void _handleChanged(double value) {
    widget.onChanged(_snapValue(value));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            color: enabled ? Colors.white : const Color(0x66FFFFFF),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Slider(
                    min: widget.min,
                    max: widget.max,
                    value: widget.value.clamp(widget.min, widget.max),
                    onChanged: enabled ? _handleChanged : null,
                  ),
                  if (widget.showCenterMarker)
                    IgnorePointer(
                      child: Align(
                        alignment: Alignment(_centerMarkerAlignment, 0),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.suffix != null) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: TextBox(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  onSubmitted: (text) {
                    final value = double.tryParse(text);
                    if (value == null) {
                      _controller.text = _format(widget.value);
                      return;
                    }
                    widget.onChanged(_snapValue(value));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.suffix!,
                style: const TextStyle(
                  color: _subtitleDefaultTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        Row(
          children: [
            Text(
              widget.leftLabel,
              style: const TextStyle(
                color: _subtitleDefaultTextColor,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Text(
              widget.rightLabel,
              style: const TextStyle(
                color: _subtitleDefaultTextColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        if (!enabled && widget.disabledHint != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.disabledHint!,
            style: const TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _SubtitleItem extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isExternal;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _SubtitleItem({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.isExternal = false,
    this.onDelete,
  });

  @override
  State<_SubtitleItem> createState() => _SubtitleItemState();
}

class _SubtitleItemState extends State<_SubtitleItem> {
  bool _isHovered = false;
  bool _isDeleteHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isDeleteHovered = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _isHovered || widget.isSelected
                ? _subtitleHoverBackgroundColor
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.isSelected
                            ? _subtitleSelectedTextColor
                            : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.isSelected
                              ? _subtitleSelectedTextColor.withValues(
                                  alpha: 0.8)
                              : _subtitleDefaultTextColor.withValues(
                                  alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                )
              else if (widget.isExternal &&
                  widget.onDelete != null &&
                  _isHovered)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isDeleteHovered = true),
                  onExit: (_) => setState(() => _isDeleteHovered = false),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onDelete,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _isDeleteHovered
                            ? _subtitleHoverBackgroundColor
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        FluentIcons.delete,
                        size: 12,
                        color: _subtitleDefaultTextColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
