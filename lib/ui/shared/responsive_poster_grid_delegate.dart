import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// 复刻 Web `/v/library/:id` 竖幅海报网格的响应式规则：
///
/// 列数 = max(1, floor(可用宽度 / [minColumnStride]))；
/// 海报宽度填满列宽 = (可用宽度 - (列数 - 1) * [crossAxisSpacing]) / 列数；
/// 高度按 2:3 竖幅比例推导，下方再预留标题/副标题文字区高度。
///
/// 窗口变宽时列数增加、单张海报收窄（下限约 140）；窗口变窄时列数减少、
/// 海报加宽，横向间距始终保持 [crossAxisSpacing] 固定，与 Web 行为一致。
class ResponsivePosterGridDelegate extends SliverGridDelegate {
  const ResponsivePosterGridDelegate({
    this.minColumnStride = 160,
    this.crossAxisSpacing = 20,
    this.mainAxisSpacing = 8,
    this.posterAspectRatio = 2 / 3,
    required this.textBlockExtent,
  });

  /// 单列步长下限（海报最小宽度 + 横向间距）。Web 为 140 + 20 = 160。
  final double minColumnStride;

  /// 海报之间的横向间距，与 Web 的 gap-x-5 (20px) 一致。
  final double crossAxisSpacing;

  /// 行与行之间的纵向间距。
  final double mainAxisSpacing;

  /// 海报宽高比（宽 / 高），竖幅为 2:3。
  final double posterAspectRatio;

  /// 海报下方文字区（标题/副标题及其间距）预留的总高度。
  final double textBlockExtent;

  /// 与 Web 一致的列数公式：max(1, floor(可用宽度 / 列步长))。
  static int columnCountFor(double availableWidth, double minColumnStride) {
    return math.max(1, (availableWidth / minColumnStride).floor());
  }

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final double availableWidth = constraints.crossAxisExtent;
    final int cols = columnCountFor(availableWidth, minColumnStride);
    final double itemWidth =
        (availableWidth - (cols - 1) * crossAxisSpacing) / cols;
    final double itemHeight =
        itemWidth / posterAspectRatio + textBlockExtent;
    return SliverGridRegularTileLayout(
      crossAxisCount: cols,
      mainAxisStride: itemHeight + mainAxisSpacing,
      crossAxisStride: itemWidth + crossAxisSpacing,
      childMainAxisExtent: itemHeight,
      childCrossAxisExtent: itemWidth,
      reverseCrossAxis:
          axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(covariant ResponsivePosterGridDelegate oldDelegate) {
    return oldDelegate.minColumnStride != minColumnStride ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing ||
        oldDelegate.posterAspectRatio != posterAspectRatio ||
        oldDelegate.textBlockExtent != textBlockExtent;
  }
}
