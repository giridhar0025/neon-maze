import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Simulation;

import '../data/store.dart';
import '../game/levels.dart';
import '../game/particles.dart';
import '../game/simulation.dart';
import '../game/tilt.dart';
import '../theme/palette.dart';

/// Screen-space mapping from world units (1 cell = 1 unit) to pixels.
class BoardView {
  const BoardView({required this.scale, required this.origin, required this.size});

  final double scale;
  final Offset origin;
  final Size size;

  Offset toScreen(Offset world) => origin + world * scale;

  Rect toScreenRect(Rect world) => Rect.fromLTRB(
        origin.dx + world.left * scale,
        origin.dy + world.top * scale,
        origin.dx + world.right * scale,
        origin.dy + world.bottom * scale,
      );

  double px(double world) => world * scale;
}

/// Renders the immutable parts of a board (background, walls, holes, zones)
/// into a cached image. Rebuilt only when the level or viewport changes.
class BoardRenderer {
  ui.Image? image;
  BoardView? view;

  void build({
    required LevelRuntime level,
    required Size size,
    required double dpr,
    required ChapterTheme theme,
    required bool colorblind,
  }) {
    if (size.isEmpty) return;

    final world = Size(level.spec.cols.toDouble(), level.spec.rows.toDouble());
    const padding = 22.0;
    final usable = Size(
      max(1, size.width - padding * 2),
      max(1, size.height - padding * 2),
    );
    final scale = min(usable.width / world.width, usable.height / world.height);
    final boardPx = Size(world.width * scale, world.height * scale);
    final origin = Offset(
      (size.width - boardPx.width) / 2,
      (size.height - boardPx.height) / 2,
    );
    final view = BoardView(scale: scale, origin: origin, size: size);
    this.view = view;

    final width = max(1, (size.width * dpr).round());
    final height = max(1, (size.height * dpr).round());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);
    _paintStatic(canvas, size, view, level, theme, colorblind);
    final picture = recorder.endRecording();
    final next = picture.toImageSync(width, height);
    image?.dispose();
    image = next;
    picture.dispose();
  }

  void dispose() {
    image?.dispose();
    image = null;
  }

  void _paintStatic(
    Canvas canvas,
    Size size,
    BoardView view,
    LevelRuntime level,
    ChapterTheme theme,
    bool colorblind,
  ) {
    final themeA = theme.a;

    // Screen backdrop.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF070C18), Color(0xFF04060D)],
        ).createShader(Offset.zero & size),
    );

    // Ambient nebula fills the letterboxed space on tall screens.
    for (final blob in [
      (Offset(size.width * 0.12, size.height * 0.10), theme.b, 0.55, 0.11),
      (Offset(size.width * 0.92, size.height * 0.26), themeA, 0.48, 0.10),
      (Offset(size.width * 0.35, size.height * 0.94), theme.b, 0.62, 0.09),
    ]) {
      final radius = size.shortestSide * blob.$3;
      canvas.drawCircle(
        blob.$1,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [blob.$2.withValues(alpha: blob.$4), Colors.transparent],
          ).createShader(Rect.fromCircle(center: blob.$1, radius: radius)),
      );
    }

    // Faint technical grid.
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 46) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 46) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Ambient bloom behind the board.
    final boardRect = view.toScreenRect(
      Rect.fromLTWH(0, 0, level.spec.cols.toDouble(), level.spec.rows.toDouble()),
    );
    canvas.drawRect(
      boardRect.inflate(view.px(1.2)),
      Paint()
        ..shader = RadialGradient(
          colors: [themeA.withValues(alpha: 0.10), Colors.transparent],
          stops: const [0.0, 1.0],
        ).createShader(boardRect.inflate(view.px(1.2))),
    );

    // Board plate.
    final plate = RRect.fromRectAndRadius(
      boardRect.inflate(view.px(0.32)),
      Radius.circular(view.px(0.42)),
    );
    canvas.drawRRect(
      plate.shift(Offset(0, view.px(0.16))),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, view.px(0.34)),
    );
    canvas.drawRRect(
      plate,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF101A31), themeA, 0.06)!,
            const Color(0xFF070B16),
          ],
        ).createShader(boardRect),
    );
    canvas.drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.055),
    );

    // Faint cell dots give the surface a machined feel.
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.035);
    for (var y = 0; y < level.spec.rows; y++) {
      for (var x = 0; x < level.spec.cols; x++) {
        canvas.drawCircle(view.toScreen(Offset(x + 0.5, y + 0.5)), 1.1, dotPaint);
      }
    }

    // Hazards under the walls: ice, tar, holes.
    for (final zone in level.ice) {
      final rect = view.toScreenRect(zone.rect);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(view.px(0.16)));
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.ice.withValues(alpha: 0.18),
              AppColors.ice.withValues(alpha: 0.04),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.ice.withValues(alpha: 0.35),
      );
      // Sheen.
      final sheen = Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 3; k++) {
        final o = rect.topLeft + Offset(rect.width * (0.18 + k * 0.26), rect.height * 0.12);
        canvas.drawLine(o, o + Offset(rect.width * 0.12, rect.height * 0.22), sheen);
      }
    }

    for (final zone in level.tar) {
      final rect = view.toScreenRect(zone.rect);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(view.px(0.2)));
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.tar.withValues(alpha: 0.30),
              const Color(0xFF1A1030).withValues(alpha: 0.65),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.tar.withValues(alpha: 0.34),
      );
    }

    for (final hole in level.holes) {
      final c = view.toScreen(hole.center);
      final r = view.px(hole.radius);

      // Deep shadow and a soft warning glow around the drop.
      canvas.drawCircle(
        c,
        r * 1.75,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.60)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.65),
      );
      canvas.drawCircle(
        c,
        r * 1.30,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.danger.withValues(alpha: 0.10),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.3)),
      );

      // Machined rim band.
      canvas.drawCircle(
        c,
        r * 1.02,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.0, r * 0.15)
          ..shader = SweepGradient(
            colors: [
              AppColors.danger.withValues(alpha: 0.55),
              themeA.withValues(alpha: 0.45),
              AppColors.danger.withValues(alpha: 0.55),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );

      // Layered well: pure black at the centre, cold blue-black at the lip.
      canvas.drawCircle(
        c,
        r * 0.94,
        Paint()
          ..shader = RadialGradient(
            colors: const [
              Color(0xFF000000),
              Color(0xFF02040A),
              Color(0xFF0B1220),
            ],
            stops: const [0.0, 0.68, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r * 0.94)),
      );
      canvas.drawCircle(
        c,
        r * 0.64,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.danger.withValues(alpha: 0.14),
      );
      canvas.drawCircle(
        c,
        r * 0.38,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = themeA.withValues(alpha: 0.10),
      );

      // Rim ticks.
      final tick = Paint()
        ..color = AppColors.danger.withValues(alpha: 0.34)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 8; k++) {
        final angle = k * pi / 4;
        final dir = Offset(cos(angle), sin(angle));
        canvas.drawLine(c + dir * (r * 1.08), c + dir * (r * 1.28), tick);
      }

      // Cold glint on the inner wall.
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.56),
        -pi * 0.80,
        pi * 0.38,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.10),
      );
    }

    _paintWalls(canvas, view, level, theme, colorblind);

    // Exit pad base.
    final exit = view.toScreen(level.exit);
    final exitR = view.px(Simulation.exitRadius);
    canvas.drawCircle(
      exit,
      exitR * 1.9,
      Paint()
        ..color = AppColors.mint.withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, exitR),
    );
    canvas.drawCircle(
      exit,
      exitR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.mint.withValues(alpha: 0.28),
            AppColors.mint.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromCircle(center: exit, radius: exitR)),
    );
    canvas.drawCircle(
      exit,
      exitR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.mint.withValues(alpha: 0.65),
    );
    canvas.drawCircle(
      exit,
      exitR * 0.38,
      Paint()..color = AppColors.mint.withValues(alpha: 0.85),
    );
  }

  void _paintWalls(
    Canvas canvas,
    BoardView view,
    LevelRuntime level,
    ChapterTheme theme,
    bool colorblind,
  ) {
    final t = Simulation.wallThickness;
    final allSegments = level.maze.wallSegments(t);
    // Breakable sections are drawn live so they can disappear on impact.
    final segments = allSegments
        .where((segment) => !level.isBreakableBox(segment))
        .toList();
    final accent = theme.a;

    // Walls are stroked with round caps and round joins — that is what gives
    // them the soft, rounded ends and the seamless curved corners.
    //
    // The overshoot is handled per end instead of globally: an end that is
    // shared with another wall is pushed *into* the joint so the two round caps
    // fuse, while a free end stops half a stroke short so its cap lands exactly
    // on the collision edge. Round geometry, zero spill.
    final joints = <String, int>{};
    String keyOf(Offset p) =>
        '${(p.dx * 1000).round()}:${(p.dy * 1000).round()}';
    final posts = <(Offset, Offset)>[];
    for (final segment in segments) {
      final horizontal = segment.width >= segment.height;
      final a = horizontal
          ? Offset(segment.left, segment.center.dy)
          : Offset(segment.center.dx, segment.top);
      final b = horizontal
          ? Offset(segment.right, segment.center.dy)
          : Offset(segment.center.dx, segment.bottom);
      posts.add((a, b));
      joints[keyOf(a)] = (joints[keyOf(a)] ?? 0) + 1;
      joints[keyOf(b)] = (joints[keyOf(b)] ?? 0) + 1;
    }

    // Solid casing under the neon so the glow has an edge to sit against.
    final shell = Path();
    for (final segment in segments) {
      shell.addRect(view.toScreenRect(segment));
    }
    canvas.drawPath(
      shell,
      Paint()
        ..color = accent.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, view.px(0.30)),
    );
    canvas.drawPath(shell, Paint()..color = const Color(0xFF05080F));

    final tubeWidth = view.px(t) * 1.14;
    final coreWidth = view.px(t) * 0.86;
    final hotWidth = max(1.0, view.px(t) * 0.30);

    void strokeWalls(double width, Paint paint) {
      final path = Path();
      for (final (a, b) in posts) {
        final start = view.toScreen(a);
        final end = view.toScreen(b);
        final delta = end - start;
        final length = delta.distance;
        if (length < 1e-6) continue;
        final dir = delta / length;
        // A shared end runs right up to the lattice point: the two round caps
        // overlap there and fuse into a curved corner. A free end stops half a
        // stroke short, so its cap lands exactly on the collision edge.
        final head = (joints[keyOf(a)] ?? 1) > 1 ? 0.0 : width / 2;
        final tail = (joints[keyOf(b)] ?? 1) > 1 ? 0.0 : width / 2;
        final p0 = start + dir * head;
        final p1 = end - dir * tail;
        path.moveTo(p0.dx, p0.dy);
        path.lineTo(p1.dx, p1.dy);
      }
      canvas.drawPath(path, paint);
    }

    strokeWalls(
      tubeWidth,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = accent.withValues(alpha: 0.34)
        ..strokeWidth = tubeWidth
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, view.px(0.14)),
    );
    strokeWalls(
      coreWidth,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = accent
        ..strokeWidth = coreWidth
        ..strokeCap = StrokeCap.round,
    );
    strokeWalls(
      hotWidth,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Color.lerp(accent, Colors.white, 0.55)!
        ..strokeWidth = hotWidth
        ..strokeCap = StrokeCap.round,
    );
  }
}

/// Draws the live scene: hazards that animate, orbs, exit state, trail, marble,
/// particles and the blackout mask.
class ScenePainter extends CustomPainter {
  ScenePainter({
    required this.sim,
    required this.level,
    required this.theme,
    required this.renderer,
    required this.particles,
    required this.settings,
    required this.tilt,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final Simulation sim;
  final LevelRuntime level;
  final ChapterTheme theme;
  final BoardRenderer renderer;
  final ParticleField particles;
  final GameSettings settings;
  final TiltController tilt;

  static const double _marbleWorldRadius = 0.19;

  @override
  void paint(Canvas canvas, Size size) {
    final view = renderer.view;
    final image = renderer.image;
    if (view == null || image == null) return;

    // The board is fixed to the screen. It used to shift with tilt as a
    // parallax flourish, but those few pixels made the maze look like it was
    // sliding under the marble while steering, so the board now stays put and
    // only the marble moves.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF04060D),
    );

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );

    _paintConveyors(canvas, view);
    _paintMagnets(canvas, view);
    _paintPortals(canvas, view);
    _paintFlowPanels(canvas, view);
    _paintBumpers(canvas, view);
    _paintSliders(canvas, view);
    _paintBreakables(canvas, view);
    _paintOrbs(canvas, view);
    _paintGates(canvas, view);
    _paintHolesLive(canvas, view);
    _paintExit(canvas, view);
    _paintTrail(canvas, view);
    _paintParticles(canvas, view);
    if (!sim.fell) _paintMarble(canvas, view);
    if (level.spec.blackout) _paintBlackout(canvas, view, size);
    _paintVignette(canvas, size);
  }

  /// Floor belts. The base is a tinted pad; the chevrons show which way it is
  /// pushing so the player can decide to ride it or fight it.
  void _paintConveyors(Canvas canvas, BoardView view) {
    for (var i = 0; i < level.conveyors.length; i++) {
      final conveyor = level.conveyors[i];
      final rect = view.toScreenRect(conveyor.rect);
      final color = settings.colorblind ? AppColors.blue : theme.b;
      final pulse = settings.reduceMotion
          ? 0.5
          : 0.5 + 0.5 * sin(sim.visualTime * 2.0 + i);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(view.px(0.16))),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.16 + pulse * 0.05),
              color.withValues(alpha: 0.04),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(view.px(0.16))),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: 0.34),
      );

      final dir = conveyor.direction;
      final perp = Offset(-dir.dy, dir.dx);
      final center = view.toScreen(conveyor.rect.center);
      final half = view.px(0.40);
      final phase = settings.reduceMotion ? 0.25 : (sim.visualTime * 1.5) % 1.0;
      final arrow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 3; k++) {
        final along = (-1.0 + (k + phase) * 0.85) * half;
        final c = center + dir * along;
        final tip = c + dir * view.px(0.11);
        final back = c - dir * view.px(0.04);
        final left = back + perp * view.px(0.085);
        final right = back - perp * view.px(0.085);
        arrow.color = color.withValues(alpha: 0.30 + 0.20 * pulse);
        canvas.drawPath(
          Path()
            ..moveTo(left.dx, left.dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(right.dx, right.dy),
          arrow,
        );
      }
      // Side rails make the belt read as a mechanical strip.
      final rail = Paint()
        ..color = color.withValues(alpha: 0.14)
        ..strokeWidth = 1;
      canvas.drawLine(
        center + perp * view.px(0.38),
        center + perp * view.px(0.38) + dir * view.px(0.7),
        rail,
      );
      canvas.drawLine(
        center - perp * view.px(0.38),
        center - perp * view.px(0.38) + dir * view.px(0.7),
        rail,
      );
    }
  }

  /// Attractors pull the marble in, repulsors push it away. The arrows point
  /// the way the force acts.
  void _paintMagnets(Canvas canvas, BoardView view) {
    for (var i = 0; i < level.magnets.length; i++) {
      final magnet = level.magnets[i];
      final center = view.toScreen(magnet.center);
      final radius = view.px(magnet.radius);
      final color = magnet.attract ? AppColors.blue : AppColors.magenta;
      final pulse = settings.reduceMotion
          ? 0.5
          : 0.5 + 0.5 * sin(sim.visualTime * 2.4 + i * 1.3);

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.05 + pulse * 0.03),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );

      // Three broken rings.
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 3; k++) {
        ring.color = color.withValues(alpha: 0.16 + 0.10 * pulse);
        final r = radius * (0.38 + k * 0.24);
        final spin = sim.visualTime * (magnet.attract ? 0.7 : -0.7) + k * 1.4;
        for (var a = 0; a < 3; a++) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: r),
            spin + a * (2 * pi / 3),
            0.65,
            false,
            ring,
          );
        }
      }

      // Radial force ticks.
      final tick = Paint()
        ..color = color.withValues(alpha: 0.30 + 0.18 * pulse)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 8; k++) {
        final angle = k * pi / 4 + sim.visualTime * 0.15;
        final outer = radius * 0.82;
        final inner = outer - radius * (magnet.attract ? 0.12 : 0.06);
        final dir = Offset(cos(angle), sin(angle));
        final start = center + dir * (magnet.attract ? outer : inner);
        final end = center + dir * (magnet.attract ? inner : outer);
        canvas.drawLine(start, end, tick);
        // Arrow head, pointing in or out.
        final tip = magnet.attract ? end : start;
        final back = magnet.attract ? start : end;
        final side = Offset(-dir.dy, dir.dx) * view.px(0.035);
        canvas.drawLine(tip, back + side, tick);
        canvas.drawLine(tip, back - side, tick);
      }

      // Centre badge with a plus (attract) or minus (repel).
      canvas.drawCircle(
        center,
        radius * 0.16,
        Paint()..color = color.withValues(alpha: 0.18),
      );
      final mark = Paint()
        ..color = color.withValues(alpha: 0.9)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center - Offset(radius * 0.07, 0),
        center + Offset(radius * 0.07, 0),
        mark,
      );
      if (magnet.attract) {
        canvas.drawLine(
          center - Offset(0, radius * 0.07),
          center + Offset(0, radius * 0.07),
          mark,
        );
      }
    }
  }

  /// Bumpers are physical redirectors, so they get a bright spring ring and a
  /// pulsing core instead of being an invisible force.
  void _paintBumpers(Canvas canvas, BoardView view) {
    for (var i = 0; i < level.bumpers.length; i++) {
      final bumper = level.bumpers[i];
      final c = view.toScreen(bumper.center);
      final r = view.px(bumper.radius);
      final pulse = settings.reduceMotion
          ? 0.5
          : 0.5 + 0.5 * sin(sim.visualTime * 2.8 + i * 1.6);
      final color = settings.colorblind ? AppColors.amber : theme.b;

      // Hit feedback. `hit` fades 1 -> 0 over ~0.25s: the ring snaps outward,
      // the core compresses, and a shockwave ring expands and dies out. The
      // strength is reduced (not removed) when reduce-motion is on.
      final hit = i < sim.bumperFlash.length
          ? sim.bumperFlash[i] * (settings.reduceMotion ? 0.45 : 1.0)
          : 0.0;
      final ringR = r * (1 + hit * 0.20);
      final coreR = r * (0.24 - hit * 0.09);

      canvas.drawCircle(
        c,
        r * 1.25,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.40)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
      );
      canvas.drawCircle(
        c,
        ringR * (1.3 + pulse * 0.12),
        Paint()
          ..color = color.withValues(alpha: 0.12 + 0.10 * pulse + 0.30 * hit)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.50),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.28 + 0.30 * hit),
              const Color(0xFF07101E),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      canvas.drawCircle(
        c,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + hit * 1.6
          ..color = color.withValues(alpha: 0.82),
      );
      canvas.drawCircle(
        c,
        ringR * 0.64,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.28 + 0.15 * pulse + 0.35 * hit),
      );

      // Expanding shockwave, only while the flash is fresh.
      if (hit > 0.01) {
        final spread = 1.0 + (1 - hit) * 0.85;
        canvas.drawCircle(
          c,
          r * spread,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8 * hit
            ..color = color.withValues(alpha: 0.55 * hit),
        );
      }

      // Spring spokes.
      final spoke = Paint()
        ..color = color.withValues(alpha: 0.55)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 6; k++) {
        final angle = k * pi / 3 + sim.visualTime * 0.18;
        final dir = Offset(cos(angle), sin(angle));
        canvas.drawLine(c + dir * (r * 0.72), c + dir * (r * 0.98), spoke);
        canvas.drawCircle(c + dir * (r * 1.04), 1.4, spoke);
      }

      canvas.drawCircle(
        c,
        coreR,
        Paint()..color = color.withValues(alpha: 0.90),
      );
      canvas.drawCircle(
        c,
        coreR * 0.5,
        Paint()
          ..color = Colors.white.withValues(
            alpha: (0.85 + 0.15 * hit).clamp(0.0, 1.0),
          ),
      );
    }
  }

  /// Sliding wall with a clear travel track and a hot leading edge.
  void _paintSliders(Canvas canvas, BoardView view) {
    for (final slider in level.sliders) {
      final rect = view.toScreenRect(slider.rectAt(sim.time));
      final color = settings.colorblind ? AppColors.amber : AppColors.ice;

      // Travel track and end stops.
      final base = view.toScreen(slider.base);
      final axis = slider.slidesVertically ? const Offset(0, 1) : const Offset(1, 0);
      final halfTrack = view.px(slider.amplitude);
      final track = Paint()
        ..color = color.withValues(alpha: 0.13)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(base - axis * halfTrack, base + axis * halfTrack, track);
      canvas.drawCircle(base - axis * halfTrack, 2, Paint()..color = color.withValues(alpha: 0.35));
      canvas.drawCircle(base + axis * halfTrack, 2, Paint()..color = color.withValues(alpha: 0.35));

      final rr = RRect.fromRectAndRadius(
        rect,
        Radius.circular(rect.shortestSide * 0.42),
      );
      canvas.drawRRect(
        rr.inflate(view.px(0.05)),
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, view.px(0.10)),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(const Color(0xFF4A2A20), color, 0.35)!,
              const Color(0xFF120A08),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color.withValues(alpha: 0.72),
      );

      final horizontal = rect.width >= rect.height;
      final coreStart = horizontal
          ? Offset(rect.left + rect.shortestSide * 0.35, rect.center.dy)
          : Offset(rect.center.dx, rect.top + rect.shortestSide * 0.35);
      final coreEnd = horizontal
          ? Offset(rect.right - rect.shortestSide * 0.35, rect.center.dy)
          : Offset(rect.center.dx, rect.bottom - rect.shortestSide * 0.35);
      canvas.drawLine(
        coreStart,
        coreEnd,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..strokeWidth = max(1, rect.shortestSide * 0.18)
          ..strokeCap = StrokeCap.round,
      );
      // End pistons on the bar.
      if (horizontal) {
        for (final x in [rect.left + rect.shortestSide * 0.3, rect.right - rect.shortestSide * 0.3]) {
          canvas.drawCircle(
            Offset(x, rect.center.dy),
            rect.shortestSide * 0.16,
            Paint()..color = color.withValues(alpha: 0.9),
          );
        }
      } else {
        for (final y in [rect.top + rect.shortestSide * 0.3, rect.bottom - rect.shortestSide * 0.3]) {
          canvas.drawCircle(
            Offset(rect.center.dx, y),
            rect.shortestSide * 0.16,
            Paint()..color = color.withValues(alpha: 0.9),
          );
        }
      }
    }
  }

  /// Live rim animation over the cached hole geometry.
  void _paintHolesLive(Canvas canvas, BoardView view) {
    for (var i = 0; i < level.holes.length; i++) {
      final hole = level.holes[i];
      final center = view.toScreen(hole.center);
      final radius = view.px(hole.radius);
      final pulse = settings.reduceMotion
          ? 0.5
          : 0.5 + 0.5 * sin(sim.visualTime * 2.2 + i * 1.7);

      // Two rotating warning arcs.
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = AppColors.danger.withValues(alpha: 0.22 + 0.20 * pulse);
      for (var k = 0; k < 2; k++) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius * 0.88),
          sim.visualTime * (k.isEven ? 0.9 : -0.9) + k * pi,
          pi * 0.55,
          false,
          arc,
        );
      }

      // Inward suction ticks.
      final suction = Paint()
        ..color = Colors.white.withValues(alpha: 0.12 + 0.10 * pulse)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 5; k++) {
        final angle = k * (2 * pi / 5) + sim.visualTime * 0.4;
        final dir = Offset(cos(angle), sin(angle));
        final outer = radius * 0.95;
        final inner = radius * (0.72 + 0.08 * sin(sim.visualTime * 3 + k));
        canvas.drawLine(center + dir * inner, center + dir * outer, suction);
      }
    }
  }

  void _paintPortals(Canvas canvas, BoardView view) {
    for (var i = 0; i < level.portals.length; i++) {
      final pair = level.portals[i];
      final pairColor = i.isEven ? theme.b : AppColors.magenta;
      for (final point in [pair.a, pair.b]) {
        final c = view.toScreen(point);
        final r = view.px(0.28);
        canvas.drawCircle(
          c,
          r * 1.5,
          Paint()
            ..color = pairColor.withValues(alpha: 0.18)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r),
        );
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = pairColor.withValues(alpha: 0.85),
        );
        for (var k = 0; k < 3; k++) {
          final start = sim.visualTime * 1.4 + k * (pi * 2 / 3);
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * (0.55 + k * 0.14)),
            start,
            pi * 0.42,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: 0.45),
          );
        }
      }
    }
  }

  /// One-way membranes: a bright frame plus animated chevrons that show the
  /// only direction the marble can pass.
  void _paintFlowPanels(Canvas canvas, BoardView view) {
    for (var i = 0; i < level.flowPanels.length; i++) {
      final panel = level.flowPanels[i];
      final rect = view.toScreenRect(panel.rect);
      final rr = RRect.fromRectAndRadius(
        rect,
        Radius.circular(rect.shortestSide * 0.5),
      );
      final color = settings.colorblind ? AppColors.blue : AppColors.mint;
      final pulse = settings.reduceMotion
          ? 0.5
          : 0.5 + 0.5 * sin(sim.visualTime * 2.2 + i);

      canvas.drawRRect(
        rr.inflate(view.px(0.05)),
        Paint()
          ..color = color.withValues(alpha: 0.16 + pulse * 0.10)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, view.px(0.12)),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.55),
              color.withValues(alpha: 0.16),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color.withValues(alpha: 0.78),
      );

      // End caps make the membrane read as a physical one-way valve.
      final vertical = rect.height > rect.width;
      final cap = Paint()
        ..color = color.withValues(alpha: 0.95)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      if (vertical) {
        canvas.drawLine(
          Offset(rect.center.dx, rect.top + 2),
          Offset(rect.center.dx, rect.bottom - 2),
          cap,
        );
      } else {
        canvas.drawLine(
          Offset(rect.left + 2, rect.center.dy),
          Offset(rect.right - 2, rect.center.dy),
          cap,
        );
      }

      // Chevrons travel with the allowed direction.
      final dir = panel.direction;
      final perp = Offset(-dir.dy, dir.dx);
      final center = view.toScreen(panel.rect.center);
      final phase = settings.reduceMotion ? 0.35 : (sim.visualTime * 1.25) % 1.0;
      final arrow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (var k = 0; k < 3; k++) {
        final along = (-0.26 + k * 0.24 + phase * 0.22) * view.scale;
        final tipWorld = panel.rect.center +
            dir * ((along / view.scale) + 0.10);
        final backWorld = panel.rect.center + dir * (along / view.scale - 0.06);
        final tip = view.toScreen(tipWorld);
        final back = view.toScreen(backWorld);
        final wing = view.px(0.075);
        final a = back + perp * wing;
        final b = back - perp * wing;
        arrow.color = color.withValues(alpha: 0.55 + 0.35 * (k / 2));
        canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(b.dx, b.dy),
          arrow,
        );
      }
      // A faint dot keeps the centre readable when the arrows are mid-cycle.
      canvas.drawCircle(center, 1.6, Paint()..color = Colors.white.withValues(alpha: 0.55));
    }
  }

  /// Cracked wall sections. They stay visibly different from solid walls so a
  /// speed player can spot the shortcut before committing to it.
  void _paintBreakables(Canvas canvas, BoardView view) {
    for (var i = 0; i < level.breakables.length; i++) {
      final wall = level.breakables[i];
      if (wall.broken) continue;
      final rect = view.toScreenRect(wall.rect);
      final rr = RRect.fromRectAndRadius(
        rect,
        Radius.circular(max(2, view.px(Simulation.wallThickness * 0.42))),
      );
      final pulse = settings.reduceMotion
          ? 0.5
          : 0.5 + 0.5 * sin(sim.visualTime * 2.8 + i * 1.7);
      // Gold core against orange walls: a breakable section should read as
      // "hit me" from across the board.
      final color = AppColors.gold;
      final glow = AppColors.fracture;
      final horizontal = wall.rect.width >= wall.rect.height;

      canvas.drawRRect(
        rr.inflate(view.px(0.07)),
        Paint()
          ..color = glow.withValues(alpha: 0.16 + pulse * 0.14)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, view.px(0.15)),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF3A2410),
              const Color(0xFF120A08),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = color.withValues(alpha: 0.88),
      );

      // Three bright dashes along the long axis make it look pre-fractured.
      final longLen = horizontal ? rect.width : rect.height;
      final shortLen = horizontal ? rect.height : rect.width;
      final core = Paint()
        ..color = color.withValues(alpha: 0.88 + pulse * 0.10)
        ..strokeWidth = max(1.4, shortLen * 0.38)
        ..strokeCap = StrokeCap.butt;
      for (var k = 0; k < 3; k++) {
        final a = 0.16 + k * 0.28;
        final b = a + 0.15;
        final p0 = horizontal
            ? Offset(rect.left + longLen * a, rect.center.dy)
            : Offset(rect.center.dx, rect.top + longLen * a);
        final p1 = horizontal
            ? Offset(rect.left + longLen * b, rect.center.dy)
            : Offset(rect.center.dx, rect.top + longLen * b);
        canvas.drawLine(p0, p1, core);
      }

      final rnd = Random(wall.from.x * 131 + wall.from.y * 17 + i * 7);
      final crack = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.40 + pulse * 0.20);
      for (var c = 0; c < 4; c++) {
        final start = Offset(
          rect.left + rect.width * (0.18 + rnd.nextDouble() * 0.64),
          rect.top + rect.height * (0.12 + rnd.nextDouble() * 0.76),
        );
        final path = Path()..moveTo(start.dx, start.dy);
        var p = start;
        for (var s = 0; s < 3; s++) {
          p += Offset(
            (rnd.nextDouble() - 0.5) * rect.width * 0.34,
            (rnd.nextDouble() - 0.5) * rect.height * 0.34,
          );
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, crack);
      }

      // Warning diamond at the impact point.
      final diamond = max(6.0, shortLen * 0.92);
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(pi / 4);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: diamond, height: diamond),
        Paint()..color = color.withValues(alpha: 0.92),
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: diamond * 0.42, height: diamond * 0.42),
        Paint()..color = const Color(0xFF120A08),
      );
      canvas.restore();
    }
  }

  void _paintOrbs(Canvas canvas, BoardView view) {
    for (var i = 0; i < level.orbs.length; i++) {
      if (sim.collected.contains(i)) continue;
      final orb = level.orbs[i];
      final bob = settings.reduceMotion ? 0.0 : sin(sim.visualTime * 2.1 + i) * view.px(0.03);
      final c = view.toScreen(orb.center) + Offset(0, bob);
      final r = view.px(orb.radius);
      final core = settings.colorblind ? AppColors.cyan : AppColors.gold;

      canvas.drawCircle(
        c,
        r * 2.1,
        Paint()
          ..color = core.withValues(alpha: 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.1),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white, core, core.withValues(alpha: 0.7)],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      canvas.drawCircle(
        c,
        r * 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = core.withValues(alpha: 0.35),
      );
    }
  }

  void _paintGates(Canvas canvas, BoardView view) {
    for (final gate in level.gates) {
      final solid = gate.solidity(sim.time);
      final railRect = view.toScreenRect(gate.rectAt(sim.time));
      final rail = RRect.fromRectAndRadius(
        railRect,
        Radius.circular(railRect.shortestSide * 0.5),
      );

      // The rail is always visible, so the player can read the timing track
      // even when the barrier has powered down.
      canvas.drawRRect(
        rail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = theme.a.withValues(alpha: 0.22 + 0.20 * (1 - solid)),
      );
      final vertical = railRect.height > railRect.width;
      final cap = Paint()..color = theme.a.withValues(alpha: 0.72);
      final dots = Paint()..color = theme.a.withValues(alpha: 0.48);
      if (vertical) {
        canvas.drawCircle(Offset(railRect.center.dx, railRect.top + 3), 2.4, cap);
        canvas.drawCircle(Offset(railRect.center.dx, railRect.bottom - 3), 2.4, cap);
        for (var i = 1; i <= 3; i++) {
          final y = railRect.top + railRect.height * i / 4;
          canvas.drawCircle(Offset(railRect.center.dx, y), 1.5, dots);
        }
      } else {
        canvas.drawCircle(Offset(railRect.left + 3, railRect.center.dy), 2.4, cap);
        canvas.drawCircle(Offset(railRect.right - 3, railRect.center.dy), 2.4, cap);
        for (var i = 1; i <= 3; i++) {
          final x = railRect.left + railRect.width * i / 4;
          canvas.drawCircle(Offset(x, railRect.center.dy), 1.5, dots);
        }
      }

      if (solid <= 0.02) continue;

      // The barrier itself grows out of the rail as solidity rises. This reads
      // as a machine charging rather than a wall snapping on.
      final rect = view.toScreenRect(gate.collisionRectAt(sim.time));
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide * 0.5));
      canvas.drawRRect(
        rr.inflate(view.px(0.06)),
        Paint()
          ..color = AppColors.danger.withValues(alpha: 0.10 + 0.24 * solid)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, view.px(0.12)),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            colors: [
              AppColors.danger.withValues(alpha: 0.35 + 0.60 * solid),
              AppColors.amber.withValues(alpha: 0.30 + 0.60 * solid),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(rect.shortestSide * 0.45)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.25 + 0.35 * solid),
      );
    }
  }

  void _paintExit(Canvas canvas, BoardView view) {
    final c = view.toScreen(level.exit);
    final r = view.px(Simulation.exitRadius);
    final open = sim.allOrbsCollected;
    final pulse = 0.5 + 0.5 * sin(sim.visualTime * 2.4);
    final color = open
        ? (settings.colorblind ? AppColors.blue : AppColors.mint)
        : AppColors.danger;

    canvas.drawCircle(
      c,
      r * (1.5 + pulse * 0.25),
      Paint()
        ..color = color.withValues(alpha: open ? 0.22 : 0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.9),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = color.withValues(alpha: open ? 0.95 : 0.5),
    );
    if (open) {
      // Upward chevrons signal "escape".
      final chevron = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.9);
      for (var k = 0; k < 2; k++) {
        final dy = r * (0.32 - k * 0.22) + (settings.reduceMotion ? 0 : sin(sim.visualTime * 3) * r * 0.04);
        final path = Path()
          ..moveTo(c.dx - r * 0.3, c.dy + dy + r * 0.18)
          ..lineTo(c.dx, c.dy + dy - r * 0.06)
          ..lineTo(c.dx + r * 0.3, c.dy + dy + r * 0.18);
        canvas.drawPath(path, chevron);
      }
    } else {
      // Locked: small crossbar.
      canvas.drawLine(
        c + Offset(-r * 0.28, 0),
        c + Offset(r * 0.28, 0),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.6),
      );
    }
  }

  void _paintTrail(Canvas canvas, BoardView view) {
    if (settings.reduceMotion) return;
    final trail = sim.trail;
    if (trail.length < 2) return;

    // A tapered ribbon reads direction far better than a row of equal dots.
    final speedT = (sim.speed / Simulation.maxSpeed).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < trail.length; i++) {
      final t = i / (trail.length - 1);
      paint
        ..color = theme.a.withValues(alpha: (0.025 + t * 0.17) * (0.45 + speedT * 0.55))
        ..strokeWidth = max(1.0, view.px(0.018 + 0.125 * t));
      canvas.drawLine(
        view.toScreen(trail[i - 1]),
        view.toScreen(trail[i]),
        paint,
      );
    }

    // Speed streaks behind a fast marble, kept subtle so the board stays clear.
    if (speedT > 0.35 && sim.velocity.distance > 0.1) {
      final dir = sim.velocity / sim.velocity.distance;
      final perp = Offset(-dir.dy, dir.dx);
      final ball = view.toScreen(sim.ball);
      final streak = Paint()
        ..color = Colors.white.withValues(alpha: 0.10 + speedT * 0.12)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      for (var k = -1; k <= 1; k++) {
        final offset = perp * (k * view.px(0.085));
        final len = view.px(0.35 + speedT * 0.55);
        canvas.drawLine(
          ball - dir * view.px(0.24) + offset,
          ball - dir * (view.px(0.24) + len) + offset,
          streak,
        );
      }
    }
  }

  void _paintParticles(Canvas canvas, BoardView view) {
    for (final p in particles.items) {
      final c = view.toScreen(p.position);
      final alpha = p.t;
      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..strokeCap = StrokeCap.round;
      if (p.streak) {
        paint
          ..strokeWidth = max(1, view.px(p.size) * 0.8)
          ..style = PaintingStyle.stroke;
        canvas.drawLine(c, c - p.velocity * view.px(0.03), paint);
      } else {
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(c, max(1, view.px(p.size) * alpha), paint);
      }
    }
  }

  void _paintMarble(Canvas canvas, BoardView view) {
    final c = view.toScreen(sim.ball);
    final r = view.px(_marbleWorldRadius);
    final tiltValue = tilt.value;

    // Keep the aura and contact shadow inside the corridor. The marble's body
    // matches its physics radius exactly, but the glow is wider, so without
    // this clip the halo paints over the wall and the ball looks like it is
    // sinking into it. Only walls near the marble are cut out, so this stays
    // cheap even on the largest boards.
    final reach = _marbleWorldRadius * 2.4;
    final ballBox = Rect.fromCircle(center: sim.ball, radius: reach);
    final nearby = <Rect>[];
    for (final box in sim.wallBoxes) {
      if (box.overlaps(ballBox)) nearby.add(view.toScreenRect(box));
    }
    canvas.save();
    if (nearby.isNotEmpty) {
      final clip = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: c, radius: view.px(reach)));
      for (final box in nearby) {
        clip.addRect(box);
      }
      canvas.clipPath(clip, doAntiAlias: true);
    }

    // Contact shadow reacts to tilt.
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(tiltValue.dx * r * 0.7, r * 0.55 + tiltValue.dy * r * 0.4),
        width: r * 1.9,
        height: r * 1.1,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45),
    );

    // Outer aura grows with speed, so the marble reads as energetic without
    // adding contact effects.
    final speedT = (sim.speed / Simulation.maxSpeed).clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      r * (1.55 + speedT * 0.30),
      Paint()
        ..color = theme.a.withValues(alpha: 0.20 + speedT * 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8),
    );
    if (speedT > 0.4) {
      canvas.drawCircle(
        c,
        r * (1.12 + speedT * 0.14),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.08 + speedT * 0.12),
      );
    }

    // Glass body.
    final centerLight = c + Offset(-tiltValue.dx * r * 0.35, -tiltValue.dy * r * 0.35);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (-tiltValue.dx * 0.5).clamp(-0.7, 0.7),
            (-tiltValue.dy * 0.5).clamp(-0.7, 0.7),
          ),
          radius: 0.95,
          colors: [
            Colors.white,
            Color.lerp(Colors.white, theme.a, 0.55)!,
            Color.lerp(theme.a, Colors.black, 0.35)!,
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Visible rolling: two surface flecks orbit the sphere as it rolls.
    _paintRollTexture(canvas, c, r);

    // Refraction crescent.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.78),
      pi * 0.15,
      pi * 0.85,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, r * 0.08)
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.55),
    );

    // Specular highlight.
    canvas.drawOval(
      Rect.fromCenter(
        center: centerLight - Offset(r * 0.18, r * 0.24),
        width: r * 0.62,
        height: r * 0.4,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.10),
    );

    // Rim light.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.7),
    );

    canvas.restore();
  }

  void _paintRollTexture(Canvas canvas, Offset c, double r) {
    final dir = sim.rollDirection;
    final perp = Offset(-dir.dy, dir.dx);
    final phase = sim.rollAngle;

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.94)));
    final fleck = Paint()..color = Colors.white.withValues(alpha: 0.20);
    for (var k = 0; k < 2; k++) {
      final angle = phase + k * pi;
      final offset =
          dir * (sin(angle) * r * 0.52) + perp * (cos(angle) * r * 0.26);
      canvas.drawCircle(c + offset, r * 0.11, fleck);
    }
    canvas.restore();

    // A subtle vein rotates with the surface, not with the camera.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(phase * 0.5);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r * 0.60),
      -0.5,
      1.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, r * 0.05)
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.13),
    );
    canvas.restore();
  }

  void _paintBlackout(Canvas canvas, BoardView view, Size size) {
    final c = view.toScreen(sim.ball);
    final radius = view.px(2.9);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (c.dx / size.width) * 2 - 1,
            (c.dy / size.height) * 2 - 1,
          ),
          radius: (radius / size.shortestSide) * 2,
          colors: [
            Colors.transparent,
            Colors.transparent,
            const Color(0xFF02030A).withValues(alpha: 0.72),
            const Color(0xFF02030A).withValues(alpha: 0.94),
          ],
          stops: const [0.0, 0.42, 0.78, 1.0],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      view.px(0.55),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = theme.a.withValues(alpha: 0.20),
    );
  }

  void _paintVignette(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
          stops: const [0.55, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) => true;
}

/// The "spirit level" bubble used for calibration and the in-game tilt readout.
class SpiritLevelPainter extends CustomPainter {
  SpiritLevelPainter({
    required this.tilt,
    required this.color,
    this.showDeadzone = true,
    this.deadzone = 0.05,
    super.repaint,
  });

  final TiltController tilt;
  final Color color;
  final bool showDeadzone;
  final double deadzone;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.16);

    canvas.drawCircle(center, radius, Paint()..color = Colors.white.withValues(alpha: 0.025));
    canvas.drawCircle(center, radius, ring);
    canvas.drawCircle(center, radius * 0.55, ring);
    canvas.drawLine(
      center - Offset(radius, 0),
      center + Offset(radius, 0),
      Paint()
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.08),
    );
    canvas.drawLine(
      center - Offset(0, radius),
      center + Offset(0, radius),
      Paint()
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.08),
    );

    if (showDeadzone) {
      canvas.drawCircle(
        center,
        radius * deadzone.clamp(0.0, 0.6),
        Paint()..color = color.withValues(alpha: 0.06),
      );
    }

    final v = tilt.value;
    final bubble = center + Offset(v.dx, v.dy) * radius * 0.92;
    canvas.drawCircle(
      bubble,
      radius * 0.17,
      Paint()
        ..color = color.withValues(alpha: 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.12),
    );
    canvas.drawCircle(
      bubble,
      radius * 0.12,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, color],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: bubble, radius: radius * 0.12)),
    );
  }

  @override
  bool shouldRepaint(covariant SpiritLevelPainter oldDelegate) => true;
}
