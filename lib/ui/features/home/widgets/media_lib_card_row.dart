import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' as cache_manager;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/home_models.dart';
import '../../../../domain/entities/media_type.dart';
import '../../../../providers/providers.dart';
import '../../../shared/common/img_loading_progress_ring.dart';
import '../../../shared/common/media_poster_placeholder.dart';
import '../../../shared/common/scroll_row.dart';

class MediaLibCardRow extends ConsumerWidget {
  final List<MediaDbListResponse> items;
  final ValueChanged<MediaDbListResponse> onItemClick;

  const MediaLibCardRow({
    super.key,
    required this.items,
    required this.onItemClick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scaleFactor = resolveWindowScaleFactor(context);
    final prefs = ref.watch(preferencesManagerProvider);
    final baseUrl = prefs.getBaseUrl();
    final token = prefs.getToken();
    final cookie = prefs.getCookie();
    final httpHeaders = token != null || (cookie != null && cookie.isNotEmpty)
        ? {
            if (token != null) 'Authorization': token,
            if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
          }
        : null;
    final itemHeight = 160 * scaleFactor;
    final cacheManager = ref.watch(imageCacheManagerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 12),
          child: Text(
            '媒体库',
            style: FluentTheme.of(context).typography.subtitle?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ScrollRow(
          height: itemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          itemSpacing: 16 * scaleFactor,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: HoverButton(
                key: ValueKey('media-lib-card-${item.title}'),
                onPressed: () => onItemClick(item),
                builder: (context, states) {
                  return MediaLibraryCard(
                    title: item.title,
                    posters: item.posters,
                    category: item.category,
                    baseUrl: baseUrl,
                    httpHeaders: httpHeaders,
                    scaleFactor: scaleFactor,
                    isHovered: states.isHovered,
                    cacheManager: cacheManager,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class MediaLibraryCard extends StatelessWidget {
  final String title;
  final List<String> posters;
  final String category;
  final String? baseUrl;
  final Map<String, String>? httpHeaders;
  final double scaleFactor;
  final bool isHovered;
  final cache_manager.CacheManager cacheManager;

  const MediaLibraryCard({
    super.key,
    required this.title,
    required this.posters,
    required this.category,
    required this.baseUrl,
    required this.httpHeaders,
    required this.scaleFactor,
    required this.isHovered,
    required this.cacheManager,
  });

  @override
  Widget build(BuildContext context) {
    // 与 Web 首页媒体库卡片一致：IPTV 库无封面时显示直播占位图，
    // 其余库显示通用"无封面"占位图。
    final placeholderType =
        category == 'IPTV' ? MediaType.liveChannel : MediaType.video;
    final visiblePosters =
        posters.where((p) => p.trim().isNotEmpty).take(4).toList();
    final borderRadius = 12 * scaleFactor;
    final innerRadius = (borderRadius - 2).clamp(0.0, double.infinity);
    final width = 240 * scaleFactor;

    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.grey[120].withValues(alpha: 0.6)),
            color: Colors.transparent,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(4 * scaleFactor),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(innerRadius),
                    color: Colors.grey[20].withValues(alpha: 0.12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            flex: 7,
                            child: _PosterRow(
                              posters: visiblePosters,
                              placeholderType: placeholderType,
                              baseUrl: baseUrl,
                              httpHeaders: httpHeaders,
                              cacheManager: cacheManager,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..scaleByDouble(1.0, -1.0, 1.0, 1.0),
                              child: _PosterRow(
                                posters: visiblePosters,
                                placeholderType: placeholderType,
                                baseUrl: baseUrl,
                                httpHeaders: httpHeaders,
                                cacheManager: cacheManager,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          widthFactor: 1,
                          heightFactor: 0.3,
                          child: Container(
                            color: const Color(0xE61C1C1C),
                            alignment: Alignment.center,
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FluentTheme.of(context).typography.caption?.copyWith(
                                fontWeight: FontWeight.normal,
                                fontSize: 14 * scaleFactor,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isHovered ? 1 : 0,
                child: Container(
                  color: const Color(0xFF1C1C1C).withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterRow extends StatelessWidget {
  final List<String> posters;
  final MediaType placeholderType;
  final String? baseUrl;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;

  const _PosterRow({
    required this.posters,
    required this.placeholderType,
    required this.baseUrl,
    required this.httpHeaders,
    required this.cacheManager,
  });

  @override
  Widget build(BuildContext context) {
    if (posters.isEmpty) {
      return Container(
        color: Colors.grey[140].withValues(alpha: 0.2),
        alignment: Alignment.center,
        child: MediaPosterPlaceholder(type: placeholderType),
      );
    }

    final widthFactor = (posters.length / 4).clamp(0.0, 1.0);
    return Align(
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: SizedBox.expand(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: posters.map((poster) {
              return Expanded(
                child: _PosterImage(
                  poster: poster,
                  placeholderType: placeholderType,
                  baseUrl: baseUrl,
                  httpHeaders: httpHeaders,
                  cacheManager: cacheManager,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  final String poster;
  final MediaType placeholderType;
  final String? baseUrl;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;

  const _PosterImage({
    required this.poster,
    required this.placeholderType,
    required this.baseUrl,
    required this.httpHeaders,
    required this.cacheManager,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = _buildPosterUrl(baseUrl, poster);
    if (imageUrl == null) {
      return Container(
        color: Colors.grey[140].withValues(alpha: 0.2),
        alignment: Alignment.center,
        child: MediaPosterPlaceholder(type: placeholderType),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      httpHeaders: httpHeaders,
      cacheManager: cacheManager,
      fit: BoxFit.cover,
      fadeOutDuration: const Duration(milliseconds: 120),
      errorWidget: (context, url, error) => const Center(child: Icon(FluentIcons.error)),
      placeholder: (context, url) => const ImgLoadingProgressRing(),
    );
  }
}

String? _buildPosterUrl(String? baseUrl, String poster) {
  final trimmed = poster.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  if (baseUrl == null) return null;
  final suffix = trimmed.contains('?') ? '' : '?w=400';
  return '$baseUrl/v/api/v1/sys/img$trimmed$suffix';
}

double resolveWindowScaleFactor(BuildContext context) {
  final windowWidth = MediaQuery.of(context).size.width;
  final windowScaleFactor = windowWidth / 1280.0;
  if (windowScaleFactor == 1) {
    return 1;
  }
  final scaled = 1 + (windowScaleFactor - 1) * 0.3;
  return scaled.clamp(1.0, 1.3);
}
