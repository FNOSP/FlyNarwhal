import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../data/models/movie_detail_models.dart';
import '../../../../data/utils/fn_data_convertor.dart';

const Color subtitleFlyoutBackgroundColor = Color(0xCC000000);
const Color subtitleFlyoutBorderColor = Color(0x80808080);
const Color subtitleSelectedTextColor = Color(0xFF2073DF);
const Color subtitleDefaultTextColor = Color(0xC8FFFFFF);
const Color subtitleHoverBackgroundColor = Color(0x1AFFFFFF);

const double subtitleFlyoutWidth = 320;
const double subtitleFlyoutPanelHeight = 390;

/// 最后一次滚动后隐藏滚动条的延迟。
/// 对齐 web 端（ms-* 自定义滚动条）实测：滚动时加 `ms-track-show`，
/// 静止约 1 秒后移除，配 0.3s 透明度过渡。
const Duration _scrollbarAutoHideDelay = Duration(milliseconds: 1000);

/// 字幕选择面板：字幕列表 + 头部操作（调整/添加）。
///
/// 播放器与详情页共用此面板。播放器使用深色实底背景并保留"调整"入口；
/// 详情页（详情页入口）隐藏"调整"、改用 Fluent 毛玻璃背景，并让滚动条
/// 在鼠标不活跃时自动隐藏。
class SubtitleSelectionPanel extends StatefulWidget {
  final List<SubtitleStream> subtitles;
  final String? selectedSubtitleGuid;
  final Map<String, String> iso6391Map;
  final Map<String, String> iso6392Map;

  /// 为 null 时完全隐藏"调整"按钮（详情页）；非 null 时显示，
  /// 是否可点击由 [canAdjustSubtitle] 控制（播放器）。
  final VoidCallback? onAdjustmentClicked;
  final bool canAdjustSubtitle;

  /// 添加菜单仅展示回调非 null 的入口；全部为 null 时隐藏"添加"按钮。
  final VoidCallback? onOpenSubtitleSearch;
  final VoidCallback? onOpenAddNasSubtitle;
  final VoidCallback? onOpenAddLocalSubtitle;

  final ValueChanged<String?> onSubtitleSelected;
  final ValueChanged<SubtitleStream>? onRequestDelete;
  final ValueChanged<SubtitleStream>? onPredownloadSimilar;

  /// 使用 Fluent Acrylic 毛玻璃背景；否则使用播放器默认的深色实底。
  final bool useAcrylicBackground;

  /// 为 true 时滚动条仅在滚动时显示，静止约 1 秒后隐藏（对齐 web 端）。
  final bool autoHideScrollbar;

  const SubtitleSelectionPanel({
    super.key,
    required this.subtitles,
    required this.selectedSubtitleGuid,
    required this.iso6391Map,
    required this.iso6392Map,
    required this.onSubtitleSelected,
    this.onAdjustmentClicked,
    this.canAdjustSubtitle = true,
    this.onOpenSubtitleSearch,
    this.onOpenAddNasSubtitle,
    this.onOpenAddLocalSubtitle,
    this.onRequestDelete,
    this.onPredownloadSimilar,
    this.useAcrylicBackground = false,
    this.autoHideScrollbar = false,
  });

  @override
  State<SubtitleSelectionPanel> createState() => _SubtitleSelectionPanelState();
}

class _SubtitleSelectionPanelState extends State<SubtitleSelectionPanel> {
  late final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  bool _scrollbarVisible = false;
  Timer? _scrollbarHideTimer;
  bool _isAddMenuExpanded = false;

  @override
  void initState() {
    super.initState();
    _scheduleScrollToSelection();
  }

  @override
  void didUpdateWidget(covariant SubtitleSelectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubtitleGuid != widget.selectedSubtitleGuid ||
        oldWidget.subtitles != widget.subtitles) {
      _scheduleScrollToSelection();
    }
  }

  @override
  void dispose() {
    _scrollbarHideTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollToSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final selectedIndex = widget.selectedSubtitleGuid == null ||
              widget.selectedSubtitleGuid!.isEmpty
          ? 0
          : widget.subtitles.indexWhere(
                (subtitle) => subtitle.guid == widget.selectedSubtitleGuid,
              ) +
              1;
      final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;
      final key = _itemKeys.putIfAbsent(safeIndex, () => GlobalKey());
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.3,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  /// 滚动条仅在滚动时显示，静止后延时隐藏（对齐 web 端行为）。
  void _onScrollActivity() {
    if (!widget.autoHideScrollbar) return;
    _scrollbarHideTimer?.cancel();
    if (!_scrollbarVisible && mounted) {
      setState(() => _scrollbarVisible = true);
    }
    _scrollbarHideTimer = Timer(_scrollbarAutoHideDelay, () {
      if (mounted) setState(() => _scrollbarVisible = false);
    });
  }

  bool _hasPredownloadButton(SubtitleStream subtitle) {
    return subtitle.isExternal == 1 &&
        subtitle.sourceId.isNotEmpty &&
        widget.onPredownloadSimilar != null;
  }

  @override
  Widget build(BuildContext context) {
    final hasAddActions = widget.onOpenSubtitleSearch != null ||
        widget.onOpenAddNasSubtitle != null ||
        widget.onOpenAddLocalSubtitle != null;

    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '字幕',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.onAdjustmentClicked != null) ...[
                    SubtitleHeaderPillButton(
                      label: '调整',
                      enabled: widget.canAdjustSubtitle,
                      onPressed: widget.onAdjustmentClicked!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (hasAddActions)
                    SubtitleHeaderPillButton(
                      label: '添加',
                      trailing: Icon(
                        _isAddMenuExpanded
                            ? FluentIcons.chevron_up_small
                            : FluentIcons.chevron_down_small,
                        size: 12,
                        color: subtitleDefaultTextColor,
                      ),
                      // 展开状态由面板自身持有：flyout 内容构建在 overlay
                      // 路由里，父组件 setState 不会重建 builder 内容，
                      // 只有面板自己的 setState 才能刷新菜单。
                      onPressed: () => setState(
                        () => _isAddMenuExpanded = !_isAddMenuExpanded,
                      ),
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(size: 1),
              ),
              Expanded(
                child: NotificationListener<ScrollUpdateNotification>(
                  onNotification: (_) {
                    _onScrollActivity();
                    return false;
                  },
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility:
                        widget.autoHideScrollbar ? _scrollbarVisible : true,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: widget.subtitles.length + 1,
                        itemBuilder: (context, index) {
                          final key = _itemKeys.putIfAbsent(
                            index,
                            () => GlobalKey(),
                          );
                          if (index == 0) {
                            return KeyedSubtree(
                              key: key,
                              child: _SubtitleItem(
                                key: const ValueKey('subtitle-item-off'),
                                title: '关闭',
                                subtitle: '',
                                isSelected:
                                    widget.selectedSubtitleGuid == null ||
                                        widget.selectedSubtitleGuid!.isEmpty,
                                onTap: () => widget.onSubtitleSelected(null),
                              ),
                            );
                          }

                          final subtitle = widget.subtitles[index - 1];
                          final showPredownload =
                              _hasPredownloadButton(subtitle);
                          return KeyedSubtree(
                            key: key,
                            child: _SubtitleItem(
                              key: ValueKey('subtitle-item-${subtitle.guid}'),
                              title: _buildTitle(subtitle),
                              subtitle: _buildSubtitle(subtitle),
                              isSelected:
                                  widget.selectedSubtitleGuid == subtitle.guid,
                              isExternal: subtitle.isExternal == 1,
                              showPredownloadSimilar: showPredownload,
                              onDelete: widget.onRequestDelete == null
                                  ? null
                                  : () =>
                                      widget.onRequestDelete!.call(subtitle),
                              onPredownloadSimilar: showPredownload
                                  ? () => widget.onPredownloadSimilar!
                                      .call(subtitle)
                                  : null,
                              onTap: () =>
                                  widget.onSubtitleSelected(subtitle.guid),
                            ),
                          );
                        },
                      ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isAddMenuExpanded && hasAddActions)
          Positioned(
            top: 48,
            right: 12,
            child: _SubtitleAddMenu(
              useAcrylicBackground: widget.useAcrylicBackground,
              onSearch: widget.onOpenSubtitleSearch,
              onAddNas: widget.onOpenAddNasSubtitle,
              onAddLocal: widget.onOpenAddLocalSubtitle,
            ),
          ),
      ],
    );

    if (widget.useAcrylicBackground) {
      return Acrylic(
        tint: const Color(0xFF242424),
        tintAlpha: 0.78,
        luminosityAlpha: 0.55,
        blurAmount: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: subtitleFlyoutBorderColor.withValues(alpha: 0.4),
          ),
        ),
        child: SizedBox(
          width: subtitleFlyoutWidth,
          height: subtitleFlyoutPanelHeight,
          child: content,
        ),
      );
    }

    return Container(
      width: subtitleFlyoutWidth,
      height: subtitleFlyoutPanelHeight,
      decoration: BoxDecoration(
        color: subtitleFlyoutBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: subtitleFlyoutBorderColor),
      ),
      child: content,
    );
  }

  String _buildTitle(SubtitleStream subtitle) {
    final languageName = FnDataConvertor.getLanguageName(
      subtitle.language,
      widget.iso6391Map,
      widget.iso6392Map,
    );
    final buffer = StringBuffer(languageName);
    if (subtitle.isExternal == 1) {
      buffer.write(' - 外挂');
    }
    if (subtitle.isDefault == 1) {
      buffer.write(' - 默认');
    }
    return buffer.toString();
  }

  String _buildSubtitle(SubtitleStream subtitle) {
    final parts = <String>[
      subtitle.format.toUpperCase(),
      if (subtitle.title.isNotEmpty) subtitle.title,
    ];
    return parts.join('  ');
  }
}

class SubtitleHeaderPillButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final Widget? trailing;
  final VoidCallback onPressed;

  const SubtitleHeaderPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.trailing,
  });

  @override
  State<SubtitleHeaderPillButton> createState() =>
      _SubtitleHeaderPillButtonState();
}

class _SubtitleHeaderPillButtonState extends State<SubtitleHeaderPillButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1 : 0.4,
      child: MouseRegion(
        cursor:
            widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onPressed : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isHovered
                  ? subtitleHoverBackgroundColor
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: subtitleFlyoutBorderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: subtitleDefaultTextColor,
                    fontSize: 12,
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 4),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtitleAddMenu extends StatelessWidget {
  final bool useAcrylicBackground;
  final VoidCallback? onSearch;
  final VoidCallback? onAddNas;
  final VoidCallback? onAddLocal;

  const _SubtitleAddMenu({
    required this.useAcrylicBackground,
    required this.onSearch,
    required this.onAddNas,
    required this.onAddLocal,
  });

  @override
  Widget build(BuildContext context) {
    final menu = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onSearch != null)
          _SubtitleAddMenuItem(
            label: '搜索字幕',
            icon: FluentIcons.search,
            onTap: onSearch!,
          ),
        if (onAddNas != null)
          _SubtitleAddMenuItem(
            label: '添加 NAS 字幕文件',
            icon: FluentIcons.storage_optical,
            onTap: onAddNas!,
          ),
        if (onAddLocal != null)
          _SubtitleAddMenuItem(
            label: '添加电脑字幕文件',
            icon: FluentIcons.devices3,
            onTap: onAddLocal!,
          ),
      ],
    );

    if (useAcrylicBackground) {
      return Acrylic(
        tint: const Color(0xFF242424),
        tintAlpha: 0.85,
        luminosityAlpha: 0.5,
        blurAmount: 20,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: subtitleFlyoutBorderColor.withValues(alpha: 0.4),
          ),
        ),
        child: SizedBox(width: 210, child: menu),
      );
    }

    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: subtitleFlyoutBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: subtitleFlyoutBorderColor),
      ),
      child: menu,
    );
  }
}

class _SubtitleAddMenuItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SubtitleAddMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_SubtitleAddMenuItem> createState() => _SubtitleAddMenuItemState();
}

class _SubtitleAddMenuItemState extends State<_SubtitleAddMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered ? subtitleHoverBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtitleItem extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isExternal;
  final bool showPredownloadSimilar;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onPredownloadSimilar;

  const _SubtitleItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.isExternal = false,
    this.showPredownloadSimilar = false,
    this.onDelete,
    this.onPredownloadSimilar,
  });

  @override
  State<_SubtitleItem> createState() => _SubtitleItemState();
}

class _SubtitleItemState extends State<_SubtitleItem> {
  bool _isHovered = false;
  bool _isDeleteHovered = false;
  bool _isPredownloadHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isDeleteHovered = false;
        _isPredownloadHovered = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: _isHovered || widget.isSelected
                ? subtitleHoverBackgroundColor
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.isSelected
                                ? subtitleSelectedTextColor
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.isSelected
                                  ? subtitleSelectedTextColor.withValues(
                                      alpha: 0.8)
                                  : subtitleDefaultTextColor.withValues(
                                      alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.isSelected)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(
                        FluentIcons.check_mark,
                        size: 14,
                        color: subtitleSelectedTextColor,
                      ),
                    )
                  else if (widget.isExternal &&
                      widget.onDelete != null &&
                      _isHovered)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _isDeleteHovered = true),
                      onExit: (_) => setState(() => _isDeleteHovered = false),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onDelete,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _isDeleteHovered
                                ? subtitleHoverBackgroundColor
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            FluentIcons.delete,
                            size: 12,
                            color: subtitleDefaultTextColor,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 28),
                ],
              ),
              if (widget.showPredownloadSimilar &&
                  widget.onPredownloadSimilar != null) ...[
                const SizedBox(height: 6),
                _PredownloadSimilarButton(
                  isHovered: _isPredownloadHovered,
                  onHoverChanged: (hovered) =>
                      setState(() => _isPredownloadHovered = hovered),
                  onTap: widget.onPredownloadSimilar!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PredownloadSimilarButton extends StatelessWidget {
  final bool isHovered;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  const _PredownloadSimilarButton({
    required this.isHovered,
    required this.onHoverChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: subtitleFlyoutBorderColor),
            color: isHovered ? subtitleHoverBackgroundColor : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/subtitle_predownload.svg',
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(
                  subtitleDefaultTextColor,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 6),
              const Flexible(
                child: Text(
                  '为其他集下载相似字幕',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: subtitleDefaultTextColor,
                    fontSize: 12,
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
