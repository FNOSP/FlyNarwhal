import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../../../../data/models/player_models.dart';
import '../../../../data/utils/fn_data_convertor.dart';
import '../../../../tooling/driver_test_mode.dart';

// Shared dark-flyout palette, identical to the other player control flyouts.
const Color _flyoutBackgroundColor = Color(0xCC000000);
const Color _flyoutBorderColor = Color(0x80808080);
const Color _selectedTextColor = Color(0xFF2073DF);
const Color _defaultTextColor = Color(0xC8FFFFFF);
const Color _hoverBackgroundColor = Color(0x1AFFFFFF);
const int _hideDelayMs = 200;
const int _animationDurationMs = 200;
const double _bridgeOffset = 40;
const double _minBridgeWidth = 56;
const double _bridgeHorizontalPadding = 12;

/// Cloud play modes mirroring the web player's 播放方式 selector.
abstract class CloudPlayMode {
  static const String direct = 'direct';
  static const String proxy = 'proxy';
}

/// Masks a cloud account nickname the same way the web player does:
/// 友人A → 友***A, 王某 → 王*, single character → *.
String maskCloudNickname(String? nickname) {
  final name = nickname?.trim() ?? '';
  if (name.isEmpty) return '';
  if (name.length < 2) return '*';
  if (name.length == 2) return '${name[0]}*';
  return '${name[0]}***${name[name.length - 1]}';
}

String cloudStorageLabel(int? cloudStorageType) {
  return FnDataConvertor.getCloudStorageTypeLabel(cloudStorageType);
}

/// Small blue "SVIP" pill shown next to cloud VIP accounts.
class _VipBadge extends StatelessWidget {
  final double size;

  const _VipBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3C3C43), Color(0xFF1C1C22)],
        ),
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: const Color(0x66FFFFFF)),
      ),
      alignment: Alignment.center,
      child: Text(
        'SVIP',
        style: TextStyle(
          fontSize: size * 0.62,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFE8E8F0),
          height: 1.0,
        ),
      ),
    );
  }
}

/// Round cloud-type avatar (Quark/Baidu icon from the app assets).
class _CloudTypeAvatar extends StatelessWidget {
  final int? cloudStorageType;
  final double size;

  const _CloudTypeAvatar({required this.cloudStorageType, required this.size});

  String? get _assetPath {
    switch (cloudStorageType) {
      case 1: // 百度网盘
        return 'assets/images/baidu_pan.png';
      case 4: // 夸克网盘
        return 'assets/images/quark_pan.png';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _assetPath;
    if (path == null) {
      return SizedBox(
        width: size,
        height: size,
        child: const Icon(
          FluentIcons.cloud,
          size: 16,
          color: _defaultTextColor,
        ),
      );
    }
    return ClipOval(
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// Control-bar chip for cloud media: cloud avatar + masked nickname, opening
/// the 播放方式 flyout on hover (mirrors the web player's account chip).
class CloudAccountChip extends StatefulWidget {
  final CloudStorageInfo cloudStorageInfo;
  final bool isDirectLink;
  final int yOffset;
  final bool isActiveControl;
  final void Function(bool isHovered)? onHoverStateChanged;
  final void Function(String mode) onPlayModeSelected;

  const CloudAccountChip({
    super.key,
    required this.cloudStorageInfo,
    required this.isDirectLink,
    this.yOffset = 0,
    this.isActiveControl = false,
    this.onHoverStateChanged,
    required this.onPlayModeSelected,
  });

  @override
  State<CloudAccountChip> createState() => _CloudAccountChipState();
}

class _CloudAccountChipState extends State<CloudAccountChip>
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

  static const double _flyoutWidth = 380;
  static const double _estimatedFlyoutHeight = 250;

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
  void didUpdateWidget(CloudAccountChip oldWidget) {
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
        if (renderObject is! RenderBox || !renderObject.hasSize) {
          return const SizedBox.shrink();
        }
        final buttonOffset = renderObject.localToGlobal(Offset.zero);
        final buttonSize = renderObject.size;
        const flyoutWidth = _flyoutWidth;
        final flyoutHeight = _flyoutSize?.height ?? _estimatedFlyoutHeight;
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

        _updateFlyoutSizeAfterFrame();

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
    final info = widget.cloudStorageInfo;
    final maskedName = maskCloudNickname(info.cloudNickName);
    final isVip = info.isVip ?? false;

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
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _isButtonHovered ? _hoverBackgroundColor : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CloudTypeAvatar(
                  cloudStorageType: info.cloudStorageType,
                  size: 24,
                ),
                if (maskedName.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    maskedName,
                    style: TextStyle(
                      color: _isButtonHovered ? Colors.white : _defaultTextColor,
                      fontSize: 15,
                    ),
                  ),
                ],
                if (isVip) ...[
                  const SizedBox(width: 6),
                  const _VipBadge(size: 18),
                ],
              ],
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
      child: _CloudPlayModeFlyoutContent(
        cloudStorageInfo: widget.cloudStorageInfo,
        isDirectLink: widget.isDirectLink,
        onPlayModeSelected: (mode) {
          _setPopupHovered(false);
          _closeFlyout();
          widget.onPlayModeSelected(mode);
        },
      ),
    );
  }
}

/// The 播放方式 flyout body: account header, description and the two mode
/// option cards, matching the web player's playModeSelector popover.
class _CloudPlayModeFlyoutContent extends StatelessWidget {
  final CloudStorageInfo cloudStorageInfo;
  final bool isDirectLink;
  final void Function(String mode) onPlayModeSelected;

  const _CloudPlayModeFlyoutContent({
    required this.cloudStorageInfo,
    required this.isDirectLink,
    required this.onPlayModeSelected,
  });

  static const _modeCards = [
    (
      mode: CloudPlayMode.direct,
      label: '网盘直连播放',
      description: '速度较快、省流',
      recommend: true,
    ),
    (
      mode: CloudPlayMode.proxy,
      label: 'NAS 代理播放',
      description: '色调或音频异常时可尝试切换',
      recommend: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final maskedName = maskCloudNickname(cloudStorageInfo.cloudNickName);
    final isVip = cloudStorageInfo.isVip ?? false;
    final selectedMode =
        isDirectLink ? CloudPlayMode.direct : CloudPlayMode.proxy;

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: _flyoutBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _flyoutBorderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account header row.
          Row(
            children: [
              _CloudTypeAvatar(
                cloudStorageType: cloudStorageInfo.cloudStorageType,
                size: 36,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  maskedName.isEmpty ? '网盘' : maskedName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isVip) ...[
                const SizedBox(width: 8),
                const _VipBadge(size: 22),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '正在播放网盘上的文件，播放速度和画质取决于网盘方规则。',
            style: TextStyle(color: Color(0xA0FFFFFF), fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            '如遇播放异常，可尝试切换播放方式。',
            style: TextStyle(color: Color(0xA0FFFFFF), fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Text(
            '播放方式',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ..._modeCards.map(
            (card) => _PlayModeCard(
              label: card.label,
              description: card.description,
              recommend: card.recommend,
              selected: selectedMode == card.mode,
              onClick: () => onPlayModeSelected(card.mode),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayModeCard extends StatefulWidget {
  final String label;
  final String description;
  final bool recommend;
  final bool selected;
  final VoidCallback onClick;

  const _PlayModeCard({
    required this.label,
    required this.description,
    required this.recommend,
    required this.selected,
    required this.onClick,
  });

  @override
  State<_PlayModeCard> createState() => _PlayModeCardState();
}

class _PlayModeCardState extends State<_PlayModeCard> {
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
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0x14FFFFFF) : const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x4DFFFFFF)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.recommend) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedTextColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '推荐',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style:
                          const TextStyle(color: Color(0xA0FFFFFF), fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (widget.selected)
                const Icon(
                  FluentIcons.check_mark,
                  size: 20,
                  color: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen error page shown when cloud playback fails, mirroring the web
/// player's playback-error page: stacked-card artwork, the centered message
/// and the action buttons (返回 / 重试 / 网盘直连播放 etc.).
class CloudPlaybackErrorDialog extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onSwitchQuality;
  final VoidCallback onSwitchProxy;
  final VoidCallback onSwitchDirect;
  final VoidCallback onBack;
  final bool isProxyMode;

  const CloudPlaybackErrorDialog({
    super.key,
    required this.onRetry,
    required this.onSwitchQuality,
    required this.onSwitchProxy,
    required this.onSwitchDirect,
    required this.onBack,
    this.isProxyMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xFF19191A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/playback_error.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              const Text(
                '抱歉，播放出错了',
                style: TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 16,
                  height: 22 / 16,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ErrorPageActionButton(
                    key: const ValueKey('player-cloud-error-back'),
                    label: '返回',
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 16),
                  _ErrorPageActionButton(
                    key: const ValueKey('player-cloud-error-retry'),
                    label: '重试',
                    onPressed: onRetry,
                  ),
                  if (!isProxyMode) ...[
                    const SizedBox(width: 16),
                    _ErrorPageActionButton(
                      key: const ValueKey('player-cloud-error-switch-quality'),
                      label: '播放其他画质',
                      onPressed: onSwitchQuality,
                    ),
                    const SizedBox(width: 16),
                    _ErrorPageActionButton(
                      key: const ValueKey('player-cloud-error-switch-proxy'),
                      label: '切换 NAS 代理播放',
                      primary: true,
                      onPressed: onSwitchProxy,
                    ),
                  ] else ...[
                    const SizedBox(width: 16),
                    _ErrorPageActionButton(
                      key: const ValueKey('player-cloud-error-switch-direct'),
                      label: '网盘直连播放',
                      primary: true,
                      onPressed: onSwitchDirect,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Action button on the playback-error page, matching the web player's
/// large Semi Design buttons (44px tall, 8px radius, 20px padding).
class _ErrorPageActionButton extends StatefulWidget {
  final String label;
  final bool primary;
  final VoidCallback onPressed;

  const _ErrorPageActionButton({
    super.key,
    required this.label,
    this.primary = false,
    required this.onPressed,
  });

  @override
  State<_ErrorPageActionButton> createState() => _ErrorPageActionButtonState();
}

class _ErrorPageActionButtonState extends State<_ErrorPageActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.primary
        ? (_isHovered ? const Color(0xFF3388FF) : const Color(0xFF0066FF))
        : (_isHovered ? const Color(0x1FFFFFFF) : const Color(0x0FFFFFFF));
    final foreground = widget.primary
        ? Colors.white
        : const Color(0xCCFFFFFF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          height: 44,
          constraints: const BoxConstraints(minWidth: 80),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: foreground,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
