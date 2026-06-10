import 'package:fluent_ui/fluent_ui.dart';
import '../../domain/entities/tag_entity.dart';

class FilterItem {
  final String label;
  final dynamic value;
  const FilterItem(this.label, this.value);
}

class FilterGroup {
  final String title;
  final List<FilterItem> options;
  const FilterGroup(this.title, this.options);
}

class FilterButton extends StatefulWidget {
  final bool isSelected;
  final Map<String, FilterItem> selectedFilters;
  final ValueChanged<String> onFilterClear;
  final VoidCallback onClick;

  const FilterButton({
    super.key,
    required this.isSelected,
    required this.selectedFilters,
    required this.onFilterClear,
    required this.onClick,
  });

  @override
  State<FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<FilterButton> {
  bool _hovered = false;

  bool get _hasNonDefaultFilters {
    return widget.selectedFilters.entries.any(
      (entry) => entry.value.label != '全部' && entry.value.value != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final backgroundColor = (_hovered || widget.isSelected)
        ? theme.resources.controlStrokeColorDefault
        : Colors.transparent;
    final textColor = theme.typography.body?.color;
    final chipVisible = _hasNonDefaultFilters && !widget.isSelected;
    final chipContent = Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...widget.selectedFilters.entries
            .where(
              (entry) =>
                  entry.value.label != '全部' && entry.value.value != null,
            )
            .map(
              (entry) => FilterChip(
                label: entry.value.label,
                onClear: () => widget.onFilterClear(entry.key),
              ),
            ),
        FilterChip(
          label: '重置',
          icon: FluentIcons.refresh,
          onClear: () => widget.onFilterClear('all'),
        ),
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onClick,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '筛选',
                    style: theme.typography.body?.copyWith(
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: widget.isSelected ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      FluentIcons.chevron_down,
                      size: 12,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return SizeTransition(
                    sizeFactor: animation,
                    axis: Axis.horizontal,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: chipVisible
                    ? Padding(
                        key: const ValueKey('filter-chips'),
                        padding: const EdgeInsets.only(left: 8),
                        child: chipContent,
                      )
                    : const SizedBox(
                        key: ValueKey('filter-chips-empty'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FilterChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onClear;

  const FilterChip({
    super.key,
    required this.label,
    this.icon = FluentIcons.clear,
    required this.onClear,
  });

  @override
  State<FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<FilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onClear,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.resources.controlStrokeColorSecondary,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.grey[120].withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: theme.typography.body?.copyWith(
                  fontSize: 12,
                  color: theme.typography.body?.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                widget.icon,
                size: 12,
                color: _hovered
                    ? theme.typography.body?.color
                    : theme.typography.caption?.color?.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FilterBox extends StatefulWidget {
  final TagListEntity? tagList;
  final List<GenreEntity>? genres;
  final Map<String, String>? iso3166;
  final Map<String, FilterItem> initialSelectedFilters;
  final ValueChanged<Map<String, FilterItem>> onFilterChanged;
  final VoidCallback? onCollapse;

  const FilterBox({
    super.key,
    this.tagList,
    this.genres,
    this.iso3166,
    this.initialSelectedFilters = const {},
    required this.onFilterChanged,
    this.onCollapse,
  });

  @override
  State<FilterBox> createState() => _FilterBoxState();
}

class _FilterBoxState extends State<FilterBox> {
  late Map<String, FilterItem> _selectedOptions;

  @override
  void initState() {
    super.initState();
    _selectedOptions = Map<String, FilterItem>.from(widget.initialSelectedFilters);
  }

  @override
  void didUpdateWidget(covariant FilterBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelectedFilters != widget.initialSelectedFilters) {
      _selectedOptions = Map<String, FilterItem>.from(widget.initialSelectedFilters);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final groups = _buildFilterGroups(
      tagList: widget.tagList,
      genres: widget.genres,
      iso3166: widget.iso3166,
    );
    for (final group in groups) {
      _selectedOptions.putIfAbsent(group.title, () => group.options.first);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.resources.controlStrokeColorDefault,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          ...groups.expand((group) {
            final selected = _selectedOptions[group.title] ?? group.options.first;
            return [
              FilterRow(
                title: group.title,
                options: group.options,
                selected: selected,
                onSelected: (item) {
                  setState(() {
                    _selectedOptions[group.title] = item;
                  });
                  widget.onFilterChanged(_selectedOptions);
                },
              ),
              const SizedBox(height: 16),
            ];
          }),
          if (widget.onCollapse != null)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: HoverButton(
                onPressed: widget.onCollapse,
                builder: (context, states) {
                  final color = states.isHovered
                      ? theme.typography.body?.color
                      : theme.typography.caption?.color;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('收起', style: TextStyle(color: color, fontSize: 14)),
                      const SizedBox(width: 4),
                      Icon(
                        FluentIcons.chevron_up,
                        size: 14,
                        color: color,
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class FilterRow extends StatelessWidget {
  final String title;
  final List<FilterItem> options;
  final FilterItem selected;
  final ValueChanged<FilterItem> onSelected;

  const FilterRow({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              title,
              style: theme.typography.body?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.typography.caption?.color,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Wrap(
            spacing: 24,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = option.label == selected.label && option.value == selected.value;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: HoverButton(
                  onPressed: () => onSelected(option),
                  builder: (context, states) {
                    final color = isSelected
                        ? const Color(0xFF2073DF)
                        : states.isHovered
                            ? theme.typography.body?.color
                            : theme.typography.caption?.color;
                    return Text(
                      option.label,
                      style: theme.typography.body?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

List<FilterGroup> _buildFilterGroups({
  TagListEntity? tagList,
  List<GenreEntity>? genres,
  Map<String, String>? iso3166,
}) {
  final groups = <FilterGroup>[];
  groups.add(
    const FilterGroup(
      '影视类型',
      [
        FilterItem('全部', null),
        FilterItem('电影', 'Movie'),
        FilterItem('电视剧', 'TV'),
      ],
    ),
  );

  if (tagList != null && genres != null) {
    final genreMap = {for (final g in genres) g.id: g};
    final options = <FilterItem>[const FilterItem('全部', null)];
    for (final id in tagList.genres) {
      final genre = genreMap[id];
      if (genre != null) {
        options.add(FilterItem(genre.name, id));
      }
    }
    groups.add(FilterGroup('类型', options));
  } else {
    groups.add(const FilterGroup('类型', [FilterItem('全部', null)]));
  }

  if (tagList != null) {
    groups.add(
      FilterGroup(
        '分辨率',
        [
          const FilterItem('全部', null),
          ...tagList.resolutions.map((r) => FilterItem(r, r)),
        ],
      ),
    );
    groups.add(
      FilterGroup(
        '视频动态范围',
        [
          const FilterItem('全部', null),
          ...tagList.colorRanges.map((r) {
            final label = r == 'DolbyVision' ? '杜比视界' : r;
            return FilterItem(label, r);
          }),
        ],
      ),
    );
    groups.add(
      FilterGroup(
        '音频规格',
        [
          const FilterItem('全部', null),
          ...tagList.audioTypes.map((r) {
            final label = switch (r) {
              'DolbySurround' => '杜比环绕',
              'DolbyAtmos' => '杜比全景声',
              'Stereo' => '立体声',
              'Others' => '其他',
              _ => r,
            };
            return FilterItem(label, r);
          }),
        ],
      ),
    );
  } else {
    groups.add(const FilterGroup('分辨率', [FilterItem('全部', null)]));
    groups.add(const FilterGroup('视频动态范围', [FilterItem('全部', null)]));
    groups.add(const FilterGroup('音频规格', [FilterItem('全部', null)]));
  }

  if (tagList != null && iso3166 != null) {
    final isoMap = iso3166;
    final options = <FilterItem>[const FilterItem('全部', null)];
    for (final code in tagList.locations) {
      options.add(FilterItem(isoMap[code] ?? code, code));
    }
    groups.add(FilterGroup('国家和地区', options));
  } else {
    groups.add(const FilterGroup('国家和地区', [FilterItem('全部', null)]));
  }

  if (tagList != null) {
    final options = <FilterItem>[const FilterItem('全部', null)];
    for (final decade in tagList.decades) {
      final label = switch (decade) {
        'Recent' => '今年',
        'Others' => '其他',
        _ when decade.endsWith('s') => '${decade.substring(0, decade.length - 1)}年代',
        _ => decade,
      };
      options.add(FilterItem(label, decade));
    }
    groups.add(FilterGroup('发行年份', options));
  } else {
    groups.add(const FilterGroup('发行年份', [FilterItem('全部', null)]));
  }

  if (tagList != null) {
    final options = <FilterItem>[const FilterItem('全部', null)];
    for (final status in tagList.recognitionStatuses) {
      final label = switch (status) {
        1 => '未匹配',
        2 => '已匹配',
        3 => 'NFO匹配',
        _ => status.toString(),
      };
      options.add(FilterItem(label, status));
    }
    groups.add(FilterGroup('匹配状态', options));
  } else {
    groups.add(const FilterGroup('匹配状态', [FilterItem('全部', null)]));
  }

  groups.add(
    const FilterGroup(
      '是否已观看',
      [
        FilterItem('全部', null),
        FilterItem('已观看', '1'),
        FilterItem('未观看', '0'),
      ],
    ),
  );

  return groups;
}
