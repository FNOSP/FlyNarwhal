import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../data/models/subtitle_models.dart';
import '../../../shared/common/app_loading_progress_ring.dart';

const Color _dialogBackgroundColor = Color(0xCC000000);
const Color _flyoutBorderColor = Color(0x80808080);
const Color _languageHoverBackgroundColor = Color(0x1AFFFFFF);
const Color _downloadButtonBorderColor = Color(0x66808080);
const Color _downloadButtonHighlightColor = Color(0x0DFFFFFF);

enum _SubtitleDownloadStatus { idle, downloading, done }

// Language option: (code, menu label, button label)
const List<(String code, String menuLabel, String buttonLabel)>
    _languageOptions = <(String, String, String)>[
  ('zh-CN', '简体中文', '中文'),
  ('en', '英文', '英文'),
];

class SubtitleSearchDialog extends StatefulWidget {
  final String mediaFileName;
  final List<String> initialTrimIds;
  final Future<SubtitleSearchResponse> Function(String language) onSearch;
  final Future<void> Function(SearchingSubtitleInfo item) onDownload;

  const SubtitleSearchDialog({
    super.key,
    required this.mediaFileName,
    required this.initialTrimIds,
    required this.onSearch,
    required this.onDownload,
  });

  @override
  State<SubtitleSearchDialog> createState() => _SubtitleSearchDialogState();
}

class _SubtitleSearchDialogState extends State<SubtitleSearchDialog> {
  final FlyoutController _languageFlyoutController = FlyoutController();

  final Map<String, _SubtitleDownloadStatus> _downloadStatuses =
      <String, _SubtitleDownloadStatus>{};
  String _language = 'zh-CN';
  bool _isLoading = true;
  String? _errorMessage;
  SubtitleSearchResponse? _response;

  @override
  void initState() {
    super.initState();
    for (final trimId in widget.initialTrimIds) {
      if (trimId.isNotEmpty) {
        _downloadStatuses[trimId] = _SubtitleDownloadStatus.done;
      }
    }
    _loadSearchResults();
  }

  @override
  void dispose() {
    _languageFlyoutController.dispose();
    super.dispose();
  }

  String get _currentButtonLabel {
    for (final option in _languageOptions) {
      if (option.$1 == _language) return option.$3;
    }
    return _languageOptions.first.$3;
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
      await widget.onDownload(item);
      if (!mounted) return;
      setState(() {
        _downloadStatuses[item.trimId] = _SubtitleDownloadStatus.done;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _downloadStatuses[item.trimId] = _SubtitleDownloadStatus.idle;
      });
      rethrow;
    }
  }

  void _showLanguageFlyout() {
    _languageFlyoutController.showFlyout(
      placementMode: FlyoutPlacementMode.bottomCenter,
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

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      // Keep the dialog surface consistent with player flyouts.
      style: const ContentDialogThemeData(
        decoration: BoxDecoration(
          color: _dialogBackgroundColor,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      title: const Text('搜索字幕'),
      content: SizedBox(
        width: 720,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.mediaFileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FlyoutTarget(
                  controller: _languageFlyoutController,
                  child: _LanguageSwitchButton(
                    label: _currentButtonLabel,
                    onPressed: _showLanguageFlyout,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '按相关度排序：',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
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
        ),
      );
    }
    final subtitles = _response?.subtitles ?? const <SearchingSubtitleInfo>[];
    if (subtitles.isEmpty) {
      return const _SubtitleEmptyState();
    }

    return ListView.separated(
      itemCount: subtitles.length,
      separatorBuilder: (_, __) => const Divider(size: 1),
      itemBuilder: (context, index) {
        final item = subtitles[index];
        final status =
            _downloadStatuses[item.trimId] ?? _SubtitleDownloadStatus.idle;
        return _SubtitleSearchItem(
          item: item,
          status: status,
          onDownload: () => _handleDownload(item),
        );
      },
    );
  }
}

// Button that triggers the language selection flyout, showing the short label.
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? _languageHoverBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _flyoutBorderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 6),
              const Icon(FluentIcons.chevron_down, size: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// Flyout menu listing the full language names.
class _LanguageMenu extends StatefulWidget {
  final String selectedCode;
  final ValueChanged<String> onSelected;

  const _LanguageMenu({
    required this.selectedCode,
    required this.onSelected,
  });

  @override
  State<_LanguageMenu> createState() => _LanguageMenuState();
}

class _LanguageMenuState extends State<_LanguageMenu> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: _dialogBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _flyoutBorderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in _languageOptions)
            _LanguageMenuItem(
              label: option.$2,
              isSelected: option.$1 == widget.selectedCode,
              onTap: () => widget.onSelected(option.$1),
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
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }
}

// Empty state with the shared empty-folder illustration.
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
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SubtitleSearchItem extends StatefulWidget {
  final SearchingSubtitleInfo item;
  final _SubtitleDownloadStatus status;
  final Future<void> Function() onDownload;

  const _SubtitleSearchItem({
    required this.item,
    required this.status,
    required this.onDownload,
  });

  @override
  State<_SubtitleSearchItem> createState() => _SubtitleSearchItemState();
}

class _SubtitleSearchItemState extends State<_SubtitleSearchItem> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '下载量: ${widget.item.download}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xC8FFFFFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SubtitleDownloadButton(
            status: widget.status,
            onPressed: widget.onDownload,
          ),
        ],
      ),
    );
  }
}

// Capsule-shaped bordered download button with idle/downloading/done states.
class _SubtitleDownloadButton extends StatefulWidget {
  final _SubtitleDownloadStatus status;
  final Future<void> Function() onPressed;

  const _SubtitleDownloadButton({
    required this.status,
    required this.onPressed,
  });

  @override
  State<_SubtitleDownloadButton> createState() =>
      _SubtitleDownloadButtonState();
}

class _SubtitleDownloadButtonState extends State<_SubtitleDownloadButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDone = widget.status == _SubtitleDownloadStatus.done;
    final isBusy = widget.status == _SubtitleDownloadStatus.downloading;
    final highlighted = _isHovered || isDone;

    return MouseRegion(
      cursor: isDone || isBusy
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: (isDone || isBusy) ? null : () => widget.onPressed(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: highlighted
                ? _downloadButtonHighlightColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _downloadButtonBorderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: AppLoadingProgressRing(size: 14, strokeWidth: 2),
                )
              else if (isDone)
                const Icon(FluentIcons.check_mark, size: 16)
              else
                const Icon(FluentIcons.download, size: 16),
              const SizedBox(width: 4),
              Text(
                isDone ? '下载完成' : '下载字幕',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
