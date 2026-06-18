import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/movie_detail_models.dart';

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
            children: [
              const Text(
                '▶',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.0,
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
  @override
  Widget build(BuildContext context) {
    final maxLines = widget.isSeason ? 2 : 4;
    final processedOverview = widget.overview.replaceAll('\n\n', '\n');

    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(
          text: processedOverview,
          style: TextStyle(
            color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
            fontSize: 15,
            height: 1.5,
          ),
        );

        final tp = TextPainter(
          text: span,
          maxLines: maxLines,
          textDirection: TextDirection.ltr,
        );
        tp.layout(maxWidth: constraints.maxWidth);

        final isOverflowing = tp.didExceedMaxLines;

        return Stack(
          children: [
            Text(
              processedOverview,
              style: TextStyle(
                color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
                fontSize: 15,
                height: 1.5,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.clip,
            ),
            if (isOverflowing)
              Positioned(
                bottom: 0,
                right: -10,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        FluentTheme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.0),
                        FluentTheme.of(context).scaffoldBackgroundColor,
                        FluentTheme.of(context).scaffoldBackgroundColor,
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 32, right: 10),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: widget.onMore,
                      child: const Text(
                        '  更多',
                        style: TextStyle(
                          color: kAccentColor,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
  final bool isSubtitle;
  final VoidCallback? onAddNasSubtitle;
  final VoidCallback? onSearchSubtitle;
  final VoidCallback? onAddLocalSubtitle;

  const StreamSelector({
    super.key,
    this.placeholder,
    this.selectedLabel,
    required this.selectedValue,
    required this.items,
    required this.onChanged,
    this.isSubtitle = false,
    this.onAddNasSubtitle,
    this.onSearchSubtitle,
    this.onAddLocalSubtitle,
  });

  @override
  State<StreamSelector<T>> createState() => _StreamSelectorState<T>();
}

class _StreamSelectorState<T> extends State<StreamSelector<T>> {
  final FlyoutController _controller = FlyoutController();
  final FlyoutController _addController = FlyoutController();
  bool _isTargetHovered = false;
  bool _isFlyoutHovered = false;
  bool _isHovered = false;
  Timer? _hideTimer;
  bool _isAddOpen = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    _addController.dispose();
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
    final count = widget.items.length;
    if (widget.isSubtitle) {
      if (count <= 1) return 317;
      if (count > 6) return 317;
      return 57.0 * (count - 1) + 32;
    }
    return 57.0 * count;
  }

  void _showAddFlyout() async {
    if (_isAddOpen) return;
    setState(() {
      _isAddOpen = true;
    });
    try {
      await _addController.showFlyout<void>(
        placementMode: FlyoutPlacementMode.bottomCenter,
        builder: (context) {
          final items = <MenuFlyoutItem>[];
          if (widget.onSearchSubtitle != null) {
            items.add(
              MenuFlyoutItem(
                text: const Text('搜索字幕'),
                onPressed: () {
                  widget.onSearchSubtitle?.call();
                  Flyout.of(context).close();
                },
              ),
            );
          }
          if (widget.onAddNasSubtitle != null) {
            items.add(
              MenuFlyoutItem(
                text: const Text('添加 NAS 字幕'),
                onPressed: () {
                  widget.onAddNasSubtitle?.call();
                  Flyout.of(context).close();
                },
              ),
            );
          }
          if (widget.onAddLocalSubtitle != null) {
            items.add(
              MenuFlyoutItem(
                text: const Text('添加本地字幕'),
                onPressed: () {
                  widget.onAddLocalSubtitle?.call();
                  Flyout.of(context).close();
                },
              ),
            );
          }
          return MenuFlyout(items: items);
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddOpen = false;
        });
      }
    }
  }

  Widget _buildHeader(BuildContext context) {
    final theme = FluentTheme.of(context);
    final hasAddActions = widget.onAddNasSubtitle != null ||
        widget.onSearchSubtitle != null ||
        widget.onAddLocalSubtitle != null;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '字幕',
            style: TextStyle(
              fontSize: 16,
              color: theme.typography.body?.color,
            ),
          ),
          FlyoutTarget(
            controller: _addController,
            child: Button(
              onPressed: hasAddActions ? _showAddFlyout : null,
              style: const ButtonStyle(
                padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                shape: WidgetStatePropertyAll(StadiumBorder()),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '添加',
                    style: TextStyle(
                      color: theme.typography.body?.color,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _isAddOpen ? -0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      FluentIcons.chevron_down_small,
                      size: 12,
                      color: theme.typography.body?.color?.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

    if (widget.isSubtitle) {
      contentItems.add(_buildHeader(context));
    }

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

    if (!widget.isSubtitle && widget.items.length <= 1) {
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
