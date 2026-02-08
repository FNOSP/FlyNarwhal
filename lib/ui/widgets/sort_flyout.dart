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

    return FlyoutTarget(
      controller: _controller,
      child: Button(
        onPressed: () {
          _controller.showFlyout<void>(
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
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selectedSortType.label),
            const SizedBox(width: 6),
            const Icon(FluentIcons.caret_solid_down),
          ],
        ),
      ),
    );
  }
}
