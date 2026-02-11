import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'movie_detail_view_model.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../data/utils/fn_data_convertor.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/providers.dart';

class MovieDetailScreen extends ConsumerWidget {
  final String guid;

  const MovieDetailScreen({super.key, required this.guid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(movieDetailNotifierProvider(guid));
    final prefsManager = ref.watch(preferencesManagerProvider);
    final baseUrl = prefsManager.getBaseUrl() ?? '';

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: detailState.when(
        data: (state) => _MovieDetailContent(state: state, baseUrl: baseUrl, guid: guid),
        loading: () => const Center(child: ProgressRing()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('加载失败: $error'),
              const SizedBox(height: 16),
              Button(
                child: const Text('重试'),
                onPressed: () => ref.read(movieDetailNotifierProvider(guid).notifier).refresh(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieDetailContent extends ConsumerStatefulWidget {
  final MovieDetailState state;
  final String baseUrl;
  final String guid;

  const _MovieDetailContent({required this.state, required this.baseUrl, required this.guid});

  @override
  ConsumerState<_MovieDetailContent> createState() => _MovieDetailContentState();
}

class _MovieDetailContentState extends ConsumerState<_MovieDetailContent> {
  int _selectedVideoStreamIndex = 0;
  String? _selectedAudioGuid;
  String? _selectedSubtitleGuid;

  @override
  void initState() {
    super.initState();
    _selectedAudioGuid = widget.state.playInfo?.audioGuid;
    _selectedSubtitleGuid = widget.state.playInfo?.subtitleGuid;
  }

  @override
  Widget build(BuildContext context) {
    final videoStreams = widget.state.streamList?.videoStreams ?? [];
    final currentMediaGuid = videoStreams.isNotEmpty && _selectedVideoStreamIndex < videoStreams.length
        ? videoStreams[_selectedVideoStreamIndex].mediaGuid
        : '';

    // Filter audio/subtitle for current media
    final currentAudioStreams = (widget.state.streamList?.audioStreams ?? [])
        .where((s) => s.mediaGuid == currentMediaGuid)
        .toList();
    final currentSubtitleStreams = (widget.state.streamList?.subtitleStreams ?? [])
        .where((s) => s.mediaGuid == currentMediaGuid)
        .toList();

    // Ensure selected audio/subtitle are valid for current media
    if (_selectedAudioGuid != null && !currentAudioStreams.any((s) => s.guid == _selectedAudioGuid)) {
      try {
        _selectedAudioGuid = currentAudioStreams.firstWhere((s) => s.isDefault == 1).guid;
      } catch (_) {
        _selectedAudioGuid = currentAudioStreams.isNotEmpty ? currentAudioStreams.first.guid : null;
      }
    }
    if (_selectedSubtitleGuid != null && _selectedSubtitleGuid != '_no_display_' && !currentSubtitleStreams.any((s) => s.guid == _selectedSubtitleGuid)) {
      try {
        _selectedSubtitleGuid = currentSubtitleStreams.firstWhere((s) => s.isDefault == 1).guid;
      } catch (_) {
        _selectedSubtitleGuid = currentSubtitleStreams.isNotEmpty ? currentSubtitleStreams.first.guid : null;
      }
    }

    final item = widget.state.item;
    if (item == null) return const Center(child: Text('未找到电影信息'));

    final backdropUrl = item.backdrops != null ? '${widget.baseUrl}${item.backdrops}' : '';
    final posterUrl = '${widget.baseUrl}${item.posters}';

    return Stack(
      children: [
        // Background Backdrop with Gradient
        if (backdropUrl.isNotEmpty)
          Positioned.fill(
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: backdropUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.8),
                        FluentTheme.of(context).scaffoldBackgroundColor,
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Main Content
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 100, 48, 48),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Poster
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: posterUrl,
                        width: 240,
                        height: 360,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 48),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: FluentTheme.of(context).typography.titleLarge?.copyWith(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (item.originalTitle != null && item.originalTitle != item.title)
                            Text(
                              item.originalTitle!,
                              style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                                fontSize: 24,
                                color: FluentTheme.of(context).typography.bodyStrong?.color?.withOpacity(0.7),
                              ),
                            ),
                          const SizedBox(height: 24),
                          _buildMetadataRow(context, item),
                          const SizedBox(height: 16),
                          if (item.watchedTs > 0)
                            _ProgressBar(
                              watchedTs: item.watchedTs,
                              totalDuration: widget.state.streamList?.videoStreams.firstOrNull?.duration ?? 0,
                            ),
                          const SizedBox(height: 32),
                          _buildActionRow(context, item),
                          const SizedBox(height: 48),
                          if (widget.state.streamList != null && widget.state.streamList!.videoStreams.length > 1)
                            _MediaSourceBoxes(
                              videoStreams: widget.state.streamList!.videoStreams,
                              selectedIndex: _selectedVideoStreamIndex,
                              onChanged: (index) => setState(() => _selectedVideoStreamIndex = index),
                            ),
                          const SizedBox(height: 24),
                          Text(
                            '概览',
                            style: FluentTheme.of(context).typography.subtitle?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _showDescriptionDialog(context, item),
                            child: Text(
                              item.overview ?? '暂无介绍',
                              style: FluentTheme.of(context).typography.body?.copyWith(
                                fontSize: 16,
                                height: 1.6,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Cast list
            if (widget.state.personList.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '演职员',
                        style: FluentTheme.of(context).typography.subtitle?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 240,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.state.personList.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 24),
                          itemBuilder: (context, index) {
                            final person = widget.state.personList[index];
                            return _PersonCard(person: person, baseUrl: widget.baseUrl);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Media Info
            if (widget.state.streamList != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(48, 24, 48, 48),
                  child: _MediaInfoSection(
                    state: widget.state,
                    selectedVideoStreamIndex: _selectedVideoStreamIndex,
                  ),
                ),
              ),
          ],
        ),

        // Back Button
        Positioned(
          top: 32,
          left: 32,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(FluentIcons.back, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ],
    );
  }

  void _showDescriptionDialog(BuildContext context, ItemResponse item) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('电影简介'),
        content: Scrollbar(
          child: SingleChildScrollView(
            child: Text(
              item.overview ?? '暂无介绍',
              style: FluentTheme.of(context).typography.body?.copyWith(height: 1.6),
            ),
          ),
        ),
        actions: [
          Button(
            child: const Text('关闭'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context, ItemResponse item) {
    final List<Widget> meta = [];
    if (item.releaseDate != null && item.releaseDate!.length >= 4) {
      meta.add(_MetadataItem(text: item.releaseDate!.substring(0, 4)));
    }
    if (item.duration > 0) {
      meta.add(_MetadataItem(text: FnDataConvertor.formatSecondsToCNDateTime(item.duration)));
    }
    if (item.voteAverage != "0") {
      meta.add(_MetadataItem(text: '⭐ ${item.voteAverage}', color: Colors.orange));
    }
    if (item.genres != null && item.genres!.isNotEmpty) {
      meta.add(_MetadataItem(text: item.genres!.join(' / ')));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: meta,
    );
  }

  Widget _buildActionRow(BuildContext context, ItemResponse item) {
    final videoStreams = widget.state.streamList?.videoStreams ?? [];
    final currentMediaGuid = videoStreams.isNotEmpty && _selectedVideoStreamIndex < videoStreams.length
        ? videoStreams[_selectedVideoStreamIndex].mediaGuid
        : '';

    final audioStreams = (widget.state.streamList?.audioStreams ?? [])
        .where((s) => s.mediaGuid == currentMediaGuid)
        .toList();
    final subtitleStreams = (widget.state.streamList?.subtitleStreams ?? [])
        .where((s) => s.mediaGuid == currentMediaGuid)
        .toList();

    return Row(
      children: [
        FilledButton(
          onPressed: () async {
            final dioClient = ref.read(dioClientProvider);
            final prefsManager = ref.read(preferencesManagerProvider);
            final baseUrl = prefsManager.getBaseUrl() ?? '';
            
            // Replicate KMP's play URL logic
            // KMP uses play_url = baseUrl + "/v/api/v1/play/video?guid=" + guid + "&media_guid=" + mediaGuid
            // + "&audio_guid=" + audioGuid + "&subtitle_guid=" + subtitleGuid
            final audioGuid = _selectedAudioGuid ?? '';
            final subtitleGuid = _selectedSubtitleGuid ?? '';
            
            final playUrl = '$baseUrl/v/api/v1/play/video?guid=${widget.guid}&media_guid=$currentMediaGuid'
                '&audio_guid=$audioGuid&subtitle_guid=$subtitleGuid';
            
            // For now, since we don't have a dedicated player widget, 
            // we'll try to open it in an external player or browser
            final uri = Uri.parse(playUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => ContentDialog(
                    title: const Text('播放失败'),
                    content: const Text('无法启动外部播放器，请检查网络连接或播放地址。'),
                    actions: [
                      Button(
                        child: const Text('确定'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                );
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                const Icon(FluentIcons.play, size: 20),
                const SizedBox(width: 12),
                Text(
                  item.watchedTs > 0 ? '继续播放' : '立即播放',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        _CircleButton(
          icon: item.isFavorite == 1 ? FluentIcons.heart_fill : FluentIcons.heart,
          color: item.isFavorite == 1 ? Colors.red : null,
          tooltip: item.isFavorite == 1 ? '取消收藏' : '加入收藏',
          onPressed: () => ref.read(movieDetailNotifierProvider(widget.guid).notifier).toggleFavorite(),
        ),
        const SizedBox(width: 12),
        _CircleButton(
          icon: item.isWatched == 1 ? FluentIcons.check_mark : FluentIcons.check_mark,
          color: item.isWatched == 1 ? FluentTheme.of(context).accentColor : null,
          tooltip: item.isWatched == 1 ? '标记为未看' : '标记为已看',
          onPressed: () => ref.read(movieDetailNotifierProvider(widget.guid).notifier).toggleWatched(),
        ),
        const SizedBox(width: 12),
        _CircleButton(
          icon: FluentIcons.more,
          tooltip: '更多操作',
          onPressed: () {
            // TODO: More options
          },
        ),
        const Spacer(),
        if (audioStreams.isNotEmpty) ...[
          _StreamSelector<AudioStream>(
            items: audioStreams,
            selectedGuid: _selectedAudioGuid,
            onChanged: (guid) => setState(() => _selectedAudioGuid = guid),
            labelBuilder: (s) => FnDataConvertor.getLanguageName(s.language, widget.state.iso6391, widget.state.iso6392),
            icon: FluentIcons.volume0,
          ),
          const SizedBox(width: 12),
        ],
        if (subtitleStreams.isNotEmpty) ...[
          _StreamSelector<SubtitleStream>(
            items: subtitleStreams,
            selectedGuid: _selectedSubtitleGuid,
            onChanged: (guid) => setState(() => _selectedSubtitleGuid = guid),
            labelBuilder: (s) => FnDataConvertor.getLanguageName(s.language, widget.state.iso6391, widget.state.iso6392),
            icon: FluentIcons.reading_mode,
            allowNone: true,
          ),
        ],
      ],
    );
  }
}

class _StreamSelector<T extends dynamic> extends StatelessWidget {
  final List<T> items;
  final String? selectedGuid;
  final ValueChanged<String?> onChanged;
  final String Function(T) labelBuilder;
  final IconData icon;
  final bool allowNone;

  const _StreamSelector({
    required this.items,
    this.selectedGuid,
    required this.onChanged,
    required this.labelBuilder,
    required this.icon,
    this.allowNone = false,
  });

  @override
  Widget build(BuildContext context) {
    final options = items.map((item) {
      return ComboBoxItem<String>(
        value: item.guid,
        child: Text(labelBuilder(item)),
      );
    }).toList();

    if (allowNone) {
      options.insert(0, const ComboBoxItem<String>(
        value: '_no_display_',
        child: Text('无'),
      ));
    }

    return ComboBox<String>(
      value: selectedGuid,
      items: options,
      onChanged: onChanged,
      placeholder: Icon(icon, size: 16),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String tooltip;
  final VoidCallback onPressed;

  const _CircleButton({
    required this.icon,
    this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(icon, color: color, size: 20),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int watchedTs;
  final int totalDuration;

  const _ProgressBar({required this.watchedTs, required this.totalDuration});

  @override
  Widget build(BuildContext context) {
    if (totalDuration <= 0) return const SizedBox.shrink();
    final progress = (watchedTs / totalDuration).clamp(0.0, 1.0);
    final remaining = totalDuration - watchedTs;

    return Row(
      children: [
        SizedBox(
          width: 300,
          child: ProgressBar(
            value: progress * 100,
            backgroundColor: Colors.white.withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '剩余 ${FnDataConvertor.formatSecondsToCNDateTime(remaining)}',
          style: FluentTheme.of(context).typography.caption?.copyWith(
            color: FluentTheme.of(context).typography.caption?.color?.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

class _MediaSourceBoxes extends StatelessWidget {
  final List<VideoStream> videoStreams;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _MediaSourceBoxes({
    required this.videoStreams,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(videoStreams.length, (index) {
        final stream = videoStreams[index];
        final isSelected = index == selectedIndex;
        final label = '${stream.resolutionType.toUpperCase()} ${stream.colorRangeType == 'DolbyVision' ? '杜比视界' : stream.colorRangeType}';
        
        return Button(
          style: ButtonStyle(
            backgroundColor: isSelected ? ButtonState.all(FluentTheme.of(context).accentColor) : null,
          ),
          onPressed: () => onChanged(index),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : null,
              fontWeight: isSelected ? FontWeight.bold : null,
            ),
          ),
        );
      }),
    );
  }
}

class _MetadataItem extends StatelessWidget {
  final String text;
  final Color? color;

  const _MetadataItem({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: FluentTheme.of(context).typography.caption?.copyWith(
          fontSize: 14,
          color: color,
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final PersonList person;
  final String baseUrl;

  const _PersonCard({required this.person, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    final imageUrl = person.profilePath.isNotEmpty ? '$baseUrl${person.profilePath}' : '';
    
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 120,
                    height: 180,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 120,
                    height: 180,
                    color: Colors.grey[160],
                    child: const Icon(FluentIcons.contact, size: 48),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            person.name,
            style: FluentTheme.of(context).typography.bodyStrong?.copyWith(fontSize: 14),
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            person.job == 'Actor' ? '饰 ${person.role}' : person.job,
            style: FluentTheme.of(context).typography.caption?.copyWith(
              fontSize: 12,
              color: FluentTheme.of(context).typography.caption?.color?.withOpacity(0.6),
            ),
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MediaInfoSection extends StatelessWidget {
  final MovieDetailState state;
  final int selectedVideoStreamIndex;

  const _MediaInfoSection({required this.state, required this.selectedVideoStreamIndex});

  @override
  Widget build(BuildContext context) {
    final videoStreams = state.streamList?.videoStreams ?? [];
    final currentMediaGuid = videoStreams.isNotEmpty && selectedVideoStreamIndex < videoStreams.length
        ? videoStreams[selectedVideoStreamIndex].mediaGuid
        : '';

    final videoStream = videoStreams.isNotEmpty && selectedVideoStreamIndex < videoStreams.length
        ? videoStreams[selectedVideoStreamIndex]
        : null;
    final fileInfo = (state.streamList?.files ?? []).firstWhere(
      (f) => f.guid == currentMediaGuid,
      orElse: () => FileInfo(
        guid: '',
        path: '',
        fileName: '',
        size: 0,
        timestamp: 0,
        type: 0,
        canPlay: 0,
        playError: '',
        createTime: 0,
        updateTime: 0,
        fileBirthTime: 0,
        progressThumbHashDir: '',
      ),
    );
    final audioStream = (state.streamList?.audioStreams ?? []).firstWhere(
      (s) => s.mediaGuid == currentMediaGuid && s.isDefault == 1,
      orElse: () => (state.streamList?.audioStreams ?? []).firstWhere(
        (s) => s.mediaGuid == currentMediaGuid,
        orElse: () => AudioStream(
          guid: '',
          mediaGuid: '',
          title: '',
          audioType: '',
          codecName: '',
          codecType: '',
          language: '',
          channels: 0,
          profile: '',
          sampleRate: '',
          isDefault: 0,
          channelLayout: '',
          duration: 0,
          index: 0,
          bitsPerRawSample: '',
          bps: 0,
          createTime: 0,
          updateTime: 0,
          isFake: false,
        ),
      ),
    );
    final subtitleStream = (state.streamList?.subtitleStreams ?? []).firstWhere(
      (s) => s.mediaGuid == currentMediaGuid && s.isDefault == 1,
      orElse: () => (state.streamList?.subtitleStreams ?? []).firstWhere(
        (s) => s.mediaGuid == currentMediaGuid,
        orElse: () => SubtitleStream(
          guid: '',
          mediaGuid: '',
          title: '',
          codecName: '',
          codecType: '',
          language: '',
          forced: 0,
          index: 0,
          isDefault: 0,
          isExternal: 0,
          format: '',
          trimId: '',
          sourceId: '',
          source: '',
          createTime: 0,
          updateTime: 0,
          extraFile: 0,
          isBitmap: 0,
          fileSize: 0,
        ),
      ),
    );

    final iso6391Map = {for (var tag in state.iso6391) tag.key: tag.value};
    
    final mediaDetails = FnDataConvertor.convertToMediaDetails(
      fileInfo: fileInfo.guid.isNotEmpty ? fileInfo : null,
      videoStream: videoStream,
      audioStream: audioStream.guid.isNotEmpty ? audioStream : null,
      subtitleStream: subtitleStream.guid.isNotEmpty ? subtitleStream : null,
      imdbId: state.item?.imdbId,
      iso6391Map: iso6391Map,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '媒体信息',
          style: FluentTheme.of(context).typography.subtitle?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        
        // File Info Section
        _InfoSection(
          title: '文件信息',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(label: '文件位置', value: mediaDetails.fileInfo.location),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _InfoRow(label: '文件大小', value: mediaDetails.fileInfo.size)),
                  Expanded(child: _InfoRow(label: '创建日期', value: mediaDetails.fileInfo.createdDate)),
                  Expanded(child: _InfoRow(label: '添加日期', value: mediaDetails.fileInfo.addedDate)),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Video/Audio Info Section
        _InfoSection(
          title: '视频/音频信息',
          child: Row(
            children: [
              Expanded(child: _TrackItem(info: mediaDetails.videoTrack)),
              Expanded(child: _TrackItem(info: mediaDetails.audioTrack)),
              Expanded(child: _TrackItem(info: mediaDetails.subtitleTrack)),
            ],
          ),
        ),
        
        if (mediaDetails.imdbLink.isNotEmpty) ...[
          const SizedBox(height: 24),
          HyperlinkButton(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('在 IMDb 上查看'),
                const SizedBox(width: 8),
                const Icon(FluentIcons.open_in_new_window, size: 12),
              ],
            ),
            onPressed: () => launchUrl(Uri.parse(mediaDetails.imdbLink)),
          ),
        ],
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: FluentTheme.of(context).typography.bodyStrong?.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FluentTheme.of(context).typography.caption?.copyWith(
            color: FluentTheme.of(context).typography.caption?.color?.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: FluentTheme.of(context).typography.body),
      ],
    );
  }
}

class _TrackItem extends StatelessWidget {
  final MediaTrackInfo info;

  const _TrackItem({required this.info});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(info.icon, size: 24, color: FluentTheme.of(context).accentColor),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(info.type, style: FluentTheme.of(context).typography.bodyStrong),
              const SizedBox(height: 4),
              Text(
                info.details.isNotEmpty ? info.details : '暂无信息',
                style: FluentTheme.of(context).typography.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
