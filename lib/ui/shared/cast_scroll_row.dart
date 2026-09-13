import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    as cache_manager;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/movie_detail_models.dart';
import '../../providers/providers.dart';
import '../shared/common/scroll_row.dart';

class CastScrollRow extends StatelessWidget {
  final String title;
  final List<PersonList> persons;
  final String baseUrl;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;
  final double height;
  final double itemSpacing;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  /// Width of a single cast item. Exposed so callers can compute the scroll
  /// offset needed to bring a given person to the leading edge.
  static const double itemWidth = 80;

  static const double defaultItemSpacing = 16;

  const CastScrollRow({
    super.key,
    required this.persons,
    required this.baseUrl,
    required this.httpHeaders,
    required this.cacheManager,
    this.title = '演职人员',
    this.height = 112,
    this.itemSpacing = defaultItemSpacing,
    this.padding = const EdgeInsets.symmetric(horizontal: 32),
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (persons.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 12),
          child: Text(
            title,
            style: FluentTheme.of(context).typography.subtitle?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        ScrollRow(
          itemCount: persons.length,
          itemBuilder: (context, index) {
            final person = persons[index];
            return _CastAvatar(
              // Index is part of the key because the same person can appear
              // multiple times (e.g. as both director and actor).
              key: ValueKey('cast-${person.personGuid}-$index'),
              person: person,
              baseUrl: baseUrl,
              httpHeaders: httpHeaders,
              cacheManager: cacheManager,
            );
          },
          height: height,
          padding: padding,
          itemSpacing: itemSpacing,
          controller: controller,
        ),
      ],
    );
  }
}

class _CastAvatar extends ConsumerStatefulWidget {
  final PersonList person;
  final String baseUrl;
  final Map<String, String>? httpHeaders;
  final cache_manager.CacheManager cacheManager;

  const _CastAvatar({
    super.key,
    required this.person,
    required this.baseUrl,
    required this.httpHeaders,
    required this.cacheManager,
  });

  @override
  ConsumerState<_CastAvatar> createState() => _CastAvatarState();
}

class _CastAvatarState extends ConsumerState<_CastAvatar> {
  bool _hovered = false;

  // Mirrors the web personJobMap (common.person.job.*): known jobs are shown
  // localized, anything else falls back to the raw job string.
  static const Map<String, String> _jobLabels = {
    'Director': '导演',
    'Screenplay': '编剧',
    'Writer': '编剧',
    'Producer': '制片人',
    'Actor': '演员',
  };

  // Navigate to person detail page, mirroring Compose CastAvatar
  void _handleTap() {
    final personGuid = widget.person.personGuid;
    if (personGuid.isEmpty) return;
    final currentUri = GoRouterState.of(context).uri.toString();
    ref.read(navigationStackProvider.notifier).pushPath(currentUri);
    // Remember the clicked person so the originating page can scroll back
    // to it when the user returns (mirrors the Web behavior).
    ref.read(castScrollReturnTargetProvider.notifier).state =
        CastScrollReturnTarget(
      mediaPath: currentUri,
      personGuid: personGuid,
    );
    context.go('/person/$personGuid');
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _buildImageUrl(widget.baseUrl, widget.person.profilePath);
    final nameColor = _hovered
        ? FluentTheme.of(context).accentColor
        : FluentTheme.of(context).typography.body?.color;
    final person = widget.person;
    final displayName = person.name.trim().isNotEmpty
        ? person.name
        : person.originalName.trim();
    // Web: actors show "饰 <role>", other jobs show the localized job label.
    final role = person.job == 'Actor'
        ? '饰 ${person.role}'
        : _jobLabels[person.job] ?? person.job;

    return SizedBox(
      width: CastScrollRow.itemWidth,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: _handleTap,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      // border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: ClipOval(
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              httpHeaders: widget.httpHeaders,
                              cacheManager: widget.cacheManager,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  const _PersonPlaceholder(),
                              errorWidget: (context, url, error) =>
                                  const _PersonPlaceholder(),
                            )
                          : const _PersonPlaceholder(),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _hovered ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1C).withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Persons without any stored name (e.g. an unscraped director)
              // only show their job line, like the web cast row.
              if (displayName.isNotEmpty) ...[
                Text(
                  displayName,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        fontSize: 12,
                        color: nameColor,
                      ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
              Text(
                role,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                      fontSize: 12,
                      color: FluentTheme.of(context)
                          .typography
                          .caption
                          ?.color
                          ?.withValues(alpha: 0.6),
                    ),
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 无头像时的占位图,与 Web 端一致:深色圆底 + 居中人形剪影(剪影尺寸
/// 约为圆直径的 53%,对应 Web 端 90px 圆内的 48px 图片)。
class _PersonPlaceholder extends StatelessWidget {
  const _PersonPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC202021),
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/person_placeholder.png',
        width: 34,
        height: 34,
        fit: BoxFit.contain,
      ),
    );
  }
}

String _buildImageUrl(String baseUrl, String path) {
  if (baseUrl.isEmpty || path.isEmpty) return '';
  final normalizedBaseUrl = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return '$normalizedBaseUrl/v/api/v1/sys/img$path';
}
