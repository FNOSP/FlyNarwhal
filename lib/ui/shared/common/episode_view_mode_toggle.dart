import 'package:fluent_ui/fluent_ui.dart';

import '../semi_icons.dart';

/// 分集列表视图切换开关（胶囊分段控件）。
///
/// 镜像 Web 端 `title="切换为卡片视图/序号视图"`：
/// - 左侧 [SemiIcons.desktop] = 卡片视图
/// - 右侧 [SemiIcons.grid] = 序号（按钮/网格）视图
///
/// 由滑动浮标指示当前状态，并附带对应 Tooltip。
class EpisodeViewModeToggle extends StatefulWidget {
  /// 当前是否为序号（按钮/网格）视图。`false` 表示卡片视图。
  final bool isButtonView;

  /// 切换视图模式时的回调，参数为切换后的值。
  final ValueChanged<bool> onChanged;

  const EpisodeViewModeToggle({
    super.key,
    required this.isButtonView,
    required this.onChanged,
  });

  @override
  State<EpisodeViewModeToggle> createState() => _EpisodeViewModeToggleState();
}

class _EpisodeViewModeToggleState extends State<EpisodeViewModeToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final iconColor =
        theme.typography.body?.color?.withValues(alpha: 0.85) ?? Colors.white;
    final borderColor = iconColor.withValues(alpha: _hovered ? 0.3 : 0.15);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged(!widget.isButtonView),
        child: Tooltip(
          message:
              widget.isButtonView ? '切换为卡片视图' : '切换为序号视图',
          // Anchor to the widget instead of the cursor: the default
          // mouse-position anchoring draws the tip right on top of the
          // button under the pointer.
          useMousePosition: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 68,
            height: 36,
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 滑动浮标
                AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: widget.isButtonView
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: SemiIcons.desktop(
                          size: 20,
                          color: iconColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SemiIcons.grid(
                          size: 20,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
