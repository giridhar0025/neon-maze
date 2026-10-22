import 'package:flutter_test/flutter_test.dart';
import 'package:neon_maze/game/levels.dart';
import 'package:neon_maze/game/simulation.dart' as game;

void main() {
  test('tilt accelerates the marble in the tilt direction', () {
    final level = LevelRuntime.build(LevelCatalog.byId(0));
    final sim = game.Simulation(level);
    sim.ball = level.start;
    sim.velocity = Offset.zero;

    for (var i = 0; i < 12; i++) {
      sim.step(1 / 60, const Offset(1, 0));
    }
    expect(sim.velocity.dx, greaterThan(0.05));
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
      expect(sim.ball.dx, lessThanOrEqualTo(level.maze.cols - sim.ballRadius + 0.02));
      expect(sim.ball.dy, lessThanOrEqualTo(level.maze.rows - sim.ballRadius + 0.02));
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
    expect(sim.won, isFalse, reason: 'exit must stay locked with orbs remaining');

    for (var i = 0; i < level.orbs.length; i++) {
      sim.collected.add(i);
    }
    sim.ball = level.exit;
    sim.step(1 / 60, Offset.zero);
    expect(sim.won, isTrue);
    expect(sim.drainEvents().any((e) => e.type == game.SimEventType.win), isTrue);
  });

  test('crossing a hole ends the run and emits a fall event', () {
    final level = LevelRuntime.build(LevelCatalog.byId(3));
    expect(level.holes, isNotEmpty);
    final sim = game.Simulation(level);
    sim.ball = level.holes.first.center;
    sim.step(1 / 60, Offset.zero);
    expect(sim.fell, isTrue);
    expect(sim.drainEvents().any((e) => e.type == game.SimEventType.fall), isTrue);
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
