import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'celebration_simulation.dart';
import 'gif_info.dart';

/// Incrementing this provider plays the donation-thanks celebration over the
/// whole window: first the kowtow sticker GIF plays once, then side confetti
/// cannons, the "谢谢老板" GIF flying in from far away, and a window-wide
/// firework show. The value itself is a monotonic trigger id, not a count
/// that is displayed anywhere.
final celebrationTriggerProvider = StateProvider<int>((ref) => 0);

const String _kowtowAsset = 'assets/images/donation_kowtow.gif';
const String _stickerAsset = 'assets/images/donation_thanks_sticker.gif';

/// Used when the kowtow GIF's frame delays cannot be parsed.
const Duration _kowtowFallbackDuration = Duration(milliseconds: 7300);
const double _kowtowFadeSeconds = 0.3;

/// Hosts the donation celebration overlay above every route, dialog and
/// toast. Mounted in the app root [Stack]; inert (non hit-testable) while no
/// celebration is playing.
class CelebrationOverlayHost extends ConsumerStatefulWidget {
  const CelebrationOverlayHost({super.key});

  @override
  ConsumerState<CelebrationOverlayHost> createState() =>
      _CelebrationOverlayHostState();
}

class _CelebrationOverlayHostState extends ConsumerState<CelebrationOverlayHost>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);

  CelebrationSimulation? _simulation;
  int _lastTrigger = 0;
  bool _active = false;
  double _elapsed = 0;
  double _kowtowSeconds = 0;

  @override
  Widget build(BuildContext context) {
    final trigger = ref.watch(celebrationTriggerProvider);
    if (trigger != _lastTrigger) {
      // First build with a new trigger id: (re)launch the celebration. This
      // is a render-phase provider read, so defer the launch to the post-frame
      // callback to stay out of the build phase.
      _lastTrigger = trigger;
      if (trigger > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _launch(MediaQuery.sizeOf(context));
        });
      }
    }

    final simulation = _simulation;
    if (!_active || simulation == null) return const SizedBox.shrink();

    final kowtowPlaying = _elapsed < _kowtowSeconds;
    final kowtowRemaining = _kowtowSeconds - _elapsed;

    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CelebrationPainter(simulation: simulation),
              ),
            ),
            Positioned.fill(
              child: _ThankYouSticker(time: simulation.time),
            ),
            if (kowtowPlaying)
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: kowtowRemaining < _kowtowFadeSeconds
                        ? (kowtowRemaining / _kowtowFadeSeconds).clamp(0.0, 1.0)
                        : 1.0,
                    child: LayoutBuilder(
                      builder: (context, constraints) => Image.asset(
                        _kowtowAsset,
                        width: math.min(600, constraints.maxWidth * 0.7),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _launch(Size size) {
    _simulation?.dispose();
    _simulation = CelebrationSimulation(size: size);
    _elapsed = 0;
    // The kowtow GIF plays once before the confetti timeline starts; parse
    // its real single-play duration so the handoff lands on the last frame.
    rootBundle.load(_kowtowAsset).then((data) {
      if (!mounted) return;
      final parsed = gifSinglePlayDuration(data.buffer.asUint8List());
      _kowtowSeconds = parsed > Duration.zero
          ? parsed.inMicroseconds / Duration.microsecondsPerSecond
          : _kowtowFallbackDuration.inMilliseconds / 1000;
      setState(() => _active = true);
      _ticker
        ..stop()
        ..start();
    });
  }

  void _onTick(Duration elapsed) {
    final simulation = _simulation;
    if (simulation == null) return;
    _elapsed = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (_elapsed >= _kowtowSeconds) {
      simulation.seekTo(_elapsed - _kowtowSeconds);
      if (simulation.isFinished) {
        _ticker.stop();
        setState(() {
          _active = false;
          _simulation = null;
        });
        simulation.dispose();
        return;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _simulation?.dispose();
    super.dispose();
  }
}

/// Bridges the simulation into a [CustomPainter]. The ticker already repaints
/// every frame while active, so [shouldRepaint] is unconditionally true.
class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter({required this.simulation});

  final CelebrationSimulation simulation;

  @override
  void paint(Canvas canvas, Size size) {
    simulation.paint(canvas, size);
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) => true;
}

/// The "谢谢老板" animated sticker GIF. Flies in from far away: perspective
/// zoom with a slight overshoot, blur-to-sharp, then holds with a gentle
/// wobble while the fireworks play, and finally scales up and fades away.
class _ThankYouSticker extends StatelessWidget {
  const _ThankYouSticker({required this.time});

  /// Simulation time in seconds.
  final double time;

  @override
  Widget build(BuildContext context) {
    double scale;
    double opacity;
    double blurSigma;
    double tilt;

    if (time < CelebrationTimeline.textZoomStart) {
      // Not flying in yet; the GIF subtree only enters once the zoom starts.
      return const SizedBox.shrink();
    } else if (time < CelebrationTimeline.textZoomEnd) {
      final span =
          CelebrationTimeline.textZoomEnd - CelebrationTimeline.textZoomStart;
      final p = ((time - CelebrationTimeline.textZoomStart) / span).clamp(0.0, 1.0);
      // easeOutBack overshoots ~1.1 before settling — the "arriving" bounce.
      final eased = Curves.easeOutBack.transform(p);
      scale = 0.05 + 0.95 * eased;
      opacity = Curves.easeIn.transform((p / 0.3).clamp(0.0, 1.0));
      blurSigma = 14 * math.pow(1 - p, 2).toDouble();
      tilt = 0.22 * (1 - p);
    } else if (time < CelebrationTimeline.fadeStart) {
      final span = CelebrationTimeline.fadeStart - CelebrationTimeline.textZoomEnd;
      final hold = ((time - CelebrationTimeline.textZoomEnd) / span).clamp(0.0, 1.0);
      scale = 1.0 + 0.02 * math.sin(hold * math.pi * 4);
      opacity = 1.0;
      blurSigma = 0;
      tilt = 0;
    } else {
      const fadeSpan = CelebrationTimeline.total - CelebrationTimeline.fadeStart;
      final fade = ((time - CelebrationTimeline.fadeStart) / fadeSpan).clamp(0.0, 1.0);
      scale = 1.0 + 0.18 * Curves.easeIn.transform(fade);
      opacity = 1.0 - fade;
      blurSigma = 0;
      tilt = 0;
    }

    final wobble = math.sin(time * math.pi * 1.4) * 2.0;

    final transform = Matrix4.identity()
      // Perspective entry so the z-tilt reads as depth while flying in.
      ..setEntry(3, 2, 0.0012)
      ..scaleByDouble(scale, scale, 1, 1)
      ..rotateX(tilt);

    Widget child = Transform(
      alignment: Alignment.center,
      transform: transform,
      child: Transform.rotate(
        angle: wobble * math.pi / 180,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Image.asset(
            _stickerAsset,
            width: 300,
            height: 300,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );

    if (blurSigma > 0.4) {
      child = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: child,
      );
    }

    return Center(child: child);
  }
}
