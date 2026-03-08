import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import 'img_loading_progress_ring.dart';

enum FnMediaType {
  movie('Movie'),
  video('Video'),
  tv('TV'),
  season('Season'),
  person('Person');

  final String value;
  const FnMediaType(this.value);

  static FnMediaType? fromString(String? value) {
    if (value == null) return null;
    return FnMediaType.values.where((e) => e.value == value).firstOrNull;
  }
}

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
  final Function(String guid, bool isFavorite, bool success)? onFavoriteToggle;
  final Function(String guid, bool isWatched, bool success)? onWatchedToggle;

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

class _MoviePosterState extends ConsumerState<MoviePoster> with SingleTickerProviderStateMixin {
  bool _isPlayButtonHovered = false;

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesManagerProvider);
    final baseUrl = prefs.getBaseUrl();
    final token = prefs.getToken();
    final cookie = prefs.getCookie();
    final resolvedPosterPath = widget.posterPath?.trim();
    final imageUrl = resolvedPosterPath != null && resolvedPosterPath.isNotEmpty && baseUrl != null
        ? '$baseUrl/v/api/v1/sys/img$resolvedPosterPath${resolvedPosterPath.contains('?') ? '' : '?w=400'}'
        : null;
    final httpHeaders = token != null || (cookie != null && cookie.isNotEmpty)
        ? {
            if (token != null) 'Authorization': token,
            if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
          }
        : null;
    final cacheManager = ref.watch(imageCacheManagerProvider);
    final theme = FluentTheme.of(context);
    final formattedScore = formatVoteAverage(widget.score);
    final showScore = formattedScore != '0.0';
    final scaleFactor = widget.scaleFactor;
    final scaledWidth = widget.width * scaleFactor;
    final scaledHeight = widget.height * scaleFactor;
    final displayResolutions = normalizeResolutions(widget.resolutions);
    final mediaType = FnMediaType.fromString(widget.type);
    final showFavoriteButton = mediaType != FnMediaType.season;

    // Play button sizes (matching Kotlin implementation)
    final normalPlayButtonSize = 48.0 * scaleFactor;
    final hoveredPlayButtonSize = 56.0 * scaleFactor;
    final playButtonSize = _isPlayButtonHovered ? hoveredPlayButtonSize : normalPlayButtonSize;

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
                Container(
                  height: scaledHeight,
                  width: scaledWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14 * scaleFactor),
                    border: Border.all(color: Colors.grey[160].withValues(alpha: 0.6)),
                    color: Colors.grey[160],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null)
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          httpHeaders: httpHeaders,
                          cacheManager: cacheManager,
                          fit: BoxFit.fitWidth,
                          fadeOutDuration: const Duration(milliseconds: 120),
                          errorWidget: (context, url, error) => const Center(child: Icon(FluentIcons.error)),
                          placeholder: (context, url) => const ImgLoadingProgressRing(),
                        )
                      else
                        const Center(child: Icon(FluentIcons.file_image)),
                      if (showScore)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                                  const Color(0xFF1C1C1C).withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (displayResolutions.isNotEmpty)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: displayResolutions.map((resolution) {
                              final lowerResolution = resolution.toLowerCase();
                              final isK = lowerResolution.endsWith('k');
                              final isP = lowerResolution.endsWith('p');
                              final label =
                                  isK ? resolution.toUpperCase() : (isP ? resolution.substring(0, resolution.length - 1) : resolution);
                              return Padding(
                                padding: EdgeInsets.only(left: 4 * scaleFactor),
                                child: Container(
                                  padding: EdgeInsets.fromLTRB(
                                    (isK ? 6 : 2) * scaleFactor,
                                    0.2 * scaleFactor,
                                    (isK ? 6 : 2) * scaleFactor,
                                    0.2 * scaleFactor,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isK ? Colors.white.withValues(alpha: 0.8) : Colors.transparent,
                                    border: isK
                                        ? null
                                        : Border.all(
                                            color: Colors.white.withValues(alpha: 0.6),
                                          width: 2 * scaleFactor,
                                          ),
                                    borderRadius: BorderRadius.circular(4 * scaleFactor),
                                  ),
                                  child: Transform.translate(
                                    offset: Offset(0, -0.6 * scaleFactor),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: isK ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.6),
                                        fontSize: (isK ? 12 : 10) * scaleFactor,
                                        fontWeight: isK ? FontWeight.w800 : FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isHovered ? 1 : 0,
                        child: Container(
                          color: const Color(0xFF1C1C1C).withValues(alpha: 0.5),
                        ),
                      ),
                      if (widget.onPlayTap != null)
                        Center(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isHovered ? 1 : 0,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) => setState(() => _isPlayButtonHovered = true),
                              onExit: (_) => setState(() => _isPlayButtonHovered = false),
                              child: GestureDetector(
                                onTap: widget.onPlayTap,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
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
                        left: 8,
                        bottom: 8,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isHovered ? 1 : 0,
                          child: Row(
                            children: [
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: IconButton(
                                  icon: Icon(
                                    FluentIcons.check_mark,
                                    color: widget.isWatched ? const Color(0xFF2173DF) : Colors.white,
                                  ),
                                  onPressed: () => _handleWatchedToggle(ref),
                                ),
                              ),
                              if (showFavoriteButton)
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: IconButton(
                                    icon: Icon(
                                      FluentIcons.favorite_star,
                                      color: widget.isFavorite ? const Color(0xFFFF0420) : Colors.white,
                                    ),
                                    onPressed: () => _handleFavoriteToggle(ref),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (widget.onMoreTap != null)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isHovered ? 1 : 0,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: IconButton(
                                icon: const Icon(FluentIcons.more),
                                onPressed: widget.onMoreTap,
                              ),
                            ),
                          ),
                        ),
                    ],
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
                      color: isHovered ? const Color(0xFF2073DF) : theme.typography.body?.color,
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
                        color: theme.typography.caption?.color?.withValues(alpha: 0.7),
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

    final mediaType = FnMediaType.fromString(widget.type);
    switch (mediaType) {
      case FnMediaType.movie:
      case FnMediaType.video:
        ref.read(navigationStackProvider.notifier).pushPath('/home');
        context.go('/movie/${widget.guid}');
        break;
      case FnMediaType.tv:
        ref.read(navigationStackProvider.notifier).pushPath('/home');
        context.go('/tv/${widget.guid}');
        break;
      case FnMediaType.season:
        ref.read(navigationStackProvider.notifier).pushPath('/home');
        context.go('/tv/season/${widget.guid}');
        break;
      case FnMediaType.person:
        // TODO: Person detail page not implemented yet
        break;
      case null:
        break;
    }
  }

  void _handleFavoriteToggle(WidgetRef ref) {
    if (widget.guid == null) return;
    final newFavorite = !widget.isFavorite;
    widget.onFavoriteToggle?.call(widget.guid!, newFavorite, true);
    if (widget.onFavoriteTap != null) {
      widget.onFavoriteTap!();
    }
  }

  void _handleWatchedToggle(WidgetRef ref) {
    if (widget.guid == null) return;
    final newWatched = !widget.isWatched;
    widget.onWatchedToggle?.call(widget.guid!, newWatched, true);
    if (widget.onWatchedTap != null) {
      widget.onWatchedTap!();
    }
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

List<String> normalizeResolutions(List<String>? input) {
  if (input == null || input.isEmpty) {
    return [];
  }
  final seen = <String>{};
  final result = <String>[];
  for (final resolution in input) {
    if (resolution == 'Others') {
      continue;
    }
    if (seen.add(resolution)) {
      result.add(resolution);
    }
  }
  return result;
}
