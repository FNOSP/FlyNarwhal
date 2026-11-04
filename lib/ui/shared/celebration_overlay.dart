import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';

/// Incrementing this provider plays the donation-thanks celebration (confetti
/// cannon launch + "谢谢老板" sticker) over the whole window. The value itself
/// is a monotonic trigger id, not a count that is displayed anywhere.
final celebrationTriggerProvider = StateProvider<int>((ref) => 0);

const Duration _celebrationDuration = Duration(milliseconds: 4600);
const Duration _stickerFadeOut = Duration(milliseconds: 600);

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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _celebrationDuration,
  );

  List<_ConfettiParticle> _particles = const [];
  int _lastTrigger = 0;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _active = false;
          _particles = const [];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final trigger = ref.watch(celebrationTriggerProvider);
    if (trigger != _lastTrigger) {
      // First build with a new trigger id: (re)launch the celebration. This is
      // a render-phase provider read, so defer the controller start to the
      // post-frame callback to stay out of the build phase.
      _lastTrigger = trigger;
      if (trigger > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _launch(MediaQuery.sizeOf(context));
        });
      }
    }

    if (trigger == 0 || !_active) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          if (progress <= 0) return const SizedBox.shrink();
          return SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ConfettiPainter(
                      particles: _particles,
                      progress: progress,
                      durationSeconds:
                          _celebrationDuration.inMilliseconds / 1000,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: _ThankYouSticker(
                    progress: progress,
                    text: AppLocalizations.of(context).donationThanks,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _launch(Size size) {
    final random = math.Random();
    _particles = _confettiBurst(random, size);
    setState(() => _active = true);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// --- Confetti physics -------------------------------------------------------

/// Metallic-paper palette sampled from real confetti cannons.
const List<Color> _confettiColors = [
  Color(0xFFFFD54A), // gold
  Color(0xFFE53935), // red
  Color(0xFF1E88E5), // blue
  Color(0xFF43A047), // green
  Color(0xFFEC407A), // pink
  Color(0xFF8E24AA), // purple
  Color(0xFFFB8C00), // orange
  Color(0xFF26C6DA), // cyan
  Color(0xFFF0F0F0), // silver
];

// Vertical air drag coefficient (1/s). With g=980 the terminal fall speed is
// g/k ≈ 800px/s, which reads as light paper rather than a rock.
const double _dragK = 1.15;
const double _gravity = 980;
const double _terminal = _gravity / _dragK;
// Stronger horizontal drag so the fan collapses into a gentle drift.
const double _dragKX = 1.5;

class _ConfettiParticle {
  _ConfettiParticle({
    required this.startX,
    required this.startY,
    required this.delay,
    required this.velocityX,
    required this.velocityY,
    required this.width,
    required this.height,
    required this.color,
    required this.rotation,
    required this.spinSpeed,
    required this.flipSpeed,
    required this.flipPhase,
    required this.swayAmplitude,
    required this.swayFrequency,
    required this.swayPhase,
  });

  final double startX;
  final double startY;
  final double delay;
  final double velocityX;
  final double velocityY;
  final double width;
  final double height;
  final Color color;
  final double rotation;
  final double spinSpeed;
  // End-over-end tumble: the piece scales to |cos| along its long axis, so it
  // alternates between face-on colour and a thin shimmering edge.
  final double flipSpeed;
  final double flipPhase;
  final double swayAmplitude;
  final double swayFrequency;
  final double swayPhase;
}

/// Four staggered cannon bursts: centre, left, right, then a smaller centre
/// encore. Angles are measured from horizontal, pointing up.
List<_ConfettiParticle> _confettiBurst(math.Random random, Size size) {
  final particles = <_ConfettiParticle>[];

  void fireCannon({
    required double originX,
    required double minAngleDeg,
    required double maxAngleDeg,
    required double minSpeed,
    required double maxSpeed,
    required double delay,
    required int count,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = (minAngleDeg +
              random.nextDouble() * (maxAngleDeg - minAngleDeg)) *
          math.pi /
          180;
      final speed = minSpeed + random.nextDouble() * (maxSpeed - minSpeed);
      final isStreamer = random.nextDouble() < 0.38;
      particles.add(
        _ConfettiParticle(
          startX: originX + (random.nextDouble() - 0.5) * 30,
          startY: size.height + 24,
          delay: delay + random.nextDouble() * 0.22,
          velocityX: math.cos(angle) * speed,
          velocityY: -math.sin(angle) * speed,
          width: isStreamer ? 5 + random.nextDouble() * 3 : 8 + random.nextDouble() * 6,
          height: isStreamer ? 18 + random.nextDouble() * 10 : 5 + random.nextDouble() * 4,
          color: _confettiColors[random.nextInt(_confettiColors.length)],
          rotation: random.nextDouble() * math.pi * 2,
          spinSpeed: (random.nextDouble() - 0.5) * 11,
          flipSpeed: 4 + random.nextDouble() * 7,
          flipPhase: random.nextDouble() * math.pi * 2,
          swayAmplitude: 14 + random.nextDouble() * 30,
          swayFrequency: 2.2 + random.nextDouble() * 3.4,
          swayPhase: random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  final left = size.width * 0.14;
  final right = size.width * 0.86;
  final centre = size.width * 0.5;

  // Centre fountain first...
  fireCannon(
    originX: centre,
    minAngleDeg: 62,
    maxAngleDeg: 118,
    minSpeed: 820,
    maxSpeed: 1350,
    delay: 0,
    count: 64,
  );
  // ...then the two side cannons angled inward.
  fireCannon(
    originX: left,
    minAngleDeg: 55,
    maxAngleDeg: 82,
    minSpeed: 900,
    maxSpeed: 1450,
    delay: 0.30,
    count: 44,
  );
  fireCannon(
    originX: right,
    minAngleDeg: 98,
    maxAngleDeg: 125,
    minSpeed: 900,
    maxSpeed: 1450,
    delay: 0.30,
    count: 44,
  );
  // A smaller encore keeps pieces arriving while the sticker holds.
  fireCannon(
    originX: centre,
    minAngleDeg: 68,
    maxAngleDeg: 112,
    minSpeed: 760,
    maxSpeed: 1150,
    delay: 0.95,
    count: 34,
  );

  return particles;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.durationSeconds,
  });

  final List<_ConfettiParticle> particles;
  final double progress;
  final double durationSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * durationSeconds;
    // Global fade-out over the tail of the celebration.
    final fadeStartSeconds =
        durationSeconds - _stickerFadeOut.inMilliseconds / 1000;
    final globalOpacity = t < fadeStartSeconds
        ? 1.0
        : ((durationSeconds - t) / (durationSeconds - fadeStartSeconds))
            .clamp(0.0, 1.0);
    if (globalOpacity <= 0) return;

    final fadePaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.saveLayer(
      Offset.zero & size,
      fadePaint..color = Color.fromRGBO(255, 255, 255, globalOpacity),
    );

    for (final particle in particles) {
      final flight = t - particle.delay;
      if (flight <= 0) continue;

      // Closed-form ballistic motion with linear air drag:
      //   vy(t) = (v0y + vt)·e^(−kt) − vt   →  y(t) = y0 + (v0y+vt)(1−e^(−kt))/k − vt·t
      final fall = _terminal;
      final dy = (particle.velocityY + fall) *
              (1 - math.exp(-_dragK * flight)) /
              _dragK -
          fall * flight;
      final y = particle.startY + dy;
      if (y > size.height + 80) continue; // already fell past the window

      final dx = particle.velocityX *
              (1 - math.exp(-_dragKX * flight)) /
              _dragKX +
          particle.swayAmplitude *
              math.sin(particle.swayFrequency * flight + particle.swayPhase);
      final x = particle.startX + dx;

      // End-over-end tumble: cos(flip) compresses the piece along its height,
      // faking a 3D rotation; the "back face" is drawn darker.
      final flip = math.cos(particle.flipSpeed * flight + particle.flipPhase);
      final faceScale = flip.abs().clamp(0.08, 1.0);
      final isBack = flip < 0;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation + particle.spinSpeed * flight);
      canvas.scale(1, faceScale);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: particle.width,
        height: particle.height,
      );
      final color =
          isBack ? particle.color.withValues(alpha: 0.55) : particle.color;
      canvas.drawRect(rect, Paint()..color = color);
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.particles != particles || oldDelegate.progress != progress;
}

/// The "谢谢老板" meme-style sticker: pops in with an elastic bounce, wobbles
/// while held, then scales up and fades away with the confetti.
class _ThankYouSticker extends StatelessWidget {
  const _ThankYouSticker({required this.progress, required this.text});

  final double progress;
  final String text;

  @override
  Widget build(BuildContext context) {
    const popInEnd = 0.14;
    const fadeOutStart =
        1.0 - _stickerFadeOutDurationFraction; // ~0.87 of the timeline

    double scale;
    double opacity;
    if (progress < popInEnd) {
      final popProgress = progress / popInEnd;
      scale = Curves.elasticOut.transform(popProgress);
      opacity = Curves.easeIn.transform(popProgress);
    } else if (progress < fadeOutStart) {
      final hold = (progress - popInEnd) / (fadeOutStart - popInEnd);
      scale = 1.0 + 0.02 * math.sin(hold * math.pi * 4);
      opacity = 1.0;
    } else {
      final fade = (progress - fadeOutStart) / (1.0 - fadeOutStart);
      scale = 1.0 + 0.18 * Curves.easeIn.transform(fade);
      opacity = 1.0 - fade;
    }

    final wobble = math.sin(progress * math.pi * 6) * 3.0;

    return Center(
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: wobble * math.pi / 180,
            child: Container(
              padding: const EdgeInsets.fromLTRB(36, 28, 36, 32),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF6),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFFF5B301),
                  width: 5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 72)),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE23E3E),
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: Color(0xFFFFE08A),
                          offset: Offset(0, 3),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const double _stickerFadeOutDurationFraction =
    _stickerFadeOutMs / _celebrationMs;
const double _stickerFadeOutMs = 600;
const double _celebrationMs = 4600;
