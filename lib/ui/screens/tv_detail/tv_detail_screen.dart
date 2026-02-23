import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' as cache_manager;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/movie_detail_models.dart';
import '../../../data/models/season_list_response.dart';
import '../../../data/utils/fn_data_convertor.dart';
import '../../../providers/providers.dart';
import '../../widgets/movie_poster.dart';
import 'tv_detail_view_model.dart';

String _buildImageUrl(String baseUrl, String path) {
  if (baseUrl.isEmpty || path.isEmpty) return '';
  final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  return '$normalizedBaseUrl/v/api/v1/sys/img$path';
}

class TvDetailScreen extends ConsumerWidget {
  final String guid;

  const TvDetailScreen({super.key, required this.guid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(tvDetailNotifierProvider(guid));
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
        data: (state) => _TvDetailContent(
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
                  onPressed: () => ref.read(tvDetailNotifierProvider(guid).notifier).refresh(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvDetailContent extends ConsumerStatefulWidget {
  final TvDetailState state;
  final String baseUrl;
  final String guid;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;

  const _TvDetailContent({
    required this.state,
    required this.baseUrl,
    required this.guid,
    required this.httpHeaders,
    required this.cacheManager,
  });

  @override
  ConsumerState<_TvDetailContent> createState() => _TvDetailContentState();
}

class _TvDetailContentState extends ConsumerState<_TvDetailContent> {
  void _handleBackNavigation(BuildContext context) {
    final previousPath = ref.read(navigationStackProvider.notifier).pop();
    if (previousPath != null && previousPath.isNotEmpty) {
      context.go(previousPath);
      return;
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.state.item;
    if (item == null) return const Center(child: Text('未找到剧集信息'));

    final windowHeight = MediaQuery.of(context).size.height;
    final backdropPath = (item.backdrops?.isNotEmpty ?? false) ? item.backdrops! : item.posters;
    final backdropUrl = _buildImageUrl(widget.baseUrl, backdropPath);
    final logoUrl = item.logos != null ? _buildImageUrl(widget.baseUrl, item.logos!) : '';

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
                      bottom: 24,
                      right: 48,
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
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 24, 48, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActionRow(context, item),
                    const SizedBox(height: 16),
                    _buildMetadataRow(context, item),
                    if (item.overview != null && item.overview!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _OverviewSection(
                        text: item.overview!,
                        onMore: () => _showDescriptionDialog(context, item),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Season List
            if (widget.state.seasonList.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '剧集列表',
                        style: FluentTheme.of(context).typography.subtitle?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      _SeasonListGrid(
                        seasons: widget.state.seasonList,
                        itemTitle: item.title,
                        scaleFactor: 1.0,
                        onWatchedToggle: (guid, isWatched, success) {
                            ref.read(tvDetailNotifierProvider(widget.guid).notifier).toggleSeasonWatched(guid, isWatched);
                        },
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
              
             if (item.imdbId != null && item.imdbId!.isNotEmpty)
               SliverToBoxAdapter(
                 child: Padding(
                   padding: const EdgeInsets.fromLTRB(48, 24, 48, 48),
                   child: MouseRegion(
                     cursor: SystemMouseCursors.click,
                     child: HyperlinkButton(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('在 IMDb 上查看'),
                          const SizedBox(width: 8),
                          const Icon(FluentIcons.open_in_new_window, size: 12),
                        ],
                      ),
                      onPressed: () => launchUrl(Uri.parse(FnDataConvertor.getImdbLink(item.imdbId))),
                    ),
                   ),
                 ),
               ),
          ],
        ),
        Padding(
            padding: const EdgeInsets.only(top: 24, left: 24),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                  icon: const Icon(FluentIcons.back, size: 24),
                  onPressed: () => _handleBackNavigation(context),
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
        title: const Text('剧集简介'),
        content: Scrollbar(
          child: SingleChildScrollView(
            child: Text(
              item.overview ?? '暂无介绍',
              style: FluentTheme.of(context).typography.body?.copyWith(height: 1.6),
            ),
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Button(
              child: const Text('关闭'),
              onPressed: () => Navigator.of(context).pop(),
            ),
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
    final playInfo = widget.state.playInfo;
    final seasonList = widget.state.seasonList;
    
    String playButtonText = '播放';
    if (playInfo != null) {
        if (seasonList.length == 1) {
             playButtonText = '第 ${playInfo.episodeNumber} 集';
        } else {
             playButtonText = '第 ${playInfo.seasonNumber} 季 第 ${playInfo.episodeNumber} 集';
        }
    }

    return Row(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: FilledButton(
            onPressed: () async {
              // TODO: Implement playback logic for TV
              // Similar to movie, but we need to know which episode to play.
              // Assuming the playInfo contains the "next episode to watch" or "last watched"
              final prefsManager = ref.read(preferencesManagerProvider);
              final baseUrl = prefsManager.getBaseUrl() ?? '';
              
              // Construct play URL based on playInfo
              // The logic from KMP:
              // val playMedia = rememberPlayMediaFunction(guid = guid, player = player)
              // It seems it delegates to a player.
              
              if (playInfo != null) {
                   // Actually in KMP `rememberPlayMediaFunction` uses `guid` (which is item guid)
                   // But `TvDetailScreen` calls `playMedia()` which presumably plays the item returned by `playInfo`?
                   // In `TvMiddleControls`:
                   // DetailPlayButton("第 ${playInfo.item.seasonNumber} 季 第 ${playInfo.item.episodeNumber} 集") { playMedia() }
                   
                   // So we can try launching the player with the item guid, and backend decides what to play?
                   // Or we use `playInfo.playItemGuid` if available.
                   
                   final targetGuid = playInfo.playItemGuid.isNotEmpty ? playInfo.playItemGuid : widget.guid;
                   final playUrl = '$baseUrl/v/api/v1/play/video?guid=$targetGuid';
                   
                   final uri = Uri.parse(playUrl);
                   if (await canLaunchUrl(uri)) {
                     await launchUrl(uri);
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
                    playButtonText,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        _CircleButton(
          icon: item.isFavorite == 1 ? FluentIcons.heart_fill : FluentIcons.heart,
          color: item.isFavorite == 1 ? Colors.red : null,
          tooltip: item.isFavorite == 1 ? '取消收藏' : '加入收藏',
          onPressed: () => ref.read(tvDetailNotifierProvider(widget.guid).notifier).toggleFavorite(),
        ),
        const SizedBox(width: 12),
        _CircleButton(
          icon: item.isWatched == 1 ? FluentIcons.check_mark : FluentIcons.check_mark,
          color: item.isWatched == 1 ? FluentTheme.of(context).accentColor : null,
          tooltip: item.isWatched == 1 ? '标记为未看' : '标记为已看',
          onPressed: () => ref.read(tvDetailNotifierProvider(widget.guid).notifier).toggleWatched(),
        ),
        const SizedBox(width: 12),
        _CircleButton(
          icon: FluentIcons.more,
          tooltip: '更多操作',
          onPressed: () {
            // TODO: More options
          },
        ),
      ],
    );
  }
}

class _SeasonListGrid extends StatelessWidget {
  final List<SeasonListResponse> seasons;
  final String itemTitle;
  final double scaleFactor;
  final Function(String guid, bool isWatched, bool success) onWatchedToggle;

  const _SeasonListGrid({
    required this.seasons,
    required this.itemTitle,
    this.scaleFactor = 1.0,
    required this.onWatchedToggle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final posterMinWidth = 128.0 * scaleFactor;
        final posterMaxWidth = 190.0 * scaleFactor;
        final spacing = 16.0;
        
        final itemsPerRow = ((availableWidth + spacing) / (posterMinWidth + spacing)).floor().clamp(1, 10);
        double itemWidth;
        if (itemsPerRow >= 4) {
          final totalSpacing = spacing * (itemsPerRow - 1);
          itemWidth = ((availableWidth - totalSpacing) / itemsPerRow).clamp(posterMinWidth, posterMaxWidth);
        } else {
          itemWidth = posterMinWidth;
        }
        final itemHeight = itemWidth * 1.5;

        return Wrap(
           spacing: spacing,
           runSpacing: spacing,
           children: seasons.map((season) {
              final episodeNumber = season.episodeNumber > 0 ? season.episodeNumber : season.localNumberOfEpisodes;
              final subtitle = season.airDate != null 
                  ? "共 $episodeNumber 集 · ${season.airDate!.length >= 4 ? season.airDate!.substring(0, 4) : season.airDate}"
                  : "共 $episodeNumber 集";
              
              return SizedBox(
                 width: itemWidth,
                 height: itemHeight + 60,
                 child: MoviePoster(
                    posterPath: season.poster,
                    title: season.title,
                    subtitle: subtitle,
                    score: season.voteAverage,
                    isFavorite: season.isFavorite == 1,
                    isWatched: season.watched == 1,
                    width: itemWidth,
                    height: itemHeight,
                    scaleFactor: scaleFactor,
                    type: season.type,
                    guid: season.guid,
                    mediaTitle: itemTitle,
                    seasonNumber: season.seasonNumber,
                    onWatchedToggle: onWatchedToggle,
                    resolutions: season.mediaStream.resolutions,
                 ),
              );
           }).toList(),
        );
    });
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

class _OverviewSection extends StatelessWidget {
  final String text;
  final VoidCallback onMore;

  const _OverviewSection({required this.text, required this.onMore});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: FluentTheme.of(context).typography.body?.copyWith(
                  fontSize: 16,
                  height: 1.6,
                ),
          ),
        ),
        const SizedBox(width: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: HyperlinkButton(
            onPressed: onMore,
            child: const Text('更多'),
          ),
        ),
      ],
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
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            icon: Icon(icon, color: color, size: 20),
            onPressed: onPressed,
          ),
        ),
      ),
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
