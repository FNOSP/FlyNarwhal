import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
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

// Fullscreen manager for handling different platforms
class FullscreenManager {
  static Future<void> enterFullscreen() async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      // Mac: Use real fullscreen
      await windowManager.setFullScreen(true);
    } else {
      // Windows/Linux: Use pseudo-fullscreen
      await windowManager.setMaximizable(true);
      await windowManager.maximize();
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
  }

  static Future<void> exitFullscreen() async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      // Mac: Exit real fullscreen
      await windowManager.setFullScreen(false);
    } else {
      // Windows/Linux: Exit pseudo-fullscreen
      await windowManager.unmaximize();
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    }
  }

  static Future<void> toggleFullscreen(bool isFullscreen) async {
    if (isFullscreen) {
      await exitFullscreen();
    } else {
      await enterFullscreen();
    }
  }

  static Future<bool> isFullscreen() async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return await windowManager.isFullScreen();
    } else {
      return await windowManager.isMaximized();
    }
  }
}

// Widget wrapper for pseudo-fullscreen on Windows
class PseudoFullscreenWrapper extends StatefulWidget {
  final Widget child;
  final bool isFullscreen;

  const PseudoFullscreenWrapper({
    super.key,
    required this.child,
    required this.isFullscreen,
  });

  @override
  State<PseudoFullscreenWrapper> createState() =>
      _PseudoFullscreenWrapperState();
}

class _PseudoFullscreenWrapperState extends State<PseudoFullscreenWrapper> {
  @override
  Widget build(BuildContext context) {
    if (!widget.isFullscreen || defaultTargetPlatform == TargetPlatform.macOS) {
      return widget.child;
    }

    // Windows/Linux pseudo-fullscreen: overlay the entire window
    return Stack(
      children: [
        // Background to cover any remaining UI
        Positioned.fill(
          child: Container(color: Colors.black),
        ),
        // Content
        Positioned.fill(
          child: widget.child,
        ),
      ],
    );
  }
}
