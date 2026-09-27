import 'package:fluent_ui/fluent_ui.dart';

import '../../../shared/semi_icons.dart';
import '../../../../data/models/home_models.dart';

/// Actions offered by the "继续观看" card's more menu, mirroring the web client.
enum ContinueWatchAction {
  removeFromContinue,
  resume,
  restart,
  deleteVideo,
}

/// Width and metrics lifted from the web dropdown (`.semi-dropdown-*`), so the
/// panel matches the browser pixel-for-pixel.
const double _kMenuWidth = 185;
const double _kItemHeight = 36;
const double _kItemHorizontalPadding = 16;
const double _kIconSize = 16;
const double _kIconSpacing = 8;
const double _kPanelRadius = 12;

const Color _kItemColor = Color(0xCCFFFFFF);

/// Opens the acrylic "更多" menu for a recently-watched card.
Future<void> showContinueWatchMenu({
  required BuildContext context,
  required FlyoutController controller,
  required PlayDetailResponse item,
  required ValueChanged<ContinueWatchAction> onAction,
}) {
  final canDelete = _resolveDeleteGuid(item) != null;
  return controller.showFlyout<void>(
    placementMode: FlyoutPlacementMode.bottomRight,
    dismissOnPointerMoveAway: false,
    builder: (flyoutContext) => _ContinueWatchMenuPanel(
      onSelected: (action) {
        Flyout.of(flyoutContext).close();
        onAction(action);
      },
      canDelete: canDelete,
    ),
  );
}

/// Delete targets either the item itself or, for episodes, its parent show.
String? _resolveDeleteGuid(PlayDetailResponse item) {
  final guid = item.guid.trim();
  if (guid.isEmpty) return null;
  if (item.type?.trim() == 'Episode') {
    final parent = item.parentGuid?.trim();
    if (parent == null || parent.isEmpty) return null;
  }
  return guid;
}

class _ContinueWatchMenuPanel extends StatefulWidget {
  final ValueChanged<ContinueWatchAction> onSelected;
  final bool canDelete;

  const _ContinueWatchMenuPanel({
    required this.onSelected,
    required this.canDelete,
  });

  @override
  State<_ContinueWatchMenuPanel> createState() =>
      _ContinueWatchMenuPanelState();
}

class _ContinueWatchMenuPanelState extends State<_ContinueWatchMenuPanel> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final entries = <_MenuEntry>[
      _MenuEntry(
        action: ContinueWatchAction.removeFromContinue,
        label: '从“继续观看”中移除',
        icon: (color) => SemiIcons.removeFromContinue(size: _kIconSize, color: color),
      ),
      _MenuEntry(
        action: ContinueWatchAction.resume,
        label: '继续播放',
        icon: (color) => SemiIcons.resumePlay(size: _kIconSize, color: color),
      ),
      _MenuEntry(
        action: ContinueWatchAction.restart,
        label: '从头开始播放',
        icon: (color) => SemiIcons.restartPlay(size: _kIconSize, color: color),
      ),
      if (widget.canDelete)
        _MenuEntry(
          action: ContinueWatchAction.deleteVideo,
          label: '删除视频',
          icon: (color) => SemiIcons.deleteVideo(size: _kIconSize, color: color),
        ),
    ];

    final theme = FluentTheme.of(context);
    // A translucent panel reads as glass over the poster artwork behind it.
    return Acrylic(
      tint: theme.resources.solidBackgroundFillColorBase,
      tintAlpha: 0.8,
      blurAmount: 30,
      elevation: 8,
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kPanelRadius),
        side: BorderSide(
          color: theme.resources.surfaceStrokeColorDefault,
          width: 1,
        ),
      ),
      child: SizedBox(
        width: _kMenuWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (entries[i].action == ContinueWatchAction.deleteVideo)
                  _buildDivider(theme),
                _ContinueWatchMenuItem(
                  key: ValueKey('continue-watch-menu-${entries[i].action.name}'),
                  label: entries[i].label,
                  iconBuilder: entries[i].icon,
                  isHovered: _hoveredIndex == i,
                  onHoverChanged: (hovered) {
                    setState(() => _hoveredIndex = hovered ? i : null);
                  },
                  onPressed: () => widget.onSelected(entries[i].action),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        height: 1,
        color: theme.resources.dividerStrokeColorDefault
            .withValues(alpha: 0.6),
      ),
    );
  }
}

class _MenuEntry {
  final ContinueWatchAction action;
  final String label;
  final Widget Function(Color color) icon;

  const _MenuEntry({
    required this.action,
    required this.label,
    required this.icon,
  });
}

class _ContinueWatchMenuItem extends StatelessWidget {
  final String label;
  final Widget Function(Color color) iconBuilder;
  final bool isHovered;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onPressed;

  const _ContinueWatchMenuItem({
    super.key,
    required this.label,
    required this.iconBuilder,
    required this.isHovered,
    required this.onHoverChanged,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          height: _kItemHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: _kItemHorizontalPadding,
          ),
          color: isHovered
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.transparent,
          child: Row(
            children: [
              iconBuilder(_kItemColor),
              const SizedBox(width: _kIconSpacing),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    color: _kItemColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
