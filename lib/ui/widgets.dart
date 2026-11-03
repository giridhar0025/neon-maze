import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/theme.dart';

class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.accent = AppColors.cyan,
    this.primary = true,
    this.compact = false,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color accent;
  final bool primary;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final radius = BorderRadius.circular(compact ? 14 : 18);
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: compact ? 15 : 20,
            color: primary ? AppColors.bg : AppColors.ink,
          ),
          SizedBox(width: compact ? 6 : 9),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.body(
              compact ? 12.5 : 16,
              weight: 700,
              color: primary ? AppColors.bg : AppColors.ink,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: primary && enabled
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.30),
                    blurRadius: compact ? 14 : 22,
                    spreadRadius: -4,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: primary
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(accent, Colors.white, 0.18)!, accent],
                    )
                  : null,
              border: Border.all(
                color: primary
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.14),
              ),
              color: primary ? null : Colors.white.withValues(alpha: 0.03),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 22,
                  vertical: compact ? 11 : 16,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.accent,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        color: AppColors.panel.withValues(alpha: 0.72),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          if (accent != null)
            BoxShadow(
              color: accent!.withValues(alpha: 0.10),
              blurRadius: 28,
              spreadRadius: -8,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    this.stars = 0,
    this.size = 18,
    this.gap = 3,
    this.dim = false,
  });

  final int stars;
  final double size;
  final double gap;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(right: i == 2 ? 0 : gap),
            child: Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i < stars
                  ? AppColors.gold
                  : (dim
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.22)),
              shadows: i < stars
                  ? [
                      Shadow(
                        color: AppColors.gold.withValues(alpha: 0.55),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.color = AppColors.cyan,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppText.body(
              11,
              weight: 600,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color = AppColors.inkFaint});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppText.body(10.5, weight: 700, color: color, letterSpacing: 2.0),
    );
  }
}

/// Compact neon-maze brand mark used in navigation chrome.
///
/// The launcher art is drawn in normalised coordinates so the in-app mark
/// reads as the same identity at 32–64 px without shipping a second bitmap.
class NeonLogoMark extends StatelessWidget {
  const NeonLogoMark({super.key, this.size = 38, this.radius = 12});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _NeonMarkPainter(radius: radius)),
    );
  }
}

class _NeonMarkPainter extends CustomPainter {
  _NeonMarkPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.save();
    canvas.clipRRect(rrect);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF122347), Color(0xFF060B18), Color(0xFF0B0718)],
          stops: [0.0, 0.58, 1.0],
        ).createShader(rect),
    );

    // Ambient cyan/violet wash.
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.18),
      size.width * 0.55,
      Paint()
        ..color = AppColors.cyan.withValues(alpha: 0.20)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.22),
    );
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.82),
      size.width * 0.48,
      Paint()
        ..color = AppColors.violet.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.22),
    );

    // The same N mark as the launcher: rounded, axis-aligned maze walls with a
    // stepped diagonal so it reads as a maze, not a plain glyph.
    const left = 0.22;
    const right = 0.78;
    const top = 0.17;
    const bottom = 0.83;
    const steps = 5;
    final stepX = (right - left) / steps;
    final stepY = (bottom - top) / steps;

    final path = Path()
      ..moveTo(size.width * left, size.height * top)
      ..lineTo(size.width * left, size.height * bottom)
      ..moveTo(size.width * right, size.height * top)
      ..lineTo(size.width * right, size.height * bottom);
    for (var k = 0; k < steps; k++) {
      final x0 = left + stepX * k;
      final x1 = left + stepX * (k + 1);
      final y0 = top + stepY * k;
      final y1 = top + stepY * (k + 1);
      path
        ..moveTo(size.width * x0, size.height * y0)
        ..lineTo(size.width * x1, size.height * y0)
        ..lineTo(size.width * x1, size.height * y1);
    }

    final stroke = size.width * 0.085;
    final shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.cyan,
        AppColors.blue,
        AppColors.violet,
        AppColors.magenta,
      ],
      stops: [0.0, 0.35, 0.70, 1.0],
    ).createShader(rect);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 1.9
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = AppColors.cyan.withValues(alpha: 0.34)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 1.1),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );

    // Mint goal node at the foot of the right arm.
    final exit = Offset(size.width * right, size.height * bottom);
    final exitR = size.width * 0.048;
    canvas.drawCircle(
      exit,
      exitR * 1.9,
      Paint()
        ..color = AppColors.mint.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, exitR * 1.6),
    );
    canvas.drawCircle(
      exit,
      exitR,
      Paint()..color = AppColors.mint.withValues(alpha: 0.22),
    );
    canvas.drawCircle(
      exit,
      exitR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012
        ..color = AppColors.mint,
    );
    canvas.drawCircle(exit, exitR * 0.44, Paint()..color = AppColors.mint);

    // Marble.
    final ball = Offset(size.width * 0.65, size.height * 0.30);
    final ballR = size.width * 0.078;
    canvas.drawCircle(
      ball,
      ballR * 1.8,
      Paint()
        ..color = AppColors.cyan.withValues(alpha: 0.38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, ballR * 1.1),
    );
    canvas.drawCircle(
      ball,
      ballR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.0,
          colors: [
            Colors.white,
            Color(0xFFB9FFFA),
            AppColors.cyan,
            Color(0xFF0A1830),
          ],
          stops: [0.0, 0.32, 0.70, 1.0],
        ).createShader(Rect.fromCircle(center: ball, radius: ballR)),
    );
    canvas.drawCircle(
      ball + Offset(-ballR * 0.28, -ballR * 0.34),
      ballR * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );

    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.16),
    );
  }

  @override
  bool shouldRepaint(covariant _NeonMarkPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

/// Decorative glass marble used on the home screen and win sheet.
class GlowMarble extends StatefulWidget {
  const GlowMarble({
    super.key,
    this.size = 118,
    this.accent = AppColors.cyan,
    this.secondary = AppColors.blue,
  });

  final double size;
  final Color accent;
  final Color secondary;

  @override
  State<GlowMarble> createState() => _GlowMarbleState();
}

class _GlowMarbleState extends State<GlowMarble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _MarblePainter(
          t: _controller.value,
          accent: widget.accent,
          secondary: widget.secondary,
        ),
      ),
    );
  }
}

class _MarblePainter extends CustomPainter {
  _MarblePainter({
    required this.t,
    required this.accent,
    required this.secondary,
  });

  final double t;
  final Color accent;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.31;
    final wobble = Offset(cos(t * 2 * pi) * 3, sin(t * 2 * pi) * 3);

    // Orbit ring.
    canvas.drawCircle(
      c,
      r * 1.55,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.10),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * 2 * pi * 0.35);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r * 1.55),
      -0.4,
      1.1,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.75),
    );
    canvas.restore();

    // Aura.
    canvas.drawCircle(
      c + wobble * 0.4,
      r * 1.6,
      Paint()
        ..color = accent.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8),
    );

    // Body.
    canvas.drawCircle(
      c + wobble * 0.5,
      r,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.35 + cos(t * 2 * pi) * 0.12, -0.42),
          radius: 1.0,
          colors: [
            Colors.white,
            Color.lerp(Colors.white, accent, 0.5)!,
            Color.lerp(accent, secondary, 0.65)!,
            const Color(0xFF0A1020),
          ],
          stops: const [0.0, 0.3, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Crescent highlight.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.8),
      pi * 0.2,
      pi * 0.75,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.6),
    );

    // Specular.
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.28, -r * 0.4) + wobble,
        width: r * 0.5,
        height: r * 0.32,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Floor glow.
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(0, r * 1.5),
        width: r * 2.2,
        height: r * 0.3,
      ),
      Paint()
        ..color = accent.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  @override
  bool shouldRepaint(covariant _MarblePainter oldDelegate) =>
      oldDelegate.t != t;
}

/// Soft moving nebula used behind menus.
class NebulaBackground extends StatefulWidget {
  const NebulaBackground({
    super.key,
    this.accent = AppColors.cyan,
    this.secondary = AppColors.magenta,
  });

  final Color accent;
  final Color secondary;

  @override
  State<NebulaBackground> createState() => _NebulaBackgroundState();
}

class _NebulaBackgroundState extends State<NebulaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _NebulaPainter(
            t: _controller.value,
            accent: widget.accent,
            secondary: widget.secondary,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _NebulaPainter extends CustomPainter {
  _NebulaPainter({
    required this.t,
    required this.accent,
    required this.secondary,
  });

  final double t;
  final Color accent;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF080E1D), Color(0xFF04060D), Color(0xFF070612)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    final blobs = [
      (Offset(0.18 + sin(t * 2 * pi) * 0.05, 0.16), accent, 0.62, 0.30),
      (Offset(0.86, 0.30 + cos(t * 2 * pi) * 0.06), secondary, 0.55, 0.24),
      (Offset(0.45 + cos(t * 2 * pi + 1) * 0.06, 0.94), accent, 0.75, 0.16),
    ];
    for (final (pos, color, radius, alpha) in blobs) {
      final center = Offset(pos.dx * size.width, pos.dy * size.height);
      canvas.drawCircle(
        center,
        size.shortestSide * radius,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  color.withValues(alpha: alpha),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ).createShader(
                Rect.fromCircle(
                  center: center,
                  radius: size.shortestSide * radius,
                ),
              ),
      );
    }

    // Faint grid.
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.022)
      ..strokeWidth = 1;
    const step = 44.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter oldDelegate) =>
      oldDelegate.t != t;
}
