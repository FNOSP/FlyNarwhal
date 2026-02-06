import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/home/home_view_model.dart';
import '../../data/models/home_models.dart';
import 'movie_poster.dart';
import 'scroll_row.dart';

class MediaLibGallery extends ConsumerWidget {
  final String title;
  final String guid;

  const MediaLibGallery({super.key, required this.title, required this.guid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(itemListNotifierProvider(guid));
    
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
              height: 280,
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              itemSpacing: 16,
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
                  width: 150,
                  height: 225,
                  onTap: () {},
                );
              },
            );
          },
          loading: () => const SizedBox(
            height: 280,
            child: Center(child: ProgressRing()),
          ),
          error: (err, stack) => SizedBox(
            height: 280,
            child: Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }
}
