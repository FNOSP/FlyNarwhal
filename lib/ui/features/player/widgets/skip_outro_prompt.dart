import 'package:fluent_ui/fluent_ui.dart';

import '../models/player_skip_action.dart';
import 'skip_intro_prompt.dart';

const playerSkipOutroPromptKey = ValueKey('player-skip-outro-prompt');
const playerSkipOutroCancelKey = ValueKey('player-skip-outro-cancel');
const playerSkipOutroPipPromptKey = ValueKey('player-skip-outro-pip-prompt');
const playerSkipOutroPipCancelKey = ValueKey('player-skip-outro-pip-cancel');

String resolveOutroPromptMessage({
  required int countdown,
  required bool autoPlayEnabled,
  required bool hasContentAfterCredits,
  required NextEpisodeLoadPhase nextEpisodePhase,
}) {
  final safeCountdown = countdown < 0 ? 0 : countdown;
  if (!autoPlayEnabled || hasContentAfterCredits) {
    return '$safeCountdown 秒后跳过片尾';
  }
  if (nextEpisodePhase == NextEpisodeLoadPhase.available) {
    return '$safeCountdown 秒后播放下一集';
  }
  return '$safeCountdown 秒后结束播放';
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
  });

  final int countdown;
  final bool autoPlayEnabled;
  final bool hasContentAfterCredits;
  final NextEpisodeLoadPhase nextEpisodePhase;
  final VoidCallback onCancel;
  final bool isPip;
  final ValueChanged<bool>? onHoverChanged;

  @override
  Widget build(BuildContext context) {
    return PlayerSkipPromptContainer(
      key: isPip ? playerSkipOutroPipPromptKey : playerSkipOutroPromptKey,
      isPip: isPip,
      message: resolveOutroPromptMessage(
        countdown: countdown,
        autoPlayEnabled: autoPlayEnabled,
        hasContentAfterCredits: hasContentAfterCredits,
        nextEpisodePhase: nextEpisodePhase,
      ),
      undoLabel: '取消',
      countdown: 0,
      actionKey: isPip ? playerSkipOutroPipCancelKey : playerSkipOutroCancelKey,
      onPressed: onCancel,
      onHoverChanged: onHoverChanged,
    );
  }
}
