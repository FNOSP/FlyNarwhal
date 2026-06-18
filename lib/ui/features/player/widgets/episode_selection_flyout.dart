import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import '../../../../data/models/episode_list_response.dart';

const Color _episodeFlyoutBackgroundColor = Color(0xE6000000);
const Color _episodeFlyoutBorderColor = Color(0x80808080);
const Color _episodeSelectedTextColor = Color(0xFF2073DF);
const Color _episodeDefaultTextColor = Color(0xC8FFFFFF);
const Color _episodeHoverBackgroundColor = Color(0x1AFFFFFF);
const int _episodeHideDelayMs = 200;
const int _episodeAnimationDurationMs = 200;
const double _episodeFlyoutWidth = 280;
const double _episodeFlyoutLeftOffset = -220;
const double _episodeFlyoutBridgeOffset = 40;
const double _estimatedEpisodeFlyoutHeight = 380;

class EpisodeSelectionFlyout extends StatefulWidget {
  final List<EpisodeListResponse> episodes;
  final String currentEpisodeGuid;
  final bool isAutoPlay;
  final int yOffset;
  final bool isActiveControl;
  final void Function(EpisodeListResponse) onEpisodeSelected;
  final void Function(bool)? onHoverStateChanged;
  final void Function(bool)? onAutoPlayChanged;

  const EpisodeSelectionFlyout({
    super.key,
    required this.episodes,
    required this.currentEpisodeGuid,
    this.isAutoPlay = true,
    this.yOffset = 0,
    this.isActiveControl = false,
    required this.onEpisodeSelected,
    this.onHoverStateChanged,
    this.onAutoPlayChanged,
  });

  @override
  State<EpisodeSelectionFlyout> createState() => _EpisodeSelectionFlyoutState();
}

class _EpisodeSelectionFlyoutState extends State<EpisodeSelectionFlyout>
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
      duration: const Duration(milliseconds: _episodeAnimationDurationMs),
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
  void didUpdateWidget(EpisodeSelectionFlyout oldWidget) {
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
        if (buttonContext == null) {
          return const SizedBox.shrink();
        }

        final renderObject = buttonContext.findRenderObject();
        if (renderObject is! RenderBox || !renderObject.hasSize) {
          return const SizedBox.shrink();
        }

        final buttonOffset = renderObject.localToGlobal(Offset.zero);
        final buttonSize = renderObject.size;
        final flyoutHeight = _flyoutSize?.height ?? _estimatedEpisodeFlyoutHeight;
        final bridgeHeight = widget.yOffset + _episodeFlyoutBridgeOffset;
        final top =
            buttonOffset.dy + buttonSize.height - bridgeHeight - flyoutHeight;

        _updateFlyoutSizeAfterFrame();

        return Stack(
          children: [
            Positioned(
              left: buttonOffset.dx + _episodeFlyoutLeftOffset,
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
                  width: _episodeFlyoutWidth,
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
                          width: _episodeFlyoutWidth,
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
    _hideTimer = Timer(const Duration(milliseconds: _episodeHideDelayMs), () {
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
        child: Text(
          '选集',
          style: TextStyle(
            color: _isButtonHovered ? Colors.white : _episodeDefaultTextColor,
            fontSize: 17,
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
      child: _EpisodeFlyoutContent(
        episodes: widget.episodes,
        currentEpisodeGuid: widget.currentEpisodeGuid,
        isAutoPlay: widget.isAutoPlay,
        onEpisodeSelected: (episode) {
          widget.onEpisodeSelected(episode);
          _setPopupHovered(false);
          _closeFlyout();
        },
        onAutoPlayChanged: widget.onAutoPlayChanged,
      ),
    );
  }
}

class _EpisodeFlyoutContent extends StatelessWidget {
  final List<EpisodeListResponse> episodes;
  final String currentEpisodeGuid;
  final bool isAutoPlay;
  final void Function(EpisodeListResponse) onEpisodeSelected;
  final void Function(bool)? onAutoPlayChanged;

  const _EpisodeFlyoutContent({
    required this.episodes,
    required this.currentEpisodeGuid,
    required this.isAutoPlay,
    required this.onEpisodeSelected,
    required this.onAutoPlayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final visibleEpisodes = episodes.take(18).toList();
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: _episodeFlyoutBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _episodeFlyoutBorderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Text(
                  '选集',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                ToggleSwitch(
                  checked: isAutoPlay,
                  onChanged: onAutoPlayChanged,
                  content: const Text(
                    '自动',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              shrinkWrap: true,
              itemCount: visibleEpisodes.length,
              itemBuilder: (context, index) {
                final episode = visibleEpisodes[index];
                final isSelected = episode.guid == currentEpisodeGuid;
                return _EpisodeItem(
                  episode: episode,
                  isSelected: isSelected,
                  onTap: () => onEpisodeSelected(episode),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeItem extends StatefulWidget {
  final EpisodeListResponse episode;
  final bool isSelected;
  final VoidCallback onTap;

  const _EpisodeItem({
    required this.episode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_EpisodeItem> createState() => _EpisodeItemState();
}

class _EpisodeItemState extends State<_EpisodeItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final episode = widget.episode;
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
                ? _episodeHoverBackgroundColor
                : Colors.transparent,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  'E${episode.episodeNumber.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: widget.isSelected
                        ? _episodeSelectedTextColor
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  episode.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isSelected
                        ? _episodeSelectedTextColor
                        : _episodeDefaultTextColor,
                    fontSize: 13,
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
