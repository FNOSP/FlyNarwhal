import 'package:fluent_ui/fluent_ui.dart';
import 'package:fly_narwhal/l10n/generated/app_localizations.dart';

import '../models/player_skip_action.dart';
import 'skip_intro_prompt.dart';

const playerSkipOutroPromptKey = ValueKey('player-skip-outro-prompt');
const playerSkipOutroCancelKey = ValueKey('player-skip-outro-cancel');
const playerSkipOutroPipPromptKey = ValueKey('player-skip-outro-pip-prompt');
const playerSkipOutroPipCancelKey = ValueKey('player-skip-outro-pip-cancel');

String resolveOutroPromptMessage({
  required AppLocalizations l10n,
  required int countdown,
  required bool autoPlayEnabled,
  required bool hasContentAfterCredits,
  required NextEpisodeLoadPhase nextEpisodePhase,
  String? subject,
}) {
  final safeCountdown = countdown < 0 ? 0 : countdown;
  if (!autoPlayEnabled || hasContentAfterCredits) {
    return l10n.playerSkipSegmentInSeconds(
      '$safeCountdown',
      subject ?? l10n.playerSkipSegmentOutro,
    );
  }
  if (nextEpisodePhase == NextEpisodeLoadPhase.available) {
    return l10n.playerSkipOutroNextEpisodeInSeconds(safeCountdown);
  }
  return l10n.playerSkipOutroEndInSeconds(safeCountdown);
}

class SkipOutroPrompt extends StatelessWidget {
  const SkipOutroPrompt({
    super.key,
    required this.countdown,
    required this.autoPlayEnabled,
    required this.hasContentAfterCredits,
    required this.nextEpisodePhase,
    required this.onCancel,
    this.isPip = false,
    this.onHoverChanged,
    this.subject,
  });

  final int countdown;
  final bool autoPlayEnabled;
  final bool hasContentAfterCredits;
  final NextEpisodeLoadPhase nextEpisodePhase;
  final VoidCallback onCancel;
  final bool isPip;
  final ValueChanged<bool>? onHoverChanged;
  final String? subject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlayerSkipPromptContainer(
      key: isPip ? playerSkipOutroPipPromptKey : playerSkipOutroPromptKey,
      isPip: isPip,
      message: resolveOutroPromptMessage(
        l10n: l10n,
        countdown: countdown,
        autoPlayEnabled: autoPlayEnabled,
        hasContentAfterCredits: hasContentAfterCredits,
        nextEpisodePhase: nextEpisodePhase,
        subject: subject ?? l10n.playerSkipSegmentOutro,
      ),
      undoLabel: l10n.commonCancel,
      countdown: 0,
      actionKey: isPip ? playerSkipOutroPipCancelKey : playerSkipOutroCancelKey,
      onPressed: onCancel,
      onHoverChanged: onHoverChanged,
    );
  }
}
