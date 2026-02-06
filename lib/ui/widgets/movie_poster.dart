import 'package:fluent_ui/fluent_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

class MoviePoster extends ConsumerWidget {
  final String? posterPath;
  final String title;
  final String? subtitle;
  final List<String>? resolutions;
  final double width;
  final double height;
  final String? score;
  final bool isFavorite;
  final bool isWatched;
  final VoidCallback? onTap;
  final VoidCallback? onPlayTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onWatchedTap;
  final VoidCallback? onMoreTap;

  const MoviePoster({
    super.key,
    this.posterPath,
    required this.title,
    this.subtitle,
    this.resolutions,
    this.width = 150,
    this.height = 225,
    this.score,
    this.isFavorite = false,
    this.isWatched = false,
    this.onTap,
    this.onPlayTap,
    this.onFavoriteTap,
    this.onWatchedTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesManagerProvider);
    final baseUrl = prefs.getBaseUrl();
    final token = prefs.getToken();
    final cookie = prefs.getCookie();
    final resolvedPosterPath = posterPath?.trim();
    final imageUrl = resolvedPosterPath != null && resolvedPosterPath.isNotEmpty && baseUrl != null
        ? '$baseUrl/v/api/v1/sys/img$resolvedPosterPath${resolvedPosterPath.contains('?') ? '' : '?w=400'}'
        : null;
    final httpHeaders = token != null || (cookie != null && cookie.isNotEmpty)
        ? {
            if (token != null) 'Authorization': token,
            if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
          }
        : null;
    final theme = FluentTheme.of(context);
    final formattedScore = formatVoteAverage(score);
    final showScore = formattedScore != '0.0';

    return HoverButton(
      onPressed: onTap,
      builder: (context, states) {
        final isHovered = states.isHovered;
        return SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: height,
                width: width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
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
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Center(child: Icon(FluentIcons.error)),
                        placeholder: (context, url) => const Center(child: ProgressRing()),
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
                          height: height / 2,
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
                    if (resolutions != null && resolutions!.isNotEmpty)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: resolutions!.map((resolution) {
                            final isK = resolution.toLowerCase().endsWith('k');
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isK ? Colors.white.withValues(alpha: 0.8) : Colors.transparent,
                                  border: isK ? null : Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  isK ? resolution.toUpperCase() : resolution.replaceAll(RegExp('[kK]'), ''),
                                  style: TextStyle(
                                    color: isK ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontWeight: isK ? FontWeight.w800 : FontWeight.bold,
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
                    if (onPlayTap != null)
                      Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isHovered ? 1 : 0,
                          child: IconButton(
                            icon: const Icon(FluentIcons.play, size: 40),
                            onPressed: onPlayTap,
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
                            if (onWatchedTap != null)
                              IconButton(
                                icon: Icon(FluentIcons.check_mark, color: isWatched ? Colors.green : Colors.white),
                                onPressed: onWatchedTap,
                              ),
                            if (onFavoriteTap != null)
                              IconButton(
                                icon: Icon(FluentIcons.favorite_star, color: isFavorite ? Colors.red : Colors.white),
                                onPressed: onFavoriteTap,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (onMoreTap != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isHovered ? 1 : 0,
                          child: IconButton(
                            icon: const Icon(FluentIcons.more),
                            onPressed: onMoreTap,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: width,
                child: Text(
                  title,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption?.copyWith(
                    fontWeight: FontWeight.normal,
                    fontSize: 12,
                    color: isHovered ? const Color(0xFF2073DF) : theme.typography.body?.color,
                  ),
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: width,
                  child: Text(
                    subtitle!,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption?.copyWith(
                      fontWeight: FontWeight.normal,
                      fontSize: 11,
                      color: theme.typography.caption?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
