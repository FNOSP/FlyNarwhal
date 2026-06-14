import 'package:fluent_ui/fluent_ui.dart';

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
    return PlayerActionButton.lottie(
      lottieAssetPath: isFullScreen
          ? 'assets/lottie/quit_full_screen_lottie.json'
          : 'assets/lottie/full_screen_lottie.json',
      onPressed: onClick,
      tooltip: isFullScreen ? '退出全屏' : '进入全屏',
      size: 30,
      iconSize: 22,
    );
  }
}
