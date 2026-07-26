import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    as cache_manager;

import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/episode_list_response.dart';

const Color _episodeFlyoutBackgroundColor = Color(0xCC000000);
const Color _episodeFlyoutBorderColor = Color(0x33FFFFFF);
const Color _episodeSelectedTextColor = Color(0xFF2073DF);
const Color _episodeDefaultTextColor = Color(0xC8FFFFFF);
const Color _episodeSecondaryTextColor = Color(0x99FFFFFF);
const Color _episodeHoverBackgroundColor = Color(0x1AFFFFFF);
const int _episodeHideDelayMs = 200;
const int _episodeAnimationDurationMs = 200;
const double _episodeFlyoutWidth = 320;
const double _episodeFlyoutHeightFactor = 0.6;
const double _episodeFlyoutBridgeOffset = 40;
const double _episodeFlyoutMinBridgeWidth = 48;
const double _episodeFlyoutBridgeHorizontalPadding = 12;
const double _episodeFlyoutHeaderHeight = 72;
const double _episodeFlyoutDividerHeight = 1;
const double _episodeFlyoutListTopSpacing = 12;
const double _episodeFlyoutListBottomPadding = 10;
const double _episodeListRowHeight = 76;
const double _episodeListRowSpacing = 6;
const int _episodeDetailedViewMaxVisibleCount = 6;
const double _episodeFlyoutMaxHeight =
    _episodeFlyoutHeaderHeight +
    _episodeFlyoutDividerHeight +
    _episodeFlyoutListTopSpacing +
    _episodeFlyoutListBottomPadding +
    ((_episodeListRowHeight + _episodeListRowSpacing) *
        _episodeDetailedViewMaxVisibleCount);

class EpisodeSelectionFlyout extends StatefulWidget {
  final List<EpisodeListResponse> episodes;
  final String currentEpisodeGuid;
  final String parentTitle;
  final String baseUrl;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;
  final int yOffset;
  final bool isActiveControl;
  final void Function(EpisodeListResponse) onEpisodeSelected;
  final void Function(bool)? onHoverStateChanged;

  const EpisodeSelectionFlyout({
    super.key,
    required this.episodes,
    required this.currentEpisodeGuid,
    required this.parentTitle,
    required this.baseUrl,
    required this.httpHeaders,
    required this.cacheManager,
    this.yOffset = 0,
    this.isActiveControl = false,
    required this.onEpisodeSelected,
    this.onHoverStateChanged,
  });

  @override
  State<EpisodeSelectionFlyout> createState() => _EpisodeSelectionFlyoutState();
}

class _EpisodeSelectionFlyoutState extends State<EpisodeSelectionFlyout>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isButtonHovered = false;
  bool _popupHovered = false;
  bool _isGridView = false;
  final GlobalKey _buttonKey = GlobalKey();
  final GlobalKey _flyoutKey = GlobalKey();
  OverlayEntry? _overlayEntry;
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

  void _requestOverlayRebuild() {
    _overlayEntry?.markNeedsBuild();
  }

  void _setPopupHovered(bool value) {
    if (_popupHovered == value || !mounted) return;
    setState(() => _popupHovered = value);
  }

  double _calculateBridgeWidth(Size buttonSize) {
    final preferredWidth =
        buttonSize.width + (_episodeFlyoutBridgeHorizontalPadding * 2);
    return preferredWidth.clamp(
      _episodeFlyoutMinBridgeWidth,
      _episodeFlyoutWidth,
    );
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

        final overlaySize = MediaQuery.of(overlayContext).size;
        final buttonOffset = renderObject.localToGlobal(Offset.zero);
        final buttonSize = renderObject.size;
        final responsiveFlyoutHeight =
            overlaySize.height * _episodeFlyoutHeightFactor;
        final flyoutHeight = responsiveFlyoutHeight
            .clamp(0.0, _episodeFlyoutMaxHeight)
            .toDouble();
        final bridgeHeight = widget.yOffset + _episodeFlyoutBridgeOffset;
        final top =
            (buttonOffset.dy + buttonSize.height - bridgeHeight - flyoutHeight)
                .clamp(8.0, overlaySize.height - flyoutHeight - bridgeHeight);
        final left =
            (buttonOffset.dx + (buttonSize.width - _episodeFlyoutWidth) / 2)
                .clamp(8.0, overlaySize.width - _episodeFlyoutWidth - 8.0);
        final bridgeWidth = _calculateBridgeWidth(buttonSize);
        final buttonCenterX = buttonOffset.dx + (buttonSize.width / 2) - left;
        final bridgeLeft = (buttonCenterX - bridgeWidth / 2)
            .clamp(0.0, _episodeFlyoutWidth - bridgeWidth);

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Listener(
                behavior: HitTestBehavior.opaque,
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
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: KeyedSubtree(
                              key: _flyoutKey,
                              child: _buildAnimatedFlyout(flyoutHeight),
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
      _requestOverlayRebuild();
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

  Widget _buildAnimatedFlyout(double height) {
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
        height: height,
        episodes: widget.episodes,
        currentEpisodeGuid: widget.currentEpisodeGuid,
        parentTitle: widget.parentTitle,
        baseUrl: widget.baseUrl,
        httpHeaders: widget.httpHeaders,
        cacheManager: widget.cacheManager,
        isGridView: _isGridView,
        onViewModeChanged: (isGridView) {
          setState(() => _isGridView = isGridView);
          _requestOverlayRebuild();
        },
        onEpisodeSelected: (episode) {
          widget.onEpisodeSelected(episode);
          _setPopupHovered(false);
          _closeFlyout();
        },
      ),
    );
  }
}

class _EpisodeFlyoutContent extends StatefulWidget {
  final double height;
  final List<EpisodeListResponse> episodes;
  final String currentEpisodeGuid;
  final String parentTitle;
  final String baseUrl;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;
  final bool isGridView;
  final void Function(bool) onViewModeChanged;
  final void Function(EpisodeListResponse) onEpisodeSelected;

  const _EpisodeFlyoutContent({
    required this.height,
    required this.episodes,
    required this.currentEpisodeGuid,
    required this.parentTitle,
    required this.baseUrl,
    required this.httpHeaders,
    required this.cacheManager,
    required this.isGridView,
    required this.onViewModeChanged,
    required this.onEpisodeSelected,
  });

  @override
  State<_EpisodeFlyoutContent> createState() => _EpisodeFlyoutContentState();
}

class _EpisodeFlyoutContentState extends State<_EpisodeFlyoutContent> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollToCurrentAfterFrame();
  }

  @override
  void didUpdateWidget(covariant _EpisodeFlyoutContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentEpisodeGuid != widget.currentEpisodeGuid ||
        oldWidget.isGridView != widget.isGridView ||
        oldWidget.episodes.length != widget.episodes.length) {
      _scrollToCurrentAfterFrame();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final index = widget.episodes
          .indexWhere((episode) => episode.guid == widget.currentEpisodeGuid);
      if (index < 0) return;
      final offset = widget.isGridView
          ? ((index ~/ 4) * 72.0)
          : (index * _episodeListRowHeight);
      final maxOffset = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(offset.clamp(0.0, maxOffset));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _episodeFlyoutWidth,
      height: widget.height,
      decoration: BoxDecoration(
        color: _episodeFlyoutBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _episodeFlyoutBorderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.parentTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _ViewModeToggle(
                  isGridView: widget.isGridView,
                  onViewModeChanged: widget.onViewModeChanged,
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: widget.isGridView
                ? _EpisodeNumberGrid(
                    episodes: widget.episodes,
                    currentEpisodeGuid: widget.currentEpisodeGuid,
                    scrollController: _scrollController,
                    onEpisodeSelected: widget.onEpisodeSelected,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    itemCount: widget.episodes.length,
                    itemBuilder: (context, index) {
                      final episode = widget.episodes[index];
                      return _EpisodeListRow(
                        episode: episode,
                        isSelected: episode.guid == widget.currentEpisodeGuid,
                        baseUrl: widget.baseUrl,
                        httpHeaders: widget.httpHeaders,
                        cacheManager: widget.cacheManager,
                        onTap: () => widget.onEpisodeSelected(episode),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  final bool isGridView;
  final void Function(bool) onViewModeChanged;

  const _ViewModeToggle({
    required this.isGridView,
    required this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewModeButton(
            icon: FluentIcons.t_v_monitor,
            isSelected: !isGridView,
            onPressed: () => onViewModeChanged(false),
          ),
          const SizedBox(width: 2),
          _ViewModeButton(
            icon: FluentIcons.grid_view_medium,
            isSelected: isGridView,
            onPressed: () => onViewModeChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatefulWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const _ViewModeButton({
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  State<_ViewModeButton> createState() => _ViewModeButtonState();
}

class _ViewModeButtonState extends State<_ViewModeButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          width: 34,
          height: 30,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.white.withValues(alpha: 0.14)
                : (_isHovered
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.icon,
            size: 17,
            color: widget.isSelected || _isHovered
                ? Colors.white
                : Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}

class _EpisodeListRow extends StatefulWidget {
  final EpisodeListResponse episode;
  final bool isSelected;
  final String baseUrl;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;
  final VoidCallback onTap;

  const _EpisodeListRow({
    required this.episode,
    required this.isSelected,
    required this.baseUrl,
    required this.httpHeaders,
    required this.cacheManager,
    required this.onTap,
  });

  @override
  State<_EpisodeListRow> createState() => _EpisodeListRowState();
}

class _EpisodeListRowState extends State<_EpisodeListRow> {
  bool _isHovered = false;

  String? _buildImageUrl() {
    final posterPath = widget.episode.poster?.trim();
    if (widget.baseUrl.isEmpty || posterPath == null || posterPath.isEmpty) {
      return null;
    }
    final normalizedBaseUrl = widget.baseUrl.endsWith('/')
        ? widget.baseUrl.substring(0, widget.baseUrl.length - 1)
        : widget.baseUrl;
    final suffix = posterPath.contains('?') ? '' : '?w=320';
    return '$normalizedBaseUrl/v/api/v1/sys/img$posterPath$suffix';
  }

  String _buildTitle() {
    final title = widget.episode.title.trim();
    if (title.isEmpty) {
      return '第 ${widget.episode.episodeNumber} 集';
    }
    return '${widget.episode.episodeNumber.toString().padLeft(2, '0')}. $title';
  }

  @override
  Widget build(BuildContext context) {
    final episode = widget.episode;
    final imageUrl = _buildImageUrl();
    final progress = episode.duration > 0
        ? (episode.ts / episode.duration).clamp(0.0, 1.0)
        : 0.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: _episodeListRowHeight,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _isHovered || widget.isSelected
                ? _episodeHoverBackgroundColor
                : Colors.transparent,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 112,
                  height: 63,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.06),
                          child: imageUrl == null
                              ? const Icon(
                                  FluentIcons.file_image,
                                  color: _episodeSecondaryTextColor,
                                  size: 22,
                                )
                              : CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  httpHeaders: widget.httpHeaders,
                                  cacheManager: widget.cacheManager,
                                  fit: BoxFit.cover,
                                  fadeOutDuration:
                                      const Duration(milliseconds: 120),
                                  placeholder: (context, url) => const Center(
                                    child: ProgressRing(strokeWidth: 2),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Center(
                                    child: Icon(
                                      FluentIcons.error,
                                      color: _episodeSecondaryTextColor,
                                      size: 18,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      if (progress > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                height: 3,
                                color: _episodeSelectedTextColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _buildTitle(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.isSelected
                            ? _episodeSelectedTextColor
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (episode.duration > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        DateTimeUtils.formatSecondsToCNDateTime(
                            episode.duration),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _episodeSecondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeNumberGrid extends StatelessWidget {
  final List<EpisodeListResponse> episodes;
  final String currentEpisodeGuid;
  final ScrollController scrollController;
  final void Function(EpisodeListResponse) onEpisodeSelected;

  const _EpisodeNumberGrid({
    required this.episodes,
    required this.currentEpisodeGuid,
    required this.scrollController,
    required this.onEpisodeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: episodes.map((episode) {
            return _EpisodeNumberCell(
              episode: episode,
              isSelected: episode.guid == currentEpisodeGuid,
              onTap: () => onEpisodeSelected(episode),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _EpisodeNumberCell extends StatefulWidget {
  final EpisodeListResponse episode;
  final bool isSelected;
  final VoidCallback onTap;

  const _EpisodeNumberCell({
    required this.episode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_EpisodeNumberCell> createState() => _EpisodeNumberCellState();
}

class _EpisodeNumberCellState extends State<_EpisodeNumberCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isSelected
        ? _episodeSelectedTextColor
        : Colors.white.withValues(alpha: _isHovered ? 0.35 : 0.14);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: 64,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                _isHovered ? _episodeHoverBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            widget.episode.episodeNumber.toString(),
            style: TextStyle(
              color:
                  widget.isSelected ? _episodeSelectedTextColor : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
