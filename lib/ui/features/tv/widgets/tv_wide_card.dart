import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../data/models/home_models.dart';
import '../../../../data/utils/fn_data_convertor.dart';
import '../../../../domain/entities/media_type.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../shared/common/fn_cached_image.dart';
import '../../../shared/common/media_poster_placeholder.dart';
import '../tv_theme.dart';
import 'tv_focusable.dart';

/// "Continue watching" wide card (design `.wide-card`): 400×225 thumb with
/// resume affordance + episode tag, title/position/progress below.
class TvWideCard extends StatefulWidget {
  const TvWideCard({
    super.key,
    required this.item,
    this.onActivate,
    this.onFocusGained,
    this.order = 100,
  });

  final PlayDetailResponse item;
  final VoidCallback? onActivate;
  final VoidCallback? onFocusGained;
  final int order;

  @override
  State<TvWideCard> createState() => _TvWideCardState();
}

class _TvWideCardState extends State<TvWideCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    final isEpisode = MediaType.tryParse(item.type) == MediaType.episode;

    final duration = item.duration ?? 0;
    final watchedTs =
        (item.ts ?? 0).clamp(0, duration > 0 ? duration : 1 << 31);
    final progress =
        duration > 0 ? (watchedTs / duration).clamp(0.0, 1.0) : 0.0;

    String formatSeconds(int seconds) =>
        FnDataConvertor.formatSecondsToCNDateTime(seconds, l10n: l10n);

    final positionText = duration > 0
        ? l10n.tvCardPlayedOf(
            formatSeconds(watchedTs),
            formatSeconds(duration),
          )
        : (buildPlayDetailSubtitle(item, l10n) ?? '');

    return TvFocusable(
      key: ValueKey('tv-resume-card-${item.guid}'),
      order: widget.order,
      onActivate: widget.onActivate,
      onFocusGained: widget.onFocusGained,
      onFocusChanged: (focused) => setState(() => _focused = focused),
      ringRadius: BorderRadius.circular(TvTheme.radiusCard),
      child: SizedBox(
        width: TvTheme.wideCardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: TvTheme.wideCardWidth,
              height: TvTheme.wideThumbHeight,
              decoration: BoxDecoration(
                color: TvTheme.bgElevated,
                borderRadius: BorderRadius.circular(TvTheme.radiusCard),
                boxShadow: TvTheme.shadowCard,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Thumb(item: item),
                  // Bottom scrim (`.wide-thumb .overlay`).
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xD90A0A0B), Color(0x000A0A0B)],
                        stops: [0.0, 0.55],
                      ),
                    ),
                  ),
                  if (isEpisode)
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xB30A0A0B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: TvTheme.border),
                        ),
                        child: Text(
                          'S${item.seasonNumber} · E${item.episodeNumber}',
                          style: TvTheme.epTag,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 18,
                    bottom: 16,
                    child: Row(
                      children: [
                        SvgPicture.string(
                          _resumeIconSvg(
                            _focused
                                ? 'rgba(51,136,255,0.9)'
                                : 'rgba(255,255,255,0.22)',
                          ),
                          width: 30,
                          height: 30,
                        ),
                        if (duration > 0) ...[
                          const SizedBox(width: 10),
                          Text(
                            l10n.movieDetailRemaining(
                              formatSeconds(duration - watchedTs),
                            ),
                            style: TvTheme.resumeLabel,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: TvTheme.wideCardWidth - 8,
                    child: Text(
                      buildPlayDetailTitle(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TvTheme.wideCardTitle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    positionText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TvTheme.wideCardSubtitle,
                  ),
                  const SizedBox(height: 8),
                  TvProgressBar(progress: progress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _resumeIconSvg(String circleFill) =>
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
    '<circle cx="12" cy="12" r="11" fill="$circleFill"/>'
    '<path d="M10 8v8l6.5-4L10 8Z" fill="#fff"/>'
    '</svg>';

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item});

  final PlayDetailResponse item;

  @override
  Widget build(BuildContext context) {
    final poster = item.poster?.trim() ?? '';
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

/// 6px progress bar with the blue gradient fill + glow (design `.progress`).
class TvProgressBar extends StatelessWidget {
  const TvProgressBar({super.key, required this.progress});

  /// 0..1
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 6,
        color: TvTheme.fill2,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [TvTheme.brandDeep, TvTheme.brandBright],
              ),
              boxShadow: [BoxShadow(color: TvTheme.brandGlow, blurRadius: 10)],
            ),
          ),
        ),
      ),
    );
  }
}
