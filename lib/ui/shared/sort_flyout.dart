import 'package:fluent_ui/fluent_ui.dart';

import 'semi_icons.dart';

class SortItem {
  final String label;
  final String value;
  const SortItem(this.label, this.value);
}

class SortFlyout extends StatefulWidget {
  final ValueChanged<String> onSortTypeSelected;
  final ValueChanged<String> onSortOrderSelected;
  final List<SortItem> sortOptions;

  const SortFlyout({
    super.key,
    required this.onSortTypeSelected,
    required this.onSortOrderSelected,
    this.sortOptions = const [
      SortItem('添加日期', 'create_time'),
      SortItem('发行年份', 'release_date'),
      SortItem('标题', 'sort_title'),
      SortItem('评分', 'vote_average'),
    ],
  });

  @override
  State<SortFlyout> createState() => _SortFlyoutState();
}

class _SortFlyoutState extends State<SortFlyout> {
  static const List<SortItem> _orderOptions = [
    SortItem('升序', 'ASC'),
    SortItem('降序', 'DESC'),
  ];

  late SortItem selectedSortType;
  late SortItem selectedSortOrder;
  final FlyoutController _controller = FlyoutController();
  bool _hovered = false;
  bool _isFlyoutOpen = false;

  @override
  void initState() {
    super.initState();
    selectedSortType = widget.sortOptions.first;
    selectedSortOrder = const SortItem('降序', 'DESC');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isDesc => selectedSortOrder.value == 'DESC';

  // Clicking the label/arrow zone flips the sort direction, like the web client.
  void _toggleSortOrder() {
    final next = _isDesc ? _orderOptions.first : _orderOptions.last;
    setState(() => selectedSortOrder = next);
    widget.onSortOrderSelected(next.value);
  }

  Future<void> _showSortMenu() async {
    if (_isFlyoutOpen) {
      return;
    }
    setState(() => _isFlyoutOpen = true);
    try {
      await _controller.showFlyout<void>(
        placementMode: FlyoutPlacementMode.bottomLeft,
        builder: (context) {
          return MenuFlyout(
            items: [
              ...widget.sortOptions.map(
                (opt) => _menuItem(
                  context,
                  opt,
                  opt.value == selectedSortType.value,
                  (picked) {
                    setState(() => selectedSortType = picked);
                    widget.onSortTypeSelected(picked.value);
                  },
                ),
              ),
              const MenuFlyoutSeparator(),
              ..._orderOptions.map(
                (opt) => _menuItem(
                  context,
                  opt,
                  opt.value == selectedSortOrder.value,
                  (picked) {
                    setState(() => selectedSortOrder = picked);
                    widget.onSortOrderSelected(picked.value);
                  },
                ),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isFlyoutOpen = false);
      }
    }
  }

  MenuFlyoutItem _menuItem(
    BuildContext context,
    SortItem opt,
    bool isSelected,
    ValueChanged<SortItem> onPick,
  ) {
    return MenuFlyoutItem(
      text: Text(opt.label),
      trailing: isSelected
          ? Icon(
              FluentIcons.check_mark,
              size: 14,
              color: FluentTheme.of(context).typography.body?.color,
            )
          : null,
      onPressed: () {
        Flyout.of(context).close();
        onPick(opt);
      },
    );
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
          decoration: BoxDecoration(
            color: active ? textColor.withValues(alpha: 0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: textColor.withValues(alpha: active ? 0.2 : 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 16),
              GestureDetector(
                key: const ValueKey('sort-order-toggle'),
                behavior: HitTestBehavior.opaque,
                onTap: _toggleSortOrder,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedSortType.label,
                      style: theme.typography.body?.copyWith(
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _SortDirectionArrows(isDesc: _isDesc, color: textColor),
                  ],
                ),
              ),
              GestureDetector(
                key: const ValueKey('sort-menu-open'),
                behavior: HitTestBehavior.opaque,
                onTap: _showSortMenu,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 4),
                    Container(
                      width: 1,
                      height: 34,
                      color: textColor.withValues(alpha: 0.1),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _isFlyoutOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: SemiIcons.chevronDown(
                        size: 16,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortDirectionArrows extends StatelessWidget {
  final bool isDesc;
  final Color color;

  const _SortDirectionArrows({required this.isDesc, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 18,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: SemiIcons.caretUp(
              size: 12,
              color: color.withValues(alpha: isDesc ? 0.35 : 0.6),
            ),
          ),
          Positioned(
            top: 6,
            left: 0,
            child: SemiIcons.caretDown(
              size: 12,
              color: color.withValues(alpha: isDesc ? 0.6 : 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
