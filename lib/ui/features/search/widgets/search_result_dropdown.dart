import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/search_result_type.dart';

import '../../../../data/models/home_models.dart';
import '../../../shared/common/fn_cached_image.dart';
import '../../../shared/common/app_loading_progress_ring.dart';
import '../../../shared/movie_poster.dart' show formatVoteAverage;
import '../search_view_model.dart';

/// Fixed height of each result row; the scroll-follow math in
/// [_SearchResultDropdownState] depends on it.
const double _kResultItemHeight = 80.0;

/// Dropdown panel showing search results with category tabs.
/// Replicates Compose SearchResultDropdown styling and layout.
class SearchResultDropdown extends ConsumerStatefulWidget {
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
  ConsumerState<SearchResultDropdown> createState() =>
      _SearchResultDropdownState();
}

class _SearchResultDropdownState extends ConsumerState<SearchResultDropdown> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SearchResultDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectionChanged = oldWidget.selectedIndex != widget.selectedIndex;
    final itemsChanged = !identical(oldWidget.items, widget.items);
    if (!selectionChanged && !itemsChanged) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToSelected();
    });
  }

  /// Scrolls the minimal distance so [widget.selectedIndex] is fully visible,
  /// mirroring Compose's bringIntoView on keyboard navigation. Does nothing
  /// when the selected item is already within the viewport.
  void _scrollToSelected() {
    final index = widget.selectedIndex;
    if (index < 0 || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final itemTop = index * _kResultItemHeight;
    final itemBottom = itemTop + _kResultItemHeight;
    final viewportTop = position.pixels;
    final viewportBottom = viewportTop + position.viewportDimension;
    double? target;
    if (itemBottom > viewportBottom) {
      target = itemBottom - position.viewportDimension;
    } else if (itemTop < viewportTop) {
      target = itemTop;
    }
    if (target == null) return;
    target = target.clamp(0.0, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 0.5) return;
    position.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final genresAsync = ref.watch(searchGenresProvider);
    final genresMap = genresAsync.valueOrNull ?? const <int, String>{};

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => widget.onPointerInteractionStart(),
      onPointerCancel: (_) => widget.onPointerInteractionEnd(),
      onPointerUp: (_) => widget.onPointerInteractionEnd(),
      child: Acrylic(
        tint: theme.resources.solidBackgroundFillColorBase,
        tintAlpha: 0.8,
        blurAmount: 30,
        elevation: 8,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: theme.resources.surfaceStrokeColorDefault,
            width: 1,
          ),
        ),
        child: SizedBox(
          width: widget.width,
          height: 500,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category tabs
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final tab in widget.tabs)
                        _TabLabel(
                          text: tab,
                          isSelected: tab == widget.selectedTab,
                          onPointerInteractionStart:
                              widget.onPointerInteractionStart,
                          onPointerInteractionEnd:
                              widget.onPointerInteractionEnd,
                          onTap: () => widget.onTabSelected(tab),
                        ),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  color: theme.resources.surfaceStrokeColorDefault
                      .withValues(alpha: 0.1),
                ),
                Expanded(
                  child: _buildContent(context, theme, genresMap),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    FluentThemeData theme,
    Map<int, String> genresMap,
  ) {
    if (widget.isLoading && widget.items.isEmpty) {
      return const Center(child: AppLoadingProgressRing());
    }
    if (widget.items.isEmpty) {
      return _EmptyResult(hasSearched: widget.hasSearched);
    }
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        return _SearchResultItem(
          item: widget.items[index],
          isSelected: index == widget.selectedIndex,
          genresMap: genresMap,
          onPointerInteractionStart: widget.onPointerInteractionStart,
          onPointerInteractionEnd: widget.onPointerInteractionEnd,
          onTap: () => widget.onItemSelected(widget.items[index]),
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
          if (hasSearched)
            Image.asset(
              'assets/images/search_no_result.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            )
          else
            Icon(
              FluentIcons.search,
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
    final isPerson =
        SearchResultType.tryParse(item.type) == SearchResultType.person;
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
          height: _kResultItemHeight,
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
                      : Image.asset(
                          isPerson
                              ? 'assets/images/person_placeholder.png'
                              : 'assets/images/video_no_cover.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
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
