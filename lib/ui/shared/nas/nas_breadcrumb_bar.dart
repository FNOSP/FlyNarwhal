import 'package:fluent_ui/fluent_ui.dart';

/// A breadcrumb path bar that replicates the web player's truncation logic:
/// - Root crumb (first): shows in full (no width cap).
/// - Middle crumbs: each hard-capped at [middleMaxWidth], ellipsis when longer.
/// - Last crumb (active file): absorbs all remaining space.
///
/// The bar is always one row — no wrap, no horizontal scroll.
class NasBreadcrumbBar extends StatelessWidget {
  final List<String> segments;
  final TextStyle style;

  /// Hard cap for middle crumbs (matches the web's 100px).
  final double middleMaxWidth;

  /// Fixed width of the chevron separator between crumbs.
  final double chevronWidth;

  /// Height of the bar.
  final double height;

  const NasBreadcrumbBar({
    super.key,
    required this.segments,
    required this.style,
    this.middleMaxWidth = 100,
    this.chevronWidth = 20,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return SizedBox(height: height);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final widths = _computeWidths(context, w);
          return ClipRect(
            child: Row(
              children: [
                for (var i = 0; i < segments.length; i++) ...[
                  if (i > 0) _buildChevron(),
                  _buildCrumb(i, widths[i]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Compute the allocated width for each crumb following the web algorithm.
  List<double> _computeWidths(BuildContext context, double w) {
    final n = segments.length;
    if (n == 1) return [w];

    final naturals = segments.map((s) => _measureText(context, s)).toList();

    if (n == 2) {
      final rootW = naturals[0].clamp(0.0, w);
      final lastW = (w - rootW - chevronWidth).clamp(0.0, w);
      return [rootW, lastW];
    }

    // n >= 3
    final rootW = naturals[0].clamp(0.0, w);
    final middleWidths = <double>[];
    for (var i = 1; i < n - 1; i++) {
      middleWidths.add(naturals[i].clamp(0.0, middleMaxWidth));
    }
    final fixed = rootW +
        middleWidths.fold<double>(0, (sum, mw) => sum + chevronWidth + mw) +
        chevronWidth; // trailing chevron before last crumb
    final lastW = (w - fixed).clamp(0.0, w);

    return [rootW, ...middleWidths, lastW];
  }

  double _measureText(BuildContext context, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  Widget _buildChevron() {
    return SizedBox(
      width: chevronWidth,
      child: const Center(
        child: Icon(
          FluentIcons.chevron_right_small,
          size: 10,
          color: Color(0x80FFFFFF),
        ),
      ),
    );
  }

  Widget _buildCrumb(int index, double width) {
    final isLast = index == segments.length - 1;
    final isFirst = index == 0;
    final text = segments[index];

    // When there's only one segment (initial state), it's the root — normal weight.
    // When there are multiple, the last one is the active target — bold.
    final isTarget = isLast && segments.length > 1;

    final crumbStyle = isTarget
        ? style.copyWith(fontWeight: FontWeight.w500)
        : style.copyWith(
            fontWeight: FontWeight.normal,
            color: isFirst
                ? style.color
                : style.color?.withValues(alpha: 0.78) ??
                    const Color(0xC8FFFFFF),
          );

    final cursor = isFirst || isTarget
        ? SystemMouseCursors.basic
        : SystemMouseCursors.click;

    return Tooltip(
      message: text,
      child: MouseRegion(
        cursor: cursor,
        child: SizedBox(
          width: width,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: crumbStyle,
          ),
        ),
      ),
    );
  }
}
