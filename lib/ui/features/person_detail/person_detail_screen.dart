import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/person_models.dart';
import '../../../providers/global_refresh.dart';
import '../../shared/common/fn_cached_image.dart';
import '../../shared/common/app_loading_progress_ring.dart';
import '../../shared/movie_poster.dart';
import 'person_detail_view_model.dart';

/// Person detail page: avatar, name, biography and works grouped by job.
/// Built to mirror Compose PersonDetailScreen.
class PersonDetailScreen extends ConsumerWidget {
  final String guid;

  const PersonDetailScreen({super.key, required this.guid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Consume each global refresh request once for the current person detail page.
    ref.listen<GlobalRefreshRequest?>(
      currentGlobalRefreshRequestProvider,
      (_, next) {
        unawaited(
          ref.read(globalRefreshManagerProvider).handleRefresh(
                consumerId: 'person-detail:$guid',
                request: next,
                onRefresh: () => ref
                    .read(personDetailNotifierProvider(guid).notifier)
                    .refresh(),
              ),
        );
      },
    );
    final detailState = ref.watch(personDetailNotifierProvider(guid));
    final theme = FluentTheme.of(context);
    final scaffoldBackgroundColor = theme.brightness == Brightness.dark
        ? const Color(0xFF282828)
        : theme.scaffoldBackgroundColor;

    return FluentTheme(
      data: theme.copyWith(scaffoldBackgroundColor: scaffoldBackgroundColor),
      child: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: detailState.when(
          data: (state) => _PersonDetailContent(state: state),
          loading: () => const Center(child: AppLoadingProgressRing()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('加载失败: $error'),
                const SizedBox(height: 16),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Button(
                    child: const Text('重试'),
                    onPressed: () => ref
                        .read(personDetailNotifierProvider(guid).notifier)
                        .refresh(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonDetailContent extends ConsumerWidget {
  final PersonDetailState state;

  const _PersonDetailContent({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = state.person;
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 56, 48, 24),
                child: _PersonHeader(person: person),
              ),
            ),
            if (state.actorWorks.isNotEmpty)
              _buildSection(context, ref, '作为演员', state.actorWorks),
            if (state.directorWorks.isNotEmpty)
              _buildSection(context, ref, '作为导演', state.directorWorks),
            if (state.screenplayWorks.isNotEmpty)
              _buildSection(context, ref, '作为编剧', state.screenplayWorks),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<PersonItemList> works,
  ) {
    final theme = FluentTheme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 8, 48, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.typography.subtitle,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final work in works)
                  MoviePoster(
                    posterPath: work.poster,
                    title: work.title,
                    subtitle: _takeYear(work.releaseDate),
                    score: work.voteAverage,
                    resolutions: work.mediaStream?.resolutions,
                    isFavorite: work.isFavorite == 1,
                    isWatched: work.watched == 1,
                    type: work.type,
                    guid: work.guid,
                    width: 130,
                    height: 195,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _takeYear(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final t = value.trim();
    return t.length >= 4 ? t.substring(0, 4) : t;
  }
}

class _PersonHeader extends StatefulWidget {
  final PersonResponse person;

  const _PersonHeader({required this.person});

  @override
  State<_PersonHeader> createState() => _PersonHeaderState();
}

class _PersonHeaderState extends State<_PersonHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final person = widget.person;
    final hasBiography =
        person.biography != null && person.biography!.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar, 2:3 ratio
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 180,
            height: 270,
            decoration: BoxDecoration(
              color: theme.resources.subtleFillColorSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: person.profile != null && person.profile!.isNotEmpty
                ? FnCachedImage(
                    posterPath: person.profile!,
                    width: 180,
                    placeholderSize: 28,
                  )
                : Icon(
                    FluentIcons.contact,
                    size: 64,
                    color: theme.resources.textFillColorTertiary,
                  ),
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.name,
                style: theme.typography.title,
              ),
              if (person.originalName != null &&
                  person.originalName!.trim().isNotEmpty &&
                  person.originalName != person.name) ...[
                const SizedBox(height: 4),
                Text(
                  person.originalName!,
                  style: theme.typography.body?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ],
              if (hasBiography) ...[
                const SizedBox(height: 16),
                Text(
                  person.biography!,
                  style: theme.typography.body,
                  maxLines: _expanded ? null : 7,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? '收起' : '更多',
                      style: theme.typography.body?.copyWith(
                        color: const Color(0xFF2173DF),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
