import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/media_type.dart';
import '../../providers/providers.dart';
import '../shared/common/fn_cached_image.dart';
import '../shared/common/poster_resolution_tags.dart';

// Accent color for watched state
const Color kAccentColorDefault = Color(0xFF2173DF);
// Danger color for favorite state
const Color kDangerDefaultColor = Color(0xFFFF0420);
const double _hoverOverlayBleed = 1.0;

class MoviePoster extends ConsumerStatefulWidget {
  final String? posterPath;
  final String title;
  final String? subtitle;
  final List<String>? resolutions;
  final double width;
  final double height;
  final double scaleFactor;
  final String? score;
  final bool isFavorite;
  final bool isWatched;
  final VoidCallback? onTap;
  final VoidCallback? onPlayTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onWatchedTap;
  final VoidCallback? onMoreTap;
  final String? type;
  final String? guid;
  final String? mediaTitle;
  final int? seasonNumber;
  final Function(
          String guid, bool currentState, Function(bool success) callback)?
      onFavoriteToggle;
  final Function(
          String guid, bool currentState, Function(bool success) callback)?
      onWatchedToggle;

  const MoviePoster({
    super.key,
    this.posterPath,
    required this.title,
    this.subtitle,
    this.resolutions,
    this.width = 150,
    this.height = 225,
    this.scaleFactor = 1,
    this.score,
    this.isFavorite = false,
    this.isWatched = false,
    this.onTap,
    this.onPlayTap,
    this.onFavoriteTap,
    this.onWatchedTap,
    this.onMoreTap,
    this.type,
    this.guid,
    this.mediaTitle,
    this.seasonNumber,
    this.onFavoriteToggle,
    this.onWatchedToggle,
  });

  @override
  ConsumerState<MoviePoster> createState() => _MoviePosterState();
}

class _MoviePosterState extends ConsumerState<MoviePoster>
    with SingleTickerProviderStateMixin {
  bool _isPlayButtonHovered = false;
  bool _isFavorite = false;
  bool _isWatched = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
    _isWatched = widget.isWatched;
  }

  @override
  void didUpdateWidget(covariant MoviePoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      _isFavorite = widget.isFavorite;
    }
    if (oldWidget.isWatched != widget.isWatched) {
      _isWatched = widget.isWatched;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesManagerProvider);
    final baseUrl = prefs.getBaseUrl();
    final resolvedPosterPath = widget.posterPath?.trim();
    final hasValidPath = resolvedPosterPath != null &&
        resolvedPosterPath.isNotEmpty &&
        baseUrl != null;
    final theme = FluentTheme.of(context);
    final formattedScore = formatVoteAverage(widget.score);
    final showScore = formattedScore != '0.0';
    final scaleFactor = widget.scaleFactor;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    double snap(double v) => (v * pixelRatio).roundToDouble() / pixelRatio;
    // Snap poster dimensions to physical pixels to avoid a 1px seam between
    // the image and the semi-transparent overlay at fractional DPI boundaries.
    final scaledWidth = snap(widget.width * scaleFactor);
    final scaledHeight = snap(widget.height * scaleFactor);
    final mediaType = MediaType.tryParse(widget.type);
    final showFavoriteButton = mediaType != MediaType.season;
    final actionInset = 8.0 * scaleFactor;

    // Play button sizes (matching Kotlin implementation)
    final normalPlayButtonSize = 48.0 * scaleFactor;
    final hoveredPlayButtonSize = 56.0 * scaleFactor;
    final playButtonSize =
        _isPlayButtonHovered ? hoveredPlayButtonSize : normalPlayButtonSize;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HoverButton(
        onPressed: widget.onTap ?? () => _handleNavigation(context, ref),
        builder: (context, states) {
          final isHovered = states.isHovered;
          return SizedBox(
            width: scaledWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: scaledHeight,
                  width: scaledWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14 * scaleFactor),
                    clipBehavior: Clip.antiAlias,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey[160].withValues(alpha: 0.6),
                        ),
                        color: Colors.grey[160],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (hasValidPath)
                            FnCachedImage(
                              posterPath: resolvedPosterPath,
                              fit: BoxFit.fitWidth,
                              width: 400,
                            )
                          else
                            const Center(child: Icon(FluentIcons.file_image)),
                          if (showScore)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  formattedScore,
                                  style: const TextStyle(
                                    color: Color(0xFFFBBF24),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isHovered ? 0 : 1,
                              child: Container(
                                height: scaledHeight / 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      const Color(0xFF1C1C1C)
                                          .withValues(alpha: 0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isHovered ? 0 : 1,
                              child: PosterResolutionTags(
                                resolutions: widget.resolutions,
                                scaleFactor: scaleFactor,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            left: -_hoverOverlayBleed,
                            top: -_hoverOverlayBleed,
                            right: -_hoverOverlayBleed,
                            bottom: -_hoverOverlayBleed,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isHovered ? 1 : 0,
                              child: ColoredBox(
                                color: const Color(0xFF1C1C1C)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          // Show play button for Movie and Video types
                          if (mediaType == MediaType.movie ||
                              mediaType == MediaType.video ||
                              widget.onPlayTap != null)
                            Center(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: isHovered ? 1 : 0,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) => setState(
                                      () => _isPlayButtonHovered = true),
                                  onExit: (_) => setState(
                                      () => _isPlayButtonHovered = false),
                                  child: GestureDetector(
                                    onTap: widget.onPlayTap ??
                                        () => _handlePlay(context),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: playButtonSize,
                                      height: playButtonSize,
                                      child: SvgPicture.asset(
                                        'assets/images/play_circle.svg',
                                        width: playButtonSize,
                                        height: playButtonSize,
                                        colorFilter: const ColorFilter.mode(
                                          Colors.white,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: actionInset,
                            bottom: actionInset,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isHovered ? 1 : 0,
                              child: _PosterIconButton(
                                svgAssetPath: _isWatched
                                    ? 'assets/images/watched_fill.svg'
                                    : 'assets/images/watched.svg',
                                isActive: _isWatched,
                                activeColor: kAccentColorDefault,
                                scaleFactor: scaleFactor,
                                onPressed: _handleWatchedToggle,
                              ),
                            ),
                          ),
                          if (showFavoriteButton)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: actionInset,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: isHovered ? 1 : 0,
                                child: Center(
                                  child: _PosterIconButton(
                                    svgAssetPath: _isFavorite
                                        ? 'assets/images/favorite_fill.svg'
                                        : 'assets/images/favorite.svg',
                                    isActive: _isFavorite,
                                    activeColor: kDangerDefaultColor,
                                    scaleFactor: scaleFactor,
                                    onPressed: _handleFavoriteToggle,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            right: actionInset,
                            bottom: actionInset,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isHovered ? 1 : 0,
                              child: _PosterIconButton(
                                icon: FluentIcons.more,
                                isActive: false,
                                activeColor: Colors.white,
                                scaleFactor: scaleFactor,
                                onPressed: widget.onMoreTap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8 * scaleFactor),
                SizedBox(
                  width: scaledWidth,
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption?.copyWith(
                      fontWeight: FontWeight.normal,
                      fontSize: 12 * scaleFactor,
                      color: isHovered
                          ? const Color(0xFF2073DF)
                          : theme.typography.body?.color,
                    ),
                  ),
                ),
                if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                  SizedBox(height: 4 * scaleFactor),
                  SizedBox(
                    width: scaledWidth,
                    child: Text(
                      widget.subtitle!,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption?.copyWith(
                        fontWeight: FontWeight.normal,
                        fontSize: 11 * scaleFactor,
                        color: theme.typography.caption?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleNavigation(BuildContext context, WidgetRef ref) {
    if (widget.guid == null || widget.guid!.isEmpty) return;

    // 预取详情数据到缓存，使进入详情页时近乎秒开。
    unawaited(ref
        .read(mediaRemoteDataSourceProvider)
        .prefetchItemDetail(widget.guid!));

    final mediaType = MediaType.tryParse(widget.type);
    switch (mediaType) {
      case MediaType.movie:
      case MediaType.video:
        ref.read(navigationStackProvider.notifier).pushPath('/home');
        context.go('/movie/${widget.guid}');
        break;
      case MediaType.tv:
        ref.read(navigationStackProvider.notifier).pushPath('/home');
        context.go('/tv/${widget.guid}');
        break;
      case MediaType.season:
        context.go('/tv/season/${widget.guid}');
        break;
      case MediaType.liveChannel:
        context.go('/player/${widget.guid}');
        break;
      case MediaType.directory:
      case MediaType.episode:
      case null:
        break;
    }
  }

  void _handlePlay(BuildContext context) {
    if (widget.guid == null || widget.guid!.isEmpty) return;

    final mediaType = MediaType.tryParse(widget.type);
    if (mediaType == MediaType.movie || mediaType == MediaType.video) {
      ref.read(navigationStackProvider.notifier).pushPath('/home');
      context.go('/player/${widget.guid}');
    }
  }

  void _handleFavoriteToggle() {
    if (widget.guid == null) return;
    widget.onFavoriteToggle?.call(
      widget.guid!,
      _isFavorite,
      (success) {
        if (success) {
          setState(() {
            _isFavorite = !_isFavorite;
          });
        }
      },
    );
    widget.onFavoriteTap?.call();
  }

  void _handleWatchedToggle() {
    if (widget.guid == null) return;
    widget.onWatchedToggle?.call(
      widget.guid!,
      _isWatched,
      (success) {
        if (success) {
          setState(() {
            _isWatched = !_isWatched;
          });
        }
      },
    );
    widget.onWatchedTap?.call();
  }
}

// Poster icon button with hover effect
class _PosterIconButton extends StatefulWidget {
  final IconData? icon;
  final String? svgAssetPath;
  final bool isActive;
  final Color activeColor;
  final double scaleFactor;
  final VoidCallback? onPressed;

  const _PosterIconButton({
    this.icon,
    this.svgAssetPath,
    required this.isActive,
    required this.activeColor,
    required this.scaleFactor,
    this.onPressed,
  });

  @override
  State<_PosterIconButton> createState() => _PosterIconButtonState();
}

class _PosterIconButtonState extends State<_PosterIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final iconSize = 16.0 * widget.scaleFactor;
    final buttonSize = 28.0 * widget.scaleFactor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Hover background
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: _isHovered
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
              // Icon
              if (widget.svgAssetPath != null)
                SvgPicture.asset(
                  widget.svgAssetPath!,
                  width: iconSize,
                  height: iconSize,
                  colorFilter: ColorFilter.mode(
                    widget.isActive ? widget.activeColor : Colors.white,
                    BlendMode.srcIn,
                  ),
                )
              else if (widget.icon != null)
                Icon(
                  widget.icon,
                  size: iconSize,
                  color: widget.isActive ? widget.activeColor : Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatVoteAverage(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '0.0';
  }
  final parsed = double.tryParse(value.trim());
  if (parsed == null) {
    return '0.0';
  }
  return parsed.toStringAsFixed(1);
}

double resolveWindowScaleFactor(BuildContext context) {
  final windowWidth = MediaQuery.of(context).size.width;
  final windowScaleFactor = windowWidth / 1280.0;
  if (windowScaleFactor == 1) {
    return 1;
  }
  final scaled = 1 + (windowScaleFactor - 1) * 0.3;
  return scaled.clamp(1.0, 1.1);
}
