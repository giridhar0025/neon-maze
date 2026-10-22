import 'dart:math';

import 'package:flutter/painting.dart';

class Particle {
  Particle({
    required this.position,
    required this.velocity,
    required this.life,
    required this.maxLife,
    required this.size,
    required this.color,
    this.streak = false,
  });

  Offset position;
  Offset velocity;
  double life;
  double maxLife;
  double size;
  Color color;
  bool streak;

  double get t => (life / maxLife).clamp(0.0, 1.0);
}

/// Small world-space particle pool used for wall sparks, orb bursts and wins.
class ParticleField {
  ParticleField({int capacity = 260}) : _capacity = capacity;

  final int _capacity;
  final List<Particle> _items = <Particle>[];
  final Random _rnd = Random(11);

  List<Particle> get items => _items;

  bool get isEmpty => _items.isEmpty;

  void clear() => _items.clear();

  void burst(
    Offset at,
    Color color, {
    int count = 12,
    double speed = 2.2,
    bool streak = false,
    double size = 0.045,
  }) {
    for (var i = 0; i < count; i++) {
      if (_items.length >= _capacity) _items.removeAt(0);
      final angle = _rnd.nextDouble() * pi * 2;
      final power = speed * (0.35 + _rnd.nextDouble() * 0.9);
      final life = 0.35 + _rnd.nextDouble() * 0.5;
      _items.add(Particle(
        position: at,
        velocity: Offset(cos(angle), sin(angle)) * power,
        life: life,
        maxLife: life,
        size: size * (0.6 + _rnd.nextDouble()),
        color: color,
        streak: streak,
      ));
    }
  }

  /// Narrow cone of sparks, used when the marble scrapes a wall.
  void impact(Offset at, Offset normal, Color color, double strength) {
    final count = (4 + strength * 5).clamp(3, 12).toInt();
    for (var i = 0; i < count; i++) {
      if (_items.length >= _capacity) _items.removeAt(0);
      final spread = (_rnd.nextDouble() - 0.5) * 1.6;
      final dir = Offset(
        normal.dx * cos(spread) - normal.dy * sin(spread),
        normal.dx * sin(spread) + normal.dy * cos(spread),
      );
      final life = 0.18 + _rnd.nextDouble() * 0.3;
      _items.add(Particle(
        position: at,
        velocity: dir * (1.2 + _rnd.nextDouble() * strength * 1.4),
        life: life,
        maxLife: life,
        size: 0.03 + _rnd.nextDouble() * 0.03,
        color: color,
        streak: true,
      ));
    }
  }

  void update(double dt) {
    for (var i = _items.length - 1; i >= 0; i--) {
      final p = _items[i];
      p.life -= dt;
      if (p.life <= 0) {
        _items.removeAt(i);
        continue;
      }
      p.position += p.velocity * dt;
      p.velocity *= exp(-2.4 * dt);
    }
  }
}
