import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    as cache_manager;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/movie_detail_models.dart';
import '../../../data/models/episode_list_response.dart';
import '../../../providers/global_refresh.dart';
import '../../../providers/providers.dart';
import '../../shared/common/fn_cached_image.dart';
import '../../shared/cast_scroll_row.dart';
import '../../shared/common/poster_resolution_tags.dart';
import '../../shared/common/scroll_row.dart';
import '../../shared/toast.dart';
import '../movie_detail/detail_components.dart';
import 'tv_season_detail_view_model.dart';

String _buildImageUrl(String baseUrl, String path) {
  if (baseUrl.isEmpty || path.isEmpty) return '';
  final normalizedBaseUrl = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return '$normalizedBaseUrl/v/api/v1/sys/img$path';
}

const double _episodePosterHeight = 140;
const double _episodePosterWidth = _episodePosterHeight * 16 / 9;
const double _episodeCardSpacing = 16;
const double _episodeRowHeight = 244;

class TvSeasonDetailScreen extends ConsumerWidget {
  final String guid;

  const TvSeasonDetailScreen({super.key, required this.guid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Consume each global refresh request once for the current season page.
    ref.listen<GlobalRefreshRequest?>(
      currentGlobalRefreshRequestProvider,
      (_, next) {
        unawaited(
          ref.read(globalRefreshManagerProvider).handleRefresh(
                consumerId: 'tv-season-detail:$guid',
                request: next,
                onRefresh: () => ref
                    .read(tvSeasonDetailNotifierProvider(guid).notifier)
                    .refresh(),
              ),
        );
      },
    );
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
                  onPressed: () => ref
                      .read(tvSeasonDetailNotifierProvider(guid).notifier)
                      .refresh(),
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
  ConsumerState<_TvSeasonDetailContent> createState() =>
      _TvSeasonDetailContentState();
}

class _TvSeasonDetailContentState
    extends ConsumerState<_TvSeasonDetailContent> {
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

  Future<void> _handleToggleWatched() async {
    final result = await ref
        .read(tvSeasonDetailNotifierProvider(widget.guid).notifier)
        .toggleWatched();
    if (!mounted) return;
    if (result.success) {
      _toastManager.showToast(
        result.message,
        type: ToastType.success,
        category: 'watched_${widget.guid}',
      );
    } else {
      _toastManager.showToast(
        '操作失败，${result.message}',
        type: ToastType.failed,
        category: 'watched_${widget.guid}',
      );
    }
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
              style: FluentTheme.of(context)
                  .typography
                  .body
                  ?.copyWith(height: 1.6),
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

  String _buildPlayButtonText() {
    final playInfo = widget.state.playInfo;
    if (playInfo == null) return '播放';
    return '第 ${playInfo.item.episodeNumber} 集';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.state.item;
    if (item == null) return const Center(child: Text('未找到分季信息'));

    final windowHeight = MediaQuery.of(context).size.height;
    final posterUrl = _buildImageUrl(widget.baseUrl, item.posters);
    final backdropPath =
        (item.backdrops?.isNotEmpty ?? false) ? item.backdrops! : item.posters;
    final backdropUrl = _buildImageUrl(widget.baseUrl, backdropPath);
    final isWatched = item.isWatched == 1;
    final textColor = FluentTheme.of(context).typography.body?.color;
    final resolvedTextColor = textColor ?? Colors.white;
    final headerHeight = windowHeight * 0.5;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: headerHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (backdropUrl.isNotEmpty)
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Image(
                          image: fnCachedImageProvider(ref, backdropUrl),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.06),
                            Colors.black.withValues(alpha: 0.2),
                            Colors.black.withValues(alpha: 0.4),
                            FluentTheme.of(context).scaffoldBackgroundColor,
                          ],
                          stops: const [0.0, 0.48, 0.72, 1.0],
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.08),
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
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 180,
                                  height: 270,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: posterUrl,
                                    httpHeaders: widget.httpHeaders,
                                    cacheManager: widget.cacheManager,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: Colors.grey[40],
                                      child: const Icon(FluentIcons.photo2,
                                          size: 48),
                                    ),
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
                                  style: FluentTheme.of(context)
                                      .typography
                                      .titleLarge
                                      ?.copyWith(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.title,
                                  style: FluentTheme.of(context)
                                      .typography
                                      .subtitle
                                      ?.copyWith(
                                        fontSize: 24,
                                        color:
                                            Colors.white.withValues(alpha: 0.8),
                                      ),
                                ),
                                const SizedBox(height: 12),
                                _buildTags(context, item),
                                const SizedBox(height: 16),
                                _buildActionButtons(
                                  context,
                                  item,
                                  isWatched,
                                  textColor,
                                  resolvedTextColor,
                                ),
                                if (item.overview != null &&
                                    item.overview!.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 920),
                                    child: MediaDescription(
                                      overview: item.overview!,
                                      onMore: () =>
                                          _showDescriptionDialog(context, item),
                                      isSeason: true,
                                    ),
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
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
                child: _EpisodeListSection(
                  episodes: widget.state.episodeList,
                  playInfo: widget.state.playInfo,
                  baseUrl: widget.baseUrl,
                  httpHeaders: widget.httpHeaders,
                  cacheManager: widget.cacheManager,
                  onEpisodeTap: (episode) {
                    // Navigate to player screen for this episode
                    ref
                        .read(navigationStackProvider.notifier)
                        .pushPath('/home');
                    context.go('/player/${episode.guid}');
                  },
                  onFavoriteToggle: (guid, isFavorite) {
                    return ref
                        .read(tvSeasonDetailNotifierProvider(widget.guid)
                            .notifier)
                        .toggleEpisodeFavorite(guid, isFavorite);
                  },
                  onWatchedToggle: (guid, isWatched) {
                    return ref
                        .read(tvSeasonDetailNotifierProvider(widget.guid)
                            .notifier)
                        .toggleEpisodeWatched(guid, isWatched);
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
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ImdbLink(imdbId: item.imdbId!),
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

  Widget _buildActionButtons(
    BuildContext context,
    ItemResponse item,
    bool isWatched,
    Color? textColor,
    Color resolvedTextColor,
  ) {
    final playInfo = widget.state.playInfo;
    final playButtonText = _buildPlayButtonText();

    return Row(
      children: [
        DetailPlayButton(
          text: playButtonText,
          onPressed: () async {
            if (playInfo != null) {
              final playItemGuid = playInfo.item.playItemGuid;
              final targetGuid =
                  playItemGuid.isNotEmpty ? playItemGuid : widget.guid;
              ref.read(navigationStackProvider.notifier).pushPath('/home');
              context.go('/player/$targetGuid');
            }
          },
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
    );
  }
}

class _EpisodeListSection extends StatefulWidget {
  final List<EpisodeListResponse> episodes;
  final PlayInfoResponse? playInfo;
  final String baseUrl;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;
  final ValueChanged<EpisodeListResponse> onEpisodeTap;
  final Future<bool> Function(String guid, bool isFavorite) onFavoriteToggle;
  final Future<bool> Function(String guid, bool isWatched) onWatchedToggle;

  const _EpisodeListSection({
    required this.episodes,
    required this.playInfo,
    required this.baseUrl,
    required this.httpHeaders,
    required this.cacheManager,
    required this.onEpisodeTap,
    required this.onFavoriteToggle,
    required this.onWatchedToggle,
  });

  @override
  State<_EpisodeListSection> createState() => _EpisodeListSectionState();
}

class _EpisodeListSectionState extends State<_EpisodeListSection> {
  late final ScrollController _scrollController = ScrollController();
  int? _lastPositionedEpisodeNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _positionToCurrentEpisode());
  }

  @override
  void didUpdateWidget(covariant _EpisodeListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episodes != widget.episodes ||
        oldWidget.playInfo != widget.playInfo) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _positionToCurrentEpisode());
    }
  }

  void _positionToCurrentEpisode() {
    if (!_scrollController.hasClients || widget.episodes.isEmpty) return;
    final currentEpisodeNumber = widget.playInfo?.item.episodeNumber;
    if (currentEpisodeNumber == null ||
        _lastPositionedEpisodeNumber == currentEpisodeNumber) {
      return;
    }
    final currentEpisodeIndex = widget.episodes.indexWhere(
      (episode) => episode.episodeNumber == currentEpisodeNumber,
    );
    if (currentEpisodeIndex < 0) return;
    final targetOffset =
        currentEpisodeIndex * (_episodePosterWidth + _episodeCardSpacing);
    final maxExtent = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(targetOffset.clamp(0, maxExtent));
    _lastPositionedEpisodeNumber = currentEpisodeNumber;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.episodes.isEmpty) {
      return const SizedBox.shrink();
    }
    final currentEpisodeNumber = widget.playInfo?.item.episodeNumber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '剧集列表',
          style: FluentTheme.of(context).typography.subtitle?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 26,
              ),
        ),
        const SizedBox(height: 16),
        ScrollRow(
          controller: _scrollController,
          height: _episodeRowHeight,
          itemCount: widget.episodes.length,
          itemSpacing: _episodeCardSpacing,
          scrollFactor: 0.9,
          itemBuilder: (context, index) {
            final episode = widget.episodes[index];
            return _EpisodeCard(
              episode: episode,
              baseUrl: widget.baseUrl,
              httpHeaders: widget.httpHeaders,
              cacheManager: widget.cacheManager,
              isCurrent: episode.episodeNumber == currentEpisodeNumber,
              onTap: () => widget.onEpisodeTap(episode),
              onFavoriteToggle: (currentState) =>
                  widget.onFavoriteToggle(episode.guid, currentState),
              onWatchedToggle: (currentState) =>
                  widget.onWatchedToggle(episode.guid, currentState),
            );
          },
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
  final Future<bool> Function(bool currentState) onFavoriteToggle;
  final Future<bool> Function(bool currentState) onWatchedToggle;

  const _EpisodeCard({
    required this.episode,
    required this.baseUrl,
    required this.httpHeaders,
    required this.cacheManager,
    required this.isCurrent,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onWatchedToggle,
  });

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _hovered = false;
  bool _isPlayButtonHovered = false;
  bool _isFavorite = false;
  bool _isWatched = false;
  final FlyoutController _moreController = FlyoutController();

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.episode.isFavorite == 1;
    _isWatched = widget.episode.watched == 1;
  }

  @override
  void didUpdateWidget(covariant _EpisodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episode.isFavorite != widget.episode.isFavorite) {
      _isFavorite = widget.episode.isFavorite == 1;
    }
    if (oldWidget.episode.watched != widget.episode.watched) {
      _isWatched = widget.episode.watched == 1;
    }
  }

  @override
  void dispose() {
    _moreController.dispose();
    super.dispose();
  }

  Future<void> _handleFavoriteToggle() async {
    final previousValue = _isFavorite;
    setState(() => _isFavorite = !previousValue);
    final success = await widget.onFavoriteToggle(previousValue);
    if (!mounted || success) return;
    setState(() => _isFavorite = previousValue);
  }

  Future<void> _handleWatchedToggle() async {
    final previousValue = _isWatched;
    setState(() => _isWatched = !previousValue);
    final success = await widget.onWatchedToggle(previousValue);
    if (!mounted || success) return;
    setState(() => _isWatched = previousValue);
  }

  void _showMoreFlyout() {
    if (_moreController.isOpen) {
      _moreController.close();
      return;
    }
    _moreController.showFlyout<void>(
      placementMode: FlyoutPlacementMode.bottomCenter,
      builder: (context) => MenuFlyout(
        items: [
          MenuFlyoutItem(
            text: const Text('播放本集'),
            onPressed: () {
              Flyout.of(context).close();
              widget.onTap();
            },
          ),
          MenuFlyoutItem(
            text: Text(_isWatched ? '标记为未看' : '标记为已看'),
            onPressed: () {
              Flyout.of(context).close();
              _handleWatchedToggle();
            },
          ),
          MenuFlyoutItem(
            text: Text(_isFavorite ? '取消收藏' : '加入收藏'),
            onPressed: () {
              Flyout.of(context).close();
              _handleFavoriteToggle();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final posterUrl = widget.episode.poster != null
        ? _buildImageUrl(widget.baseUrl, widget.episode.poster!)
        : '';
    final borderColor = _hovered
        ? Colors.white.withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.1);
    final playButtonSize = _isPlayButtonHovered ? 56.0 : 48.0;
    const actionBottom = 14.0;
    final progress = widget.episode.duration > 0
        ? (widget.episode.ts / widget.episode.duration).clamp(0.0, 1.0)
        : 0.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: _episodePosterWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: _episodePosterHeight,
                width: _episodePosterWidth,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: borderColor,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: posterUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: posterUrl,
                                httpHeaders: widget.httpHeaders,
                                cacheManager: widget.cacheManager,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[40],
                                  child:
                                      const Icon(FluentIcons.photo2, size: 32),
                                ),
                              )
                            : Container(
                                color: Colors.grey[40],
                                child: const Icon(FluentIcons.photo2, size: 32),
                              ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _hovered ? 0 : 1,
                        child: Container(
                          height: _episodePosterHeight / 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                const Color(0xFF1C1C1C).withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 11,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _hovered ? 0 : 1,
                        child: PosterResolutionTags(
                          resolutions: widget.episode.mediaStream.resolutions,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _hovered ? 1 : 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1C1C1C).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox(
                        height: 5,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                            if (progress > 0)
                              FractionallySizedBox(
                                widthFactor: progress,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  color: const Color(0xFF2073DF),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _hovered ? 1 : 0,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) =>
                              setState(() => _isPlayButtonHovered = true),
                          onExit: (_) =>
                              setState(() => _isPlayButtonHovered = false),
                          child: GestureDetector(
                            onTap: widget.onTap,
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: playButtonSize,
                              height: playButtonSize,
                              alignment: Alignment.center,
                              child: SvgPicture.asset(
                                'assets/images/play_circle.svg',
                                width: playButtonSize,
                                height: playButtonSize,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: actionBottom,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _hovered ? 1 : 0,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _EpisodePosterActionButton(
                                svgAssetPath: _isWatched
                                    ? 'assets/images/watched_fill.svg'
                                    : 'assets/images/watched.svg',
                                isActive: _isWatched,
                                activeColor: const Color(0xFF2173DF),
                                onPressed: _handleWatchedToggle,
                              ),
                              const SizedBox(width: 14),
                              _EpisodePosterActionButton(
                                svgAssetPath: _isFavorite
                                    ? 'assets/images/favorite_fill.svg'
                                    : 'assets/images/favorite.svg',
                                isActive: _isFavorite,
                                activeColor: const Color(0xFFFF0420),
                                onPressed: _handleFavoriteToggle,
                              ),
                              const SizedBox(width: 14),
                              FlyoutTarget(
                                controller: _moreController,
                                child: _EpisodePosterActionButton(
                                  icon: FluentIcons.more,
                                  isActive: false,
                                  activeColor: Colors.white,
                                  onPressed: _showMoreFlyout,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '第 ${widget.episode.episodeNumber} 集 ${widget.episode.title}',
                        style: theme.typography.bodyStrong?.copyWith(
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.episode.overview?.trim().isNotEmpty == true
                            ? widget.episode.overview!.trim()
                            : '暂无剧集简介',
                        style: theme.typography.caption?.copyWith(
                          color: theme.typography.caption?.color
                              ?.withValues(alpha: 0.78),
                          fontSize: 14,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            widget.episode.runtime != null &&
                                    widget.episode.runtime! > 0
                                ? '${widget.episode.runtime} 分钟'
                                : '时长未知',
                            style: theme.typography.caption?.copyWith(
                              fontSize: 12,
                              color: theme.typography.caption?.color
                                  ?.withValues(alpha: 0.65),
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

class _EpisodePosterActionButton extends StatefulWidget {
  final IconData? icon;
  final String? svgAssetPath;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onPressed;

  const _EpisodePosterActionButton({
    this.icon,
    this.svgAssetPath,
    required this.isActive,
    required this.activeColor,
    required this.onPressed,
  });

  @override
  State<_EpisodePosterActionButton> createState() =>
      _EpisodePosterActionButtonState();
}

class _EpisodePosterActionButtonState
    extends State<_EpisodePosterActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _isHovered
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
              if (widget.svgAssetPath != null)
                SvgPicture.asset(
                  widget.svgAssetPath!,
                  width: 16,
                  height: 16,
                  colorFilter: ColorFilter.mode(
                    widget.isActive ? widget.activeColor : Colors.white,
                    BlendMode.srcIn,
                  ),
                )
              else if (widget.icon != null)
                Icon(
                  widget.icon,
                  size: 16,
                  color: widget.isActive ? widget.activeColor : Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
