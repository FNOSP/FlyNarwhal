import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/home/home_view_model.dart';
import '../../data/models/home_models.dart';
import 'movie_poster.dart';
import 'scroll_row.dart';

class MediaLibGallery extends ConsumerWidget {
  final String title;
  final String guid;
  final Function(String guid, bool currentState, Function(bool success) callback)? onFavoriteToggle;
  final Function(String guid, bool currentState, Function(bool success) callback)? onWatchedToggle;

  const MediaLibGallery({
    super.key,
    required this.title,
    required this.guid,
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
    final captionStyle = FluentTheme.of(context).typography.caption?.copyWith(fontSize: 12 * scaleFactor);
    final subtitleStyle = FluentTheme.of(context).typography.caption?.copyWith(fontSize: 11 * scaleFactor);
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
    final rowHeight = scaledPosterHeight + textSpacing + titleHeight + subtitleLineHeight * 2;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
          child: Text(title, style: FluentTheme.of(context).typography.subtitle),
        ),
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
                return MoviePoster(
                  title: item.title,
                  subtitle: buildPosterSubtitle(item),
                  posterPath: item.poster,
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
                    if (item.type == 'TV') {
                      context.go('/tv/${item.guid}');
                    } else {
                      context.go('/movie/${item.guid}');
                    }
                  },
                  onPlayTap: () {
                    context.go('/player/${item.guid}');
                  },
                  onFavoriteToggle: onFavoriteToggle,
                  onWatchedToggle: onWatchedToggle,
                );
              },
            );
          },
          loading: () => SizedBox(
            height: rowHeight,
            child: const Center(child: ProgressRing()),
          ),
          error: (err, stack) => SizedBox(
            height: rowHeight,
            child: Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }
}