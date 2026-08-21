import 'package:fluent_ui/fluent_ui.dart';

/// 圆形 “?” 悬浮提示图标，复刻 KMP 版 HoverTip。
/// 悬停时在上方弹出提示文本（无需点击，鼠标移开即消失）。
class HoverTip extends StatelessWidget {
  const HoverTip({
    super.key,
    required this.tipText,
    this.maxWidth = 300,
  });

  final String tipText;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final textColor = theme.typography.body?.color ?? Colors.white;
    final captionColor = theme.typography.caption?.color ?? textColor;

    return Tooltip(
      message: tipText,
      useMousePosition: false,
      style: TooltipThemeData(
        maxWidth: maxWidth,
        waitDuration: Duration.zero,
      ),
      child: Container(
        width: 12,
        height: 12,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: textColor.withValues(alpha: 0.25)),
        ),
        child: Text(
          '?',
          style: theme.typography.caption?.copyWith(
            fontSize: 8,
            height: 1,
            color: captionColor,
          ),
        ),
      ),
    );
  }
}
