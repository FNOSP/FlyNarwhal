import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/home_models.dart';
import '../../providers/providers.dart';
import 'img_loading_progress_ring.dart';
import 'scroll_row.dart';

// Accent color for watched state
const Color kAccentColorDefault = Color(0xFF2173DF);
// Danger color for favorite state
const Color kDangerDefaultColor = Color(0xFFFF0420);

class RecentlyWatched extends ConsumerWidget {
  final String title;
  final List<PlayDetailResponse> items;
  final double itemHeight;
  final EdgeInsetsGeometry padding;
  final Function(
          String guid, bool currentState, Function(bool success) callback)?
      onFavoriteToggle;
  final Function(
          String guid, bool currentState, Function(bool success) callback)?
      onWatchedToggle;
  final Function(String guid)? onItemRemoved;

  const RecentlyWatched({
    super.key,
    required this.title,
    required this.items,
    this.itemHeight = 190,
    this.padding = const EdgeInsets.symmetric(horizontal: 32),
    this.onFavoriteToggle,
    this.onWatchedToggle,
    this.onItemRemoved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final scaleFactor = resolveWindowScaleFactor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 12),
          child:
              Text(title, style: FluentTheme.of(context).typography.subtitle),
        ),
        ScrollRow(
          height: itemHeight * scaleFactor,
          padding: padding,
          itemSpacing: 16 * scaleFactor,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return RecentlyWatchedItem(
              key: ValueKey('recently-watched-item-$index'),
              item: item,
              itemIndex: index,
              onFavoriteToggle: onFavoriteToggle,
              onWatchedToggle: onWatchedToggle,
              onItemRemoved: onItemRemoved,
            );
          },
        ),
      ],
    );
  }
}

class RecentlyWatchedItem extends ConsumerStatefulWidget {
  final PlayDetailResponse item;
  final int itemIndex;
  final Function(
          String guid, bool currentState, Function(bool success) callback)?
      onFavoriteToggle;
  final Function(
          String guid, bool currentState, Function(bool success) callback)?
      onWatchedToggle;
  final Function(String guid)? onItemRemoved;

  const RecentlyWatchedItem({
    super.key,
    required this.item,
    required this.itemIndex,
    this.onFavoriteToggle,
    this.onWatchedToggle,
    this.onItemRemoved,
  });

  @override
  ConsumerState<RecentlyWatchedItem> createState() =>
      _RecentlyWatchedItemState();
}

class _RecentlyWatchedItemState extends ConsumerState<RecentlyWatchedItem>
    with SingleTickerProviderStateMixin {
  bool _isPlayButtonHovered = false;
  bool _isFavorite = false;
  bool _isWatched = false;
  bool _isVisible = true;
  bool _isRemoved = false;
  Timer? _removeTimer;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.item.isFavorite == 1;
    _isWatched = widget.item.watched == 1;
  }

  @override
  void didUpdateWidget(covariant RecentlyWatchedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.guid != widget.item.guid) {
      _isFavorite = widget.item.isFavorite == 1;
      _isWatched = widget.item.watched == 1;
      _isVisible = true;
      _isRemoved = false;
      _removeTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _removeTimer?.cancel();
    super.dispose();
  }

  void _handleFavoriteToggle() {
    widget.onFavoriteToggle?.call(
      widget.item.guid,
      _isFavorite,
      (success) {
        if (success) {
          setState(() {
            _isFavorite = !_isFavorite;
          });
        }
      },
    );
  }

  void _handleWatchedToggle() {
    widget.onWatchedToggle?.call(
      widget.item.guid,
      _isWatched,
      (success) {
        if (success && !_isWatched) {
          // Mark as watched, trigger remove animation
          setState(() {
            _isWatched = true;
            _isVisible = false;
          });
          // Wait for animation then remove
          _removeTimer = Timer(const Duration(milliseconds: 500), () {
            widget.onItemRemoved?.call(widget.item.guid);
            setState(() {
              _isRemoved = true;
            });
          });
        } else if (success) {
          setState(() {
            _isWatched = !_isWatched;
          });
        }
      },
    );
  }

  void _handleItemNavigation(BuildContext context) {
    final itemGuid = widget.item.guid.trim();
    if (itemGuid.isEmpty) {
      return;
    }

    switch (widget.item.type?.trim()) {
      case 'Movie':
      case 'Video':
        ref.read(navigationStackProvider.notifier).pushPath('/home');
        context.go('/movie/$itemGuid');
        return;
      case 'Episode':
        final parentGuid = widget.item.parentGuid?.trim();
        if (parentGuid == null || parentGuid.isEmpty) {
          return;
        }
        context.go('/tv/season/$parentGuid');
        return;
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRemoved) {
      return const SizedBox.shrink();
    }

    final theme = FluentTheme.of(context);
    final prefs = ref.watch(preferencesManagerProvider);
    final baseUrl = prefs.getBaseUrl();
    final token = prefs.getToken();
    final cookie = prefs.getCookie();
    final resolvedPosterPath = widget.item.poster?.trim();
    final imageUrl = resolvedPosterPath != null &&
            resolvedPosterPath.isNotEmpty &&
            baseUrl != null
        ? '$baseUrl/v/api/v1/sys/img$resolvedPosterPath${resolvedPosterPath.contains('?') ? '' : '?w=400'}'
        : null;
    final httpHeaders = token != null || (cookie != null && cookie.isNotEmpty)
        ? {
            if (token != null) 'Authorization': token,
            if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
          }
        : null;
    final cacheManager = ref.watch(imageCacheManagerProvider);
    final watchedTs = widget.item.ts ?? 0;
    final duration = widget.item.duration ?? 0;
    final progress =
        duration > 0 ? (watchedTs / duration).clamp(0.0, 1.0) : 0.0;
    final displayTitle = buildPlayDetailTitle(widget.item);
    final displaySubtitle = buildPlayDetailSubtitle(widget.item);
    final scaleFactor = resolveWindowScaleFactor(context);
    final posterWidth = 240 * scaleFactor;
    final normalPlayButtonSize = 48.0 * scaleFactor;
    final hoveredPlayButtonSize = 56.0 * scaleFactor;
    final playButtonSize =
        _isPlayButtonHovered ? hoveredPlayButtonSize : normalPlayButtonSize;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _isVisible ? 1.0 : 0.0,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: HoverButton(
            onPressed: () => _handleItemNavigation(context),
            builder: (context, states) {
              final isHovered = states.isHovered;
              return SizedBox(
                width: posterWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14 * scaleFactor),
                          border: Border.all(
                              color: Colors.grey[160].withValues(alpha: 0.6)),
                          color: Colors.grey[160],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (imageUrl != null)
                              CachedNetworkImage(
                                imageUrl: imageUrl,
                                httpHeaders: httpHeaders,
                                cacheManager: cacheManager,
                                fit: BoxFit.cover,
                                fadeOutDuration:
                                    const Duration(milliseconds: 120),
                                errorWidget: (context, url, error) =>
                                    const Center(
                                        child: Icon(FluentIcons.error)),
                                placeholder: (context, url) =>
                                    const ImgLoadingProgressRing(),
                              )
                            else
                              const Center(child: Icon(FluentIcons.file_image)),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: SizedBox(
                                width: double.infinity,
                                height: 5,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(
                                        color: Colors.white
                                            .withValues(alpha: 0.05)),
                                    if (progress > 0)
                                      FractionallySizedBox(
                                        widthFactor: progress,
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                            color: const Color(0xFF2073DF)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isHovered ? 1 : 0,
                              child: Container(
                                color: const Color(0xFF1C1C1C)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            Center(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: isHovered ? 1 : 0,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) => setState(
                                      () => _isPlayButtonHovered = true),
                                  onExit: (_) => setState(
                                      () => _isPlayButtonHovered = false),
                                  child: GestureDetector(
                                    key: ValueKey(
                                      'recently-watched-play-${widget.itemIndex}',
                                    ),
                                    onTap: () {
                                      ref
                                          .read(
                                              navigationStackProvider.notifier)
                                          .pushPath('/home');
                                      context.go('/player/${widget.item.guid}');
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: playButtonSize,
                                      height: playButtonSize,
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
                              right: 8,
                              bottom: 8,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: isHovered ? 1 : 0,
                                child: Row(
                                  children: [
                                    _PosterIconButton(
                                      svgAssetPath: _isWatched
                                          ? 'assets/images/watched_fill.svg'
                                          : 'assets/images/watched.svg',
                                      isActive: _isWatched,
                                      activeColor: kAccentColorDefault,
                                      scaleFactor: scaleFactor,
                                      onPressed: _handleWatchedToggle,
                                    ),
                                    _PosterIconButton(
                                      svgAssetPath: _isFavorite
                                          ? 'assets/images/favorite_fill.svg'
                                          : 'assets/images/favorite.svg',
                                      isActive: _isFavorite,
                                      activeColor: kDangerDefaultColor,
                                      scaleFactor: scaleFactor,
                                      onPressed: _handleFavoriteToggle,
                                    ),
                                    _PosterIconButton(
                                      icon: FluentIcons.more,
                                      isActive: false,
                                      activeColor: Colors.white,
                                      scaleFactor: scaleFactor,
                                      onPressed: () {},
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: posterWidth,
                      child: Text(
                        displayTitle,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption?.copyWith(
                          fontWeight: FontWeight.normal,
                          fontSize: 12,
                          color: isHovered
                              ? const Color(0xFF2073DF)
                              : theme.typography.body?.color,
                        ),
                      ),
                    ),
                    if (displaySubtitle != null) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        width: posterWidth,
                        child: Text(
                          displaySubtitle,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption?.copyWith(
                            fontWeight: FontWeight.normal,
                            fontSize: 12,
                            color: theme.typography.caption?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Poster icon button with hover effect
class _PosterIconButton extends StatefulWidget {
  final IconData? icon;
  final String? svgAssetPath;
  final bool isActive;
  final Color activeColor;
  final double scaleFactor;
  final VoidCallback? onPressed;

  const _PosterIconButton({
    this.icon,
    this.svgAssetPath,
    required this.isActive,
    required this.activeColor,
    required this.scaleFactor,
    this.onPressed,
  });

  @override
  State<_PosterIconButton> createState() => _PosterIconButtonState();
}

class _PosterIconButtonState extends State<_PosterIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final iconSize = 16.0 * widget.scaleFactor;
    final buttonSize = 28.0 * widget.scaleFactor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Hover background
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: _isHovered
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
              // Icon
              if (widget.svgAssetPath != null)
                SvgPicture.asset(
                  widget.svgAssetPath!,
                  width: iconSize,
                  height: iconSize,
                  colorFilter: ColorFilter.mode(
                    widget.isActive ? widget.activeColor : Colors.white,
                    BlendMode.srcIn,
                  ),
                )
              else if (widget.icon != null)
                Icon(
                  widget.icon,
                  size: iconSize,
                  color: widget.isActive ? widget.activeColor : Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
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
