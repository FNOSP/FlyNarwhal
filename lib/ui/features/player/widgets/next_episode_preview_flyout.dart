import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    as cache_manager;

import '../../../../data/models/episode_list_response.dart';
import '../../../../domain/entities/media_type.dart';
import '../../../shared/common/media_poster_placeholder.dart';
import 'player_action_button.dart';

const Color _flyoutBackgroundColor = Color(0xCC000000);
const Color _flyoutBorderColor = Color(0x80808080);
const Color _secondaryTextColor = Color(0xB3FFFFFF);
const BorderRadius _flyoutBorderRadius = BorderRadius.all(Radius.circular(8));
const int _hideDelayMs = 200;
const int _animationDurationMs = 200;
const double _flyoutWidth = 253;
const double _flyoutBridgeOffset = 40;
const double _flyoutBridgeWidth = 46;
const double _estimatedFlyoutHeight = 214;

class NextEpisodePreviewFlyout extends StatefulWidget {
  final EpisodeListResponse nextEpisode;
  final String baseUrl;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;
  final bool isActiveControl;
  final VoidCallback onClick;
  final void Function(bool)? onHoverStateChanged;

  const NextEpisodePreviewFlyout({
    super.key,
    required this.nextEpisode,
    required this.baseUrl,
    required this.httpHeaders,
    required this.cacheManager,
    this.isActiveControl = false,
    required this.onClick,
    this.onHoverStateChanged,
  });

  @override
  State<NextEpisodePreviewFlyout> createState() =>
      _NextEpisodePreviewFlyoutState();
}

class _NextEpisodePreviewFlyoutState extends State<NextEpisodePreviewFlyout>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isButtonHovered = false;
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
  void didUpdateWidget(NextEpisodePreviewFlyout oldWidget) {
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
      if (!_isButtonHovered && mounted) {
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
    if (_isButtonHovered) {
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
      if (!mounted || _isExpanded) return;
      callback(hovered);
    });
  }

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (_) {
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
        final bridgeHeight = buttonSize.height + _flyoutBridgeOffset;
        final left = buttonOffset.dx + (buttonSize.width - _flyoutWidth) / 2;
        final top =
            buttonOffset.dy + buttonSize.height - bridgeHeight - flyoutHeight;

        _updateFlyoutSizeAfterFrame();

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: IgnorePointer(
                child: SizedBox(
                  width: _flyoutWidth,
                  height: flyoutHeight + bridgeHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        child: KeyedSubtree(
                          key: _flyoutKey,
                          child: _buildAnimatedFlyout(),
                        ),
                      ),
                      Positioned(
                        left: (_flyoutWidth - _flyoutBridgeWidth) / 2,
                        top: flyoutHeight,
                        child: SizedBox(
                          width: _flyoutBridgeWidth,
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
        child: PlayerActionButton.svg(
          svgAssetPath: 'assets/images/next_episode.svg',
          onPressed: widget.onClick,
          tooltip: '下一个视频',
          size: 30,
          iconSize: 20,
          padding: const EdgeInsets.all(4),
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
      child: _NextEpisodeFlyoutContent(
        episode: widget.nextEpisode,
        baseUrl: widget.baseUrl,
        httpHeaders: widget.httpHeaders,
        cacheManager: widget.cacheManager,
      ),
    );
  }
}

class _NextEpisodeFlyoutContent extends StatelessWidget {
  final EpisodeListResponse episode;
  final String baseUrl;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;

  const _NextEpisodeFlyoutContent({
    required this.episode,
    required this.baseUrl,
    required this.httpHeaders,
    required this.cacheManager,
  });

  String? _buildImageUrl() {
    final posterPath = episode.poster?.trim();
    if (baseUrl.isEmpty || posterPath == null || posterPath.isEmpty) {
      return null;
    }
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final suffix = posterPath.contains('?') ? '' : '?w=640';
    return '$normalizedBaseUrl/v/api/v1/sys/img$posterPath$suffix';
  }

  String _buildEpisodeTitle() {
    final title = episode.title.trim();
    if (title.isEmpty) {
      return '第${episode.episodeNumber}集';
    }
    return '${episode.episodeNumber.toString().padLeft(2, '0')}. $title';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _buildImageUrl();
    return Container(
      width: _flyoutWidth,
      decoration: BoxDecoration(
        color: _flyoutBackgroundColor,
        borderRadius: _flyoutBorderRadius,
        border: Border.all(color: _flyoutBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.white.withValues(alpha: 0.06),
                  child: imageUrl == null
                      ? const Center(
                          child: MediaPosterPlaceholder(
                            type: MediaType.episode,
                            size: 36,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          httpHeaders: httpHeaders,
                          cacheManager: cacheManager,
                          fit: BoxFit.cover,
                          fadeOutDuration: const Duration(milliseconds: 120),
                          placeholder: (context, url) =>
                              const Center(child: ProgressRing(strokeWidth: 2)),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(
                              FluentIcons.error,
                              color: _secondaryTextColor,
                              size: 20,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '下一个视频',
              style: TextStyle(
                color: _secondaryTextColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _buildEpisodeTitle(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
