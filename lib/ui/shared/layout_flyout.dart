import 'package:fluent_ui/fluent_ui.dart';

import '../../domain/entities/live_library_settings.dart';
import 'semi_icons.dart';

/// 布局菜单形态：
/// [live]    直播库：海报墙/列表 + 竖幅/横幅（仅海报墙下可用），镜像 Web 直播库。
/// [compact] 普通媒体库：仅 竖幅海报/横幅海报 两项，镜像 Web `/library/:id`。
enum LayoutMenuVariant { live, compact }

/// 布局切换胶囊，镜像 Web 端直播库的布局菜单。
/// [LayoutMenuVariant.live]：第一组 海报墙/列表，第二组 竖幅海报/横幅海报（仅海报墙下可用）。
/// [LayoutMenuVariant.compact]：仅 竖幅海报/横幅海报（普通媒体库用）。
/// 样式沿用筛选/排序胶囊。
class LayoutFlyout extends StatefulWidget {
  final LiveViewType viewType;
  final ValueChanged<LiveViewType> onLayoutSelected;
  final LayoutMenuVariant variant;

  const LayoutFlyout({
    super.key,
    required this.viewType,
    required this.onLayoutSelected,
    this.variant = LayoutMenuVariant.live,
  });

  @override
  State<LayoutFlyout> createState() => _LayoutFlyoutState();
}

class _LayoutFlyoutState extends State<LayoutFlyout> {
  final FlyoutController _controller = FlyoutController();
  bool _hovered = false;
  bool _isFlyoutOpen = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isPosterWall => widget.viewType != LiveViewType.list;

  // 普通媒体库(compact)菜单：仅 竖幅海报/横幅海报 两项，均可切换，镜像 Web `/library/:id`。
  List<MenuFlyoutItemBase> _buildCompactItems(
      BuildContext context, Color checkColor) {
    return [
      MenuFlyoutItem(
        key: const ValueKey('layout-vertical-poster'),
        leading: const _PosterShapeIcon(vertical: true),
        text: const Text('竖幅海报'),
        trailing: widget.viewType == LiveViewType.verticalPoster
            ? Icon(FluentIcons.check_mark, size: 14, color: checkColor)
            : null,
        onPressed: () {
          Flyout.of(context).close();
          widget.onLayoutSelected(LiveViewType.verticalPoster);
        },
      ),
      MenuFlyoutItem(
        key: const ValueKey('layout-horizontal-poster'),
        leading: const _PosterShapeIcon(vertical: false),
        text: const Text('横幅海报'),
        trailing: widget.viewType == LiveViewType.horizontalPoster
            ? Icon(FluentIcons.check_mark, size: 14, color: checkColor)
            : null,
        onPressed: () {
          Flyout.of(context).close();
          widget.onLayoutSelected(LiveViewType.horizontalPoster);
        },
      ),
    ];
  }

  // 直播库(live)菜单：海报墙/列表分组 + 竖幅/横幅海报。
  List<MenuFlyoutItemBase> _buildLiveItems(
      BuildContext context, Color checkColor) {
    return [
      MenuFlyoutItem(
        key: const ValueKey('layout-poster-wall'),
        leading: const Icon(FluentIcons.grid_view_medium, size: 16),
        text: const Text('海报墙'),
        trailing: _isPosterWall
            ? Icon(FluentIcons.check_mark, size: 14, color: checkColor)
            : null,
        onPressed: () {
          Flyout.of(context).close();
          widget.onLayoutSelected(LiveViewType.verticalPoster);
        },
      ),
      MenuFlyoutItem(
        key: const ValueKey('layout-list'),
        leading: const Icon(FluentIcons.bulleted_list, size: 16),
        text: const Text('列表'),
        trailing: !_isPosterWall
            ? Icon(FluentIcons.check_mark, size: 14, color: checkColor)
            : null,
        onPressed: () {
          Flyout.of(context).close();
          widget.onLayoutSelected(LiveViewType.list);
        },
      ),
      const MenuFlyoutSeparator(),
      MenuFlyoutItem(
        key: const ValueKey('layout-vertical-poster'),
        leading: const _PosterShapeIcon(vertical: true),
        text: const Text('竖幅海报'),
        trailing: widget.viewType == LiveViewType.verticalPoster
            ? Icon(FluentIcons.check_mark, size: 14, color: checkColor)
            : null,
        onPressed: _isPosterWall
            ? () {
                Flyout.of(context).close();
                widget.onLayoutSelected(LiveViewType.verticalPoster);
              }
            : null,
      ),
      MenuFlyoutItem(
        key: const ValueKey('layout-horizontal-poster'),
        leading: const _PosterShapeIcon(vertical: false),
        text: const Text('横幅海报'),
        trailing: widget.viewType == LiveViewType.horizontalPoster
            ? Icon(FluentIcons.check_mark, size: 14, color: checkColor)
            : null,
        onPressed: _isPosterWall
            ? () {
                Flyout.of(context).close();
                widget.onLayoutSelected(LiveViewType.horizontalPoster);
              }
            : null,
      ),
    ];
  }

  Future<void> _showMenu() async {
    if (_isFlyoutOpen) {
      return;
    }
    setState(() => _isFlyoutOpen = true);
    try {
      await _controller.showFlyout<void>(
        placementMode: FlyoutPlacementMode.bottomLeft,
        builder: (context) {
          final theme = FluentTheme.of(context);
          final checkColor = theme.typography.body?.color ?? Colors.white;
          return MenuFlyout(
            items: widget.variant == LayoutMenuVariant.compact
                ? _buildCompactItems(context, checkColor)
                : _buildLiveItems(context, checkColor),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isFlyoutOpen = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final textColor = theme.typography.body?.color ?? Colors.white;
    final active = _hovered || _isFlyoutOpen;

    return FlyoutTarget(
      controller: _controller,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 36,
          padding: const EdgeInsets.only(left: 16, right: 12),
          decoration: BoxDecoration(
            color:
                active ? textColor.withValues(alpha: 0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: textColor.withValues(alpha: active ? 0.2 : 0.1),
            ),
          ),
          child: GestureDetector(
            key: const ValueKey('layout-menu-open'),
            behavior: HitTestBehavior.opaque,
            onTap: _showMenu,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '布局',
                  style: theme.typography.body?.copyWith(
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _isFlyoutOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: SemiIcons.chevronDown(size: 16, color: textColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 竖幅/横幅海报的矩形轮廓小图标，对齐 Web 端菜单图标。
class _PosterShapeIcon extends StatelessWidget {
  final bool vertical;

  const _PosterShapeIcon({required this.vertical});

  @override
  Widget build(BuildContext context) {
    final color = FluentTheme.of(context).typography.body?.color;
    return Container(
      width: vertical ? 10 : 16,
      height: vertical ? 14 : 10,
      decoration: BoxDecoration(
        border: Border.all(color: color ?? Colors.white, width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
