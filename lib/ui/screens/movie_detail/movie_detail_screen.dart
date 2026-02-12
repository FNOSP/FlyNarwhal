import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'movie_detail_view_model.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../data/utils/fn_data_convertor.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' as cache_manager;
import '../../../providers/providers.dart';
import 'detail_components.dart';

String _buildImageUrl(String baseUrl, String path) {
  if (baseUrl.isEmpty || path.isEmpty) return '';
  final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  return '$normalizedBaseUrl/v/api/v1/sys/img$path';
}

class MovieDetailScreen extends ConsumerWidget {
  final String guid;

  const MovieDetailScreen({super.key, required this.guid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(movieDetailNotifierProvider(guid));
    final prefsManager = ref.watch(preferencesManagerProvider);
    final baseUrl = prefsManager.getBaseUrl() ?? '';
    final token = prefsManager.getToken();
    final cookie = prefsManager.getCookie();
    final httpHeaders = token != null || (cookie != null && cookie.isNotEmpty)
        ? {
            if (token != null) 'Authorization': token,
            if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
          }
        : null;
    final cacheManager = ref.watch(imageCacheManagerProvider);

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: detailState.when(
        data: (state) => _MovieDetailContent(
          state: state,
          baseUrl: baseUrl,
          guid: guid,
          httpHeaders: httpHeaders,
          cacheManager: cacheManager,
        ),
        loading: () => const Center(child: ProgressRing()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('加载失败: $error'),
              const SizedBox(height: 16),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Button(
                  child: const Text('重试'),
                  onPressed: () => ref.read(movieDetailNotifierProvider(guid).notifier).refresh(),
                ),
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
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;

  const _MovieDetailContent({
    required this.state,
    required this.baseUrl,
    required this.guid,
    required this.httpHeaders,
    required this.cacheManager,
  });

  @override
  ConsumerState<_MovieDetailContent> createState() => _MovieDetailContentState();
}

class _MovieDetailContentState extends ConsumerState<_MovieDetailContent> {
  int _selectedVideoStreamIndex = 0;
  String _currentMediaGuid = '';
  
  String? _selectedAudioGuid;
  String? _selectedSubtitleGuid;
  
  // Maps to track selection per media guid
  final Map<String, String> _mediaGuidAudioGuidMap = {};
  final Map<String, String> _mediaGuidSubtitleGuidMap = {};

  @override
  void initState() {
    super.initState();
    _initializeSelection();
  }

  @override
  void didUpdateWidget(covariant _MovieDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _initializeSelection();
    }
  }

  void _initializeSelection() {
    final playInfo = widget.state.playInfo;
    final streamList = widget.state.streamList;

    if (playInfo == null || streamList == null) return;

    // Initialize maps based on PlayInfo or Defaults
    for (var audio in streamList.audioStreams) {
      if (audio.guid == playInfo.audioGuid) {
        _mediaGuidAudioGuidMap[audio.mediaGuid] = audio.guid;
      } else if (audio.isDefault == 1 && !_mediaGuidAudioGuidMap.containsKey(audio.mediaGuid)) {
        _mediaGuidAudioGuidMap[audio.mediaGuid] = audio.guid;
      }
    }

    for (var subtitle in streamList.subtitleStreams) {
      if (playInfo.subtitleGuid == '_no_display_') {
        _mediaGuidSubtitleGuidMap[subtitle.mediaGuid] = '_no_display_';
      } else if (subtitle.guid == playInfo.subtitleGuid) {
        _mediaGuidSubtitleGuidMap[subtitle.mediaGuid] = subtitle.guid;
      } else if (subtitle.isDefault == 1 && !_mediaGuidSubtitleGuidMap.containsKey(subtitle.mediaGuid)) {
        _mediaGuidSubtitleGuidMap[subtitle.mediaGuid] = subtitle.guid;
      }
    }

    // Set initial media guid
    if (_currentMediaGuid.isEmpty) {
      _currentMediaGuid = playInfo.mediaGuid;
    }

    // Update index based on current media guid
    final index = streamList.videoStreams.indexWhere((s) => s.mediaGuid == _currentMediaGuid);
    if (index != -1) {
      _selectedVideoStreamIndex = index;
    } else if (streamList.videoStreams.isNotEmpty) {
      _selectedVideoStreamIndex = 0;
      _currentMediaGuid = streamList.videoStreams[0].mediaGuid;
    }

    _updateCurrentStreamSelections();
  }

  void _updateCurrentStreamSelections() {
    _selectedAudioGuid = _mediaGuidAudioGuidMap[_currentMediaGuid];
    _selectedSubtitleGuid = _mediaGuidSubtitleGuidMap[_currentMediaGuid];

    // Fallbacks if not in map
    if (_selectedAudioGuid == null) {
      final audios = widget.state.streamList?.audioStreams.where((s) => s.mediaGuid == _currentMediaGuid).toList() ?? [];
      if (audios.isNotEmpty) {
        _selectedAudioGuid = audios.firstWhere((s) => s.isDefault == 1, orElse: () => audios.first).guid;
        _mediaGuidAudioGuidMap[_currentMediaGuid] = _selectedAudioGuid!;
      }
    }

    if (_selectedSubtitleGuid == null) {
      final subtitles = widget.state.streamList?.subtitleStreams.where((s) => s.mediaGuid == _currentMediaGuid).toList() ?? [];
      if (subtitles.isNotEmpty) {
         // Check if we should default to none or first default
         // Logic: if playInfo said no_display, we should have caught it. 
         // Here we just pick a default if map is empty.
         final defaultSub = subtitles.firstWhere((s) => s.isDefault == 1, orElse: () => subtitles.first);
         _selectedSubtitleGuid = defaultSub.guid;
         _mediaGuidSubtitleGuidMap[_currentMediaGuid] = _selectedSubtitleGuid!;
      } else {
        _selectedSubtitleGuid = '_no_display_';
        _mediaGuidSubtitleGuidMap[_currentMediaGuid] = '_no_display_';
      }
    }
  }

  void _onVideoStreamSelected(int index) {
    setState(() {
      _selectedVideoStreamIndex = index;
      if (widget.state.streamList != null && widget.state.streamList!.videoStreams.length > index) {
        _currentMediaGuid = widget.state.streamList!.videoStreams[index].mediaGuid;
        _updateCurrentStreamSelections();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.state.item;
    if (item == null) return const Center(child: Text('未找到电影信息'));

    final windowHeight = MediaQuery.of(context).size.height;
    final backdropPath = (item.backdrops?.isNotEmpty ?? false) ? item.backdrops! : item.posters;
    final backdropUrl = _buildImageUrl(widget.baseUrl, backdropPath);
    final logoUrl = item.logos != null ? _buildImageUrl(widget.baseUrl, item.logos!) : '';

    final iso3166Map = {for (var tag in widget.state.iso3166) tag.key: tag.value};

    // Calculate total duration for progress bar
    final totalDuration = widget.state.streamList?.videoStreams.elementAtOrNull(_selectedVideoStreamIndex)?.duration ?? 0;
    final formatedTotalDuration = FnDataConvertor.formatSecondsToCNDateTime(totalDuration);

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: windowHeight * 0.5,
                child: Stack(
                  children: [
                    if (backdropUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: backdropUrl,
                        httpHeaders: widget.httpHeaders,
                        cacheManager: widget.cacheManager,
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
                            Colors.transparent,
                            FluentTheme.of(context).scaffoldBackgroundColor,
                          ],
                          stops: const [0.45, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 48,
                      bottom: 0, // Adjusted to match KMP logic which aligns bottom start with padding
                      right: 48,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 0), // Adjust padding if needed
                        child: logoUrl.isNotEmpty
                            ? _LogoTitle(
                                url: logoUrl,
                                title: item.title,
                                httpHeaders: widget.httpHeaders,
                                cacheManager: widget.cacheManager,
                              )
                            : Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: FluentTheme.of(context).typography.titleLarge?.copyWith(
                                  fontSize: 60,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     // Progress Bar
                    if (item.watchedTs > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _ProgressBar(
                          watchedTs: item.watchedTs,
                          totalDuration: totalDuration,
                        ),
                      ),

                    // Controls Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Actions
                        Row(
                          children: [
                            DetailPlayButton(
                              text: item.watchedTs > 0 ? '继续播放' : '播放',
                              onPressed: _playMedia,
                            ),
                            const SizedBox(width: 16),
                            CircleIconButton(
                              icon: item.isFavorite == 1 ? FluentIcons.heart_fill : FluentIcons.heart,
                              iconColor: item.isFavorite == 1 ? Colors.red : null,
                              tooltip: item.isFavorite == 1 ? '取消收藏' : '加入收藏',
                              onPressed: () => ref.read(movieDetailNotifierProvider(widget.guid).notifier).toggleFavorite(),
                            ),
                            const SizedBox(width: 16),
                            CircleIconButton(
                              icon: item.isWatched == 1 ? FluentIcons.check_mark : FluentIcons.check_mark,
                              iconColor: item.isWatched == 1 ? FluentTheme.of(context).accentColor : null,
                              tooltip: item.isWatched == 1 ? '标记为未看' : '标记为已看',
                              onPressed: () => ref.read(movieDetailNotifierProvider(widget.guid).notifier).toggleWatched(),
                            ),
                            const SizedBox(width: 16),
                            CircleIconButton(
                              icon: FluentIcons.more,
                              tooltip: '更多操作',
                              onPressed: () {},
                            ),
                          ],
                        ),
                        
                        // Right: Tags
                        Flexible(
                          child: DetailTags(
                            item: item,
                            formatedTotalDuration: formatedTotalDuration,
                            iso3166Map: iso3166Map,
                            genresMap: widget.state.genres,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Quality Tags & Selectors
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (widget.state.streamList != null) ...[
                          StreamSelector<String>(
                             placeholder: '字幕',
                             selectedValue: _selectedSubtitleGuid,
                             items: [
                               StreamOptionItem(label: '无', value: '_no_display_'),
                               ...(widget.state.streamList!.subtitleStreams
                                  .where((s) => s.mediaGuid == _currentMediaGuid)
                                  .map((s) {
                                    final lang = FnDataConvertor.getLanguageName(s.language, widget.state.iso6391, widget.state.iso6392);
                                    final label = s.isExternal == 1 ? '$lang - 外挂' : lang;
                                    return StreamOptionItem(label: label, value: s.guid);
                                  })),
                             ],
                             onChanged: (val) {
                               setState(() {
                                 _selectedSubtitleGuid = val;
                                 _mediaGuidSubtitleGuidMap[_currentMediaGuid] = val;
                               });
                             },
                          ),
                          const SizedBox(width: 12),
                          StreamSelector<String>(
                             placeholder: '音频',
                             selectedValue: _selectedAudioGuid,
                             items: widget.state.streamList!.audioStreams
                                .where((s) => s.mediaGuid == _currentMediaGuid)
                                .map((s) {
                                  final lang = FnDataConvertor.getLanguageName(s.language, widget.state.iso6391, widget.state.iso6392);
                                  return StreamOptionItem(label: lang, value: s.guid);
                                }).toList(),
                             onChanged: (val) {
                               setState(() {
                                 _selectedAudioGuid = val;
                                 _mediaGuidAudioGuidMap[_currentMediaGuid] = val;
                               });
                             },
                          ),
                          const SizedBox(width: 12),
                          // Quality Tags
                          if (widget.state.streamList!.videoStreams.isNotEmpty && _selectedVideoStreamIndex < widget.state.streamList!.videoStreams.length) ...[
                             MediaQualityTag(text: widget.state.streamList!.videoStreams[_selectedVideoStreamIndex].resolutionType.toUpperCase()),
                             const SizedBox(width: 8),
                             if (widget.state.streamList!.videoStreams[_selectedVideoStreamIndex].colorRangeType == 'DolbyVision')
                                const MediaQualityTag(text: '杜比视界')
                             else 
                                MediaQualityTag(text: widget.state.streamList!.videoStreams[_selectedVideoStreamIndex].colorRangeType),
                          ],
                          const SizedBox(width: 8),
                           // Audio Type Tag
                          Builder(builder: (context) {
                             final audio = widget.state.streamList!.audioStreams.where((s) => s.guid == _selectedAudioGuid).firstOrNull;
                             return MediaQualityTag(text: audio?.audioType ?? '');
                          }),
                        ],
                      ],
                    ),

                    // Video Stream Source Boxes
                    if (widget.state.streamList != null && widget.state.streamList!.videoStreams.length > 1) ...[
                      const SizedBox(height: 16),
                      _MediaSourceBoxes(
                        videoStreams: widget.state.streamList!.videoStreams,
                        selectedIndex: _selectedVideoStreamIndex,
                        onChanged: _onVideoStreamSelected,
                      ),
                    ],

                    // Overview
                    if (item.overview != null && item.overview!.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      MediaDescription(
                        overview: item.overview!,
                        onMore: () => showDialog(
                          context: context,
                          builder: (_) => MediaDescriptionDialog(title: '电影简介', content: item.overview!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Cast List
            if (widget.state.personList.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Text('演职员', style: FluentTheme.of(context).typography.subtitle), // Optional Header
                      // const SizedBox(height: 16),
                      SizedBox(
                        height: 240,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          itemCount: widget.state.personList.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 24),
                          itemBuilder: (context, index) {
                            final person = widget.state.personList[index];
                            return _PersonCard(
                              person: person,
                              baseUrl: widget.baseUrl,
                              httpHeaders: widget.httpHeaders,
                              cacheManager: widget.cacheManager,
                            );
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
                    currentMediaGuid: _currentMediaGuid,
                    currentAudioGuid: _selectedAudioGuid,
                    currentSubtitleGuid: _selectedSubtitleGuid,
                  ),
                ),
              ),
          ],
        ),
        
        // Back Button
        Positioned(
          top: 20,
          left: 20,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: IconButton(
              icon: const Icon(FluentIcons.back, size: 24, color: Colors.white),
              onPressed: () => Navigator.pop(context),
              style: ButtonStyle(
                backgroundColor: ButtonState.all(Colors.black.withOpacity(0.5)),
                shape: ButtonState.all(const CircleBorder()),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _playMedia() async {
    final prefsManager = ref.read(preferencesManagerProvider);
    final baseUrl = prefsManager.getBaseUrl() ?? '';
    
    final audioGuid = _selectedAudioGuid ?? '';
    final subtitleGuid = _selectedSubtitleGuid ?? '';
    
    final playUrl = '$baseUrl/v/api/v1/play/video?guid=${widget.guid}&media_guid=$_currentMediaGuid'
        '&audio_guid=$audioGuid&subtitle_guid=$subtitleGuid';
    
    final uri = Uri.parse(playUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
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
  }
}

class _LogoTitle extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;

  const _LogoTitle({
    required this.url,
    required this.title,
    required this.httpHeaders,
    required this.cacheManager,
  });

  @override
  State<_LogoTitle> createState() => _LogoTitleState();
}

class _LogoTitleState extends State<_LogoTitle> {
  double _height = 90.0;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
  }

  @override
  void didUpdateWidget(covariant _LogoTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resolveImageSize();
    }
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  void _resolveImageSize() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    final provider = CachedNetworkImageProvider(
      widget.url,
      headers: widget.httpHeaders,
      cacheManager: widget.cacheManager,
    );
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      final width = info.image.width.toDouble();
      final height = info.image.height.toDouble();
      final actualWidth = height > 0 ? width / height * 90 : 0;
      final nextHeight = actualWidth > 0 && actualWidth < 280 ? 150.0 : 90.0;
      if (mounted) {
        setState(() => _height = nextHeight);
      }
    });
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: widget.url,
      httpHeaders: widget.httpHeaders,
      cacheManager: widget.cacheManager,
      height: _height,
      fit: BoxFit.fitHeight,
      errorWidget: (context, url, error) => Text(
        widget.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: FluentTheme.of(context).typography.titleLarge?.copyWith(
          fontSize: 60,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.1,
        ),
      ),
      placeholder: (context, url) => const SizedBox(
        height: 90,
        child: ProgressRing(),
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
        
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Button(
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
          ),
        );
      }),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final PersonList person;
  final String baseUrl;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;

  const _PersonCard({
    required this.person,
    required this.baseUrl,
    required this.httpHeaders,
    required this.cacheManager,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = _buildImageUrl(baseUrl, person.profilePath);
    
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    httpHeaders: httpHeaders,
                    cacheManager: cacheManager,
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
  final String currentMediaGuid;
  final String? currentAudioGuid;
  final String? currentSubtitleGuid;

  const _MediaInfoSection({
    required this.state,
    required this.selectedVideoStreamIndex,
    required this.currentMediaGuid,
    this.currentAudioGuid,
    this.currentSubtitleGuid,
  });

  @override
  Widget build(BuildContext context) {
    final videoStreams = state.streamList?.videoStreams ?? [];
    
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
      (s) => s.guid == currentAudioGuid,
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
    );
    
    final subtitleStream = (state.streamList?.subtitleStreams ?? []).firstWhere(
      (s) => s.guid == currentSubtitleGuid,
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
          ImdbLink(imdbId: state.item?.imdbId ?? ''),
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
