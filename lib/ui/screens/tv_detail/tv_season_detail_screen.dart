import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' as cache_manager;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/movie_detail_models.dart';
import '../../../data/models/episode_list_response.dart';
import '../../../data/utils/fn_data_convertor.dart';
import '../../../providers/providers.dart';
import '../../widgets/cast_scroll_row.dart';
import '../../widgets/toast.dart';
import '../movie_detail/detail_components.dart';
import 'tv_season_detail_view_model.dart';

String _buildImageUrl(String baseUrl, String path) {
  if (baseUrl.isEmpty || path.isEmpty) return '';
  final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  return '$normalizedBaseUrl/v/api/v1/sys/img$path';
}

class TvSeasonDetailScreen extends ConsumerWidget {
  final String guid;

  const TvSeasonDetailScreen({super.key, required this.guid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(tvSeasonDetailNotifierProvider(guid));
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
        data: (state) => _TvSeasonDetailContent(
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
                  onPressed: () => ref.read(tvSeasonDetailNotifierProvider(guid).notifier).refresh(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvSeasonDetailContent extends ConsumerStatefulWidget {
  final TvSeasonDetailState state;
  final String baseUrl;
  final String guid;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;

  const _TvSeasonDetailContent({
    required this.state,
    required this.baseUrl,
    required this.guid,
    required this.httpHeaders,
    required this.cacheManager,
  });

  @override
  ConsumerState<_TvSeasonDetailContent> createState() => _TvSeasonDetailContentState();
}

class _TvSeasonDetailContentState extends ConsumerState<_TvSeasonDetailContent> {
  late final ToastManager _toastManager = ToastManager();
  late final ScrollController _descriptionScrollController = ScrollController();

  @override
  void dispose() {
    _descriptionScrollController.dispose();
    _toastManager.dispose();
    super.dispose();
  }

  void _handleBackNavigation(BuildContext context) {
    final previousPath = ref.read(navigationStackProvider.notifier).pop();
    if (previousPath != null && previousPath.isNotEmpty) {
      context.go(previousPath);
      return;
    }
    context.go('/home');
  }

  Future<void> _handleToggleFavorite() async {
    await ref.read(tvSeasonDetailNotifierProvider(widget.guid).notifier).toggleFavorite();
  }

  Future<void> _handleToggleWatched() async {
    await ref.read(tvSeasonDetailNotifierProvider(widget.guid).notifier).toggleWatched();
  }

  void _showDescriptionDialog(BuildContext context, ItemResponse item) {
    if (_descriptionScrollController.hasClients) {
      _descriptionScrollController.jumpTo(0);
    }
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('剧集简介'),
        content: Scrollbar(
          controller: _descriptionScrollController,
          child: SingleChildScrollView(
            controller: _descriptionScrollController,
            primary: false,
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

  @override
  Widget build(BuildContext context) {
    final item = widget.state.item;
    if (item == null) return const Center(child: Text('未找到分季信息'));

    final windowHeight = MediaQuery.of(context).size.height;
    final posterUrl = _buildImageUrl(widget.baseUrl, item.posters);
    final isFavorite = item.isFavorite == 1;
    final isWatched = item.isWatched == 1;
    final textColor = FluentTheme.of(context).typography.body?.color;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: windowHeight * 0.5,
                child: Stack(
                  children: [
                    if (posterUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: posterUrl,
                        httpHeaders: widget.httpHeaders,
                        cacheManager: widget.cacheManager,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[40],
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                            FluentTheme.of(context).scaffoldBackgroundColor,
                          ],
                          stops: const [0.4, 0.72, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 48,
                      bottom: 24,
                      right: 48,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (posterUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 180,
                                height: 270,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: posterUrl,
                                  httpHeaders: widget.httpHeaders,
                                  cacheManager: widget.cacheManager,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[40],
                                    child: const Icon(FluentIcons.photo2, size: 48),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.tvTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: FluentTheme.of(context).typography.titleLarge?.copyWith(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.title,
                                  style: FluentTheme.of(context).typography.subtitle?.copyWith(
                                        fontSize: 24,
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                ),
                                const SizedBox(height: 12),
                                _buildTags(context, item),
                                const SizedBox(height: 16),
                                _buildActionButtons(context, item, isFavorite, isWatched, textColor),
                                if (item.overview != null && item.overview!.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  MediaDescription(
                                    overview: item.overview!,
                                    onMore: () => _showDescriptionDialog(context, item),
                                    isSeason: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 24, 48, 24),
                child: _EpisodeListSection(
                  episodes: widget.state.episodeList,
                  playInfo: widget.state.playInfo,
                  baseUrl: widget.baseUrl,
                  httpHeaders: widget.httpHeaders,
                  cacheManager: widget.cacheManager,
                  onEpisodeTap: (episode) {
                    // Navigate to player screen for this episode
                    ref.read(navigationStackProvider.notifier).pushPath('/home');
                    context.go('/player/${episode.guid}');
                  },
                  onWatchedToggle: (guid, isWatched) {
                    ref.read(tvSeasonDetailNotifierProvider(widget.guid).notifier).toggleEpisodeWatched(guid, isWatched);
                  },
                ),
              ),
            ),
            if (widget.state.personList.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: CastScrollRow(
                    persons: widget.state.personList,
                    baseUrl: widget.baseUrl,
                    httpHeaders: widget.httpHeaders,
                    cacheManager: widget.cacheManager,
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

  Widget _buildTags(BuildContext context, ItemResponse item) {
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

    if (item.airDate != null && item.airDate!.length >= 4) {
      items.add(Text(
        item.airDate!.substring(0, 4),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 14,
        ),
      ));
    }

    if (item.localNumberOfEpisodes > 0) {
      items.add(Text(
        '共 ${item.localNumberOfEpisodes} 集',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 14,
        ),
      ));
    }

    final List<Widget> displayItems = [];
    for (int i = 0; i < items.length; i++) {
      displayItems.add(items[i]);
      if (i < items.length - 1) {
        displayItems.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            '/',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ));
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      children: displayItems,
    );
  }

  Widget _buildActionButtons(BuildContext context, ItemResponse item, bool isFavorite, bool isWatched, Color? textColor) {
    final playInfo = widget.state.playInfo;
    final playButtonText = playInfo != null ? '第 ${playInfo.episodeNumber} 集' : '播放';

    return Row(
      children: [
        DetailPlayButton(
          text: playButtonText,
          onPressed: () async {
            if (playInfo != null) {
              final targetGuid = playInfo.playItemGuid.isNotEmpty ? playInfo.playItemGuid : widget.guid;
              ref.read(navigationStackProvider.notifier).pushPath('/home');
              context.go('/player/$targetGuid');
            }
          },
        ),
        const SizedBox(width: 16),
        CircleIconButton(
          icon: item.isFavorite == 1 ? FluentIcons.heart : FluentIcons.heart,
          iconColor: isFavorite ? const Color(0xFFFF0420) : textColor,
          tooltip: item.isFavorite == 1 ? '取消收藏' : '加入收藏',
          onPressed: _handleToggleFavorite,
        ),
        const SizedBox(width: 16),
        CircleIconButton(
          icon: FluentIcons.check_mark,
          iconColor: isWatched ? const Color(0xFF2173DF) : textColor,
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
    );
  }
}

class _EpisodeListSection extends StatelessWidget {
  final List<EpisodeListResponse> episodes;
  final PlayInfoResponse? playInfo;
  final String baseUrl;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;
  final ValueChanged<EpisodeListResponse> onEpisodeTap;
  final Function(String guid, bool isWatched) onWatchedToggle;

  const _EpisodeListSection({
    required this.episodes,
    required this.playInfo,
    required this.baseUrl,
    required this.httpHeaders,
    required this.cacheManager,
    required this.onEpisodeTap,
    required this.onWatchedToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentEpisodeIndex = playInfo?.episodeNumber != null
        ? episodes.indexWhere((e) => e.episodeNumber == playInfo!.episodeNumber)
        : -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '剧集列表',
          style: FluentTheme.of(context).typography.subtitle?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: episodes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final episode = episodes[index];
              final isCurrent = index == currentEpisodeIndex;
              return _EpisodeCard(
                episode: episode,
                baseUrl: baseUrl,
                httpHeaders: httpHeaders,
                cacheManager: cacheManager,
                isCurrent: isCurrent,
                onTap: () => onEpisodeTap(episode),
                onWatchedToggle: () => onWatchedToggle(episode.guid, episode.watched == 1),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EpisodeCard extends StatefulWidget {
  final EpisodeListResponse episode;
  final String baseUrl;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onWatchedToggle;

  const _EpisodeCard({
    required this.episode,
    required this.baseUrl,
    required this.httpHeaders,
    required this.cacheManager,
    required this.isCurrent,
    required this.onTap,
    required this.onWatchedToggle,
  });

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final posterUrl = widget.episode.poster != null
        ? _buildImageUrl(widget.baseUrl, widget.episode.poster!)
        : '';
    final isWatched = widget.episode.watched == 1;
    final borderColor = widget.isCurrent
        ? const Color(0xFF2173DF)
        : _hovered
            ? Colors.white.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.1);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 280,
          decoration: BoxDecoration(
            color: _hovered ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
            border: Border.all(color: borderColor, width: widget.isCurrent ? 2 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                    child: posterUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            httpHeaders: widget.httpHeaders,
                            cacheManager: widget.cacheManager,
                            width: 280,
                            height: 120,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              width: 280,
                              height: 120,
                              color: Colors.grey[40],
                              child: const Icon(FluentIcons.photo2, size: 32),
                            ),
                          )
                        : Container(
                            width: 280,
                            height: 120,
                            color: Colors.grey[40],
                            child: const Icon(FluentIcons.photo2, size: 32),
                          ),
                  ),
                  if (isWatched)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2173DF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          FluentIcons.check_mark,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (widget.isCurrent)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2173DF),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
                        ),
                        child: const Text(
                          '正在播放',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '第 ${widget.episode.episodeNumber} 集',
                        style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                              fontSize: 14,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.episode.title,
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                              color: FluentTheme.of(context).typography.caption?.color?.withValues(alpha: 0.8),
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          if (widget.episode.runtime != null && widget.episode.runtime! > 0)
                            Text(
                              '${widget.episode.runtime} 分钟',
                              style: FluentTheme.of(context).typography.caption?.copyWith(
                                    fontSize: 12,
                                    color: FluentTheme.of(context).typography.caption?.color?.withValues(alpha: 0.6),
                                  ),
                            ),
                          const Spacer(),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: widget.onWatchedToggle,
                              child: Icon(
                                isWatched ? FluentIcons.check_mark : FluentIcons.circle_ring,
                                size: 16,
                                color: isWatched ? const Color(0xFF2173DF) : FluentTheme.of(context).typography.caption?.color?.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
