import 'dart:math';

import 'package:flutter/painting.dart';

import 'levels.dart';

enum SimEventType { orb, fall, win, portal, bumper, breakWall }

class SimEvent {
  const SimEvent(this.type, this.position, [this.strength = 0]);

  final SimEventType type;
  final Offset position;
  final double strength;
}

/// Deterministic marble physics on a 1-unit-per-cell board.
///
/// The marble is a rigid circle rolling on a tilted plane:
///  * gravity comes from the board tilt,
///  * rolling resistance and quadratic drag slow it down,
///  * walls apply a normal impulse plus tangential friction **only on a real
///    impact**, so grazing a wall does not glue the marble to it,
///  * integration runs at a fixed 240 Hz so the feel is identical on 60, 90 and
///    120 Hz displays,
///  * `rollAngle`/`rollDirection` describe the visible rolling of the marble.
class Simulation {
  Simulation(this.level, {this.ballRadius = 0.19})
      : wallBoxes = level.maze
            .wallBoxes(wallThickness)
            .where((box) => !level.isBreakableBox(box))
            .toList() {
    reset();
  }

  static const double wallThickness = kWallThickness;

  /// Free-flow tuning: gravity does most of the work, the marble keeps
  /// momentum, and the speed cap only stops it from running away.
  static const double gravity = 14.0;
  static const double maxSpeed = 7.2;
  static const double fixedStep = 1 / 240;
  static const double exitRadius = 0.30;
  static const double portalRadius = 0.26;

  final LevelRuntime level;
  final double ballRadius;
  final List<Rect> wallBoxes;

  Offset ball = Offset.zero;
  Offset velocity = Offset.zero;

  /// Distance rolled, in radians, wrapped to 2π. Render-only.
  double rollAngle = 0;
  Offset rollDirection = const Offset(0, 1);

  double time = 0;
  double visualTime = 0;
  double portalCooldown = 0;
  double invulnerable = 0;
  bool fell = false;
  bool won = false;

  final Set<int> collected = <int>{};
  final List<SimEvent> events = <SimEvent>[];
  final List<Offset> trail = <Offset>[];
  double _trailClock = 0;
  double _bumperCooldown = 0;
  double _accumulator = 0;
  Offset _lastTilt = Offset.zero;

  int get remainingOrbs => level.orbs.length - collected.length;

  bool get allOrbsCollected => remainingOrbs <= 0;

  double get speed => velocity.distance;

  bool get isResting => speed < 0.07;

  bool get isRolling => speed > 0.05;

  Offset get tilt => _lastTilt;

  List<SimEvent> drainEvents() {
    final copy = List<SimEvent>.of(events);
    events.clear();
    return copy;
  }

  void reset() {
    ball = level.start;
    velocity = Offset.zero;
    rollAngle = 0;
    rollDirection = const Offset(0, 1);
    time = 0;
    portalCooldown = 0;
    invulnerable = 0.35;
    fell = false;
    won = false;
    collected.clear();
    events.clear();
    for (final wall in level.breakables) {
      wall.broken = false;
    }
    trail
      ..clear()
      ..add(ball);
    _trailClock = 0;
    _bumperCooldown = 0;
    _accumulator = 0;
    _lastTilt = Offset.zero;
  }

  /// Consumes a frame delta. Physics always advances in fixed steps, so a
  /// dropped frame cannot change the trajectory or let the marble tunnel.
  void step(double dt, Offset tiltInput) {
    if (fell || won) return;
    dt = dt.clamp(0.0, 1.0 / 30.0);

    final tilt = Offset(
      tiltInput.dx.clamp(-1.0, 1.0),
      tiltInput.dy.clamp(-1.0, 1.0),
    );
    _lastTilt = tilt;

    _accumulator += dt;
    var steps = 0;
    while (_accumulator >= fixedStep && steps < 30) {
      _stepFixed(fixedStep, tilt);
      _accumulator -= fixedStep;
      steps++;
      if (fell || won) {
        _accumulator = 0;
        break;
      }
    }
    // A long stall (app resume, debugger) should not fast-forward the run.
    if (steps == 30) _accumulator = 0;

    _updateTrail(dt);
  }

  void _stepFixed(double h, Offset tilt) {
    time += h;
    portalCooldown = max(0, portalCooldown - h);
    invulnerable = max(0, invulnerable - h);
    _bumperCooldown = max(0, _bumperCooldown - h);

    final inIce = _insideAny(level.ice);
    final inTar = _insideAny(level.tar);

    // Gravity component along the tilted board.
    velocity += tilt * gravity * h;
    _applyFields(h);

    // Low rolling resistance so the marble flows with gravity. The quadratic
    // term only catches very high speeds.
    final drag = inTar ? 3.2 : (inIce ? 0.04 : 0.14);
    final quadratic = inTar ? 0.45 : (inIce ? 0.008 : 0.018);
    velocity *= exp(-(drag + speed * quadratic) * h);
    if (inTar) velocity *= exp(-0.5 * h);

    final sp = speed;
    if (sp > maxSpeed) velocity = velocity * (maxSpeed / sp);
    if (sp < 0.006 && tilt.distance < 0.01) velocity = Offset.zero;

    _integrate(h);
    _resolveWalls();
    _resolveGates(h);
    _resolveSliders(h);
    _resolveFlowPanels();
    _resolveBreakables();
    _resolveBumpers();
    _resolveSpecials();

    // Surface roll: a point on the marble travels `distance / radius` radians.
    final travel = velocity * h;
    final distance = travel.distance;
    if (distance > 1e-7 && !fell) {
      rollDirection = travel / distance;
      rollAngle = (rollAngle + distance / ballRadius) % (2 * pi);
    }
  }

  void _integrate(double h) {
    ball += velocity * h;
  }

  void _applyFields(double h) {
    for (final conveyor in level.conveyors) {
      if (conveyor.rect.contains(ball)) {
        velocity += conveyor.direction * (conveyor.strength * h);
      }
    }
    for (final magnet in level.magnets) {
      final delta = magnet.center - ball;
      final distance = delta.distance;
      if (distance >= magnet.radius || distance < 1e-4) continue;
      final falloff = 1 - distance / magnet.radius;
      final sign = magnet.attract ? 1.0 : -1.0;
      velocity += (delta / distance) * (magnet.strength * falloff * falloff * sign * h);
    }
    // Holes pull before they kill, so the failure reads as a smooth slide into
    // the drop instead of an instant teleport.
    for (final hole in level.holes) {
      final delta = hole.center - ball;
      final distance = delta.distance;
      final influence = hole.radius * 1.75;
      if (distance >= influence || distance < 1e-4) continue;
      final falloff = 1 - distance / influence;
      velocity += (delta / distance) * (5.5 * falloff * falloff * h);
    }
  }

  void _resolveWalls() {
    // Two passes settle corner contacts (two walls meeting at a corner).
    for (var pass = 0; pass < 2; pass++) {
      for (final rect in wallBoxes) {
        _resolveBox(rect, restitution: 0.50, tangentialLoss: 0.015);
      }
    }
  }

  void _resolveGates(double h) {
    for (final gate in level.gates) {
      final solid = gate.solidity(time);
      if (solid <= 0.02) continue;
      final rect = gate.collisionRectAt(time);
      _resolveBox(rect, restitution: 0.45, tangentialLoss: 0.03);
      if (!rect.inflate(ballRadius).contains(ball)) continue;
      // A moving gate carries the marble a little.
      final c0 = gate.collisionRectAt(time - h).center;
      final c1 = gate.collisionRectAt(time).center;
      final gateVelocity = (c1 - c0) / max(h, 1e-4);
      velocity += gateVelocity * 0.18;
    }
  }

  /// Short sliding walls with a moving gap. They are always solid, and the
  /// moving surface gives the marble a small carry when it is touched.
  void _resolveSliders(double h) {
    for (final slider in level.sliders) {
      final rect = slider.rectAt(time);
      _resolveBox(rect, restitution: 0.38, tangentialLoss: 0.02);
      if (!rect.inflate(ballRadius).contains(ball)) continue;
      final c0 = slider.rectAt(time - h).center;
      final c1 = slider.rectAt(time).center;
      final slideVelocity = (c1 - c0) / max(h, 1e-4);
      velocity += slideVelocity * 0.22;
    }
  }

  /// One-way membranes are only solid while the marble is not travelling with
  /// the arrows. That keeps the intended route open and blocks the reverse.
  void _resolveFlowPanels() {
    for (final panel in level.flowPanels) {
      final along = velocity.dx * panel.direction.dx +
          velocity.dy * panel.direction.dy;
      final near = (ball - panel.rect.center).distance;
      if (along > 0.0) {
        // A small forward assist makes a correctly entered flow feel like a
        // current instead of a patch of floor.
        if (near < 0.55) velocity += panel.direction * (1.1 * Simulation.fixedStep);
        continue;
      }
      // Approaching against the arrows: nudge with the current first, then
      // resolve the membrane, so the stop is less abrupt.
      if (near < 0.5) velocity += panel.direction * (1.8 * Simulation.fixedStep);
      _resolveBox(panel.rect, restitution: 0.42, tangentialLoss: 0.02);
    }
  }

  /// Breakable sections crack open when hit hard. The pre-impact velocity is
  /// restored so a smash reads as punching through, not bouncing off.
  void _resolveBreakables() {
    for (final wall in level.breakables) {
      if (wall.broken) continue;
      final incoming = velocity;
      final impact = _resolveBox(
        wall.rect,
        restitution: 0.30,
        tangentialLoss: 0.01,
      );
      if (impact < 2.0) continue;
      wall.broken = true;
      velocity = incoming * 0.78;
      events.add(SimEvent(SimEventType.breakWall, wall.rect.center, impact));
    }
  }

  double _resolveBox(
    Rect rect, {
    required double restitution,
    required double tangentialLoss,
  }) {
    final cx = ball.dx.clamp(rect.left, rect.right);
    final cy = ball.dy.clamp(rect.top, rect.bottom);
    final delta = ball - Offset(cx, cy);
    final dist = delta.distance;

    if (dist >= ballRadius) return 0;

    Offset normal;
    double penetration;
    if (dist < 1e-5) {
      // Center is inside the box: escape through the nearest face.
      final left = ball.dx - rect.left;
      final right = rect.right - ball.dx;
      final top = ball.dy - rect.top;
      final bottom = rect.bottom - ball.dy;
      final m = min(min(left, right), min(top, bottom));
      if (m == left) {
        normal = const Offset(-1, 0);
        penetration = left + ballRadius;
      } else if (m == right) {
        normal = const Offset(1, 0);
        penetration = right + ballRadius;
      } else if (m == top) {
        normal = const Offset(0, -1);
        penetration = top + ballRadius;
      } else {
        normal = const Offset(0, 1);
        penetration = bottom + ballRadius;
      }
    } else {
      normal = delta / dist;
      penetration = ballRadius - dist;
    }

    // Positional correction with a tiny slop avoids contact jitter.
    ball += normal * (penetration + 0.0002);

    final vn = velocity.dx * normal.dx + velocity.dy * normal.dy;
    if (vn >= 0) return 0;

    final impact = -vn;
    // Low-speed contacts settle instead of micro-bouncing forever.
    final effectiveRestitution = impact > 0.35 ? restitution : 0.0;
    velocity -= normal * (vn * (1 + effectiveRestitution));

    // Friction only on a real impact. Applying it every fixed step while the
    // marble rests against a wall is what makes wall-slides feel sticky.
    if (impact > 0.08) {
      final tangent = Offset(-normal.dy, normal.dx);
      final vt = velocity.dx * tangent.dx + velocity.dy * tangent.dy;
      velocity -= tangent * (vt * tangentialLoss);
    }

    // Wall contacts are intentionally silent: the bounce stays, but no sparks,
    // haptics or SFX fire when the marble merely touches or grazes a wall.
    return impact;
  }

  void _resolveBumpers() {
    for (final b in level.bumpers) {
      final d = ball - b.center;
      final dist = d.distance;
      final minDist = b.radius + ballRadius;
      if (dist >= minDist) continue;

      final n = dist < 1e-5 ? const Offset(1, 0) : d / dist;
      ball = b.center + n * minDist;
      final vn = velocity.dx * n.dx + velocity.dy * n.dy;
      if (vn < 0) {
        velocity -= n * (vn * 1.7);
      }
      // Keep bumpers lively without launching the marble across the board.
      final sp = speed;
      if (sp < 1.25) velocity += n * (1.25 - sp);
      if (speed > maxSpeed) velocity = velocity * (maxSpeed / speed);

      if (_bumperCooldown == 0) {
        _bumperCooldown = 0.12;
        events.add(SimEvent(SimEventType.bumper, ball, speed));
      }
    }
  }

  void _resolveSpecials() {
    for (final h in level.holes) {
      if ((ball - h.center).distance < h.radius * 0.82) {
        fell = true;
        events.add(SimEvent(SimEventType.fall, ball, 1));
        return;
      }
    }

    for (var i = 0; i < level.orbs.length; i++) {
      if (collected.contains(i)) continue;
      final orb = level.orbs[i];
      if ((ball - orb.center).distance < orb.radius + ballRadius * 0.55) {
        collected.add(i);
        events.add(SimEvent(SimEventType.orb, orb.center, 1));
      }
    }

    if (portalCooldown == 0) {
      for (final pair in level.portals) {
        if ((ball - pair.a).distance < portalRadius) {
          _teleport(pair.b);
          events.add(SimEvent(SimEventType.portal, pair.a, 1));
          return;
        }
        if ((ball - pair.b).distance < portalRadius) {
          _teleport(pair.a);
          events.add(SimEvent(SimEventType.portal, pair.b, 1));
          return;
        }
      }
    }

    if (allOrbsCollected && (ball - level.exit).distance < exitRadius) {
      won = true;
      events.add(SimEvent(SimEventType.win, level.exit, 1));
    }
  }

  void _teleport(Offset target) {
    final direction = velocity.distance < 0.2
        ? const Offset(0, -1)
        : velocity / velocity.distance;
    ball = target + direction * 0.16;
    velocity *= 0.82;
    portalCooldown = 0.75;
    invulnerable = 0.2;
  }

  bool _insideAny(List<Zone> zones) {
    for (final z in zones) {
      if (z.rect.contains(ball)) return true;
    }
    return false;
  }

  void _updateTrail(double dt) {
    _trailClock += dt;
    if (_trailClock < 0.018) return;
    _trailClock = 0;
    if (speed < 0.15) return;
    trail.add(ball);
    if (trail.length > 34) trail.removeAt(0);
  }

  int score(int timeMs, double multiplier) {
    final base = 600 + level.spec.cols * level.spec.rows * 8;
    final speedBonus = max(0, level.spec.parMs - timeMs) ~/ 25;
    final orbBonus = level.orbs.length * 40;
    return ((base + speedBonus + orbBonus) * multiplier).round();
  }
}
