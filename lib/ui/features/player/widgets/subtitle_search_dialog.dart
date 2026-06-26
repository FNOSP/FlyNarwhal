import 'package:fluent_ui/fluent_ui.dart';
import '../../../../data/models/subtitle_models.dart';
import '../../../shared/common/app_loading_progress_ring.dart';

enum _SubtitleDownloadStatus { idle, downloading, done }

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
  static const _languageOptions = <(String code, String label)>[
    ('zh-CN', '中文'),
    ('en', '英文'),
  ];

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

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
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
                SizedBox(
                  width: 120,
                  child: ComboBox<String>(
                    value: _language,
                    items: [
                      for (final option in _languageOptions)
                        ComboBoxItem<String>(
                          value: option.$1,
                          child: Text(option.$2),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null || value == _language) return;
                      setState(() => _language = value);
                      _loadSearchResults();
                    },
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
      return const Center(child: Text('未搜索到相关字幕'));
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
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDone = widget.status == _SubtitleDownloadStatus.done;
    final isBusy = widget.status == _SubtitleDownloadStatus.downloading;
    return Container(
      color: _isHovered ? const Color(0x0DFFFFFF) : Colors.transparent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '下载量: ${widget.item.download}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xC8FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: isDone || isBusy ? null : () => widget.onDownload(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isBusy) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: AppLoadingProgressRing(size: 12, strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                    ] else if (isDone) ...[
                      const Icon(FluentIcons.check_mark, size: 12),
                      const SizedBox(width: 8),
                    ] else ...[
                      const Icon(FluentIcons.download, size: 12),
                      const SizedBox(width: 8),
                    ],
                    Text(isDone ? '下载完成' : '下载字幕'),
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
