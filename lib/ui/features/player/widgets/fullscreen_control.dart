import 'package:fluent_ui/fluent_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'player_action_button.dart';

class FullScreenControl extends StatelessWidget {
  final bool isFullScreen;
  final VoidCallback onClick;

  const FullScreenControl({
    super.key,
    required this.isFullScreen,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlayerActionButton.lottie(
      lottieAssetPath: isFullScreen
          ? 'assets/lottie/quit_full_screen_lottie.json'
          : 'assets/lottie/full_screen_lottie.json',
      onPressed: onClick,
      tooltip: isFullScreen
          ? l10n.playerFullscreenExit
          : l10n.playerFullscreenEnter,
      size: 30,
      iconSize: 22,
    );
  }
}
