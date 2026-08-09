import 'package:fluent_ui/fluent_ui.dart';

const playerSkipIntroPromptKey = ValueKey('player-skip-intro-prompt');
const playerSkipIntroUndoKey = ValueKey('player-skip-intro-undo');
const playerSkipIntroPipPromptKey = ValueKey('player-skip-intro-pip-prompt');
const playerSkipIntroPipUndoKey = ValueKey('player-skip-intro-pip-undo');

class SkipIntroPrompt extends StatelessWidget {
  const SkipIntroPrompt({
    super.key,
    required this.countdown,
    required this.onUndo,
    this.isPip = false,
    this.onHoverChanged,
  });

  final int countdown;
  final VoidCallback onUndo;
  final bool isPip;
  final ValueChanged<bool>? onHoverChanged;

  @override
  Widget build(BuildContext context) {
    return PlayerSkipPromptContainer(
      key: isPip ? playerSkipIntroPipPromptKey : playerSkipIntroPromptKey,
      isPip: isPip,
      onHoverChanged: onHoverChanged,
      message: '已自动跳过片头',
      undoLabel: '撤销',
      countdown: countdown,
      actionKey: isPip ? playerSkipIntroPipUndoKey : playerSkipIntroUndoKey,
      onPressed: onUndo,
    );
  }
}

class PlayerSkipPromptContainer extends StatelessWidget {
  const PlayerSkipPromptContainer({
    super.key,
    required this.isPip,
    required this.message,
    required this.undoLabel,
    required this.countdown,
    required this.actionKey,
    required this.onPressed,
    this.onHoverChanged,
  });

  final bool isPip;
  final String message;
  final String undoLabel;
  final int countdown;
  final Key actionKey;
  final VoidCallback onPressed;
  final ValueChanged<bool>? onHoverChanged;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      bottom: isPip ? 12 : 120,
      child: MouseRegion(
        onEnter: (_) => onHoverChanged?.call(true),
        onExit: (_) => onHoverChanged?.call(false),
        child: Container(
          constraints: isPip
              ? const BoxConstraints(maxWidth: 360)
              : const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2B2B2B).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              HyperlinkButton(
                key: actionKey,
                onPressed: onPressed,
                style: const ButtonStyle(
                  padding: WidgetStatePropertyAll(EdgeInsets.zero),
                  foregroundColor: WidgetStatePropertyAll(Colors.white),
                ),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 14,
                    ),
                    children: [
                      TextSpan(text: undoLabel),
                      if (countdown > 0)
                        TextSpan(
                          text: ' ${countdown.clamp(0, 5)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                    ],
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
