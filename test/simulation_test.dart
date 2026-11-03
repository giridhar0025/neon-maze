import 'package:flutter_test/flutter_test.dart';
import 'package:neon_maze/game/levels.dart';
import 'package:neon_maze/game/maze.dart';
import 'package:neon_maze/game/powerups.dart';
import 'package:neon_maze/game/simulation.dart' as game;

void main() {
  test('tilt accelerates the marble in the tilt direction', () {
    final level = LevelRuntime.build(LevelCatalog.byId(0));
    final sim = game.Simulation(level);
    sim.ball = level.start;
    sim.velocity = Offset.zero;

    // Short burst: enough to accelerate, short enough not to reach the wall.
    for (var i = 0; i < 6; i++) {
      sim.step(1 / 60, const Offset(1, 0));
    }
    expect(sim.velocity.dx, greaterThan(0.2));
    expect(sim.ball.dx, greaterThan(level.start.dx));
  });

  test('the marble never tunnels through the outer wall', () {
    final level = LevelRuntime.build(LevelCatalog.byId(0));
    final sim = game.Simulation(level);
    sim.ball = level.start;
    sim.velocity = const Offset(-9, 0);

    for (var i = 0; i < 30; i++) {
      sim.step(1 / 60, const Offset(-1, 0));
      expect(sim.ball.dx, greaterThanOrEqualTo(sim.ballRadius - 0.02));
      expect(sim.ball.dy, greaterThanOrEqualTo(sim.ballRadius - 0.02));
      expect(
        sim.ball.dx,
        lessThanOrEqualTo(level.maze.cols - sim.ballRadius + 0.02),
      );
      expect(
        sim.ball.dy,
        lessThanOrEqualTo(level.maze.rows - sim.ballRadius + 0.02),
      );
    }
  });

  test('orbs are collected and the exit stays locked until all are taken', () {
    final spec = LevelCatalog.chapter(1).first;
    final level = LevelRuntime.build(spec);
    expect(level.orbs.length, greaterThanOrEqualTo(2));

    final sim = game.Simulation(level);
    sim.ball = level.orbs.first.center;
    sim.step(1 / 60, Offset.zero);
    expect(sim.collected, contains(0));

    sim.ball = level.exit;
    sim.step(1 / 60, Offset.zero);
    expect(
      sim.won,
      isFalse,
      reason: 'exit must stay locked with orbs remaining',
    );

    for (var i = 0; i < level.orbs.length; i++) {
      sim.collected.add(i);
    }
    sim.ball = level.exit;
    sim.step(1 / 60, Offset.zero);
    expect(sim.won, isTrue);
    expect(
      sim.drainEvents().any((e) => e.type == game.SimEventType.win),
      isTrue,
    );
  });

  test('crossing a hole ends the run and emits a fall event', () {
    final level = LevelRuntime.build(LevelCatalog.byId(3));
    expect(level.holes, isNotEmpty);
    final sim = game.Simulation(level);
    sim.ball = level.holes.first.center;
    sim.step(1 / 60, Offset.zero);
    expect(sim.fell, isTrue);
    expect(
      sim.drainEvents().any((e) => e.type == game.SimEventType.fall),
      isTrue,
    );
  });

  test('pulse gates alternate between solid and passable', () {
    const gate = Gate(
      base: Offset(2, 2),
      spansVertically: true,
      amplitude: 0.1,
      speed: 2.0,
      phase: 0,
    );
    final states = [for (var i = 0; i < 160; i++) gate.isActive(i / 40)];
    expect(states.where((active) => active).length, greaterThan(20));
    expect(states.where((active) => !active).length, greaterThan(20));
  });

  test('tuned sliders, belts and magnets stay physically passable', () {
    final level = LevelRuntime.build(LevelCatalog.byId(799));
    final sim = game.Simulation(level);

    for (final slider in level.sliders) {
      // At an extreme the bar leaves a clear gap on one side of the corridor.
      final gap =
          0.5 -
          game.Simulation.wallThickness / 2 +
          slider.amplitude -
          slider.halfLong;
      expect(
        gap,
        greaterThan(2 * sim.ballRadius),
        reason: 'slider gap is narrower than the marble',
      );
    }

    for (final belt in level.conveyors) {
      // A full tilt must always be able to beat a belt and a magnet.
      expect(belt.strength, lessThan(game.Simulation.gravity));
    }
    for (final magnet in level.magnets) {
      expect(magnet.strength, lessThan(game.Simulation.gravity));
    }
  });

  test('fixed timestep is independent of frame rate', () {
    final level = LevelRuntime.build(LevelCatalog.byId(12));
    final sixty = game.Simulation(level);
    final twoForty = game.Simulation(level);

    sixty.step(1 / 60, const Offset(0.6, 0.25));
    for (var i = 0; i < 4; i++) {
      twoForty.step(1 / 240, const Offset(0.6, 0.25));
    }

    expect(sixty.ball.dx, closeTo(twoForty.ball.dx, 1e-9));
    expect(sixty.ball.dy, closeTo(twoForty.ball.dy, 1e-9));
    expect(sixty.velocity.dx, closeTo(twoForty.velocity.dx, 1e-9));
    expect(sixty.velocity.dy, closeTo(twoForty.velocity.dy, 1e-9));
  });

  test('rolling angle advances in the direction of travel', () {
    final level = LevelRuntime.build(LevelCatalog.byId(0));
    final sim = game.Simulation(level);
    sim.ball = level.start;
    sim.velocity = Offset.zero;

    for (var i = 0; i < 6; i++) {
      sim.step(1 / 60, const Offset(1, 0));
    }

    expect(sim.rollAngle, greaterThan(0.02));
    expect(sim.rollDirection.dx, greaterThan(0.8));
    expect(sim.rollDirection.distance, closeTo(1.0, 1e-6));
  });

  test('grazing a wall keeps most of the tangential speed', () {
    // Top-left start, top wall is always solid. Find a level whose start opens
    // east so the marble can slide along that wall.
    final level = LevelCatalog.all
        .map(LevelRuntime.build)
        .firstWhere((runtime) => !runtime.maze.hasWall(0, 0, Dir.east));

    final sim = game.Simulation(level);
    sim.ball = level.start;
    sim.velocity = const Offset(3, 0);

    for (var i = 0; i < 18; i++) {
      // Press into the top wall while moving along it.
      sim.step(1 / 60, const Offset(0, -1));
    }

    expect(
      sim.speed,
      greaterThan(1.8),
      reason: 'wall sliding should not scrub off most of the speed',
    );
  });

  test('the marble settles when the board is level and still', () {
    final level = LevelCatalog.all
        .map(LevelRuntime.build)
        .firstWhere(
          (runtime) => runtime.holes.every(
            (hole) => (hole.center - runtime.start).distance > 2.5,
          ),
        );
    final sim = game.Simulation(level);
    sim.ball = level.start;
    sim.velocity = const Offset(0.35, 0);

    for (var i = 0; i < 600; i++) {
      sim.step(1 / 60, Offset.zero);
    }

    expect(sim.speed, lessThan(0.15));
  });

  test('speed never exceeds the cap', () {
    final level = LevelRuntime.build(LevelCatalog.byId(20));
    final sim = game.Simulation(level);
    sim.ball = level.start;

    for (var i = 0; i < 240; i++) {
      sim.step(1 / 60, const Offset(1, 0.4));
      expect(sim.speed, lessThanOrEqualTo(game.Simulation.maxSpeed + 1e-6));
      if (sim.fell || sim.won) {
        sim.reset();
      }
    }
  });

  test('reset restores start, orbs and flags', () {
    final level = LevelRuntime.build(LevelCatalog.chapter(1).first);
    final sim = game.Simulation(level);
    sim.collected.add(0);
    sim.fell = true;
    sim.reset();

    expect(sim.fell, isFalse);
    expect(sim.won, isFalse);
    expect(sim.collected, isEmpty);
    expect(sim.ball, level.start);
    expect(sim.velocity, Offset.zero);
    expect(sim.time, 0);
  });

  test('score rewards faster runs and higher multipliers', () {
    final level = LevelRuntime.build(LevelCatalog.byId(20));
    final sim = game.Simulation(level);
    final fast = sim.score(10_000, 1.0);
    final slow = sim.score(40_000, 1.0);
    final hard = sim.score(10_000, 1.35);
    expect(fast, greaterThan(slow));
    expect(hard, greaterThan(fast));
  });

  test('power-up pickups fill the belt and can be activated', () {
    final level = LevelCatalog.all
        .map(LevelRuntime.build)
        .firstWhere((runtime) => runtime.powerUps.isNotEmpty);
    final sim = game.Simulation(level);
    final pickup = level.powerUps.first;

    sim.ball = pickup.center;
    sim.velocity = Offset.zero;
    sim.step(1 / 60, Offset.zero);

    expect(sim.belt.length, 1);
    expect(sim.belt.first, pickup.type);
    expect(sim.collectedPowerUps, contains(0));
    expect(
      sim.drainEvents().any((e) => e.type == game.SimEventType.powerUp),
      isTrue,
    );

    final activated = sim.activatePowerUp(0);
    expect(activated, pickup.type);
    expect(sim.belt, isEmpty);
    expect(sim.hasActiveEffect, isTrue);
    expect(
      sim.drainEvents().any((e) => e.type == game.SimEventType.powerUpUsed),
      isTrue,
    );
  });

  test('shield absorbs a fall and returns the marble to safety', () {
    final level = LevelRuntime.build(LevelCatalog.byId(3));
    final sim = game.Simulation(level);
    sim.shieldCharges = 1;
    sim.ball = level.holes.first.center;
    sim.velocity = Offset.zero;

    sim.step(1 / 60, Offset.zero);

    expect(sim.fell, isFalse);
    expect(sim.shieldCharges, 0);
    expect(sim.ball, level.start);
    expect(
      sim.drainEvents().any((e) => e.type == game.SimEventType.shieldSave),
      isTrue,
    );
  });

  test('slow field slows the hazard clock, not the run timer', () {
    final level = LevelRuntime.build(LevelCatalog.byId(300));
    final sim = game.Simulation(level);
    sim.belt.add(PowerUpType.slow);
    sim.activatePowerUp(0);
    expect(sim.slowTimer, greaterThan(5));

    for (var i = 0; i < 60; i++) {
      sim.step(1 / 60, Offset.zero);
    }
    expect(sim.time, closeTo(1.0, 0.05));
    expect(sim.hazardTime, lessThan(0.6));
  });

  test('reset clears power-ups and active effects', () {
    final level = LevelCatalog.all
        .map(LevelRuntime.build)
        .firstWhere((runtime) => runtime.powerUps.isNotEmpty);
    final sim = game.Simulation(level);
    sim.belt.add(PowerUpType.magnet);
    sim.activatePowerUp(0);
    sim.shieldCharges = 2;
    sim.reset();

    expect(sim.belt, isEmpty);
    expect(sim.shieldCharges, 0);
    expect(sim.magnetTimer, 0);
    expect(sim.collectedPowerUps, isEmpty);
    expect(sim.hazardTime, 0);
  });

  test('simulation stays finite over a long random-ish run', () {
    final level = LevelRuntime.build(LevelCatalog.byId(35));
    final sim = game.Simulation(level);
    const inputs = [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1),
      Offset(0.5, 0.5),
      Offset.zero,
    ];
    for (var i = 0; i < 1200; i++) {
      sim.step(1 / 60, inputs[(i ~/ 37) % inputs.length]);
      expect(sim.ball.dx.isFinite, isTrue);
      expect(sim.ball.dy.isFinite, isTrue);
      expect(sim.velocity.dx.isFinite, isTrue);
      expect(sim.velocity.dy.isFinite, isTrue);
      if (sim.fell || sim.won) sim.reset();
    }
  });
}
