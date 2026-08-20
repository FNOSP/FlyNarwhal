import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/entities/media_type.dart';
import '../home_view_model.dart';
import '../../../../data/models/home_models.dart';
import '../../../shared/movie_poster.dart';
import '../../../shared/common/scroll_row.dart';
import '../../../shared/common/app_loading_progress_ring.dart';
import '../../../../providers/providers.dart';

class MediaLibGallery extends ConsumerWidget {
  final String title;
  final String guid;
  final VoidCallback? onTitleTap;
  final Function(
          String guid, bool currentState, Function(bool success) callback)?
      onFavoriteToggle;
  final Function(
          String guid, bool currentState, Function(bool success) callback)?
      onWatchedToggle;

  const MediaLibGallery({
    super.key,
    required this.title,
    required this.guid,
    this.onTitleTap,
    this.onFavoriteToggle,
    this.onWatchedToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(itemListNotifierProvider(guid));
    final scaleFactor = resolveWindowScaleFactor(context);
    const posterHeight = 225.0;
    const posterWidth = posterHeight * 2 / 3;
    final scaledPosterHeight = posterHeight * scaleFactor;
    final captionStyle = FluentTheme.of(context)
        .typography
        .caption
        ?.copyWith(fontSize: 12 * scaleFactor);
    final subtitleStyle = FluentTheme.of(context)
        .typography
        .caption
        ?.copyWith(fontSize: 11 * scaleFactor);
    double lineHeight(TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: 'A', style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(minWidth: 0, maxWidth: double.infinity);
      return painter.height;
    }

    final titleHeight = lineHeight(captionStyle);
    final subtitleLineHeight = lineHeight(subtitleStyle);
    final textSpacing = (8 + 4) * scaleFactor;
    final rowHeight =
        scaledPosterHeight + textSpacing + titleHeight + subtitleLineHeight * 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleRow(context),
        listAsync.when(
          data: (data) {
            if (data.list.isEmpty) return const SizedBox.shrink();
            return ScrollRow(
              height: rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              itemSpacing: 16 * scaleFactor,
              itemCount: data.list.length,
              itemBuilder: (context, index) {
                final item = data.list[index];
                final isDirectory =
                    MediaType.tryParse(item.type) == MediaType.directory;
                return MoviePoster(
                  title: item.title,
                  subtitle: buildPosterSubtitle(item),
                  posterPath: item.effectivePoster,
                  score: item.voteAverage,
                  resolutions: item.mediaStream?.resolutions,
                  isFavorite: item.isFavorite == 1,
                  isWatched: (item.watched ?? 0) == 1,
                  width: posterWidth,
                  height: posterHeight,
                  scaleFactor: scaleFactor,
                  type: item.type,
                  guid: item.guid,
                  onTap: () {
                    switch (MediaType.tryParse(item.type)) {
                      case MediaType.tv:
                        context.go('/tv/${item.guid}');
                        break;
                      case MediaType.season:
                        context.go('/tv/season/${item.guid}');
                        break;
                      case MediaType.directory:
                        context.go('/folder/${item.guid}');
                        break;
                      default:
                        context.go('/movie/${item.guid}');
                    }
                  },
                  onPlayTap: isDirectory
                      ? null
                      : () {
                          if (item.type == MediaType.liveChannel.value) {
                            ref
                                .read(navigationStackProvider.notifier)
                                .playerSourcePath =
                                GoRouterState.of(context).uri.toString();
                            context.go('/live/${item.guid}');
                          } else {
                            context.go('/player/${item.guid}');
                          }
                        },
                  onFavoriteToggle: onFavoriteToggle,
                  onWatchedToggle: onWatchedToggle,
                );
              },
            );
          },
          loading: () => SizedBox(
            height: rowHeight,
            child: const Center(child: AppLoadingProgressRing()),
          ),
          error: (err, stack) => SizedBox(
            height: rowHeight,
            child: Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleRow(BuildContext context) {
    final callback = onTitleTap;
    if (callback == null) {
      return Padding(
        padding: const EdgeInsets.only(left: 32.0, bottom: 12.0),
        child: Text(
          title,
          style: FluentTheme.of(context)
              .typography
              .subtitle
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HoverButton(
        onPressed: callback,
        builder: (context, states) {
          return Padding(
            padding: const EdgeInsets.only(left: 32.0, bottom: 12.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: FluentTheme.of(context).typography.subtitle?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(
                  FluentIcons.chevron_right,
                  size: 12,
                  color: FluentTheme.of(context)
                      .typography
                      .subtitle
                      ?.color
                      ?.withValues(alpha: 0.7),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
