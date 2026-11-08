import 'package:fluent_ui/fluent_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../tv_theme.dart';

/// Bottom key-hint strip (design `.keyhints`): right-aligned keycaps over a
/// gradient that fades into the page background.
class TvKeyHints extends StatelessWidget {
  const TvKeyHints({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IgnorePointer(
      child: Container(
        height: TvTheme.keyHintsHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: TvTheme.sidePadding,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xEB0A0A0B), Color(0x000A0A0B)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _TvKeyHint(keycap: '←→↑↓', label: l10n.tvHintMove),
            _TvKeyHint(keycap: 'OK', label: l10n.tvHintOk, ok: true),
            _TvKeyHint(keycap: '◀', label: l10n.tvHintBack),
            _TvKeyHint(keycap: '⋯', label: l10n.tvHintMore),
          ],
        ),
      ),
    );
  }
}

class _TvKeyHint extends StatelessWidget {
  const _TvKeyHint(
      {required this.keycap, required this.label, this.ok = false});

  final String keycap;
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 34),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ok ? TvTheme.brandSoft : TvTheme.bgRaised,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: ok
                    ? const Color(0x803388FF) // rgba(51,136,255,.5)
                    : TvTheme.borderStrong,
                width: 1,
              ),
            ),
            // The 3px bottom border reads as keycap thickness; approximate it
            // with an asymmetric inner shadow via a second container.
            child: Text(keycap, style: TvTheme.keyCap),
          ),
          const SizedBox(width: 10),
          Text(label, style: TvTheme.keyHint),
        ],
      ),
    );
  }
}
