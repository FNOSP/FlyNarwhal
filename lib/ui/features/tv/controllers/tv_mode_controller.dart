import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/log/app_talker.dart';
import '../../../navigation/app_router.dart';
import 'tv_fullscreen_driver.dart';

/// Route of the TV big-screen home. Lives outside the ShellRoute (like the
/// player routes) so it renders without the desktop app chrome.
const String kTvModeRoute = '/bigscreen';

/// Owns the TV big-screen mode session: navigation to/from [kTvModeRoute]
/// paired with the window fullscreen form. Not persisted — restarting the
/// app always comes up in desktop mode.
class TvModeController extends ChangeNotifier {
  TvModeController(this._ref);

  final Ref _ref;
  final TvFullscreenDriver _driver = TvFullscreenDriver();

  bool _isInTvMode = false;
  bool _isTransitioning = false;

  bool get isInTvMode => _isInTvMode;

  TvFullscreenDriver get driver => _driver;

  /// Pushes the TV route first, waits a frame, then enters fullscreen so the
  /// TV UI is already on screen while the (animated) fullscreen transition
  /// runs — avoids a white flash on macOS.
  Future<void> enterTvMode() async {
    if (_isTransitioning || _isInTvMode) {
      return;
    }

    _isTransitioning = true;
    try {
      final router = _ref.read(routerProvider);
      if (router.state.matchedLocation != kTvModeRoute) {
        router.push(kTvModeRoute);
      }
      await WidgetsBinding.instance.endOfFrame;
      await _driver.enter();
      // macOS occasionally refuses the toggle when it lands inside another
      // window transition; confirm and retry before giving up.
      for (var attempt = 0; attempt < 3; attempt++) {
        if (await _driver.isFullscreenActive()) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (attempt < 2) {
          await _driver.enter();
        }
      }
      AppTalker.info(
        'TvMode',
        'enterTvMode fullscreen=${await _driver.isFullscreenActive()}',
      );
      _isInTvMode = true;
      notifyListeners();
    } finally {
      _isTransitioning = false;
    }
  }

  /// Leaves TV mode: pops back to the desktop UI first, then exits the
  /// window fullscreen form. Idempotent; safe to call from the
  /// leave-fullscreen fallback (the driver's exit() tolerates an already
  /// non-fullscreen window and still releases the persistence guard).
  Future<void> exitTvMode() async {
    if (_isTransitioning) {
      return;
    }

    _isTransitioning = true;
    try {
      final wasInTvMode = _isInTvMode;
      _isInTvMode = false;
      notifyListeners();

      final router = _ref.read(routerProvider);
      if (router.state.matchedLocation == kTvModeRoute) {
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/home');
        }
      }
      if (wasInTvMode || await _driver.isFullscreenActive()) {
        await _driver.exit();
      }
      AppTalker.info(
        'TvMode',
        'exitTvMode fullscreen=${await _driver.isFullscreenActive()}',
      );
    } finally {
      _isTransitioning = false;
    }
  }
}

final tvModeControllerProvider = Provider<TvModeController>((ref) {
  final controller = TvModeController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
