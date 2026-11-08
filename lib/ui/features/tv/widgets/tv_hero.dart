import 'dart:async';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../data/models/home_models.dart';
import '../../../../data/utils/fn_data_convertor.dart';
import '../../../../domain/entities/media_type.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../shared/common/fn_cached_image.dart';
import '../tv_theme.dart';
import 'tv_focusable.dart';

/// Hero spotlight (design `.hero`, home.html override height 580): the
/// focused continue-watching item's blurred art + metadata. When the focused
/// item changes, the body fades out (110ms), swaps, then fades back in
/// (body 160ms / art 220ms) — the design's staggered transition.
class TvHero extends StatefulWidget {
  const TvHero(
      {super.key, required this.item, this.onPlay, this.playOrder = 50});

  final PlayDetailResponse? item;
  final VoidCallback? onPlay;

  /// Focus order of the primary button (cards use 0..n).
  final int playOrder;

  @override
  State<TvHero> createState() => _TvHeroState();
}

class _TvHeroState extends State<TvHero> {
  PlayDetailResponse? _displayed;
  double _bodyOpacity = 1;
  double _artOpacity = 1;
  Duration _bodyDuration = Duration.zero;
  Duration _artDuration = Duration.zero;
  Timer? _swapTimer;

  @override
  void initState() {
    super.initState();
    _displayed = widget.item;
  }

  @override
  void didUpdateWidget(TvHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.item;
    if (next?.guid == _displayed?.guid) {
      // Same item; keep any in-flight transition, but adopt a first value.
      if (_displayed == null && next != null) {
        setState(() {
          _displayed = next;
          _bodyOpacity = 1;
          _artOpacity = 1;
        });
      }
      return;
    }
    if (next == null) {
      _swapTimer?.cancel();
      setState(() {
        _displayed = null;
        _bodyOpacity = 1;
        _artOpacity = 1;
      });
      return;
    }
    if (_displayed == null) {
      setState(() {
        _displayed = next;
        _bodyOpacity = 1;
        _artOpacity = 1;
      });
      return;
    }

    // Phase 1: fade out (body 110ms, art to 25% 110ms).
    _swapTimer?.cancel();
    setState(() {
      _bodyDuration = const Duration(milliseconds: 110);
      _artDuration = const Duration(milliseconds: 110);
      _bodyOpacity = 0;
      _artOpacity = 0.25;
    });
    // Phase 2: swap content and fade back in (body 160ms, art 220ms).
    _swapTimer = Timer(const Duration(milliseconds: 110), () {
      if (!mounted) return;
      setState(() {
        _displayed = next;
        _bodyDuration = const Duration(milliseconds: 160);
        _artDuration = const Duration(milliseconds: 220);
        _bodyOpacity = 1;
        _artOpacity = 1;
      });
    });
  }

  @override
  void dispose() {
    _swapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = _displayed;

    return SizedBox(
      height: TvTheme.heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: _artOpacity,
            duration: _artDuration,
            child: _HeroArt(item: item),
          ),
          // Three-layer scrim (`.hero-scrim`).
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB8101011), Color(0x00101011)],
                  stops: [0.0, 0.22],
                ),
              ),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xF0101011),
                    Color(0xB8101011),
                    Color(0x00101011)
                  ],
                  stops: [0.0, 0.34, 0.68],
                ),
              ),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [TvTheme.bgBase, Color(0x00101011)],
                  stops: [0.0, 0.46],
                ),
              ),
            ),
          ),
          Positioned(
            left: TvTheme.heroBodyLeft,
            bottom: TvTheme.heroBodyBottom,
            child: AnimatedOpacity(
              opacity: _bodyOpacity,
              duration: _bodyDuration,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: TvTheme.heroBodyMaxWidth,
                ),
                child: item == null
                    ? const SizedBox.shrink()
                    : _HeroBody(
                        item: item,
                        onPlay: widget.onPlay,
                        playOrder: widget.playOrder,
                        remainingText: _remainingText(item, l10n),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _remainingText(PlayDetailResponse item, AppLocalizations l10n) {
    final duration = item.duration ?? 0;
    if (duration <= 0) return null;
    final watched = (item.ts ?? 0).clamp(0, duration);
    final percent = ((watched / duration) * 100).round();
    return l10n.tvHeroWatchedRemaining(
      '$percent',
      FnDataConvertor.formatSecondsToCNDateTime(duration - watched, l10n: l10n),
    );
  }
}

class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.item});

  final PlayDetailResponse? item;

  @override
  Widget build(BuildContext context) {
    final poster = item?.poster?.trim() ?? '';
    if (poster.isEmpty) {
      return const ColoredBox(color: TvTheme.bgBase);
    }
    // `.bgblur`: blur(26px) saturate(1.18) scale(1.32), dimmed to .88 via a
    // color matrix, covering the hero like `background-size: cover`.
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.88, 0, 0, 0, 0, //
            0, 0.88, 0, 0, 0, //
            0, 0, 0.88, 0, 0, //
            0, 0, 0, 1, 0, //
          ]),
          child: Transform.scale(
            scale: 1.32,
            child: FnCachedImage(
              posterPath: poster,
              fit: BoxFit.cover,
              errorWidget: const ColoredBox(color: TvTheme.bgBase),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBody extends StatelessWidget {
  const _HeroBody({
    required this.item,
    required this.playOrder,
    required this.remainingText,
    this.onPlay,
  });

  final PlayDetailResponse item;
  final int playOrder;
  final String? remainingText;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mediaType = MediaType.tryParse(item.type);
    final isEpisode = mediaType == MediaType.episode;
    final kickerSuffix = isEpisode
        ? 'S${item.seasonNumber} · E${item.episodeNumber}'
        : switch (mediaType) {
            MediaType.tv => l10n.mediaTypeTv,
            MediaType.liveChannel => l10n.mediaTypeLive,
            _ => l10n.mediaTypeMovie,
          };

    final rating = double.tryParse(item.voteAverage?.trim() ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kicker: 22×2 blue bar + label.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 2,
              decoration: const BoxDecoration(
                color: TvTheme.brand,
                boxShadow: [BoxShadow(color: TvTheme.brandGlow, blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.tvHeroKicker(kickerSuffix),
              style: TvTheme.heroKicker,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          buildPlayDetailTitle(item),
          style: TvTheme.heroTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            if (rating != null && rating > 0) ...[
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: rating.toStringAsFixed(1),
                      style: TvTheme.heroRatingNum,
                    ),
                    TextSpan(text: '/10', style: TvTheme.heroRatingOf),
                  ],
                ),
              ),
              if (remainingText != null) const _MetaDot(),
            ],
            if (remainingText != null)
              Text(remainingText!, style: TvTheme.heroMeta),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            TvButton(
              label: l10n.actionContinuePlay,
              iconSvg: _kIconPlay,
              primary: true,
              order: playOrder,
              onActivate: onPlay,
            ),
            const SizedBox(width: 16),
            TvButton(
              label: l10n.tvHeroDetails,
              iconSvg: _kIconInfo,
              enabled: false,
            ),
            const SizedBox(width: 16),
            TvButton(
              label: l10n.tvHeroFavorite,
              iconSvg: _kIconHeart,
              enabled: false,
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: TvTheme.text3,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Hero/empty-state pill button (design `.btn`, 64 high, 21/600 label).
class TvButton extends StatelessWidget {
  const TvButton({
    super.key,
    required this.label,
    required this.iconSvg,
    this.primary = false,
    this.enabled = true,
    this.onActivate,
    this.order = 100,
  });

  final String label;
  final String iconSvg;
  final bool primary;
  final bool enabled;
  final VoidCallback? onActivate;
  final int order;

  @override
  Widget build(BuildContext context) {
    final button = AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 150),
      child: Container(
        height: TvTheme.buttonHeight,
        padding: const EdgeInsets.symmetric(horizontal: 36),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TvTheme.radiusPill),
          gradient: primary
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [TvTheme.brand, TvTheme.brandDeep],
                )
              : null,
          color: primary ? null : const Color(0x1AFFFFFF),
          border: primary ? null : Border.all(color: TvTheme.borderStrong),
          boxShadow: primary
              ? const [
                  BoxShadow(
                    color: TvTheme.brandGlow,
                    blurRadius: 28,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(
              iconSvg,
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                TvTheme.text0,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            Text(label, style: TvTheme.buttonLabel),
          ],
        ),
      ),
    );

    if (!enabled) {
      return button;
    }
    return TvFocusable(
      order: order,
      onActivate: onActivate,
      ringRadius: BorderRadius.circular(TvTheme.radiusPill),
      child: button,
    );
  }
}

const String _kIconPlay =
    '<svg viewBox="0 0 24 24" fill="#fff" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M8 5.5v13l11-6.5-11-6.5Z"/></svg>';

const String _kIconInfo =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" '
    'xmlns="http://www.w3.org/2000/svg">'
    '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5M12 7.8v.4"/>'
    '</svg>';

const String _kIconHeart =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" '
    'xmlns="http://www.w3.org/2000/svg">'
    '<path d="M12 20s-7-4.4-7-9.4A4.1 4.1 0 0 1 12 7.6 4.1 4.1 0 0 1 19 10.6c0 5-7 9.4-7 9.4Z"/>'
    '</svg>';

/// Empty-state hero (design `.hero-empty`): centered guidance shown when
/// there is no continue-watching history. Its buttons render disabled this
/// phase (library/search have no TV pages yet).
class TvHeroEmpty extends StatelessWidget {
  const TvHeroEmpty({super.key, this.libraryTotal});

  /// Total media count for the description suffix; hidden when null.
  final int? libraryTotal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = libraryTotal;
    return Container(
      height: TvTheme.heroHeight,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TvTheme.fill,
              boxShadow: const [
                BoxShadow(color: TvTheme.brandGlow, blurRadius: 48),
              ],
            ),
            child: const Icon(
              FluentIcons.clock,
              size: 44,
              color: TvTheme.brandBright,
            ),
          ),
          const SizedBox(height: 28),
          Text(l10n.tvEmptyTitle, style: TvTheme.emptyTitle),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              total != null && total > 0
                  ? '${l10n.tvEmptyDesc}${l10n.tvEmptyDescCount('$total')}'
                  : l10n.tvEmptyDesc,
              textAlign: TextAlign.center,
              style: TvTheme.emptyDesc,
            ),
          ),
          const SizedBox(height: 36),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TvButton(
                label: l10n.tvEmptyGoLibrary,
                iconSvg: _kIconLibrary,
                primary: true,
                enabled: false,
              ),
              const SizedBox(width: 16),
              TvButton(
                label: l10n.tvEmptyGoSearch,
                iconSvg: _kIconSearch,
                enabled: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const String _kIconLibrary =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" '
    'xmlns="http://www.w3.org/2000/svg">'
    '<rect x="4" y="4" width="7" height="7" rx="1.5"/>'
    '<rect x="13" y="4" width="7" height="7" rx="1.5"/>'
    '<rect x="4" y="13" width="7" height="7" rx="1.5"/>'
    '<rect x="13" y="13" width="7" height="7" rx="1.5"/>'
    '</svg>';

const String _kIconSearch =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" '
    'xmlns="http://www.w3.org/2000/svg">'
    '<circle cx="11" cy="11" r="6.5"/><path d="m16 16 4.5 4.5"/>'
    '</svg>';
