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
      canvas.drawCircle(
        c,
        r * 1.55,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.55),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: const [Color(0xFF000000), Color(0xFF05060C)],
            stops: const [0.6, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = themeA.withValues(alpha: 0.30),
      );
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.72),
        -pi * 0.15,
        pi * 0.9,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = AppColors.danger.withValues(alpha: 0.22),
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
    final boxes = level.maze.wallBoxes(t);
    final accent = theme.a;

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, view.px(0.12));
    final sheen = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = view.px(0.075)
      ..color = accent.withValues(alpha: 0.34)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, view.px(0.11));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = accent.withValues(alpha: 0.88);

    const inset = 0.02;
    for (final box in boxes) {
      final rect = view.toScreenRect(box.deflate(0));
      final radius = Radius.circular(max(2, view.px(t * 0.45)));
      final rr = RRect.fromRectAndRadius(rect, radius);
      final inner = RRect.fromRectAndRadius(
        rect.deflate(view.px(inset)).deflate(0),
        radius,
      );

      canvas.drawRRect(
        rr.shift(Offset(0, view.px(0.05))),
        shadow,
      );
      canvas.drawRRect(
        inner,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(rect.left, rect.top),
            Offset(rect.left, rect.bottom),
            [Color.lerp(const Color(0xFF33477D), accent, 0.10)!, const Color(0xFF0A0F1E)],
          ),
      );
      if (rect.width > rect.height) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              inner.left + 1,
              inner.top + 1,
              inner.width - 2,
              max(1, inner.height * 0.26),
            ),
            Radius.circular(max(1, view.px(t * 0.3))),
          ),
          sheen,
        );
      }
      canvas.drawRRect(inner, glow);
      canvas.drawRRect(inner, edge);
    }
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

    // Parallax keeps the board feeling physical without moving the physics.
    final parallax = settings.reduceMotion
        ? Offset.zero
        : Offset(-tilt.value.dx, -tilt.value.dy) * 7.0;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF04060D),
    );

    canvas.save();
    canvas.translate(parallax.dx, parallax.dy);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    _paintPortals(canvas, view);
    _paintOrbs(canvas, view);
    _paintGates(canvas, view);
    _paintExit(canvas, view);
    _paintTrail(canvas, view);
    _paintParticles(canvas, view);
    if (!sim.fell) _paintMarble(canvas, view);
    if (level.spec.blackout) _paintBlackout(canvas, view, size);
    _paintVignette(canvas, size);
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
      final active = gate.isActive(sim.visualTime);
      final rect = view.toScreenRect(gate.rectAt(sim.visualTime));
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide * 0.5));

      if (!active) {
        // Powered-down state: a ghost rail with end caps and a dotted core.
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = theme.a.withValues(alpha: 0.40),
        );
        final vertical = rect.height > rect.width;
        final cap = Paint()..color = theme.a.withValues(alpha: 0.75);
        final dots = Paint()..color = theme.a.withValues(alpha: 0.55);
        if (vertical) {
          canvas.drawCircle(Offset(rect.center.dx, rect.top + 3), 2.6, cap);
          canvas.drawCircle(Offset(rect.center.dx, rect.bottom - 3), 2.6, cap);
          for (var i = 1; i <= 3; i++) {
            final y = rect.top + rect.height * i / 4;
            canvas.drawCircle(Offset(rect.center.dx, y), 1.6, dots);
          }
        } else {
          canvas.drawCircle(Offset(rect.left + 3, rect.center.dy), 2.6, cap);
          canvas.drawCircle(Offset(rect.right - 3, rect.center.dy), 2.6, cap);
          for (var i = 1; i <= 3; i++) {
            final x = rect.left + rect.width * i / 4;
            canvas.drawCircle(Offset(x, rect.center.dy), 1.6, dots);
          }
        }
        continue;
      }

      canvas.drawRRect(
        rr,
        Paint()
          ..color = AppColors.danger.withValues(alpha: 0.38)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, view.px(0.10)),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            colors: [
              AppColors.danger.withValues(alpha: 0.95),
              AppColors.amber.withValues(alpha: 0.9),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(rect.shortestSide * 0.45)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.5),
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
    for (var i = 0; i < trail.length; i++) {
      final t = i / trail.length;
      final p = view.toScreen(trail[i]);
      final r = view.px(_marbleWorldRadius) * (0.25 + t * 0.7);
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = theme.a.withValues(alpha: 0.05 + t * 0.12)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
      );
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

    // Outer aura.
    canvas.drawCircle(
      c,
      r * 1.55,
      Paint()
        ..color = theme.a.withValues(alpha: 0.24)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8),
    );

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
