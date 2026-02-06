import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'media_library_view_model.dart';
import '../../../data/models/home_models.dart';
import '../../widgets/movie_poster.dart';

class MediaLibraryScreen extends ConsumerWidget {
  final String? id;
  const MediaLibraryScreen({super.key, this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (id == null) return const Center(child: Text("Invalid Library ID"));
    
    final asyncData = ref.watch(mediaLibraryNotifierProvider(id!));
    final notifier = ref.read(mediaLibraryNotifierProvider(id!).notifier);
    final mdbName = asyncData.asData?.value.mdbName;

    return ScaffoldPage(
      header: PageHeader(title: Text(mdbName ?? '媒体库')),
      content: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
            notifier.loadMore();
          }
          return false;
        },
        child: asyncData.when(
          data: (data) {
            if (data.list.isEmpty) return const Center(child: Text("No items"));
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.6,
              ),
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
          loading: () => const Center(child: ProgressRing()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}
