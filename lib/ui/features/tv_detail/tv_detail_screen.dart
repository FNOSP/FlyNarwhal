import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    as cache_manager;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/common/app_loading_progress_ring.dart';

import '../../../data/models/movie_detail_models.dart';
import '../../../data/models/season_list_response.dart';
import '../../../data/utils/fn_data_convertor.dart';
import '../../../providers/global_refresh.dart';
import '../../../providers/providers.dart';
import '../movie_detail/detail_components.dart';
import '../../shared/common/img_loading_progress_ring.dart';
import '../../shared/movie_poster.dart';
import '../../shared/toast.dart';
import 'tv_detail_view_model.dart';

String _buildImageUrl(String baseUrl, String path) {
  if (baseUrl.isEmpty || path.isEmpty) return '';
  final normalizedBaseUrl = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return '$normalizedBaseUrl/v/api/v1/sys/img$path';
}

class TvDetailScreen extends ConsumerWidget {
  final String guid;

  const TvDetailScreen({super.key, required this.guid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Consume each global refresh request once for the current TV detail page.
    ref.listen<GlobalRefreshRequest?>(
      currentGlobalRefreshRequestProvider,
      (_, next) {
        unawaited(
          ref.read(globalRefreshManagerProvider).handleRefresh(
                consumerId: 'tv-detail:$guid',
                request: next,
                onRefresh: () =>
                    ref.read(tvDetailNotifierProvider(guid).notifier).refresh(),
              ),
        );
      },
    );
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

    final theme = FluentTheme.of(context);
    final scaffoldBackgroundColor = theme.brightness == Brightness.dark
        ? const Color(0xFF282828)
        : theme.scaffoldBackgroundColor;

    return FluentTheme(
      data: theme.copyWith(scaffoldBackgroundColor: scaffoldBackgroundColor),
      child: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: detailState.when(
          data: (state) => _TvDetailContent(
            state: state,
            baseUrl: baseUrl,
            guid: guid,
            httpHeaders: httpHeaders,
            cacheManager: cacheManager,
          ),
          loading: () => const Center(child: AppLoadingProgressRing()),
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
                        .read(tvDetailNotifierProvider(guid).notifier)
                        .refresh(),
                  ),
                ),
              ],
            ),
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
  late final ToastManager _toastManager = ToastManager();
  late final FlyoutController _moreController = FlyoutController();

  @override
  void dispose() {
    _moreController.dispose();
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
    final result = await ref
        .read(tvDetailNotifierProvider(widget.guid).notifier)
        .toggleFavorite();
    if (!mounted) return;
    if (result.success) {
      _toastManager.showToast(
        result.message,
        type: ToastType.success,
        category: 'favorite_${widget.guid}',
      );
    } else {
      _toastManager.showToast(
        '操作失败，${result.message}',
        type: ToastType.failed,
        category: 'favorite_${widget.guid}',
      );
    }
  }

  Future<void> _handleToggleWatched() async {
    final result = await ref
        .read(tvDetailNotifierProvider(widget.guid).notifier)
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

  Future<bool> _handleToggleSeasonWatched(
      String seasonGuid, bool isWatched) async {
    final result = await ref
        .read(tvDetailNotifierProvider(widget.guid).notifier)
        .toggleSeasonWatched(seasonGuid, isWatched);
    if (!mounted) return false;
    if (result.success) {
      _toastManager.showToast(
        result.message,
        type: ToastType.success,
        category: 'season_watched_$seasonGuid',
      );
    } else {
      _toastManager.showToast(
        '操作失败，${result.message}',
        type: ToastType.failed,
        category: 'season_watched_$seasonGuid',
      );
    }
    return result.success;
  }

  Future<void> _playMedia() async {
    final playInfo = widget.state.playInfo;
    if (playInfo == null) return;

    final targetGuid = playInfo.item.guid.isNotEmpty ? playInfo.item.guid : widget.guid;
    ref.read(navigationStackProvider.notifier).pushPath('/home');
    context.go('/player/$targetGuid');
  }

  void _showDescriptionDialog(ItemResponse item) {
    showDialog(
      context: context,
      builder: (_) => MediaDescriptionDialog(
        title: '剧集简介',
        content: (item.overview ?? '暂无介绍').replaceAll('\n\n', '\n'),
      ),
    );
  }

  void _showMoreFlyout(ItemResponse item) {
    if (_moreController.isOpen) {
      _moreController.close();
      return;
    }

    _moreController.showFlyout<void>(
      placementMode: FlyoutPlacementMode.bottomCenter,
      builder: (context) => MenuFlyout(
        items: [
          MenuFlyoutItem(
            text: const Text('刷新页面'),
            onPressed: () {
              Flyout.of(context).close();
              ref
                  .read(tvDetailNotifierProvider(widget.guid).notifier)
                  .refresh();
            },
          ),
          if (item.imdbId != null && item.imdbId!.isNotEmpty)
            MenuFlyoutItem(
              text: const Text('在 IMDb 上查看'),
              onPressed: () {
                Flyout.of(context).close();
                launchUrl(Uri.parse(FnDataConvertor.getImdbLink(item.imdbId)));
              },
            ),
          MenuFlyoutItem(
            text: Text(item.isFavorite == 1 ? '取消收藏' : '加入收藏'),
            onPressed: () {
              Flyout.of(context).close();
              _handleToggleFavorite();
            },
          ),
          MenuFlyoutItem(
            text: Text(item.isWatched == 1 ? '标记为未看' : '标记为已看'),
            onPressed: () {
              Flyout.of(context).close();
              _handleToggleWatched();
            },
          ),
        ],
      ),
    );
  }

  String _buildPlayButtonText() {
    final playInfo = widget.state.playInfo;
    if (playInfo == null) return '播放';

    if (widget.state.seasonList.length == 1) {
      return '第 ${playInfo.item.episodeNumber} 集';
    }

    return '第 ${playInfo.item.seasonNumber} 季 第 ${playInfo.item.episodeNumber} 集';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.state.item;
    if (item == null) return const Center(child: Text('未找到剧集信息'));

    final windowHeight = MediaQuery.of(context).size.height;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    // Round to physical pixels to avoid a visible seam under the hero backdrop.
    final backdropHeight =
        (windowHeight * 0.5 * pixelRatio).roundToDouble() / pixelRatio;
    final backdropPath =
        (item.backdrops?.isNotEmpty ?? false) ? item.backdrops! : item.posters;
    final backdropUrl = _buildImageUrl(widget.baseUrl, backdropPath);
    final logoUrl =
        item.logos != null ? _buildImageUrl(widget.baseUrl, item.logos!) : '';

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: backdropHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (backdropUrl.isNotEmpty)
                      Positioned.fill(
                        child: Image(
                          image: CachedNetworkImageProvider(
                            backdropUrl,
                            headers: widget.httpHeaders,
                            cacheManager: widget.cacheManager,
                          ),
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
                padding: const EdgeInsets.fromLTRB(48, 24, 48, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActionRow(context, item),
                    if (item.overview != null && item.overview!.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      MediaDescription(
                        overview: item.overview!,
                        onMore: () => _showDescriptionDialog(item),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (widget.state.seasonList.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(48, 32, 48, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '剧季列表',
                        style: FluentTheme.of(context)
                            .typography
                            .subtitle
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      _SeasonListGrid(
                        seasons: widget.state.seasonList,
                        itemTitle: item.title,
                        scaleFactor: 1.0,
                        onWatchedToggle: (guid, isWatched) async {
                          return _handleToggleSeasonWatched(guid, isWatched);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            if (item.imdbId != null && item.imdbId!.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(48, 24, 48, 48),
                  child: ImdbLink(imdbId: item.imdbId!),
                ),
              ),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _handleBackNavigation(context),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.01),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 0.65, 0.85, 1.0],
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  FluentIcons.back,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ToastHost(toastManager: _toastManager),
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context, ItemResponse item) {
    final textColor = FluentTheme.of(context).typography.body?.color;
    final resolvedTextColor = textColor ?? Colors.white;
    final isFavorite = item.isFavorite == 1;
    final isWatched = item.isWatched == 1;
    final playButtonText = _buildPlayButtonText();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DetailPlayButton(
              key: const ValueKey('tv-detail-play'),
              text: playButtonText,
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
                  isFavorite ? const Color(0xFFFF0420) : resolvedTextColor,
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
            FlyoutTarget(
              controller: _moreController,
              child: CircleIconButton(
                icon: FluentIcons.more,
                iconColor: textColor,
                tooltip: '更多操作',
                onPressed: () => _showMoreFlyout(item),
              ),
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
                iso3166Map: widget.state.iso3166,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeasonListGrid extends StatelessWidget {
  final List<SeasonListResponse> seasons;
  final String itemTitle;
  final double scaleFactor;
  final Future<bool> Function(String guid, bool isWatched) onWatchedToggle;

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
      const spacing = 16.0;

      final itemsPerRow =
          ((availableWidth + spacing) / (posterMinWidth + spacing))
              .floor()
              .clamp(1, 10);
      double itemWidth;
      if (itemsPerRow >= 4) {
        final totalSpacing = spacing * (itemsPerRow - 1);
        itemWidth = ((availableWidth - totalSpacing) / itemsPerRow)
            .clamp(posterMinWidth, posterMaxWidth);
      } else {
        itemWidth = posterMinWidth;
      }
      final itemHeight = itemWidth * 1.5;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: seasons.map((season) {
          final episodeNumber = season.episodeNumber > 0
              ? season.episodeNumber
              : season.localNumberOfEpisodes;
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
              onWatchedToggle: (guid, currentState, callback) async {
                final success = await onWatchedToggle(guid, currentState);
                callback(success);
              },
              resolutions: season.mediaStream.resolutions,
              onPlayTap: () {
                context.go('/tv/season/${season.guid}');
              },
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
      // Keep the title box stable before the logo finishes loading.
      final aspectRatio = imgHeight > 0 ? imgWidth / imgHeight : 1.0;
      final nextHeight =
          aspectRatio > 0 && aspectRatio < 280.0 / 90.0 ? 150.0 : 90.0;
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
