import 'package:fluent_ui/fluent_ui.dart';

import '../../../../data/models/home_models.dart';
import '../../../../domain/entities/media_type.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../shared/common/fn_cached_image.dart';
import '../../../shared/common/media_poster_placeholder.dart';
import '../../../shared/common/poster_resolution_tags.dart'
    show normalizePosterResolutions;
import '../tv_theme.dart';
import 'tv_focusable.dart';

/// Shelf poster card (design `.poster-card`): 240×360 poster with gold rating
/// and resolution badges plus a centered static title drawer.
class TvPosterCard extends StatefulWidget {
  const TvPosterCard({
    super.key,
    required this.item,
    this.onActivate,
    this.order = 200,
  });

  final MediaItem item;

  /// Poster cards are focusable for arrow traversal; this stays null until
  /// the TV detail pages exist.
  final VoidCallback? onActivate;
  final int order;

  @override
  State<TvPosterCard> createState() => _TvPosterCardState();
}

class _TvPosterCardState extends State<TvPosterCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = widget.item;

    final rating = double.tryParse(item.voteAverage?.trim() ?? '');
    final ratingText =
        (rating != null && rating > 0) ? rating.toStringAsFixed(1) : null;
    final resLabel = _resolutionLabel(item.mediaStream?.resolutions);
    final subtitle = buildPosterSubtitle(item, l10n) ?? '';

    return TvFocusable(
      key: ValueKey('tv-poster-card-${item.guid}'),
      order: widget.order,
      onActivate: widget.onActivate,
      onFocusChanged: (focused) => setState(() => _focused = focused),
      ringRadius: BorderRadius.circular(TvTheme.radiusPoster),
      child: SizedBox(
        width: TvTheme.posterCardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: TvTheme.posterCardWidth,
              height: TvTheme.posterHeight,
              decoration: BoxDecoration(
                color: TvTheme.bgElevated,
                borderRadius: BorderRadius.circular(TvTheme.radiusPoster),
                boxShadow: TvTheme.shadowCard,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Poster(item: item),
                  if (ratingText != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: TvTheme.ratingGold.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(ratingText, style: TvTheme.posterRate),
                      ),
                    ),
                  if (resLabel != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xB80A0A0B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: TvTheme.borderStrong,
                          ),
                        ),
                        child: Text(resLabel, style: TvTheme.posterRes),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Column(
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: _focused
                        ? TvTheme.posterCardTitleFocused
                        : TvTheme.posterCardTitle,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TvTheme.posterCardSubtitle,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// First standard resolution rendered the design's way: `4K` uppercased,
/// `1080p` with the trailing p stripped (`1080`).
String? _resolutionLabel(List<String>? resolutions) {
  final normalized = normalizePosterResolutions(resolutions);
  if (normalized.isEmpty) {
    return null;
  }
  final first = normalized.first.trim();
  final lower = first.toLowerCase();
  if (lower.endsWith('k')) {
    return first.toUpperCase();
  }
  if (lower.endsWith('p')) {
    return first.substring(0, first.length - 1);
  }
  return first;
}

class _Poster extends StatelessWidget {
  const _Poster({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final poster = item.effectivePoster?.trim() ?? '';
    if (poster.isEmpty) {
      return Center(
        child: MediaPosterPlaceholder(type: MediaType.tryParse(item.type)),
      );
    }
    return FnCachedImage(
      posterPath: poster,
      fit: BoxFit.cover,
      errorWidget: Center(
        child: MediaPosterPlaceholder(type: MediaType.tryParse(item.type)),
      ),
    );
  }
}
