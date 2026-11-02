import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// 回归：设置页切换字号时整页被打进错误屏。
///
/// 触发链是 `MediaQuery(textScaler:)` 换掉列表子树 → 行上的 GlobalKey
/// 驱动框架去 inactive 队列认领旧 element（`_retakeInactiveElement`）→
/// 断言 `_InactiveElements.remove` 失败（`_elements.contains(element)`）。
/// 修复把该行的 key 换成同类型的 [ValueKey]，让框架就地更新这一行、不再
/// 牵动 element 的跨父级迁移。
///
/// 这里用与设置页同构的最小结构锁住这个性质：同一个列表子树在 textScaler
/// 之间来回切换，命中 key 的 element 必须始终是同一个，且全程不抛异常。
void main() {
  /// 与设置页一致：行高跟随 textScaler，改字号会撑高每一行。
  Widget build(double scale, Key rowKey) {
    return MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FluentApp(
          home: ScaffoldPage(
            content: ListView(
              children: [
                for (var i = 0; i < 6; i++)
                  Builder(
                    builder: (context) => SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(40),
                      child: Text('row $i'),
                    ),
                  ),
                Card(
                  key: rowKey,
                  padding: const EdgeInsets.all(12),
                  child: const Text('字体大小'),
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the anchored row is updated in place when the scale flips', (
    tester,
  ) async {
    // 与设置页一致：同类型的 key，不是 GlobalKey。
    final rowKey = const ValueKey('settings-ui-font-scale-row');

    await tester.pumpWidget(build(1.0, rowKey));
    final original = tester.element(find.byKey(rowKey));

    // 放大 → 缩小 → 复原：每一步都应就地更新同一个 element。
    for (final scale in <double>[1.25, 0.85, 1.0]) {
      await tester.pumpWidget(build(scale, rowKey));
      await tester.pump();
      expect(
        tester.element(find.byKey(rowKey)),
        same(original),
        reason: 'scale $scale re-parented the anchored row',
      );
      expect(tester.takeException(), isNull);
    }
  });
}