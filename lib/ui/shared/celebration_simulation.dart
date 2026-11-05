import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Timeline of the donation celebration, in seconds from launch. Exposed so
/// the overlay widget can derive phase progress (e.g. the sticker zoom) from
/// [CelebrationSimulation.time].
abstract final class CelebrationTimeline {
  /// Left cannon fires at the very start, right cannon follows shortly after.
  static const double cannonLeft = 0.0;
  static const double cannonRight = 0.22;
  /// Encore volleys while the sticker flies in.
  static const double cannonEncoreLeft = 2.4;
  static const double cannonEncoreRight = 2.65;

  /// "谢谢老板" flies in from far away (perspective zoom + blur-to-sharp).
  static const double textZoomStart = 0.9;
  static const double textZoomEnd = 2.6;

  /// Window-wide firework show: rockets launch randomly in this window.
  static const double fireworksStart = 2.3;
  static const double fireworksLastLaunch = 7.8;

  /// Sticker and leftovers fade; the overlay unmounts at [total].
  static const double fadeStart = 8.4;
  static const double total = 9.6;
}

// --- Physics constants ------------------------------------------------------

// Confetti gravity, deliberately lighter than real 9.8m/s² so paper pieces
// float. With drag k=1.15 the terminal fall speed is g/k ≈ 520px/s, which
// reads as light paper rather than a rock.
const double _gravity = 600;
const double _confettiDragY = 1.15;
const double _confettiDragX = 1.5;

/// Hard cap on simultaneously active additive particles (sparks + trails).
/// New bursts shrink when the budget is nearly exhausted.
const int _maxSparks = 2200;

/// Fixed simulation step. Frames slower than this (or huge test pumps) are
/// sub-stepped; gaps beyond [_teleportGap] fast-forward instead of simulating
/// thousands of steps after e.g. the window losing focus.
const double _maxStep = 1 / 30;
const double _teleportGap = 0.5;

// --- Palette ----------------------------------------------------------------

const List<ui.Color> _confettiColors = [
  ui.Color(0xFFFFD54A), // gold
  ui.Color(0xFFE53935), // red
  ui.Color(0xFF1E88E5), // blue
  ui.Color(0xFF43A047), // green
  ui.Color(0xFFEC407A), // pink
  ui.Color(0xFF8E24AA), // purple
  ui.Color(0xFFFB8C00), // orange
  ui.Color(0xFF26C6DA), // cyan
  ui.Color(0xFFF0F0F0), // silver
];

/// Firework shell colours: vivid, slightly lighter than the confetti palette
/// so additive blending does not blow them out to white immediately.
const List<ui.Color> _shellColors = [
  ui.Color(0xFFFFB830), // gold
  ui.Color(0xFFFF4D4D), // red
  ui.Color(0xFF5EEA8D), // green
  ui.Color(0xFF6CB4FF), // blue
  ui.Color(0xFFD49BFF), // purple
  ui.Color(0xFFFF8FBE), // pink
  ui.Color(0xFF5BE7F4), // cyan
  ui.Color(0xFFFF9A3D), // orange
  ui.Color(0xFFF4F7FF), // cool white
];

const ui.Color _trailColor = ui.Color(0xFFFFD9A0); // warm rocket-trail white
const ui.Color _smokeColor = ui.Color(0xFF9AA3AF);

// --- Particles --------------------------------------------------------------

enum _ConfettiKind { rect, ribbon }

class _Confetti {
  _Confetti({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.width,
    required this.height,
    required this.color,
    required this.kind,
    required this.ax,
    required this.ay,
    required this.az,
    required this.wx,
    required this.wy,
    required this.wz,
    required this.swayAmplitude,
    required this.swayFrequency,
    required this.swayPhase,
    required this.ribbonPhase,
  });

  double x, y, vx, vy;
  final double width;
  final double height;
  final ui.Color color;
  final _ConfettiKind kind;
  // Euler angles around the three axes and their angular velocities. The
  // piece is a thin plate whose face normal starts at +z.
  double ax, ay, az;
  final double wx, wy, wz;
  final double swayAmplitude;
  final double swayFrequency;
  final double swayPhase;
  final double ribbonPhase;
  bool dead = false;
}

class _Rocket {
  _Rocket({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.burstY,
    required this.color,
    required this.shell,
    required this.secondaryColor,
    required this.hasSecondary,
  });

  double x, y, vx, vy;
  final double burstY;
  final ui.Color color;
  final _ShellType shell;
  final ui.Color secondaryColor;
  final bool hasSecondary;
  bool dead = false;
}

enum _ShellType { peony, willow }

class _Spark {
  _Spark({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.gravity,
    required this.drag,
    required this.life,
    required this.size,
    required this.color,
    required this.strobe,
    required this.twinkleFreq,
    required this.phase,
  });

  double x, y, vx, vy;
  final double gravity;
  final double drag;
  final double life;
  final double size;
  final ui.Color color;
  final bool strobe;
  final double twinkleFreq;
  final double phase;
  double age = 0;
  bool dead = false;
}

class _Smoke {
  _Smoke({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.growth,
    required this.life,
  });

  double x, y, vx, vy, radius;
  final double growth;
  final double life;
  double age = 0;
  bool dead = false;
}

/// A timed one-shot action (cannon fire, rocket launch, secondary burst,
/// gold sparkle spawn). The queue stays sorted by [at].
class _Event {
  _Event(this.at, this.action);
  final double at;
  final void Function() action;
}

// --- Simulation -------------------------------------------------------------

/// Pure-Dart particle simulation for the donation celebration: side confetti
/// cannons, gold sparkles around the arriving sticker, and a window-wide
/// firework show (rocket trails → spherical shell bursts → drooping willow
/// sparks → crackle strobing → smoke). No widget/riverpod dependencies so it
/// can be unit-tested headlessly.
///
/// Drive with [seekTo] (absolute time, sub-stepped) and render with [paint].
class CelebrationSimulation {
  CelebrationSimulation({required this.size, math.Random? random})
      : random = random ?? math.Random() {
    _scheduleShow();
  }

  final ui.Size size;
  final math.Random random;

  double time = 0;

  final List<_Confetti> _confetti = [];
  final List<_Rocket> _rockets = [];
  final List<_Spark> _sparks = [];
  final List<_Smoke> _smokes = [];
  final List<_Event> _events = [];

  // Screen flash on shell bursts: colour + remaining alpha.
  ui.Color _flashColor = const ui.Color(0xFFFFFFFF);
  double _flashAlpha = 0;

  // Paint/sprite caches (created lazily on first paint).
  final Map<int, ui.Image?> _glowCache = {};
  final Map<int, ui.Paint> _confettiFrontPaints = {};
  final Map<int, ui.Paint> _confettiBackPaints = {};
  bool _glowUnsupported = false;
  static const ui.Rect _unitRect = ui.Rect.fromLTWH(-0.5, -0.5, 1, 1);
  final ui.Paint _sparkPaint = ui.Paint()..blendMode = ui.BlendMode.plus;
  final ui.Paint _flashPaint = ui.Paint()..blendMode = ui.BlendMode.plus;
  final ui.Paint _smokePaint = ui.Paint();
  final ui.Paint _ribbonPaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round;
  final ui.Paint _streakPaint = ui.Paint()
    ..blendMode = ui.BlendMode.plus
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round;
  final Float64List _confettiMatrix = Float64List(16)
    // z scale and w stay identity: the per-piece entries only fill rows 0–1.
    ..[10] = 1
    ..[15] = 1;

  // Debug/test introspection.
  int get confettiCount => _confetti.length;
  int get rocketCount => _rockets.length;
  int get sparkCount => _sparks.length;
  int get smokeCount => _smokes.length;
  bool get isFinished => time >= CelebrationTimeline.total;

  /// Test hook: the lowest live confetti piece (max y), or null when no
  /// confetti is airborne.
  double? get debugConfettiMaxY {
    double? maxY;
    for (final piece in _confetti) {
      if (maxY == null || piece.y > maxY) maxY = piece.y;
    }
    return maxY;
  }

  /// Releases cached offscreen glow sprites. The overlay calls this once the
  /// celebration has finished and the painter is out of the tree.
  void dispose() {
    for (final image in _glowCache.values) {
      image?.dispose();
    }
    _glowCache.clear();
  }

  /// Advances the simulation to absolute time [t] seconds. Large gaps (window
  /// unfocused, giant test pumps) fast-forward instead of sub-stepping.
  void seekTo(double t) {
    if (t <= time) return;
    if (t - time > _teleportGap) {
      time = t - _maxStep;
      _runScheduledEvents();
    }
    while (time < t) {
      final dt = math.min(_maxStep, t - time);
      _advance(dt);
    }
  }

  void _advance(double dt) {
    time += dt;
    _runScheduledEvents();
    _integrateRockets(dt);
    _integrateSparks(dt);
    _integrateConfetti(dt);
    _integrateSmoke(dt);
    if (_flashAlpha > 0) {
      _flashAlpha = math.max(0, _flashAlpha - dt * 0.45);
    }
    _reap();
  }

  void _runScheduledEvents() {
    while (_events.isNotEmpty && _events.first.at <= time) {
      _events.removeAt(0).action();
    }
  }

  void _schedule(_Event event) {
    // Insert keeping the queue sorted; the queue is tiny so a linear scan is
    // cheaper than maintaining a heap.
    var index = _events.length;
    while (index > 0 && _events[index - 1].at > event.at) {
      index--;
    }
    _events.insert(index, event);
  }

  // --- Show scheduling -------------------------------------------------------

  void _scheduleShow() {
    _schedule(_Event(CelebrationTimeline.cannonLeft, () => _fireCannon(
        originX: size.width * 0.12, direction: 1)));
    _schedule(_Event(CelebrationTimeline.cannonRight, () => _fireCannon(
        originX: size.width * 0.88, direction: -1)));
    // Smaller encore volleys keep pieces raining while the sticker arrives
    // and the fireworks begin.
    _schedule(_Event(CelebrationTimeline.cannonEncoreLeft, () => _fireCannon(
        originX: size.width * 0.12, direction: 1, count: 55)));
    _schedule(_Event(CelebrationTimeline.cannonEncoreRight, () => _fireCannon(
        originX: size.width * 0.88, direction: -1, count: 55)));

    // 7–9 rockets spread randomly across the firework window.
    final launches = 7 + random.nextInt(3);
    var t = CelebrationTimeline.fireworksStart;
    final span =
        CelebrationTimeline.fireworksLastLaunch - CelebrationTimeline.fireworksStart;
    for (var i = 0; i < launches; i++) {
      final jitter = (random.nextDouble() - 0.5) * 0.35;
      final at = t + jitter;
      if (at >= CelebrationTimeline.fireworksStart &&
          at <= CelebrationTimeline.fireworksLastLaunch) {
        _schedule(_Event(at, _launchRocket));
      }
      t += span / launches;
    }

    // Sparse gold sparkles while the sticker flies in.
    for (var t = CelebrationTimeline.textZoomStart + 0.1;
        t < CelebrationTimeline.textZoomEnd;
        t += 0.2) {
      _schedule(_Event(t, _spawnGoldSparkles));
    }
  }

  // --- Spawners --------------------------------------------------------------

  void _fireCannon({
    required double originX,
    required int direction,
    int? count,
  }) {
    final pieces = count ?? 90 + random.nextInt(20);
    for (var i = 0; i < pieces; i++) {
      // Cannon tilted inward: 42°–78° from horizontal.
      final angle = (42 + random.nextDouble() * 36) * math.pi / 180;
      final speed = 1000 + random.nextDouble() * 900;
      final isRibbon = random.nextDouble() < 0.45;
      _confetti.add(
        _Confetti(
          x: originX + (random.nextDouble() - 0.5) * 26,
          y: size.height + 18,
          vx: direction * math.cos(angle) * speed,
          vy: -math.sin(angle) * speed,
          width: isRibbon ? 4 + random.nextDouble() * 2 : 7 + random.nextDouble() * 6,
          height:
              isRibbon ? 20 + random.nextDouble() * 12 : 5 + random.nextDouble() * 4,
          color: _confettiColors[random.nextInt(_confettiColors.length)],
          kind: isRibbon ? _ConfettiKind.ribbon : _ConfettiKind.rect,
          ax: random.nextDouble() * math.pi * 2,
          ay: random.nextDouble() * math.pi * 2,
          az: random.nextDouble() * math.pi * 2,
          wx: (random.nextDouble() - 0.5) * 9,
          wy: 3 + random.nextDouble() * 8,
          wz: (random.nextDouble() - 0.5) * 11,
          swayAmplitude: 14 + random.nextDouble() * 28,
          swayFrequency: 2.2 + random.nextDouble() * 3.2,
          swayPhase: random.nextDouble() * math.pi * 2,
          ribbonPhase: random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  void _launchRocket() {
    final color = _shellColors[random.nextInt(_shellColors.length)];
    ui.Color secondary = _shellColors[random.nextInt(_shellColors.length)];
    while (secondary == color) {
      secondary = _shellColors[random.nextInt(_shellColors.length)];
    }
    _rockets.add(
      _Rocket(
        x: (0.08 + random.nextDouble() * 0.84) * size.width,
        y: size.height + 8,
        vx: (random.nextDouble() - 0.5) * 110,
        vy: -(950 + random.nextDouble() * 350),
        burstY: (0.14 + random.nextDouble() * 0.3) * size.height,
        color: color,
        shell: random.nextDouble() < 0.32
            ? _ShellType.willow
            : _ShellType.peony,
        secondaryColor: secondary,
        hasSecondary: random.nextDouble() < 0.3,
      ),
    );
  }

  void _spawnGoldSparkles() {
    for (var i = 0; i < 5; i++) {
      _addSpark(
        x: size.width * 0.5 + (random.nextDouble() - 0.5) * size.width * 0.4,
        y: size.height * 0.5 + (random.nextDouble() - 0.5) * size.height * 0.3,
        vx: (random.nextDouble() - 0.5) * 60,
        vy: -20 - random.nextDouble() * 50,
        gravity: 90,
        drag: 0.8,
        life: 0.6 + random.nextDouble() * 0.5,
        size: 4 + random.nextDouble() * 4,
        color: const ui.Color(0xFFFFD977),
        strobe: true,
      );
    }
  }

  void _burst(_Rocket rocket) {
    final willow = rocket.shell == _ShellType.willow;
    var count = willow
        ? 90 + random.nextInt(40)
        : 140 + random.nextInt(80);
    // Shrink the burst when the spark budget is nearly exhausted.
    final headroom = _maxSparks - _sparks.length;
    if (headroom < count + 200) {
      count = math.max(40, (count * (headroom / (count + 200))).round());
    }
    final baseSpeed = willow
        ? 220 + random.nextDouble() * 100
        : 280 + random.nextDouble() * 140;

    for (var i = 0; i < count; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      // Two populations: a dense outer shell ring plus a slower inner core —
      // together they read as a spherical burst in 2D projection.
      final shellRing = random.nextDouble() < 0.7;
      final speed = baseSpeed *
          (shellRing ? 0.85 + random.nextDouble() * 0.15 : 0.2 + random.nextDouble() * 0.5);
      _addSpark(
        x: rocket.x,
        y: rocket.y,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        gravity: willow ? 560 : 330,
        drag: willow ? 0.9 : 1.9,
        life: willow
            ? 2.6 + random.nextDouble()
            : 1.4 + random.nextDouble() * 0.8,
        size: willow ? 2.5 + random.nextDouble() * 1.5 : 3 + random.nextDouble() * 3,
        color: rocket.color,
        strobe: !willow && random.nextDouble() < 0.35,
      );
    }

    // Smoke puffs, drawn under the sparks.
    final smokeCount = 4 + random.nextInt(3);
    for (var i = 0; i < smokeCount; i++) {
      _smokes.add(
        _Smoke(
          x: rocket.x + (random.nextDouble() - 0.5) * 40,
          y: rocket.y + (random.nextDouble() - 0.5) * 40,
          vx: (random.nextDouble() - 0.5) * 24,
          vy: -18 - random.nextDouble() * 14,
          radius: 18 + random.nextDouble() * 16,
          growth: 12 + random.nextDouble() * 10,
          life: 1.4 + random.nextDouble() * 0.5,
        ),
      );
    }

    _flashColor = rocket.color;
    _flashAlpha = 0.05 + random.nextDouble() * 0.015;

    if (rocket.hasSecondary) {
      _schedule(
        _Event(time + 0.35, () {
          final mini = 28 + random.nextInt(14);
          for (var i = 0; i < mini; i++) {
            final angle = random.nextDouble() * math.pi * 2;
            final speed = 120 + random.nextDouble() * 80;
            _addSpark(
              x: rocket.x + (random.nextDouble() - 0.5) * 90,
              y: rocket.y + (random.nextDouble() - 0.5) * 90,
              vx: math.cos(angle) * speed,
              vy: math.sin(angle) * speed,
              gravity: 380,
              drag: 1.8,
              life: 0.8 + random.nextDouble() * 0.5,
              size: 2.5 + random.nextDouble() * 2,
              color: rocket.secondaryColor,
              strobe: random.nextDouble() < 0.5,
            );
          }
        }),
      );
    }
  }

  void _addSpark({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double gravity,
    required double drag,
    required double life,
    required double size,
    required ui.Color color,
    required bool strobe,
  }) {
    if (_sparks.length >= _maxSparks) return;
    _sparks.add(
      _Spark(
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        gravity: gravity,
        drag: drag,
        life: life,
        size: size,
        color: color,
        strobe: strobe,
        twinkleFreq: 22 + random.nextDouble() * 30,
        phase: random.nextDouble() * math.pi * 2,
      ),
    );
  }

  // --- Integration -----------------------------------------------------------

  void _integrateRockets(double dt) {
    for (final rocket in _rockets) {
      rocket.vy += 380 * dt; // slight deceleration while climbing
      rocket.vx *= math.exp(-0.35 * dt);
      rocket.x += rocket.vx * dt;
      rocket.y += rocket.vy * dt;

      // Trail embers.
      for (var i = 0; i < 2; i++) {
        _addSpark(
          x: rocket.x + (random.nextDouble() - 0.5) * 4,
          y: rocket.y + (random.nextDouble() - 0.5) * 4,
          vx: -rocket.vx * 0.05 + (random.nextDouble() - 0.5) * 50,
          vy: -rocket.vy * 0.05 + (random.nextDouble() - 0.5) * 50,
          gravity: 120,
          drag: 2.4,
          life: 0.22 + random.nextDouble() * 0.18,
          size: 4 + random.nextDouble() * 3,
          color: _trailColor,
          strobe: false,
        );
      }

      if (rocket.y <= rocket.burstY || rocket.vy > -60) {
        _burst(rocket);
        rocket.dead = true;
      }
    }
  }

  void _integrateSparks(double dt) {
    for (final spark in _sparks) {
      spark.age += dt;
      if (spark.age >= spark.life) {
        spark.dead = true;
        continue;
      }
      spark.vy += spark.gravity * dt;
      final damp = math.exp(-spark.drag * dt);
      spark.vx *= damp;
      spark.vy *= damp;
      spark.x += spark.vx * dt;
      spark.y += spark.vy * dt;
      if (spark.y > size.height + 40 ||
          spark.x < -120 ||
          spark.x > size.width + 120) {
        spark.dead = true;
      }
    }
  }

  void _integrateConfetti(double dt) {
    for (final piece in _confetti) {
      final sway = piece.swayAmplitude *
          math.sin(piece.swayFrequency * time + piece.swayPhase);
      piece.vx += (-_confettiDragX * piece.vx + sway) * dt;
      piece.vy += (_gravity - _confettiDragY * piece.vy) * dt;
      piece.x += piece.vx * dt;
      piece.y += piece.vy * dt;
      piece.ax += piece.wx * dt;
      piece.ay += piece.wy * dt;
      piece.az += piece.wz * dt;
      if (piece.y > size.height + 80) {
        piece.dead = true;
      }
    }
  }

  void _integrateSmoke(double dt) {
    for (final smoke in _smokes) {
      smoke.age += dt;
      if (smoke.age >= smoke.life) {
        smoke.dead = true;
        continue;
      }
      smoke.x += smoke.vx * dt;
      smoke.y += smoke.vy * dt;
      smoke.radius += smoke.growth * dt;
    }
  }

  void _reap() {
    _swapRemove(_confetti, (c) => c.dead);
    _swapRemove(_rockets, (r) => r.dead);
    _swapRemove(_sparks, (s) => s.dead);
    _swapRemove(_smokes, (s) => s.dead);
  }

  static void _swapRemove<T>(List<T> list, bool Function(T) isDead) {
    var i = 0;
    while (i < list.length) {
      if (isDead(list[i])) {
        final last = list.removeLast();
        // When the dead element was itself the tail, it is already gone.
        if (i < list.length) list[i] = last;
      } else {
        i++;
      }
    }
  }

  // --- Rendering ---------------------------------------------------------------

  void paint(ui.Canvas canvas, ui.Size canvasSize) {
    _paintSmoke(canvas);
    _paintFlash(canvas, canvasSize);
    _paintAdditiveLayer(canvas);
    _paintConfetti(canvas);
  }

  void _paintSmoke(ui.Canvas canvas) {
    for (final smoke in _smokes) {
      final ratio = smoke.age / smoke.life;
      // Quick fade in, slow fade out.
      final alpha = 0.09 *
          (ratio < 0.15 ? ratio / 0.15 : 1 - (ratio - 0.15) / 0.85);
      if (alpha <= 0) continue;
      _smokePaint.color = _smokeColor.withValues(alpha: alpha);
      canvas.drawCircle(
        ui.Offset(smoke.x, smoke.y),
        smoke.radius,
        _smokePaint,
      );
    }
  }

  void _paintFlash(ui.Canvas canvas, ui.Size canvasSize) {
    if (_flashAlpha <= 0.001) return;
    _flashPaint.color = _flashColor.withValues(alpha: _flashAlpha);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      _flashPaint,
    );
  }

  void _paintAdditiveLayer(ui.Canvas canvas) {
    _sparkPaint.blendMode = ui.BlendMode.plus;

    // Rockets: bright climbing head.
    for (final rocket in _rockets) {
      _drawGlow(canvas, rocket.x, rocket.y, 11, _trailColor, 1);
    }
    for (final spark in _sparks) {
      final ratio = spark.age / spark.life;
      var alpha = ratio < 0.7 ? 1.0 : 1 - (ratio - 0.7) / 0.3;
      if (spark.strobe) {
        alpha *= 0.62 + 0.38 * math.sin(spark.age * spark.twinkleFreq + spark.phase);
        // Random-looking dropout towards the end of life: crackle.
        if (ratio > 0.75 &&
            math.sin(spark.age * 97 + spark.phase * 13) > 0.35) {
          alpha *= 0.2;
        }
      }
      if (alpha <= 0.02) continue;
      final drawSize = spark.size * (1.5 - 0.5 * ratio);

      // Motion streak: a short additive line behind the spark along its
      // velocity, the comet tail real firework embers show.
      final speed =
          math.sqrt(spark.vx * spark.vx + spark.vy * spark.vy);
      if (speed > 60) {
        final streak = math.min(0.045, 22 / speed);
        _streakPaint
          ..color = spark.color.withValues(alpha: (alpha * 0.45).clamp(0, 1))
          ..strokeWidth = drawSize * 0.9;
        canvas.drawLine(
          ui.Offset(spark.x - spark.vx * streak, spark.y - spark.vy * streak),
          ui.Offset(spark.x, spark.y),
          _streakPaint,
        );
      }
      _drawGlow(canvas, spark.x, spark.y, drawSize, spark.color, alpha.clamp(0, 1));
    }
  }

  void _drawGlow(
      ui.Canvas canvas, double x, double y, double radius, ui.Color color, double alpha) {
    final sprite = _glowFor(color);
    final rect = ui.Rect.fromCenter(
      center: ui.Offset(x, y),
      width: radius * 4,
      height: radius * 4,
    );
    _sparkPaint.color = ui.Color.fromRGBO(255, 255, 255, alpha);
    if (sprite != null) {
      canvas.drawImageRect(sprite, _glowSourceRect, rect, _sparkPaint);
    } else {
      // Fallback when offscreen sprite rasterisation is unavailable.
      _sparkPaint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(ui.Offset(x, y), radius, _sparkPaint);
    }
  }

  static const ui.Rect _glowSourceRect = ui.Rect.fromLTWH(0, 0, 32, 32);

  ui.Image? _glowFor(ui.Color color) {
    if (_glowUnsupported) return null;
    final cached = _glowCache[color.toARGB32()];
    if (cached != null) return cached;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()
        ..shader = ui.Gradient.radial(
          const ui.Offset(16, 16),
          16,
          [
            color.withValues(alpha: 1),
            color.withValues(alpha: 0.5),
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0),
          ],
          [0, 0.35, 0.65, 1],
        );
      canvas.drawCircle(const ui.Offset(16, 16), 16, paint);
      final image = recorder.endRecording().toImageSync(32, 32);
      _glowCache[color.toARGB32()] = image;
      return image;
    } catch (_) {
      _glowUnsupported = true;
      return null;
    }
  }

  void _paintConfetti(ui.Canvas canvas) {
    // Only during the final fade do we pay for one saveLayer; while flying,
    // confetti is fully opaque and needs no layer.
    final fading = time > CelebrationTimeline.fadeStart;
    if (fading) {
      final alpha = ((CelebrationTimeline.total - time) /
              (CelebrationTimeline.total - CelebrationTimeline.fadeStart))
          .clamp(0.0, 1.0);
      if (alpha <= 0) return;
      canvas.saveLayer(
        ui.Offset.zero & size,
        ui.Paint()..color = ui.Color.fromRGBO(255, 255, 255, alpha),
      );
    }

    final path = ui.Path();
    for (final piece in _confetti) {
      final ca = math.cos(piece.ax), sa = math.sin(piece.ax);
      final cb = math.cos(piece.ay), sb = math.sin(piece.ay);
      final cc = math.cos(piece.az), sc = math.sin(piece.az);
      // Rows 0–1 of R = Rz·Ry·Rx (orthographic projection of the 3D rotation);
      // nz = R22 = ca·cb is the face normal's z component.
      final r00 = cc * cb;
      final r01 = cc * sa * sb - sc * ca;
      final r10 = sc * cb;
      final r11 = sc * sa * sb + cc * ca;
      final nz = ca * cb;
      final isBack = nz < 0;

      if (piece.kind == _ConfettiKind.rect) {
        // Column-major 4×4 with the piece's width/height baked in, drawing a
        // unit rect centred on the origin.
        _confettiMatrix[0] = r00 * piece.width;
        _confettiMatrix[1] = r10 * piece.width;
        _confettiMatrix[4] = r01 * piece.height;
        _confettiMatrix[5] = r11 * piece.height;
        _confettiMatrix[12] = piece.x;
        _confettiMatrix[13] = piece.y;
        canvas.save();
        canvas.transform(_confettiMatrix);
        canvas.drawRect(_unitRect, _confettiPaint(piece.color, isBack));
        canvas.restore();
      } else {
        // Ribbon: a quadratic strip from tail to head along the flight
        // direction, its middle swaying so the ribbon writhes mid-air. The
        // projected width narrows with |nz| to fake the plate turning.
        var dirX = piece.vx, dirY = piece.vy;
        final dirLen = math.sqrt(dirX * dirX + dirY * dirY);
        if (dirLen < 1) {
          dirX = 0;
          dirY = -1;
        } else {
          dirX /= dirLen;
          dirY /= dirLen;
        }
        final headX = piece.x, headY = piece.y;
        final tailX = headX - dirX * piece.height;
        final tailY = headY - dirY * piece.height;
        final sway = math.sin(time * 9 + piece.ribbonPhase) *
            (5 + 4 * math.sin(piece.ay).abs());
        final ctrlX = (headX + tailX) / 2 - dirY * sway;
        final ctrlY = (headY + tailY) / 2 + dirX * sway;
        path.reset();
        path.moveTo(tailX, tailY);
        path.quadraticBezierTo(ctrlX, ctrlY, headX, headY);
        _ribbonPaint
          ..color = _confettiPaint(piece.color, isBack).color
          ..strokeWidth = piece.width * (0.35 + 0.65 * nz.abs());
        canvas.drawPath(path, _ribbonPaint);
      }
    }

    if (fading) canvas.restore();
  }

  ui.Paint _confettiPaint(ui.Color color, bool isBack) {
    final cache = isBack ? _confettiBackPaints : _confettiFrontPaints;
    return cache.putIfAbsent(
      color.toARGB32(),
      () => ui.Paint()
        ..color = isBack ? color.withValues(alpha: 0.55) : color,
    );
  }
}
