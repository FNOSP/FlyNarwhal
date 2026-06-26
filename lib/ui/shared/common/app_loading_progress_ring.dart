import 'package:fluent_ui/fluent_ui.dart';

/// 深色模式下进度环白色，浅色模式下黑色，与海报图片加载进度条保持一致。
const Color kLoadingRingColorDark = Color(0x8BFFFFFF);
const Color kLoadingRingColorLight = Color(0x8B000000);

/// 主题自适应的页面加载进度环。
///
/// 根据 [FluentTheme.brightness] 自动选择：
/// - 深色 → 半透明白 [kLoadingRingColorDark]
/// - 浅色 → 半透明黑 [kLoadingRingColorLight]
///
/// 构造器为 `const`，可在任意位置以常量子树形式使用。
class AppLoadingProgressRing extends StatelessWidget {
  final double size;
  final double? strokeWidth;

  const AppLoadingProgressRing({
    super.key,
    this.size = 32.0,
    this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final color = isDark ? kLoadingRingColorDark : kLoadingRingColorLight;
    return SizedBox(
      width: size,
      height: size,
      child: ProgressRing(
        activeColor: color,
        strokeWidth: strokeWidth ?? 4.0,
      ),
    );
  }
}
