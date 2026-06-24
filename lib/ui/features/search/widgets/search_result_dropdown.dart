import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/home_models.dart';
import '../../../shared/common/fn_cached_image.dart';
import '../../../shared/movie_poster.dart' show formatVoteAverage;
import '../search_view_model.dart';

/// Dropdown panel showing search results with category tabs.
/// Replicates Compose SearchResultDropdown styling and layout.
class SearchResultDropdown extends ConsumerWidget {
  final double width;
  final bool isLoading;
  final bool hasSearched;
  final List<String> tabs;
  final String selectedTab;
  final ValueChanged<String> onTabSelected;
  final List<MediaItem> items;
  final int selectedIndex;
  final ValueChanged<MediaItem> onItemSelected;
  final VoidCallback onPointerInteractionStart;
  final VoidCallback onPointerInteractionEnd;

  const SearchResultDropdown({
    super.key,
    required this.width,
    required this.isLoading,
    required this.hasSearched,
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onPointerInteractionStart,
    required this.onPointerInteractionEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final genresAsync = ref.watch(searchGenresProvider);
    final genresMap = genresAsync.valueOrNull ?? const <int, String>{};

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onPointerInteractionStart(),
      onPointerCancel: (_) => onPointerInteractionEnd(),
      onPointerUp: (_) => onPointerInteractionEnd(),
      child: Container(
        width: width,
        height: 500,
        decoration: BoxDecoration(
          color: theme.resources.solidBackgroundFillColorBase,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.resources.surfaceStrokeColorDefault,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  for (final tab in tabs) ...[
                    _TabLabel(
                      text: tab,
                      isSelected: tab == selectedTab,
                      onPointerInteractionStart: onPointerInteractionStart,
                      onPointerInteractionEnd: onPointerInteractionEnd,
                      onTap: () => onTabSelected(tab),
                    ),
                    const SizedBox(width: 24),
                  ],
                ],
              ),
            ),
            Container(
              height: 1,
              color: theme.resources.surfaceStrokeColorDefault.withValues(alpha: 0.1),
            ),
            Expanded(
              child: _buildContent(context, theme, genresMap),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    FluentThemeData theme,
    Map<int, String> genresMap,
  ) {
    if (isLoading && items.isEmpty) {
      return const Center(child: ProgressRing());
    }
    if (items.isEmpty) {
      return _EmptyResult(hasSearched: hasSearched);
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _SearchResultItem(
          item: items[index],
          isSelected: index == selectedIndex,
          genresMap: genresMap,
          onPointerInteractionStart: onPointerInteractionStart,
          onPointerInteractionEnd: onPointerInteractionEnd,
          onTap: () => onItemSelected(items[index]),
        );
      },
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onPointerInteractionStart;
  final VoidCallback onPointerInteractionEnd;
  final VoidCallback onTap;

  const _TabLabel({
    required this.text,
    required this.isSelected,
    required this.onPointerInteractionStart,
    required this.onPointerInteractionEnd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) {
          onPointerInteractionStart();
        },
        onTapCancel: onPointerInteractionEnd,
        onTap: () {
          onTap();
          onPointerInteractionEnd();
        },
        child: Text(
          text,
          style: theme.typography.body?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? const Color(0xFF2173DF)
                : theme.resources.textFillColorSecondary,
          ),
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  final bool hasSearched;

  const _EmptyResult({required this.hasSearched});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.search_issue,
            size: 48,
            color: theme.resources.textFillColorTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            hasSearched ? '搜索无结果' : '输入关键词搜索',
            style: theme.typography.body?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultItem extends StatefulWidget {
  final MediaItem item;
  final bool isSelected;
  final Map<int, String> genresMap;
  final VoidCallback onPointerInteractionStart;
  final VoidCallback onPointerInteractionEnd;
  final VoidCallback onTap;

  const _SearchResultItem({
    required this.item,
    required this.isSelected,
    required this.genresMap,
    required this.onPointerInteractionStart,
    required this.onPointerInteractionEnd,
    required this.onTap,
  });

  @override
  State<_SearchResultItem> createState() => _SearchResultItemState();
}

class _SearchResultItemState extends State<_SearchResultItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final item = widget.item;
    final isPerson = item.type == 'Person';
    final highlight = widget.isSelected || _isHovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          widget.onPointerInteractionStart();
        },
        onTapCancel: widget.onPointerInteractionEnd,
        onTap: () {
          widget.onTap();
          widget.onPointerInteractionEnd();
        },
        child: Container(
          height: 80,
          color: highlight
              ? theme.resources.subtleFillColorSecondary
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Poster, 11:17 aspect ratio
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 64 * 11 / 17,
                  height: 64,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: item.poster != null && item.poster!.isNotEmpty
                      ? FnCachedImage(
                          posterPath: item.poster!,
                          width: 64,
                          placeholderSize: 16,
                        )
                      : Icon(
                          isPerson ? FluentIcons.contact : FluentIcons.video,
                          size: 20,
                          color: theme.resources.textFillColorTertiary,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfo(theme, item, isPerson),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(FluentThemeData theme, MediaItem item, bool isPerson) {
    if (isPerson) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.title,
            style: theme.typography.bodyStrong,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${item.numberOfItem ?? 0} 个作品',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      );
    }

    final voteAverage = formatVoteAverage(item.voteAverage);
    final showScore = voteAverage != '0.0';
    final genresText = item.genres
        ?.map((id) => widget.genresMap[id])
        .where((e) => e != null && e.isNotEmpty)
        .join(' / ');
    final year = item.releaseDate?.trim().isNotEmpty == true
        ? item.releaseDate!.substring(
            0, item.releaseDate!.length >= 4 ? 4 : item.releaseDate!.length)
        : (item.firstAirDate?.trim().isNotEmpty == true
            ? item.firstAirDate!.substring(0,
                item.firstAirDate!.length >= 4 ? 4 : item.firstAirDate!.length)
            : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          item.title,
          style: theme.typography.bodyStrong,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (showScore) ...[
              Text(
                voteAverage,
                style: theme.typography.body?.copyWith(
                  color: const Color(0xFFFACC15),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '分',
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (genresText != null && genresText.isNotEmpty)
              Flexible(
                child: Text(
                  genresText,
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        if (year.isNotEmpty ||
            (item.type == 'TV' && (item.numberOfEpisodes ?? 0) > 0)) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              if (year.isNotEmpty)
                Text(
                  year,
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              if (item.type == 'TV' && (item.numberOfEpisodes ?? 0) > 0) ...[
                if (year.isNotEmpty) const SizedBox(width: 8),
                Text(
                  '共 ${item.numberOfEpisodes} 集',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
