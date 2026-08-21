import 'package:fluent_ui/fluent_ui.dart';

// 与播放器解码模式 tips 框一致的深色配色（半透明黑底 + 灰描边 + 白字）。
const Color _backgroundColor = Color(0xCC000000);
const Color _borderColor = Color(0x80808080);
const Color _textColor = Color(0xC8FFFFFF);

/// 统一的 tips 框组件：悬浮触发控件时在其上方弹出深色说明框。
/// 样式复刻播放器解码模式的 tips，供菜单项/图标说明复用。
class TipBox extends StatelessWidget {
  const TipBox({
    super.key,
    required this.message,
    required this.child,
    this.verticalOffset = 28,
    this.maxWidth,
  });

  final String message;
  final Widget child;

  /// 提示框与触发控件中心的垂直间距，需大于控件半高以避开控件本身。
  final double verticalOffset;

  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      useMousePosition: false,
      style: TooltipThemeData(
        waitDuration: Duration.zero,
        showDuration: const Duration(seconds: 5),
        preferBelow: false,
        verticalOffset: verticalOffset,
        maxWidth: maxWidth,
        textStyle: const TextStyle(color: _textColor, fontSize: 12),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
      ),
      child: child,
    );
  }
}
