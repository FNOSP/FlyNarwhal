import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';

// 与播放器解码模式 tips 框一致的深色配色（半透明黑底 + 灰描边 + 白字）。
const Color _backgroundColor = Color(0xCC000000);
const Color _borderColor = Color(0x80808080);
const Color _textColor = Color(0xC8FFFFFF);

/// 统一的 tips 框组件：悬浮触发控件时在其上方弹出深色说明框。
/// 样式复刻播放器解码模式的 tips，供菜单项/图标说明复用。
class TipBox extends StatefulWidget {
  const TipBox({
    super.key,
    required this.message,
    required this.child,
    this.richMessage,
    this.verticalOffset = 28,
    this.maxWidth,
  });

  final String message;
  final Widget child;

  /// 富文本提示内容（如含可点击链接）；提供时优先于 [message]。
  /// 其中的 recognizer 由本组件负责 dispose。
  final InlineSpan? richMessage;

  /// 提示框与触发控件中心的垂直间距，需大于控件半高以避开控件本身。
  final double verticalOffset;

  final double? maxWidth;

  @override
  State<TipBox> createState() => _TipBoxState();
}

class _TipBoxState extends State<TipBox> {
  final List<GestureRecognizer> _recognizers = [];

  @override
  void didUpdateWidget(TipBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.richMessage, widget.richMessage)) {
      _disposeRecognizers();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  InlineSpan? _prepareRichMessage() {
    final span = widget.richMessage;
    if (span == null || _recognizers.isNotEmpty) return span;
    span.visitChildren((child) {
      if (child is TextSpan) {
        final recognizer = child.recognizer;
        if (recognizer != null) _recognizers.add(recognizer);
      }
      return true;
    });
    return span;
  }

  @override
  Widget build(BuildContext context) {
    final rich = _prepareRichMessage();
    return Tooltip(
      // fluent_ui 断言 message 与 richMessage 恰好一个非空。
      message: rich == null ? widget.message : null,
      richMessage: rich,
      // 含可点链接时让浮层接收鼠标事件：移入浮层不消失，可点击。
      interactive: rich != null,
      useMousePosition: false,
      style: TooltipThemeData(
        waitDuration: Duration.zero,
        // 默认 1.5s 不足以把鼠标移进提示框点击链接。
        showDuration: const Duration(seconds: 30),
        preferBelow: false,
        verticalOffset: widget.verticalOffset,
        maxWidth: widget.maxWidth,
        textStyle: const TextStyle(color: _textColor, fontSize: 12),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
      ),
      child: widget.child,
    );
  }
}
