import 'package:fluent_ui/fluent_ui.dart';

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
  Widget build(BuildContext context) {
    const orderOptions = [
      SortItem('升序', 'ASC'),
      SortItem('降序', 'DESC'),
    ];
    final theme = FluentTheme.of(context);
    final backgroundColor = (_hovered || _isFlyoutOpen)
        ? theme.resources.controlStrokeColorDefault
        : Colors.transparent;
    final textColor = theme.typography.body?.color;

    return FlyoutTarget(
      controller: _controller,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () async {
            if (_isFlyoutOpen) {
              return;
            }
            setState(() => _isFlyoutOpen = true);
            try {
              await _controller.showFlyout<void>(
                placementMode: FlyoutPlacementMode.bottomCenter,
                builder: (context) {
                  return MenuFlyout(
                    items: [
                      ...widget.sortOptions.map((opt) {
                        final isSelected = opt.value == selectedSortType.value;
                        return MenuFlyoutItem(
                          leading: isSelected ? const Icon(FluentIcons.check_mark) : null,
                          text: Text(
                            opt.label,
                            style: TextStyle(
                              color: isSelected
                                  ? FluentTheme.of(context).typography.body?.color
                                  : FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.7),
                            ),
                          ),
                          onPressed: () {
                            setState(() => selectedSortType = opt);
                            widget.onSortTypeSelected(opt.value);
                          },
                        );
                      }),
                      const MenuFlyoutSeparator(),
                      ...orderOptions.map((opt) {
                        final isSelected = opt.value == selectedSortOrder.value;
                        return MenuFlyoutItem(
                          leading: isSelected ? const Icon(FluentIcons.check_mark) : null,
                          text: Text(
                            opt.label,
                            style: TextStyle(
                              color: isSelected
                                  ? FluentTheme.of(context).typography.body?.color
                                  : FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.7),
                            ),
                          ),
                          onPressed: () {
                            setState(() => selectedSortOrder = opt);
                            widget.onSortOrderSelected(opt.value);
                          },
                        );
                      }),
                    ],
                  );
                },
              );
            } finally {
              if (mounted) {
                setState(() => _isFlyoutOpen = false);
              }
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.grey[120].withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedSortType.label,
                  style: theme.typography.body?.copyWith(
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _isFlyoutOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    FluentIcons.chevron_down,
                    size: 12,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
