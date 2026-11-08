import 'package:fluent_ui/fluent_ui.dart';

import '../tv_theme.dart';

/// Horizontal content shelf (design `.shelf`): baseline-aligned head
/// (title + count + more link) over a horizontally scrolling card row with a
/// 120px fade at the trailing edge.
///
/// Cards wrapped in [TvFocusable] carry a 7px focus halo, so [itemExtent]
/// must be the card width + 14 + the desired visual gap, and the row padding
/// compensates the halo on the leading edge.
class TvShelf extends StatelessWidget {
  const TvShelf({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemExtent,
    required this.rowHeight,
    required this.itemBuilder,
    this.countLabel,
    this.moreLabel,
    this.marginTop = 0,
    this.scrollController,
  });

  final String title;
  final String? countLabel;
  final String? moreLabel;
  final double marginTop;
  final int itemCount;

  /// Full width per row slot: card + focus halo + visual gap.
  final double itemExtent;

  /// Card column height including the 14px focus halo.
  final double rowHeight;
  final NullableIndexedWidgetBuilder itemBuilder;
  final ScrollController? scrollController;

  /// Vertical breathing room so the focus ring/glow of scaled cards is not
  /// clipped by the row viewport.
  static const double _glowMargin = 24;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: marginTop,
        bottom: TvTheme.shelfBottomMargin,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TvTheme.sidePadding,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(title, style: TvTheme.shelfTitle),
                if (countLabel != null) ...[
                  const SizedBox(width: 12),
                  Text(countLabel!, style: TvTheme.shelfCount),
                ],
                const Spacer(),
                if (moreLabel != null)
                  Text(moreLabel!, style: TvTheme.shelfMore),
              ],
            ),
          ),
          const SizedBox(height: TvTheme.shelfHeadBottomMargin),
          SizedBox(
            height: rowHeight + _glowMargin * 2,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListView.builder(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.hardEdge,
                    padding: const EdgeInsets.symmetric(
                      horizontal: TvTheme.sidePadding - TvTheme.focusHaloExtent,
                      vertical: _glowMargin,
                    ),
                    itemExtent: itemExtent,
                    itemCount: itemCount,
                    itemBuilder: (context, index) => Align(
                      alignment: Alignment.centerLeft,
                      child: itemBuilder(context, index),
                    ),
                  ),
                ),
                // Trailing edge fade (`.shelf::after`).
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: TvTheme.shelfFadeWidth,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0x00101011), TvTheme.bgBase],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
