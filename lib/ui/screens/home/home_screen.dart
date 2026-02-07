import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'home_view_model.dart';
import '../../widgets/media_lib_card_row.dart';
import '../../widgets/media_lib_gallery.dart';
import '../../widgets/recently_watched.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaDbListAsync = ref.watch(mediaDbListNotifierProvider);
    final playListAsync = ref.watch(playListNotifierProvider);
    
    return ScaffoldPage(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 36, left: 32, bottom: 32),
            child: Text(
              "首页",
              style: FluentTheme.of(context).typography.subtitle,
            ),
          ),
          Expanded(
            child: Scrollbar(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  mediaDbListAsync.when(
                    data: (data) => MediaLibCardRow(
                      items: data,
                      onItemClick: (item) {
                        context.go('/library/${item.guid}');
                      },
                    ),
                    loading: () => const Center(child: ProgressRing()),
                    error: (err, stack) => Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text('Error loading libraries: $err'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  playListAsync.when(
                    data: (data) => RecentlyWatched(
                      title: "继续观看",
                      items: data,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (err, stack) => const SizedBox.shrink(),
                  ),
                  // const SizedBox(height: 12),
                  mediaDbListAsync.when(
                    data: (data) {
                      return Column(
                        children: data
                            .map(
                              (lib) => MediaLibGallery(
                                title: lib.title,
                                guid: lib.guid,
                              ),
                            )
                            .toList(),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (err, stack) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
