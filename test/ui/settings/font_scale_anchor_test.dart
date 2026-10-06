import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// 锁定「切换字号后把目标行钉回原位」的补偿算法。
///
/// 设置页里带 fontSize 的文本都跟随全局 textScaler（fluent_ui 重新导出了
/// Flutter 的 Text），改字号会撑高每一行，把下方正在操作的项推走。这里用
/// 与设置页同构的最小滚动结构复刻补偿：量出目标行在内容坐标中的位移，
/// 再用 ScrollPosition.correctBy 把它抵消掉。
void main() {
  const rowKey = ValueKey('font-scale-row');

  Widget build(double scale, ScrollController controller) {
    return MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FluentApp(
          home: ScaffoldPage(
            content: ListView(
              controller: controller,
              children: [
                for (var i = 0; i < 6; i++)
                  // 行高跟随 textScaler，模拟设置页里带 fontSize 的卡片行。
                  Builder(
                    builder: (context) => SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(40),
                      child: Text('row $i'),
                    ),
                  ),
                const SizedBox(
                  key: rowKey,
                  height: 40,
                  child: Text('字体大小'),
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('correctBy keeps the anchored row at the same viewport offset', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(build(1.0, controller));
    controller.jumpTo(120);
    await tester.pump();

    final viewport = find.byType(ScaffoldPage);
    double rowTopInViewport() {
      final rowBox = tester.renderObject<RenderBox>(find.byKey(rowKey));
      final viewportBox = tester.renderObject<RenderBox>(viewport);
      return rowBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
    }

    double rowOffsetInContent() =>
        rowTopInViewport() + controller.offset;

    final beforeContentOffset = rowOffsetInContent();
    final beforeTop = rowTopInViewport();

    // 放大字号：新排版把该行推下去。
    await tester.pumpWidget(build(1.25, controller));
    await tester.pump();
    final driftedTop = rowTopInViewport();
    final afterContentOffset = rowOffsetInContent();

    // 补偿：抵消内容坐标上的位移。
    controller.jumpTo(controller.offset + (afterContentOffset - beforeContentOffset));
    await tester.pump();

    expect(rowTopInViewport(), closeTo(beforeTop, 0.5));
    // 补偿前确实发生了位移，说明补偿是必要的。
    expect(driftedTop, isNot(closeTo(beforeTop, 0.5)));
  });
}
