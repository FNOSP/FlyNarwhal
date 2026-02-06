import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/home_models.dart';
import '../../providers/providers.dart';
import 'scroll_row.dart';

class RecentlyWatched extends ConsumerWidget {
  final String title;
  final List<PlayDetailResponse> items;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  const RecentlyWatched({
    super.key,
    required this.title,
    required this.items,
    this.itemHeight = 240,
    this.padding = const EdgeInsets.symmetric(horizontal: 32),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 12),
          child: Text(title, style: FluentTheme.of(context).typography.subtitle),
        ),
        ScrollRow(
          height: itemHeight,
          padding: padding,
          itemSpacing: 16,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return RecentlyWatchedItem(item: item);
          },
        ),
      ],
    );
  }
}

class RecentlyWatchedItem extends ConsumerWidget {
  final PlayDetailResponse item;

  const RecentlyWatchedItem({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final prefs = ref.watch(preferencesManagerProvider);
    final baseUrl = prefs.getBaseUrl();
    final token = prefs.getToken();
    final cookie = prefs.getCookie();
    final resolvedPosterPath = item.poster?.trim();
    final imageUrl = resolvedPosterPath != null && resolvedPosterPath.isNotEmpty && baseUrl != null
        ? '$baseUrl/v/api/v1/sys/img$resolvedPosterPath${resolvedPosterPath.contains('?') ? '' : '?w=400'}'
        : null;
    final httpHeaders = token != null || (cookie != null && cookie.isNotEmpty)
        ? {
            if (token != null) 'Authorization': token,
            if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
          }
        : null;
    final progress = item.watched == 0 ? 0.0 : 1.0;
    final displayTitle = buildPlayDetailTitle(item);
    final displaySubtitle = buildPlayDetailSubtitle(item);

    return HoverButton(
      onPressed: () {},
      builder: (context, states) {
        final isHovered = states.isHovered;
        return SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
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
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          height: 5,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                                  Container(color: Colors.white.withValues(alpha: 0.05)),
                              if (progress > 0)
                                FractionallySizedBox(
                                  widthFactor: progress,
                                  child: Container(color: const Color(0xFF2073DF)),
                                ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isHovered ? 1 : 0,
                        child: Container(
                          color: const Color(0xFF1C1C1C).withValues(alpha: 0.5),
                        ),
                      ),
                      Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isHovered ? 1 : 0,
                          child: IconButton(
                            icon: const Icon(FluentIcons.play, size: 40),
                            onPressed: () {},
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isHovered ? 1 : 0,
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(FluentIcons.check_mark, color: item.watched == 1 ? Colors.green : Colors.white),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: Icon(FluentIcons.favorite_star, color: item.isFavorite == 1 ? Colors.red : Colors.white),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(FluentIcons.more),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 320,
                child: Text(
                  displayTitle,
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
              if (displaySubtitle != null) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: 320,
                  child: Text(
                    displaySubtitle,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption?.copyWith(
                      fontWeight: FontWeight.normal,
                      fontSize: 12,
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
