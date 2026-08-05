import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'movie_detail_view_model.dart';
import '../../../core/utils/log/app_talker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_result.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../data/utils/fn_data_convertor.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    as cache_manager;
import '../../../providers/global_refresh.dart';
import '../../../providers/providers.dart';
import '../../../providers/file_providers.dart';
import '../../shared/common/fn_cached_image.dart';
import 'detail_components.dart';
import '../../shared/common/img_loading_progress_ring.dart';
import '../../shared/nas/add_nas_subtitle_dialog.dart';
import '../../shared/cast_scroll_row.dart';
import '../../shared/toast.dart';

String _buildImageUrl(String baseUrl, String path) {
  final trimmedPath = path.trim();
  if (baseUrl.isEmpty || trimmedPath.isEmpty) return '';

  final lowerPath = trimmedPath.toLowerCase();
  if (lowerPath.startsWith('http://') || lowerPath.startsWith('https://')) {
    return trimmedPath;
  }

  final normalizedBaseUrl = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;

  if (trimmedPath.startsWith('/v/api/v1/sys/img')) {
    return '$normalizedBaseUrl$trimmedPath';
  }
  if (trimmedPath.startsWith('v/api/v1/sys/img')) {
    return '$normalizedBaseUrl/$trimmedPath';
  }

  final normalizedPath =
      trimmedPath.startsWith('/') ? trimmedPath : '/$trimmedPath';
  return '$normalizedBaseUrl/v/api/v1/sys/img$normalizedPath';
}

String _formatAudioTypeLabel(String audioType) {
  return switch (audioType.trim().toLowerCase()) {
    'stereo' => '立体声',
    _ => audioType,
  };
}

class MovieDetailScreen extends ConsumerWidget {
  final String guid;

  const MovieDetailScreen({super.key, required this.guid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Consume each global refresh request once for the current detail page.
    ref.listen<GlobalRefreshRequest?>(
      currentGlobalRefreshRequestProvider,
      (_, next) {
        unawaited(
          ref.read(globalRefreshManagerProvider).handleRefresh(
                consumerId: 'movie-detail:$guid',
                request: next,
                onRefresh: () => ref
                    .read(movieDetailNotifierProvider(guid).notifier)
                    .refresh(),
              ),
        );
      },
    );
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

    final theme = FluentTheme.of(context);
    final scaffoldBackgroundColor = theme.brightness == Brightness.dark
        ? const Color(0xFF282828)
        : theme.scaffoldBackgroundColor;

    return FluentTheme(
        data: theme.copyWith(scaffoldBackgroundColor: scaffoldBackgroundColor),
        child: ScaffoldPage(
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
                      onPressed: () => ref
                          .read(movieDetailNotifierProvider(guid).notifier)
                          .refresh(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
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
  ConsumerState<_MovieDetailContent> createState() =>
      _MovieDetailContentState();
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

    if (streamList == null) return;

    _mediaGuidAudioGuidMap.clear();
    _mediaGuidSubtitleGuidMap.clear();

    final playInfoAudioGuid = playInfo?.audioGuid;
    final playInfoSubtitleGuid = playInfo?.subtitleGuid;

    for (var audio in streamList.audioStreams) {
      if (playInfoAudioGuid != null &&
          playInfoAudioGuid.isNotEmpty &&
          audio.guid == playInfoAudioGuid) {
        _mediaGuidAudioGuidMap[audio.mediaGuid] = audio.guid;
      } else if (audio.isDefault == 1 &&
          !_mediaGuidAudioGuidMap.containsKey(audio.mediaGuid)) {
        _mediaGuidAudioGuidMap[audio.mediaGuid] = audio.guid;
      }
    }

    for (var subtitle in streamList.subtitleStreams) {
      if (playInfoSubtitleGuid == '_no_display_') {
        _mediaGuidSubtitleGuidMap[subtitle.mediaGuid] = '_no_display_';
      } else if (playInfoSubtitleGuid != null &&
          playInfoSubtitleGuid.isNotEmpty &&
          subtitle.guid == playInfoSubtitleGuid) {
        _mediaGuidSubtitleGuidMap[subtitle.mediaGuid] = subtitle.guid;
      } else if (subtitle.isDefault == 1 &&
          !_mediaGuidSubtitleGuidMap.containsKey(subtitle.mediaGuid)) {
        _mediaGuidSubtitleGuidMap[subtitle.mediaGuid] = subtitle.guid;
      }
    }

    if (playInfo?.mediaGuid != null && playInfo!.mediaGuid.isNotEmpty) {
      _currentMediaGuid = playInfo.mediaGuid;
    } else if (streamList.videoStreams.isNotEmpty) {
      _currentMediaGuid = streamList.videoStreams[0].mediaGuid;
    }

    final index = streamList.videoStreams
        .indexWhere((s) => s.mediaGuid == _currentMediaGuid);
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

    if (_selectedAudioGuid == null) {
      final audios = widget.state.streamList?.audioStreams
              .where((s) => s.mediaGuid == _currentMediaGuid)
              .toList() ??
          [];
      if (audios.isNotEmpty) {
        _selectedAudioGuid = audios
            .firstWhere((s) => s.isDefault == 1, orElse: () => audios.first)
            .guid;
        _mediaGuidAudioGuidMap[_currentMediaGuid] = _selectedAudioGuid!;
      }
    }

    if (_selectedSubtitleGuid == null) {
      final subtitles = widget.state.streamList?.subtitleStreams
              .where((s) => s.mediaGuid == _currentMediaGuid)
              .toList() ??
          [];
      if (subtitles.isNotEmpty) {
        final defaultSub = subtitles.firstWhere((s) => s.isDefault == 1,
            orElse: () => subtitles.first);
        _selectedSubtitleGuid = defaultSub.guid;
        _mediaGuidSubtitleGuidMap[_currentMediaGuid] = _selectedSubtitleGuid!;
      } else {
        _selectedSubtitleGuid = '_no_display_';
        _mediaGuidSubtitleGuidMap[_currentMediaGuid] = '_no_display_';
      }
    }
  }

  String _resolveCurrentFilePath() {
    final files = widget.state.streamList?.files ?? [];
    for (final file in files) {
      if (file.guid == _currentMediaGuid) {
        return file.path;
      }
    }
    if (files.isNotEmpty) {
      return files.first.path;
    }
    return '';
  }

  void _showAddNasSubtitleDialog(String mediaGuid) {
    showDialog(
      context: context,
      builder: (dialogContext) => AddNasSubtitleDialog(
        title: '添加字幕',
        currentPath: _resolveCurrentFilePath(),
        onConfirm: (paths) async {
          try {
            final markResult = await ref
                .read(fileRepositoryProvider)
                .markSubtitle(mediaGuid, paths);
            if (!mounted) return;
            try {
              await ref
                  .read(movieDetailNotifierProvider(widget.guid).notifier)
                  .refresh();
            } catch (error) {
              AppTalker.warning(
                'MovieDetailScreen',
                'refresh after NAS subtitle mark failed: $error',
              );
            }
            if (!mounted) return;
            // Sync the selection to the subtitle registered by the mark API
            // so the next playback starts with it.
            setState(() {
              _mediaGuidSubtitleGuidMap[_currentMediaGuid] = markResult.guid;
              if (_currentMediaGuid == mediaGuid) {
                _selectedSubtitleGuid = markResult.guid;
              }
            });
          } catch (error) {
            if (!mounted) return;
            if (error is FailureInfo &&
                error.code == ResponseCodes.subtitleAlreadyMarked) {
              ref.read(toastManagerProvider.notifier).showToast(
                    '该文件已被添加为字幕',
                    type: ToastType.info,
                    category: 'nas-subtitle:$mediaGuid',
                  );
              return;
            }
            showDialog(
              context: context,
              builder: (errorContext) => ContentDialog(
                title: const Text('添加字幕失败'),
                content: Text('请稍后重试：$error'),
                actions: [
                  Button(
                    child: const Text('确定'),
                    onPressed: () => Navigator.of(errorContext).pop(),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  void _onVideoStreamSelected(int index) {
    setState(() {
      _selectedVideoStreamIndex = index;
      if (widget.state.streamList != null &&
          widget.state.streamList!.videoStreams.length > index) {
        _currentMediaGuid =
            widget.state.streamList!.videoStreams[index].mediaGuid;
        _updateCurrentStreamSelections();
      }
    });
  }

  Future<void> _handleToggleFavorite() async {
    final result = await ref
        .read(movieDetailNotifierProvider(widget.guid).notifier)
        .toggleFavorite();
    if (!mounted) return;
    ref.read(toastManagerProvider.notifier).showToast(
          result.success ? result.message : '操作失败，${result.message}',
          type: result.success ? ToastType.success : ToastType.failed,
          category: 'favorite:${widget.guid}',
        );
  }

  Future<void> _handleToggleWatched() async {
    final result = await ref
        .read(movieDetailNotifierProvider(widget.guid).notifier)
        .toggleWatched();
    if (!mounted) return;
    ref.read(toastManagerProvider.notifier).showToast(
          result.success ? result.message : '操作失败，${result.message}',
          type: result.success ? ToastType.success : ToastType.failed,
          category: 'watched:${widget.guid}',
        );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.state.item;
    if (item == null) return const Center(child: Text('未找到电影信息'));

    final windowHeight = MediaQuery.of(context).size.height;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    // Align backdrop height to an integer number of physical pixels to prevent
    // a 1px seam caused by drawRect (gradient) and drawImageRect (image) using
    // different sub-pixel rounding rules at fractional DPI boundaries.
    final backdropHeight =
        (windowHeight * 0.5 * pixelRatio).roundToDouble() / pixelRatio;
    // Also snap the width so the backdrop Stack has integer-physical-pixel
    // dimensions on both axes, preventing a 1px seam on the left/right edges.
    final backdropWidth =
        (MediaQuery.of(context).size.width * pixelRatio).roundToDouble() /
            pixelRatio;

    final backdropPath =
        (item.backdrops?.isNotEmpty ?? false) ? item.backdrops! : item.posters;
    final backdropUrl = _buildImageUrl(widget.baseUrl, backdropPath);
    final logoUrl =
        item.logos != null ? _buildImageUrl(widget.baseUrl, item.logos!) : '';

    final iso3166Map = widget.state.iso3166;
    final textColor = FluentTheme.of(context).typography.body?.color;
    final resolvedTextColor = textColor ?? Colors.white;
    // Cover the final physical pixels at the moving sliver boundary where
    // fractional scroll offsets can expose the backdrop below the gradient.
    final backdropSeamCoverHeight = 2 / pixelRatio;
    final isFavorite = item.isFavorite == 1;
    final isWatched = item.isWatched == 1;

    // Calculate total duration for progress bar
    final totalDuration = widget.state.streamList?.videoStreams
            .elementAtOrNull(_selectedVideoStreamIndex)
            ?.duration ??
        0;
    final formatedTotalDuration =
        FnDataConvertor.formatSecondsToCNDateTime(totalDuration);

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                width: backdropWidth,
                height: backdropHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (backdropUrl.isNotEmpty)
                      Positioned.fill(
                        child: Image(
                          image: fnCachedImageProvider(ref, backdropUrl),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    Positioned.fill(
                      child: DecoratedBox(
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
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: backdropSeamCoverHeight,
                      child: ColoredBox(
                        color: FluentTheme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(48, 0, 48, 24),
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
                                style: FluentTheme.of(context)
                                    .typography
                                    .titleLarge
                                    ?.copyWith(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
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

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            DetailPlayButton(
                              key: const ValueKey('movie-detail-play'),
                              text: item.watchedTs > 0 ? '继续播放' : '播放',
                              onPressed: _playMedia,
                            ),
                            const SizedBox(width: 16),
                            CircleIconButton(
                              icon: item.isFavorite == 1
                                  ? FluentIcons.heart_fill
                                  : FluentIcons.heart,
                              iconColor: textColor,
                              iconWidget: SvgPicture.asset(
                                isFavorite
                                    ? 'assets/images/favorite_fill.svg'
                                    : 'assets/images/favorite.svg',
                                width: 22,
                                height: 22,
                                colorFilter: ColorFilter.mode(
                                  isFavorite
                                      ? const Color(0xFFFF0420)
                                      : resolvedTextColor,
                                  BlendMode.srcIn,
                                ),
                              ),
                              tooltip: item.isFavorite == 1 ? '取消收藏' : '加入收藏',
                              onPressed: _handleToggleFavorite,
                            ),
                            const SizedBox(width: 16),
                            CircleIconButton(
                              icon: FluentIcons.check_mark,
                              iconColor: isWatched ? kAccentColor : textColor,
                              iconWidget: SvgPicture.asset(
                                item.isWatched == 1
                                    ? 'assets/images/watched_fill.svg'
                                    : 'assets/images/watched.svg',
                                width: 22,
                                height: 22,
                                colorFilter: ColorFilter.mode(
                                  isWatched ? kAccentColor : resolvedTextColor,
                                  BlendMode.srcIn,
                                ),
                              ),
                              tooltip: item.isWatched == 1 ? '标记为未看' : '标记为已看',
                              onPressed: _handleToggleWatched,
                            ),
                            const SizedBox(width: 16),
                            CircleIconButton(
                              icon: FluentIcons.more,
                              tooltip: '更多操作',
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(width: 96),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              DetailTags(
                                item: item,
                                formatedTotalDuration: formatedTotalDuration,
                                iso3166Map: iso3166Map,
                                genresMap: widget.state.genres,
                              ),
                              const SizedBox(height: 8),
                              // Quality Tags & Selectors
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (widget.state.streamList != null) ...[
                                    Builder(builder: (context) {
                                      final subtitleStreams = widget
                                          .state.streamList!.subtitleStreams
                                          .where((s) =>
                                              s.mediaGuid == _currentMediaGuid)
                                          .toList();
                                      final currentSubtitle = subtitleStreams
                                          .where((s) =>
                                              s.guid == _selectedSubtitleGuid)
                                          .firstOrNull;
                                      final subtitleLabel = _selectedSubtitleGuid ==
                                              '_no_display_'
                                          ? '无字幕'
                                          : '${FnDataConvertor.getLanguageName(currentSubtitle?.language ?? '', widget.state.iso6391, widget.state.iso6392)}字幕';
                                      final subtitleItems = [
                                        StreamOptionItem<String>(
                                          title: '无',
                                          value: '_no_display_',
                                          isNoDisplay: true,
                                        ),
                                        ...subtitleStreams.map((s) {
                                          final lang =
                                              FnDataConvertor.getLanguageName(
                                                  s.language,
                                                  widget.state.iso6391,
                                                  widget.state.iso6392);
                                          final title = s.isExternal == 1
                                              ? '$lang - 外挂'
                                              : lang;
                                          return StreamOptionItem<String>(
                                            title: title,
                                            value: s.guid,
                                            subtitle1: s.format.toUpperCase(),
                                            subtitle3: s.title,
                                            isDefault: s.isDefault == 1,
                                            isExternal: s.isExternal == 1,
                                          );
                                        }),
                                      ];
                                      return StreamSelector<String>(
                                        placeholder: '字幕',
                                        selectedLabel: subtitleLabel,
                                        selectedValue: _selectedSubtitleGuid,
                                        items: subtitleItems,
                                        isSubtitle: true,
                                        onAddNasSubtitle: () =>
                                            _showAddNasSubtitleDialog(
                                                _currentMediaGuid),
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedSubtitleGuid = val;
                                            _mediaGuidSubtitleGuidMap[
                                                _currentMediaGuid] = val;
                                          });
                                        },
                                      );
                                    }),
                                    const SizedBox(width: 12),
                                    Builder(builder: (context) {
                                      final audioStreams = widget
                                          .state.streamList!.audioStreams
                                          .where((s) =>
                                              s.mediaGuid == _currentMediaGuid)
                                          .toList();
                                      final currentAudio = audioStreams
                                          .where((s) =>
                                              s.guid == _selectedAudioGuid)
                                          .firstOrNull;
                                      final audioLabel = currentAudio == null
                                          ? '音频'
                                          : '${FnDataConvertor.getLanguageName(currentAudio.language, widget.state.iso6391, widget.state.iso6392)}音频';
                                      final audioItems = audioStreams.map((s) {
                                        final lang =
                                            FnDataConvertor.getLanguageName(
                                                s.language,
                                                widget.state.iso6391,
                                                widget.state.iso6392);
                                        return StreamOptionItem<String>(
                                          title: lang,
                                          value: s.guid,
                                          subtitle1: s.codecName,
                                          subtitle2: s.channelLayout,
                                          subtitle3: s.title,
                                          isDefault: s.isDefault == 1,
                                        );
                                      }).toList();
                                      return StreamSelector<String>(
                                        placeholder: '音频',
                                        selectedLabel: audioLabel,
                                        selectedValue: _selectedAudioGuid,
                                        items: audioItems,
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedAudioGuid = val;
                                            _mediaGuidAudioGuidMap[
                                                _currentMediaGuid] = val;
                                          });
                                        },
                                      );
                                    }),
                                    const SizedBox(width: 12),
                                    // Quality Tags
                                    if (widget.state.streamList!.videoStreams
                                            .isNotEmpty &&
                                        _selectedVideoStreamIndex <
                                            widget.state.streamList!
                                                .videoStreams.length) ...[
                                      MediaQualityTag(
                                          text: widget
                                              .state
                                              .streamList!
                                              .videoStreams[
                                                  _selectedVideoStreamIndex]
                                              .resolutionType
                                              .toUpperCase()),
                                      const SizedBox(width: 8),
                                      MediaQualityTag(
                                          text: widget
                                              .state
                                              .streamList!
                                              .videoStreams[
                                                  _selectedVideoStreamIndex]
                                              .colorRangeType),
                                    ],
                                    const SizedBox(width: 8),
                                    // Audio Type Tag
                                    Builder(builder: (context) {
                                      final audio = widget
                                          .state.streamList!.audioStreams
                                          .where((s) =>
                                              s.guid == _selectedAudioGuid)
                                          .firstOrNull;
                                      return MediaQualityTag(
                                          text: _formatAudioTypeLabel(
                                              audio?.audioType ?? ''));
                                    }),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Video Stream Source Boxes
                    if (widget.state.streamList != null &&
                        widget.state.streamList!.videoStreams.length > 1) ...[
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
                          builder: (_) => MediaDescriptionDialog(
                              title: '电影简介', content: item.overview!),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: CastScrollRow(
                    persons: widget.state.personList,
                    baseUrl: widget.baseUrl,
                    httpHeaders: widget.httpHeaders,
                    cacheManager: widget.cacheManager,
                  ),
                ),
              ),

            // Media Info
            if (widget.state.streamList != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(48, 0, 48, 48),
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
      ],
    );
  }

  Future<void> _playMedia() async {
    // Navigate to player screen
    ref.read(navigationStackProvider.notifier).pushPath('/home');
    context.go(
      '/player/${widget.guid}'
      '?media_guid=$_currentMediaGuid'
      '&audio_guid=${_selectedAudioGuid ?? ''}'
      '&subtitle_guid=${_selectedSubtitleGuid ?? ''}',
    );
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
  double _width = 280.0;
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
      final imgWidth = info.image.width.toDouble();
      final imgHeight = info.image.height.toDouble();
      // Determine height based on aspect ratio
      final aspectRatio = imgHeight > 0 ? imgWidth / imgHeight : 1.0;
      final nextHeight =
          aspectRatio > 0 && aspectRatio < 280.0 / 90.0 ? 150.0 : 90.0;
      // Calculate width based on aspect ratio and height
      final nextWidth = aspectRatio * nextHeight;
      if (mounted) {
        setState(() {
          _height = nextHeight;
          _width = nextWidth;
        });
      }
    });
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: CachedNetworkImage(
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
        placeholder: (context, url) => const Align(
          alignment: Alignment.centerLeft,
          child: ImgLoadingProgressRing(),
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
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            activeColor: kAccentColor,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '剩余 ${FnDataConvertor.formatSecondsToCNDateTime(remaining)}',
          style: FluentTheme.of(context).typography.caption?.copyWith(
                color: FluentTheme.of(context)
                    .typography
                    .caption
                    ?.color
                    ?.withValues(alpha: 0.6),
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
        final colorRangeType = stream.colorRangeType == 'DolbyVision'
            ? '杜比视界'
            : stream.colorRangeType;
        final label = '${stream.resolutionType.toUpperCase()} $colorRangeType';

        return VideoSelectionBox(
          text: label,
          isSelected: isSelected,
          onClick: () => onChanged(index),
        );
      }),
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

    final videoStream = videoStreams.isNotEmpty &&
            selectedVideoStreamIndex < videoStreams.length
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

    final iso6391Map = state.iso6391;

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
          style: FluentTheme.of(context)
              .typography
              .subtitle
              ?.copyWith(fontWeight: FontWeight.bold),
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
                  Expanded(
                      child: _InfoRow(
                          label: '文件大小', value: mediaDetails.fileInfo.size)),
                  Expanded(
                      child: _InfoRow(
                          label: '创建日期',
                          value: mediaDetails.fileInfo.createdDate)),
                  Expanded(
                      child: _InfoRow(
                          label: '添加日期',
                          value: mediaDetails.fileInfo.addedDate)),
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
              Expanded(
                child: _TrackItem(
                  info: mediaDetails.videoTrack,
                  iconAssetPath: 'assets/images/vedio.svg',
                ),
              ),
              Expanded(
                child: _TrackItem(
                  info: mediaDetails.audioTrack,
                  iconAssetPath: 'assets/images/audio.svg',
                ),
              ),
              Expanded(
                child: _TrackItem(
                  info: mediaDetails.subtitleTrack,
                  iconAssetPath: 'assets/images/vedio.svg',
                ),
              ),
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
          style: FluentTheme.of(context)
              .typography
              .bodyStrong
              ?.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                color: FluentTheme.of(context)
                    .typography
                    .caption
                    ?.color
                    ?.withValues(alpha: 0.5),
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
  final String iconAssetPath;

  const _TrackItem({required this.info, required this.iconAssetPath});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final primaryColor = theme.typography.body?.color ?? Colors.white;
    final secondaryColor =
        theme.typography.caption?.color?.withValues(alpha: 0.8) ??
            primaryColor.withValues(alpha: 0.8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconAssetPath,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(secondaryColor, BlendMode.srcIn),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                info.type,
                style: theme.typography.body?.copyWith(
                  fontSize: 14,
                  color: secondaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          info.details.isNotEmpty ? info.details : '暂无信息',
          style: theme.typography.body?.copyWith(
            fontSize: 13,
            color: primaryColor,
          ),
        ),
      ],
    );
  }
}
