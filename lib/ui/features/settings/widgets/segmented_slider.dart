import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';

/// 分段式选择器：圆角矩形凹槽内一枚滑块随选中项平移，滑块可悬停高亮。
///
/// 用于把离散档位的 Slider 换成更直观的按钮组，交互上等价于单值选择。
/// 圆角与 Fluent 按钮保持一致（4px），使它与设置页其他按钮同族。
class SegmentedSlider<T> extends StatefulWidget {
  const SegmentedSlider({
    super.key,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
    this.maxItemWidth = 120,
    this.padding = 16,
    this.height = 24,
    this.spacing = 2,
    this.cornerRadius = 4,
  });

  /// 档位顺序，决定滑块从左到右的位置。
  final List<T> values;

  /// 当前选中档位，不在 [values] 中时按第一项显示。
  final T selected;

  /// 档位文案。
  final String Function(T value) labelBuilder;

  final ValueChanged<T> onChanged;

  /// 单项宽度上限；超过它的文案会被省略号截断，防止超长翻译撑破布局。
  final double maxItemWidth;

  /// 单项左右内边距，决定文字与凹槽边缘的最小留白。
  final double padding;

  final double height;

  /// 项与项之间（以及凹槽内边距）的间隙。
  final double spacing;

  /// 凹槽与滑块的圆角，默认与 Fluent 按钮一致。
  final double cornerRadius;

  @override
  State<SegmentedSlider<T>> createState() => _SegmentedSliderState<T>();
}

class _SegmentedSliderState<T> extends State<SegmentedSlider<T>> {
  int _hoveredIndex = -1;

  int get _selectedIndex {
    final index = widget.values.indexOf(widget.selected);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final count = widget.values.length;
    final gap = widget.spacing;
    final radius = BorderRadius.circular(widget.cornerRadius);
    final trackColor = isDark
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFEDEDED);
    final thumbColor = isDark
        ? const Color(0xFF3F3F3F)
        : const Color(0xFFFFFFFF);
    final selectedTextColor = theme.typography.body?.color ??
        (isDark ? Colors.white : Colors.black);
    final idleTextColor =
        isDark ? const Color(0xFF9A9A9A) : const Color(0xFF6B6B6B);

    // 档位文案随语言变化，实测最长文案的固有宽度后反推单项宽度：
    // 各项等宽（文案切换档时不跳动），凹槽与滑块的外围尺寸都由它推出。
    final textScaler = MediaQuery.textScalerOf(context);
    final labelStyle = const TextStyle(fontSize: 13);
    var widest = 0.0;
    for (final value in widget.values) {
      final painter = TextPainter(
        text: TextSpan(text: widget.labelBuilder(value), style: labelStyle),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    final itemWidth =
        math.min(widest + widget.padding * 2, widget.maxItemWidth);

    // 整体宽度由项数与项宽推出，选中下标直接换算成滑块左偏移。
    final trackWidth = itemWidth * count + gap * (count - 1);
    final thumbLeft = _selectedIndex * (itemWidth + gap);

    return SizedBox(
      width: trackWidth + gap * 2,
      height: widget.height + gap * 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(
            widget.cornerRadius + gap,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(gap),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: thumbLeft,
                top: 0,
                width: itemWidth,
                height: widget.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: thumbColor,
                    borderRadius: radius,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF5A5A5A)
                          : const Color(0xFFD6D6D6),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < count; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    _buildItem(
                      index: i,
                      width: itemWidth,
                      isSelected: i == _selectedIndex,
                      selectedTextColor: selectedTextColor,
                      idleTextColor: idleTextColor,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem({
    required int index,
    required double width,
    required bool isSelected,
    required Color selectedTextColor,
    required Color idleTextColor,
  }) {
    final value = widget.values[index];
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = -1),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (value != widget.selected) {
            widget.onChanged(value);
          }
        },
        child: SizedBox(
          width: width,
          height: widget.height,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? selectedTextColor
                    : (_hoveredIndex == index
                        ? selectedTextColor
                        : idleTextColor),
              ),
              // 宽度已按最长文案留足内边距，单行 + 省略号只兜底超长翻译。
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.spacing),
                child: Text(
                  widget.labelBuilder(value),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
