import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../providers/providers.dart';
import '../controllers/tv_mode_controller.dart';
import '../tv_theme.dart';
import 'tv_focusable.dart';

/// Top floating navigation rail (design `.rail`): logo, nav pills, clock and
/// user chip over a gradient that fades into the hero art.
class TvRail extends ConsumerStatefulWidget {
  const TvRail({super.key});

  @override
  ConsumerState<TvRail> createState() => _TvRailState();
}

class _TvRailState extends ConsumerState<TvRail> {
  late Timer _clockTimer;
  late String _clockText;

  @override
  void initState() {
    super.initState();
    _clockText = _formatClock(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final text = _formatClock(DateTime.now());
      if (text != _clockText && mounted) {
        setState(() => _clockText = text);
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  static String _formatClock(DateTime now) {
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final username =
        ref.watch(userInfoProvider).valueOrNull?.username.trim() ?? '';

    return Container(
      height: TvTheme.railHeight,
      padding: const EdgeInsets.symmetric(horizontal: TvTheme.sidePadding),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE00A0A0B), Color(0x800A0A0B), Color(0x000A0A0B)],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Row(
        children: [
          const _TvLogo(),
          const SizedBox(width: 44),
          Expanded(
            child: Row(
              children: [
                _TvNavItem(
                  label: l10n.tvNavHome,
                  icon: _kIconHome,
                  active: true,
                  order: 900,
                ),
                _TvNavItem(
                  label: l10n.tvNavLibrary,
                  icon: _kIconLibrary,
                  order: 901,
                ),
                _TvNavItem(
                  label: l10n.tvNavSearch,
                  icon: _kIconSearch,
                  order: 902,
                ),
                _TvNavItem(
                  label: l10n.tvNavFavorites,
                  icon: _kIconFavorite,
                  order: 903,
                ),
                _TvNavItem(
                  label: l10n.tvNavHistory,
                  icon: _kIconHistory,
                  order: 904,
                ),
                _TvNavItem(
                  label: l10n.tvNavSettings,
                  icon: _kIconSettings,
                  order: 905,
                ),
                const SizedBox(width: 20),
                Container(
                  width: 1,
                  height: 28,
                  color: TvTheme.border,
                ),
                const SizedBox(width: 20),
                _TvNavItem(
                  label: l10n.tvExitBigScreen,
                  icon: _kIconExit,
                  order: 906,
                  onActivate: () {
                    ref.read(tvModeControllerProvider).exitTvMode();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Row(
            children: [
              Text(_clockText, style: TvTheme.clock),
              const SizedBox(width: 14),
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4A5568), Color(0xFF2D3748)],
                  ),
                  border: Border.all(color: TvTheme.borderStrong),
                ),
                child: Text(
                  username.isEmpty ? '·' : username[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: TvTheme.text1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TvTheme.userName,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TvLogo extends StatelessWidget {
  const _TvLogo();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [TvTheme.brand, TvTheme.brandDeep],
            ),
            boxShadow: const [
              BoxShadow(
                  color: TvTheme.brandGlow,
                  blurRadius: 16,
                  offset: Offset(0, 4)),
            ],
          ),
          child: SvgPicture.string(
            '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
            '<path d="M4 6.5C4 5.1 5.1 4 6.5 4h11C18.9 4 20 5.1 20 6.5v8c0 1.4-1.1 2.5-2.5 2.5H13l-4 3.5V17H6.5C5.1 17 4 15.9 4 14.5v-8Z" fill="#fff"/>'
            '<circle cx="9" cy="10.5" r="1.4" fill="#3388ff"/>'
            '<circle cx="15" cy="10.5" r="1.4" fill="#3388ff"/>'
            '</svg>',
            width: 24,
            height: 24,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appTitle, style: TvTheme.logoName),
            const SizedBox(height: 1),
            Text('FLYNARWHAL TV', style: TvTheme.logoSub),
          ],
        ),
      ],
    );
  }
}

class _TvNavItem extends StatefulWidget {
  const _TvNavItem({
    required this.label,
    required this.icon,
    this.active = false,
    this.onActivate,
    this.order = 100,
  });

  final String label;
  final String icon;
  final bool active;
  final VoidCallback? onActivate;
  final int order;

  @override
  State<_TvNavItem> createState() => _TvNavItemState();
}

class _TvNavItemState extends State<_TvNavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.active || _focused;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: TvFocusable(
        style: TvFocusStyle.nav,
        order: widget.order,
        onActivate: widget.onActivate,
        onFocusChanged: (focused) => setState(() => _focused = focused),
        child: AnimatedContainer(
          duration: TvTheme.focusTransition,
          height: TvTheme.navItemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: highlighted ? TvTheme.fill2 : Colors.transparent,
            borderRadius: BorderRadius.circular(TvTheme.radiusPill),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.string(
                    widget.icon,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      highlighted ? TvTheme.text0 : TvTheme.text2,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style:
                        highlighted ? TvTheme.navItemActive : TvTheme.navItem,
                  ),
                ],
              ),
              if (widget.active)
                Positioned(
                  bottom: -4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 18,
                      height: 3,
                      decoration: BoxDecoration(
                        color: TvTheme.brand,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: const [
                          BoxShadow(color: TvTheme.brandGlow, blurRadius: 10),
                        ],
                      ),
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

// ---- Rail icons, transcribed from the design's inline SVGs ----

const String _kIconHome =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" '
    'xmlns="http://www.w3.org/2000/svg">'
    '<path d="M4 11 12 4l8 7v8a1 1 0 0 1-1 1h-4v-6h-6v6H5a1 1 0 0 1-1-1v-8Z"/>'
    '</svg>';

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

const String _kIconFavorite =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" '
    'xmlns="http://www.w3.org/2000/svg">'
    '<path d="M12 20s-7-4.4-7-9.4A4.1 4.1 0 0 1 12 7.6 4.1 4.1 0 0 1 19 10.6c0 5-7 9.4-7 9.4Z"/>'
    '</svg>';

const String _kIconHistory =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" '
    'xmlns="http://www.w3.org/2000/svg">'
    '<circle cx="12" cy="12" r="8"/><path d="M12 7.5V12l3 2"/>'
    '</svg>';

const String _kIconSettings =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" '
    'xmlns="http://www.w3.org/2000/svg">'
    '<circle cx="12" cy="12" r="3"/>'
    '<path d="M12 4v2m0 12v2m8-8h-2M6 12H4m13.7-5.7-1.4 1.4M7.7 16.3l-1.4 1.4m11.4 0-1.4-1.4M7.7 7.7 6.3 6.3"/>'
    '</svg>';

const String _kIconExit =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" '
    'xmlns="http://www.w3.org/2000/svg">'
    '<path d="M14 4h4a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-4"/>'
    '<path d="M9 8l-4 4 4 4M5 12h9"/>'
    '</svg>';
