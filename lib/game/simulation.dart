import 'dart:math';

import 'package:flutter/painting.dart';

import 'levels.dart';

enum SimEventType { wallHit, orb, fall, win, portal, bumper }

class SimEvent {
  const SimEvent(this.type, this.position, [this.strength = 0]);

  final SimEventType type;
  final Offset position;
  final double strength;
}

/// Deterministic marble physics on a 1-unit-per-cell board.
///
/// The simulation is intentionally engine-free: a circle against a small set of
/// axis-aligned boxes, resolved with sub-stepping. That keeps behaviour stable
/// at 120 Hz, testable without a device, and free of a physics dependency.
class Simulation {
  Simulation(this.level, {this.ballRadius = 0.19})
      : wallBoxes = level.maze.wallBoxes(wallThickness) {
    reset();
  }

  static const double wallThickness = 0.14;
  static const double gravity = 11.0;
  static const double maxSpeed = 6.4;
  static const double exitRadius = 0.30;
  static const double portalRadius = 0.26;

  final LevelRuntime level;
  final double ballRadius;
  final List<Rect> wallBoxes;

  Offset ball = Offset.zero;
  Offset velocity = Offset.zero;

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
  double _wallCooldown = 0;
  Offset _lastTilt = Offset.zero;

  int get remainingOrbs => level.orbs.length - collected.length;

  bool get allOrbsCollected => remainingOrbs <= 0;

  double get speed => velocity.distance;

  bool get isResting => speed < 0.07;

  Offset get tilt => _lastTilt;

  List<SimEvent> drainEvents() {
    final copy = List<SimEvent>.of(events);
    events.clear();
    return copy;
  }

  void reset() {
    ball = level.start;
    velocity = Offset.zero;
    time = 0;
    portalCooldown = 0;
    invulnerable = 0.35;
    fell = false;
    won = false;
    collected.clear();
    events.clear();
    trail
      ..clear()
      ..add(ball);
    _trailClock = 0;
    _wallCooldown = 0;
    _lastTilt = Offset.zero;
  }

  void step(double dt, Offset tiltInput) {
    if (fell || won) return;
    dt = dt.clamp(0.0, 1.0 / 30.0);
    time += dt;
    portalCooldown = max(0, portalCooldown - dt);
    invulnerable = max(0, invulnerable - dt);
    _wallCooldown = max(0, _wallCooldown - dt);

    final tilt = Offset(
      tiltInput.dx.clamp(-1.0, 1.0),
      tiltInput.dy.clamp(-1.0, 1.0),
    );
    _lastTilt = tilt;

    final inIce = _insideAny(level.ice);
    final inTar = _insideAny(level.tar);

    // Acceleration from board tilt, then speed-dependent drag.
    velocity += tilt * gravity * dt;
    final drag = inIce
        ? 0.20
        : inTar
            ? 2.6
            : 0.75;
    final rolling = inIce ? 0.02 : 0.16;
    final damping = exp(-(drag + speed * rolling) * dt);
    velocity *= damping;

    if (inTar) velocity *= 0.985;
    final sp = speed;
    if (sp > maxSpeed) {
      velocity = velocity * (maxSpeed / sp);
    }
    if (sp < 0.012 && tilt.distance < 0.02) {
      velocity = Offset.zero;
    }

    // Sub-step to keep collision resolution stable at any frame rate.
    const stepSize = 1 / 180;
    final steps = (dt / stepSize).ceil().clamp(1, 10);
    final h = dt / steps;
    for (var s = 0; s < steps; s++) {
      _integrate(h);
      _resolveWalls();
      _resolveGates(h);
      if (fell || won) break;
    }

    _resolveBumpers();
    _resolveSpecials();
    _updateTrail(dt);
  }

  void _integrate(double h) {
    ball += velocity * h;
  }

  void _resolveWalls() {
    for (var pass = 0; pass < 2; pass++) {
      for (final rect in wallBoxes) {
        _resolveBox(rect, restitution: 0.46, friction: 0.72);
      }
    }
  }

  void _resolveGates(double h) {
    for (final gate in level.gates) {
      if (!gate.isActive(time)) continue;
      final rect = gate.rectAt(time);
      _resolveBox(rect, restitution: 0.42, friction: 0.85);
      if (!rect.inflate(ballRadius).contains(ball)) continue;
      // Moving gates carry the marble a little.
      final c0 = gate.rectAt(time - h).center;
      final c1 = gate.rectAt(time).center;
      final gateVelocity = (c1 - c0) / max(h, 1e-4);
      velocity += gateVelocity * 0.22;
    }
  }

  void _resolveBox(
    Rect rect, {
    required double restitution,
    required double friction,
  }) {
    final cx = ball.dx.clamp(rect.left, rect.right);
    final cy = ball.dy.clamp(rect.top, rect.bottom);
    var delta = ball - Offset(cx, cy);
    var dist = delta.distance;

    if (dist >= ballRadius) return;

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

    ball += normal * penetration;

    final vn = velocity.dx * normal.dx + velocity.dy * normal.dy;
    if (vn < 0) {
      final impact = -vn;
      velocity -= normal * (vn * (1 + restitution));
      // Tangential friction keeps corner grazing from feeling sticky.
      final tangent = Offset(-normal.dy, normal.dx);
      final vt = velocity.dx * tangent.dx + velocity.dy * tangent.dy;
      velocity -= tangent * (vt * (1 - friction));

      if (impact > 0.55 && _wallCooldown == 0) {
        _wallCooldown = 0.08;
        events.add(SimEvent(SimEventType.wallHit, ball, impact));
      }
    }
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
        velocity -= n * (vn * 2.25);
      }
      if (velocity.distance < 2.0) velocity += n * 1.6;
      events.add(SimEvent(SimEventType.bumper, ball, velocity.distance));
    }
  }

  void _resolveSpecials() {
    // Holes.
    for (final h in level.holes) {
      if ((ball - h.center).distance < h.radius * 0.72) {
        fell = true;
        events.add(SimEvent(SimEventType.fall, ball, 1));
        return;
      }
    }

    // Orbs.
    for (var i = 0; i < level.orbs.length; i++) {
      if (collected.contains(i)) continue;
      final orb = level.orbs[i];
      if ((ball - orb.center).distance < orb.radius + ballRadius * 0.55) {
        collected.add(i);
        events.add(SimEvent(SimEventType.orb, orb.center, 1));
      }
    }

    // Portals.
    if (portalCooldown == 0) {
      for (final pair in level.portals) {
        if ((ball - pair.a).distance < portalRadius) {
          _teleport(pair.b, SimEventType.portal);
          events.add(SimEvent(SimEventType.portal, pair.a, 1));
          return;
        }
        if ((ball - pair.b).distance < portalRadius) {
          _teleport(pair.a, SimEventType.portal);
          events.add(SimEvent(SimEventType.portal, pair.b, 1));
          return;
        }
      }
    }

    // Exit: locked until every orb is collected.
    if (allOrbsCollected && (ball - level.exit).distance < exitRadius) {
      won = true;
      events.add(SimEvent(SimEventType.win, level.exit, 1));
    }
  }

  void _teleport(Offset target, SimEventType type) {
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
