import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../data/models/subtitle_models.dart';
import '../../../shared/common/app_loading_progress_ring.dart';

// Translucent card surface; the playing video stays faintly visible behind it.
const Color _cardBackgroundColor = Color(0xB31C1C1C);
// Scrim drawn by the dialog route's modal barrier (kept here for reference and
// passed to showDialog from the call site).
const Color subtitleSearchScrimColor = Color(0x66000000);
const Color _cardBorderColor = Color(0x1FFFFFFF);
const Color _dividerColor = Color(0x33FFFFFF);
const Color _secondaryTextColor = Color(0xC8FFFFFF);
const Color _languageHoverBackgroundColor = Color(0x1AFFFFFF);
const Color _pillBorderColor = Color(0x66FFFFFF);
const Color _pillHoverBackgroundColor = Color(0x14FFFFFF);

enum _SubtitleDownloadStatus { idle, downloading, done }

// Language option: (server code, display label).
const List<(String code, String label)> _languageOptions = <(String, String)>[
  ('zh-CN', '简体中文'),
  ('en', '英文'),
];

class SubtitleSearchDialog extends StatefulWidget {
  final String mediaFileName;

  // trimId -> guid of the subtitle stream already attached to the media. A
  // search result whose trimId appears here is considered downloaded, and the
  // matching guid is what the "download similar for other episodes" action
  // targets.
  final Map<String, String> initialSubtitleGuidByTrimId;
  final Future<SubtitleSearchResponse> Function(String language) onSearch;

  // Downloads a single subtitle. Returns the guid of the resulting subtitle
  // stream so the matching row can offer the "similar episodes" action.
  final Future<String?> Function(SearchingSubtitleInfo item) onDownload;

  // Queues a server task that fetches the same subtitle for the other episodes
  // of the current series.
  final Future<void> Function(
    SearchingSubtitleInfo item,
    String subtitleGuid,
  ) onDownloadSimilar;

  const SubtitleSearchDialog({
    super.key,
    required this.mediaFileName,
    required this.initialSubtitleGuidByTrimId,
    required this.onSearch,
    required this.onDownload,
    required this.onDownloadSimilar,
  });

  @override
  State<SubtitleSearchDialog> createState() => _SubtitleSearchDialogState();
}

class _SubtitleSearchDialogState extends State<SubtitleSearchDialog> {
  final FlyoutController _languageFlyoutController = FlyoutController();

  final Map<String, _SubtitleDownloadStatus> _downloadStatuses =
      <String, _SubtitleDownloadStatus>{};
  final Map<String, String> _subtitleGuidByTrimId = <String, String>{};
  String _language = 'zh-CN';
  bool _isLoading = true;
  String? _errorMessage;
  SubtitleSearchResponse? _response;

  @override
  void initState() {
    super.initState();
    widget.initialSubtitleGuidByTrimId.forEach((trimId, guid) {
      if (trimId.isNotEmpty && guid.isNotEmpty) {
        _downloadStatuses[trimId] = _SubtitleDownloadStatus.done;
        _subtitleGuidByTrimId[trimId] = guid;
      }
    });
    _loadSearchResults();
  }

  @override
  void dispose() {
    _languageFlyoutController.dispose();
    super.dispose();
  }

  String get _currentLanguageLabel {
    for (final option in _languageOptions) {
      if (option.$1 == _language) return option.$2;
    }
    return _languageOptions.first.$2;
  }

  Future<void> _loadSearchResults() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await widget.onSearch(_language);
      if (!mounted) return;
      setState(() {
        _response = response;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDownload(SearchingSubtitleInfo item) async {
    final status = _downloadStatuses[item.trimId];
    if (status == _SubtitleDownloadStatus.downloading ||
        status == _SubtitleDownloadStatus.done) {
      return;
    }
    setState(() {
      _downloadStatuses[item.trimId] = _SubtitleDownloadStatus.downloading;
    });
    try {
      final subtitleGuid = await widget.onDownload(item);
      if (!mounted) return;
      setState(() {
        _downloadStatuses[item.trimId] = _SubtitleDownloadStatus.done;
        if (subtitleGuid != null && subtitleGuid.isNotEmpty) {
          _subtitleGuidByTrimId[item.trimId] = subtitleGuid;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _downloadStatuses[item.trimId] = _SubtitleDownloadStatus.idle;
      });
    }
  }

  Future<void> _handleDownloadSimilar(SearchingSubtitleInfo item) async {
    final subtitleGuid = _subtitleGuidByTrimId[item.trimId];
    if (subtitleGuid == null || subtitleGuid.isEmpty) return;
    await widget.onDownloadSimilar(item, subtitleGuid);
  }

  void _showLanguageFlyout() {
    _languageFlyoutController.showFlyout(
      placementMode: FlyoutPlacementMode.bottomRight,
      builder: (context) => _LanguageMenu(
        selectedCode: _language,
        onSelected: (code) {
          Navigator.of(context).pop();
          if (code == _language) return;
          setState(() => _language = code);
          _loadSearchResults();
        },
      ),
    );
  }

  void _close(BuildContext context) => Navigator.of(context).pop();

  // Reference size at full screen; the card scales with the smaller window
  // dimension while keeping this 4:3 aspect ratio fixed.
  static const double _cardWidth = 600;
  static const double _cardHeight = 453;
  static const double _minScale = 0.55;
  static const double _maxScale = 1.2;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // The dialog route's canvas is the whole screen even in fullscreen, so the
    // smaller of width/height drives the scale (capped for very large displays).
    final scale = (math.min(screenSize.width, screenSize.height) / 680)
        .clamp(_minScale, _maxScale);
    final cardWidth =
        math.min(_cardWidth * scale, screenSize.width * 0.94);
    final cardHeight =
        math.min(_cardHeight * scale, screenSize.height * 0.94);

    // The route's modal barrier (see the call site) draws the scrim and closes
    // the dialog on outside taps. The card only needs to absorb hits so taps on
    // its empty areas don't reach the barrier, which is why a hit-test-only
    // [Listener] is used instead of a tap recognizer: it never enters the
    // gesture arena, so the pill buttons inside always win their taps.
    return Center(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: _cardBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorderColor),
          ),
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DialogHeader(onClose: () => _close(context)),
              const SizedBox(height: 16),
              Container(height: 1, color: _dividerColor),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _MiddleEllipsisText(
                      widget.mediaFileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FlyoutTarget(
                    controller: _languageFlyoutController,
                    child: _LanguageSwitchButton(
                      label: _currentLanguageLabel,
                      onPressed: _showLanguageFlyout,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                '按相关度排序：',
                style: TextStyle(
                  color: _secondaryTextColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: AppLoadingProgressRing());
    }
    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _secondaryTextColor),
        ),
      );
    }
    final subtitles = _response?.subtitles ?? const <SearchingSubtitleInfo>[];
    if (subtitles.isEmpty) {
      return const _SubtitleEmptyState();
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: subtitles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 22),
      itemBuilder: (context, index) {
        final item = subtitles[index];
        final status =
            _downloadStatuses[item.trimId] ?? _SubtitleDownloadStatus.idle;
        final subtitleGuid = _subtitleGuidByTrimId[item.trimId];
        return _SubtitleSearchItem(
          item: item,
          status: status,
          canDownloadSimilar: status == _SubtitleDownloadStatus.done &&
              subtitleGuid != null &&
              subtitleGuid.isNotEmpty,
          onDownload: () => _handleDownload(item),
          onDownloadSimilar: () => _handleDownloadSimilar(item),
        );
      },
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _DialogHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text(
            '添加字幕',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _IconButton(icon: FluentIcons.clear, onPressed: onClose),
      ],
    );
  }
}

class _IconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _IconButton({required this.icon, required this.onPressed});

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color:
                _isHovered ? _languageHoverBackgroundColor : Colors.transparent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

// Text that truncates with an ellipsis in the middle, keeping the file
// extension visible (e.g. "Severance.2022.S01E03...uawei.mkv").
class _MiddleEllipsisText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _MiddleEllipsisText(this.text, {required this.style});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        if (painter.width <= constraints.maxWidth) {
          return Text(text, maxLines: 1, style: style);
        }

        const ellipsis = '...';
        final chars = text.characters.toList();
        // Smallest possible middle-ellipsis form (one char each side); used as
        // the fallback so the result never exceeds the available width.
        final minimal = '${chars.first}$ellipsis${chars.last}';
        var head = 1;
        var tail = chars.length;
        String fit = minimal;
        while (head + 1 < tail) {
          final mid = (head + tail) ~/ 2;
          final candidate = chars.take(mid).join() +
              ellipsis +
              chars.skip(chars.length - mid).join();
          final candidatePainter = TextPainter(
            text: TextSpan(text: candidate, style: style),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout();
          if (candidatePainter.width <= constraints.maxWidth) {
            fit = candidate;
            head = mid;
          } else {
            tail = mid;
          }
        }
        return Text(fit, maxLines: 1, style: style);
      },
    );
  }
}

// Rounded-full bordered button that opens the language selection flyout.
class _LanguageSwitchButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _LanguageSwitchButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_LanguageSwitchButton> createState() => _LanguageSwitchButtonState();
}

class _LanguageSwitchButtonState extends State<_LanguageSwitchButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color:
                _isHovered ? _languageHoverBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _pillBorderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(width: 8),
              const Icon(FluentIcons.chevron_down,
                  size: 12, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  final String selectedCode;
  final ValueChanged<String> onSelected;

  const _LanguageMenu({
    required this.selectedCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: _cardBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in _languageOptions)
            _LanguageMenuItem(
              label: option.$2,
              isSelected: option.$1 == selectedCode,
              onTap: () => onSelected(option.$1),
            ),
        ],
      ),
    );
  }
}

class _LanguageMenuItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageMenuItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_LanguageMenuItem> createState() => _LanguageMenuItemState();
}

class _LanguageMenuItemState extends State<_LanguageMenuItem> {
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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: (_isHovered || widget.isSelected)
                ? _languageHoverBackgroundColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _SubtitleEmptyState extends StatelessWidget {
  const _SubtitleEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/empty_folder.svg',
            width: 110,
            height: 110,
          ),
          const SizedBox(height: 12),
          const Text(
            '未搜索到相关字幕',
            style: TextStyle(color: _secondaryTextColor, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SubtitleSearchItem extends StatelessWidget {
  final SearchingSubtitleInfo item;
  final _SubtitleDownloadStatus status;
  final bool canDownloadSimilar;
  final VoidCallback onDownload;
  final VoidCallback onDownloadSimilar;

  const _SubtitleSearchItem({
    required this.item,
    required this.status,
    required this.canDownloadSimilar,
    required this.onDownload,
    required this.onDownloadSimilar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _MiddleEllipsisText(
                item.filename,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '下载量 ${item.download}',
              style: const TextStyle(
                color: _secondaryTextColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildActions(),
      ],
    );
  }

  Widget _buildActions() {
    if (status == _SubtitleDownloadStatus.downloading) {
      return _PillButton(
        icon: const SizedBox(
          width: 15,
          height: 15,
          child: AppLoadingProgressRing(size: 15, strokeWidth: 2),
        ),
        label: '下载中',
        enabled: false,
        onPressed: () {},
      );
    }
    if (status == _SubtitleDownloadStatus.done) {
      return Row(
        children: [
          _PillButton(
            icon: const Icon(FluentIcons.check_mark,
                size: 16, color: Colors.white),
            label: '下载完成',
            enabled: false,
            onPressed: () {},
          ),
          if (canDownloadSimilar) ...[
            const SizedBox(width: 12),
            _PillButton(
              icon: const _CircleDownArrowIcon(size: 16, color: Colors.white),
              label: '为其他集下载相似字幕',
              enabled: true,
              onPressed: onDownloadSimilar,
            ),
          ],
        ],
      );
    }
    return _PillButton(
      icon: const Icon(FluentIcons.download, size: 16, color: Colors.white),
      label: '下载字幕',
      enabled: true,
      onPressed: onDownload,
    );
  }
}

// Capsule-shaped bordered action button used for the download actions.
class _PillButton extends StatefulWidget {
  final Widget icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _isHovered && widget.enabled;
    return MouseRegion(
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onPressed : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: highlighted ? _pillHoverBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _pillBorderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.icon,
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Outlined circle enclosing a downward arrow, matching the web glyph used on
// the "download similar subtitles for other episodes" action.
class _CircleDownArrowIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _CircleDownArrowIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CircleDownArrowPainter(color)),
    );
  }
}

class _CircleDownArrowPainter extends CustomPainter {
  final Color color;

  _CircleDownArrowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - paint.strokeWidth / 2;
    canvas.drawCircle(center, radius, paint);

    final shaftTop = size.height * 0.28;
    final shaftBottom = size.height * 0.64;
    canvas.drawLine(
      Offset(center.dx, shaftTop),
      Offset(center.dx, shaftBottom),
      paint,
    );

    final headWidth = size.width * 0.17;
    final headHeight = size.height * 0.15;
    canvas.drawLine(
      Offset(center.dx - headWidth, shaftBottom - headHeight),
      Offset(center.dx, shaftBottom),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + headWidth, shaftBottom - headHeight),
      Offset(center.dx, shaftBottom),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleDownArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
