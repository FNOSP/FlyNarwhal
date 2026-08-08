import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/movie_detail_models.dart';
import '../player/widgets/subtitle_selection_panel.dart';

const kAccentColor = Color(0xFF2173DF);

class DetailPlayButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const DetailPlayButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 160),
        child: FilledButton(
          onPressed: onPressed,
          style: const ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(kAccentColor),
            shape: WidgetStatePropertyAll(StadiumBorder()),
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/images/btn_play.svg',
                width: 28,
                height: 28,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Transform.translate(
                offset: const Offset(0, 2),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.0,
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

class Separator extends StatelessWidget {
  const Separator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        '/',
        style: TextStyle(
          color: FluentTheme.of(context).typography.caption?.color?.withValues(alpha: 0.5),
          fontSize: 14,
        ),
      ),
    );
  }
}

class DetailTags extends StatelessWidget {
  final ItemResponse item;
  final String? formatedTotalDuration;
  final Map<String, String> iso3166Map;
  final Map<int, String> genresMap;
  final String? smartAnalysisStatusText;

  const DetailTags({
    super.key,
    required this.item,
    this.formatedTotalDuration,
    this.iso3166Map = const {},
    this.genresMap = const {},
    this.smartAnalysisStatusText,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = [];

    final voteAverage = double.tryParse(item.voteAverage) ?? 0.0;
    if (voteAverage > 0) {
      items.add(Text(
        '${voteAverage.toStringAsFixed(1)} 分',
        style: const TextStyle(
          color: Color(0xFFFACC15),
          fontSize: 14,
        ),
      ));
    }

    if (item.contentRatings != null && item.contentRatings!.isNotEmpty) {
      items.add(Text(
        item.contentRatings!,
        style: TextStyle(
          color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
          fontSize: 14,
        ),
      ));
    }

    if (item.airDate != null && item.airDate!.length >= 4) {
      items.add(Text(
        item.airDate!.substring(0, 4),
        style: TextStyle(
          color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
          fontSize: 14,
        ),
      ));
    }

    if (item.genres != null && item.genres!.isNotEmpty) {
      final genresText = item.genres!
          .map((id) => genresMap[id] ?? '')
          .where((s) => s.isNotEmpty)
          .join(' ');

      if (genresText.isNotEmpty) {
        items.add(Text(
          genresText,
          style: TextStyle(
            color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ));
      }
    }

    if (item.productionCountries != null && item.productionCountries!.isNotEmpty) {
      final countriesText = item.productionCountries!
          .map((c) {
            final parts = c.split(RegExp(r'[^A-Za-z]+')).where((p) => p.isNotEmpty);
            final converted = parts.map((p) => iso3166Map[p] ?? p).join(' ');
            return converted.isNotEmpty ? converted : c;
          })
          .where((c) => c.isNotEmpty)
          .join(' ');
      if (countriesText.isNotEmpty) {
        items.add(Text(
          countriesText,
          style: TextStyle(
            color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ));
      }
    }

    if (formatedTotalDuration != null && formatedTotalDuration!.isNotEmpty) {
      items.add(Text(
        formatedTotalDuration!,
        style: TextStyle(
          color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
          fontSize: 14,
        ),
      ));
    }

    if (item.ancestorName.isNotEmpty) {
      items.add(Text(
        item.ancestorName,
        style: TextStyle(
          color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
          fontSize: 14,
        ),
      ));
    }

    if (smartAnalysisStatusText != null && smartAnalysisStatusText!.isNotEmpty) {
      items.add(Text(
        '智能片头/片尾检测状态：$smartAnalysisStatusText',
        style: TextStyle(
          color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
          fontSize: 14,
        ),
      ));
    }

    final List<Widget> displayItems = [];
    for (int i = 0; i < items.length; i++) {
      displayItems.add(items[i]);
      if (i < items.length - 1) {
        displayItems.add(const Separator());
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: displayItems,
    );
  }
}

class ImdbLink extends StatefulWidget {
  final String imdbId;

  const ImdbLink({super.key, required this.imdbId});

  @override
  State<ImdbLink> createState() => _ImdbLinkState();
}

class _ImdbLinkState extends State<ImdbLink> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.imdbId.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '链接:  ',
          style: TextStyle(
            color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () async {
              final url = 'https://www.imdb.com/title/${widget.imdbId}/';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
            },
            child: Text(
              'IMDB链接',
              style: TextStyle(
                color: FluentTheme.of(context).typography.bodyStrong?.color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                decoration: isHovered ? TextDecoration.underline : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MediaDescription extends StatefulWidget {
  final String overview;
  final VoidCallback onMore;
  final bool isSeason;

  const MediaDescription({
    super.key,
    required this.overview,
    required this.onMore,
    this.isSeason = false,
  });

  @override
  State<MediaDescription> createState() => _MediaDescriptionState();
}

class _MediaDescriptionState extends State<MediaDescription> {
  static const String _moreLabel = '更多';
  static const double _moreGap = 4;

  @override
  Widget build(BuildContext context) {
    final maxLines = widget.isSeason ? 2 : 4;
    final processedOverview = widget.overview.replaceAll('\n\n', '\n');
    final bodyStyle = TextStyle(
      color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
      fontSize: 15,
      height: 1.5,
    );
    const moreStyle = TextStyle(color: kAccentColor, fontSize: 15, height: 1.5);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        // 参考 Web 端:按字符截断文本为“更多”按钮留出空间,
        // 按钮作为内联元素放在最后一行,避免渐变遮罩盖住文字造成重叠。
        final fullPainter = TextPainter(
          text: TextSpan(text: processedOverview, style: bodyStyle),
          maxLines: maxLines,
          textDirection: TextDirection.ltr,
        );
        fullPainter.layout(maxWidth: maxWidth);

        if (!fullPainter.didExceedMaxLines) {
          return Text(processedOverview, style: bodyStyle);
        }

        final moreWidth = (TextPainter(
          text: const TextSpan(text: _moreLabel, style: moreStyle),
          textDirection: TextDirection.ltr,
        )..layout()).width;
        final reservedWidth = moreWidth + _moreGap;

        bool fitsWithMore(int prefixLen) {
          final tp = TextPainter(
            text: TextSpan(
              text: '${processedOverview.substring(0, prefixLen)}...',
              style: bodyStyle,
            ),
            maxLines: maxLines,
            textDirection: TextDirection.ltr,
          );
          tp.layout(maxWidth: maxWidth);
          if (tp.didExceedMaxLines) return false;
          final lines = tp.computeLineMetrics();
          // 未占满 maxLines 时无需预留;占满则最后一行需为“更多”留出空间。
          // 注意:此处不能用 WidgetSpan 占位——裸 TextPainter 无法布局占位组件。
          return lines.length < maxLines ||
              lines.last.width + reservedWidth <= maxWidth;
        }

        // 二分查找能放下“更多”按钮的最长前缀
        int lo = 0;
        int hi = processedOverview.length;
        while (lo < hi) {
          final mid = (lo + hi + 1) >> 1;
          if (fitsWithMore(mid)) {
            lo = mid;
          } else {
            hi = mid - 1;
          }
        }
        final truncated = processedOverview.substring(0, lo).trimRight();

        // 将“更多”按钮推到最后一行右端,与 Web 端视觉一致
        final truncatedPainter = TextPainter(
          text: TextSpan(text: '$truncated...', style: bodyStyle),
          maxLines: maxLines,
          textDirection: TextDirection.ltr,
        );
        truncatedPainter.layout(maxWidth: maxWidth);
        final lastLineWidth = truncatedPainter.computeLineMetrics().last.width;
        final spacerWidth =
            (maxWidth - lastLineWidth - reservedWidth).clamp(0.0, maxWidth);

        return Text.rich(
          TextSpan(children: [
            TextSpan(text: '$truncated...', style: bodyStyle),
            WidgetSpan(
              alignment: PlaceholderAlignment.bottom,
              child: SizedBox(width: spacerWidth, height: 1),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onMore,
                  child: Padding(
                    padding: const EdgeInsets.only(left: _moreGap),
                    child: const Text(_moreLabel, style: moreStyle),
                  ),
                ),
              ),
            ),
          ]),
          maxLines: maxLines,
          overflow: TextOverflow.clip,
        );
      },
    );
  }
}

class MediaDescriptionDialog extends StatelessWidget {
  final String title;
  final String content;

  const MediaDescriptionDialog({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: FluentTheme.of(context).typography.subtitle),
          IconButton(
            icon: const Icon(FluentIcons.chrome_close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Text(
          content,
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class CircleIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? iconColor;
  final Widget? iconWidget;
  final double iconSize;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
    this.iconWidget,
    this.iconSize = 22,
  });

  @override
  State<CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<CircleIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.white.withValues(alpha: _hovered ? 0.3 : 0.1);
    final backgroundColor = _hovered ? Colors.white.withValues(alpha: 0.02) : Colors.transparent;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: Center(
              child: widget.iconWidget ??
                  Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: widget.iconSize,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class MediaQualityTag extends StatelessWidget {
  final String text;

  const MediaQualityTag({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final raw = text.trim();
    const imageTags = {
      'DolbySurround': 'dolby_surround_logo.png',
      'DolbyVision': 'dolby_vision_logo.png',
      'DTS': 'dts_logo.png',
      'DolbyAtmos': 'dolby_atmos_logo.png',
    };
    if (imageTags.containsKey(raw)) {
      return Image.asset(
        'assets/images/${imageTags[raw]}',
        height: 24,
        color: Colors.white.withValues(alpha: 0.5),
        colorBlendMode: BlendMode.srcIn,
      );
    }
    final lower = raw.toLowerCase();
    final isResolution = lower.endsWith('k') || lower.endsWith('p');
    const textColor = Colors.white;
    final backgroundColor = Colors.white.withValues(alpha: 0.2);
    final borderColor = Colors.white.withValues(alpha: 0.5);

    if (isResolution) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          raw.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor,
            height: 1.1,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1.0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        raw,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor.withValues(alpha: 0.9),
          height: 1.1,
        ),
      ),
    );
  }
}

class VideoSelectionBox extends StatefulWidget {
  final String text;
  final VoidCallback onClick;
  final bool isSelected;

  const VideoSelectionBox({
    super.key,
    required this.text,
    required this.onClick,
    required this.isSelected,
  });

  @override
  State<VideoSelectionBox> createState() => _VideoSelectionBoxState();
}

class _VideoSelectionBoxState extends State<VideoSelectionBox> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final textColor = widget.isSelected ? kAccentColor : theme.typography.body?.color ?? Colors.white;
    final borderColor = widget.isSelected
        ? kAccentColor
        : _isHovered
            ? Colors.white.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.1);
    final backgroundColor = _isHovered ? Colors.white.withValues(alpha: 0.02) : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onClick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 128,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(
              color: borderColor,
              width: widget.isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class StreamOptionItem<T> {
  final String title;
  final String subtitle1;
  final String subtitle2;
  final String subtitle3;
  final T value;
  final bool isDefault;
  final bool isExternal;
  final bool isNoDisplay;

  StreamOptionItem({
    required this.title,
    required this.value,
    this.subtitle1 = '',
    this.subtitle2 = '',
    this.subtitle3 = '',
    this.isDefault = false,
    this.isExternal = false,
    this.isNoDisplay = false,
  });
}

class StreamSelector<T> extends StatefulWidget {
  final String? placeholder;
  final String? selectedLabel;
  final T? selectedValue;
  final List<StreamOptionItem<T>> items;
  final ValueChanged<T> onChanged;

  const StreamSelector({
    super.key,
    this.placeholder,
    this.selectedLabel,
    required this.selectedValue,
    required this.items,
    required this.onChanged,
  });

  @override
  State<StreamSelector<T>> createState() => _StreamSelectorState<T>();
}

class _StreamSelectorState<T> extends State<StreamSelector<T>> {
  final FlyoutController _controller = FlyoutController();
  bool _isTargetHovered = false;
  bool _isFlyoutHovered = false;
  bool _isHovered = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!mounted) return;
      // flyout 程序化关闭时 MouseRegion 不触发 onExit，需显式复位，
      // 否则触发器箭头保持旋转状态。
      if (!_controller.isOpen && _isFlyoutHovered) {
        _isFlyoutHovered = false;
      }
      // 关闭后 _isHovered 仍可能为 true（_handleTargetHover(false) 在
      // flyout 仍开着时被设上去的），需要重新同步，否则箭头不会归位。
      _syncHoveredState();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  StreamOptionItem<T>? _findSelectedItem() {
    for (final item in widget.items) {
      if (item.value == widget.selectedValue) return item;
    }
    return null;
  }

  void _showFlyout() {
    if (_controller.isOpen) return;
    _controller.showFlyout<void>(
      placementMode: FlyoutPlacementMode.auto,
      barrierDismissible: false,
      dismissOnPointerMoveAway: false,
      buildTarget: true,
      builder: (context) {
        return FlyoutContent(
          child: MouseRegion(
            opaque: true,
            onEnter: (_) => _handleFlyoutHover(true),
            onExit: (_) => _handleFlyoutHover(false),
            child: SizedBox(
              width: 240,
              child: _buildFlyoutContent(context),
            ),
          ),
        );
      },
    );
  }

  void _handleTargetHover(bool hovered) {
    _isTargetHovered = hovered;
    if (hovered) {
      _cancelHide();
      _showFlyout();
    } else {
      _scheduleHide();
    }
    _syncHoveredState();
  }

  void _handleFlyoutHover(bool hovered) {
    _isFlyoutHovered = hovered;
    if (hovered) {
      _cancelHide();
    } else {
      _scheduleHide();
    }
    _syncHoveredState();
  }

  void _syncHoveredState() {
    if (!mounted) return;
    final nextHovered = _isTargetHovered || _isFlyoutHovered || _controller.isOpen;
    if (_isHovered != nextHovered) {
      setState(() {
        _isHovered = nextHovered;
      });
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      if (!_isTargetHovered && !_isFlyoutHovered && _controller.isOpen) {
        _controller.close();
      }
    });
  }

  void _cancelHide() {
    _hideTimer?.cancel();
  }

  double _calculateFlyoutHeight() {
    return 57.0 * widget.items.length;
  }

  Widget _buildOptionItem(
    BuildContext context,
    StreamOptionItem<T> item,
  ) {
    final theme = FluentTheme.of(context);
    final isSelected = item.value == widget.selectedValue;
    final titleText = item.isDefault ? '${item.title} - 默认' : item.title;
    final subtitleText = [
      item.subtitle1,
      item.subtitle2,
      item.subtitle3,
    ].where((s) => s.isNotEmpty).join('  ');

    return FlyoutListTile(
      onPressed: () {
        widget.onChanged(item.value);
        Flyout.of(context).close();
      },
      text: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleText,
            style: TextStyle(
              fontSize: 15,
              color: isSelected ? theme.accentColor : theme.typography.body?.color,
            ),
          ),
          if (!item.isNoDisplay)
            Text(
              subtitleText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? theme.accentColor
                    : theme.typography.body?.color?.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
      trailing: isSelected
          ? Icon(
              FluentIcons.check_mark,
              size: 14,
              color: theme.accentColor,
            )
          : null,
    );
  }

  Widget _buildFlyoutContent(BuildContext context) {
    final noDisplayItem = widget.items.where((i) => i.isNoDisplay).toList();
    final otherItems = widget.items.where((i) => !i.isNoDisplay).toList();
    final contentItems = <Widget>[];

    if (otherItems.isNotEmpty) {
      if (noDisplayItem.isNotEmpty) {
        contentItems.add(_buildOptionItem(context, noDisplayItem.first));
      }
      for (final item in otherItems) {
        contentItems.add(_buildOptionItem(context, item));
      }
    } else if (noDisplayItem.isNotEmpty) {
      contentItems.add(_buildOptionItem(context, noDisplayItem.first));
    } else {
      contentItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '无内容',
            style: TextStyle(
              fontSize: 13,
              color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: _calculateFlyoutHeight()),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contentItems,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = _findSelectedItem();
    final label = widget.selectedLabel ?? selectedItem?.title ?? widget.placeholder ?? 'Select';

    if (widget.items.length <= 1) {
      return Text(
        label,
        style: TextStyle(
          color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
          fontSize: 14,
        ),
      );
    }

    return FlyoutTarget(
      controller: _controller,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _handleTargetHover(true),
        onExit: (_) => _handleTargetHover(false),
        child: GestureDetector(
          onTap: _showFlyout,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isHovered ? -0.5 : 0,
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  FluentIcons.chevron_down_small,
                  size: 12,
                  color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 详情页字幕选择器：复用播放器的 [SubtitleSelectionPanel]，
/// 但不提供"调整"入口，使用 Fluent 毛玻璃背景，
/// 滚动条在鼠标不活跃时自动隐藏。
class SubtitleStreamSelector extends StatefulWidget {
  final String? selectedLabel;
  final List<SubtitleStream> subtitles;

  /// 为 null 表示当前选中"关闭"。
  final String? selectedSubtitleGuid;
  final Map<String, String> iso6391Map;
  final Map<String, String> iso6392Map;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onAddNasSubtitle;
  final VoidCallback? onSearchSubtitle;
  final VoidCallback? onAddLocalSubtitle;
  final ValueChanged<SubtitleStream>? onRequestDelete;
  final ValueChanged<SubtitleStream>? onPredownloadSimilar;

  const SubtitleStreamSelector({
    super.key,
    this.selectedLabel,
    required this.subtitles,
    required this.selectedSubtitleGuid,
    required this.iso6391Map,
    required this.iso6392Map,
    required this.onChanged,
    this.onAddNasSubtitle,
    this.onSearchSubtitle,
    this.onAddLocalSubtitle,
    this.onRequestDelete,
    this.onPredownloadSimilar,
  });

  @override
  State<SubtitleStreamSelector> createState() => _SubtitleStreamSelectorState();
}

class _SubtitleStreamSelectorState extends State<SubtitleStreamSelector> {
  final FlyoutController _controller = FlyoutController();
  bool _isTargetHovered = false;
  bool _isFlyoutHovered = false;
  bool _isHovered = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!mounted) return;
      // flyout 被程序化关闭（如选中字幕后）时，包裹面板的 MouseRegion
      // 随路由销毁不会触发 onExit，_isFlyoutHovered 会卡死为 true，
      // 导致触发器箭头不复位——这里随 controller 关闭显式复位。
      if (!_controller.isOpen && _isFlyoutHovered) {
        _isFlyoutHovered = false;
      }
      // 关闭后 _isHovered 仍可能为 true（_handleTargetHover(false) 在
      // flyout 仍开着时被设上去的），需要重新同步，否则箭头不会归位。
      _syncHoveredState();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showFlyout() {
    if (_controller.isOpen) return;
    _controller.showFlyout<void>(
      placementMode: FlyoutPlacementMode.auto,
      barrierDismissible: false,
      dismissOnPointerMoveAway: false,
      buildTarget: true,
      builder: (context) {
        return MouseRegion(
          opaque: true,
          onEnter: (_) => _handleFlyoutHover(true),
          onExit: (_) => _handleFlyoutHover(false),
          child: SubtitleSelectionPanel(
            subtitles: widget.subtitles,
            selectedSubtitleGuid: widget.selectedSubtitleGuid,
            iso6391Map: widget.iso6391Map,
            iso6392Map: widget.iso6392Map,
            onAdjustmentClicked: null,
            onSubtitleSelected: (guid) {
              widget.onChanged(guid);
              _controller.close();
            },
            onOpenSubtitleSearch: widget.onSearchSubtitle == null
                ? null
                : () {
                    _controller.close();
                    widget.onSearchSubtitle!.call();
                  },
            onOpenAddNasSubtitle: widget.onAddNasSubtitle == null
                ? null
                : () {
                    _controller.close();
                    widget.onAddNasSubtitle!.call();
                  },
            onOpenAddLocalSubtitle: widget.onAddLocalSubtitle == null
                ? null
                : () {
                    _controller.close();
                    widget.onAddLocalSubtitle!.call();
                  },
            onRequestDelete: widget.onRequestDelete,
            onPredownloadSimilar: widget.onPredownloadSimilar,
            useAcrylicBackground: true,
            autoHideScrollbar: true,
          ),
        );
      },
    );
  }

  void _handleTargetHover(bool hovered) {
    _isTargetHovered = hovered;
    if (hovered) {
      _cancelHide();
      _showFlyout();
    } else {
      _scheduleHide();
    }
    _syncHoveredState();
  }

  void _handleFlyoutHover(bool hovered) {
    _isFlyoutHovered = hovered;
    if (hovered) {
      _cancelHide();
    } else {
      _scheduleHide();
    }
    _syncHoveredState();
  }

  void _syncHoveredState() {
    if (!mounted) return;
    final nextHovered =
        _isTargetHovered || _isFlyoutHovered || _controller.isOpen;
    if (_isHovered != nextHovered) {
      setState(() {
        _isHovered = nextHovered;
      });
    }
  }
  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      if (!_isTargetHovered && !_isFlyoutHovered && _controller.isOpen) {
        _controller.close();
      }
    });
  }

  void _cancelHide() {
    _hideTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.selectedLabel ?? '字幕';

    return FlyoutTarget(
      controller: _controller,
      child: MouseRegion(
        key: const ValueKey('movie-detail-subtitle-selector'),
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _handleTargetHover(true),
        onExit: (_) => _handleTargetHover(false),
        child: GestureDetector(
          onTap: _showFlyout,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: FluentTheme.of(context)
                      .typography
                      .body
                      ?.color
                      ?.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isHovered ? -0.5 : 0,
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  FluentIcons.chevron_down_small,
                  size: 12,
                  color: FluentTheme.of(context)
                      .typography
                      .body
                      ?.color
                      ?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
