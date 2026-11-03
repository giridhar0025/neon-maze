import 'package:flutter_test/flutter_test.dart';
import 'package:neon_maze/game/daily.dart';
import 'package:neon_maze/game/levels.dart';
import 'package:neon_maze/game/maze.dart';

void main() {
  test('catalog has eight chapters of one hundred levels', () {
    expect(LevelCatalog.all.length, 800);
    expect(LevelCatalog.levelsPerChapter, 100);
    expect(LevelCatalog.byId(0).cols, 5);
    expect(LevelCatalog.byId(99).chapter, 0);
    expect(LevelCatalog.byId(100).chapter, 1);
    expect(LevelCatalog.byId(699).chapter, 6);
    expect(LevelCatalog.byId(799).chapter, 7);
    expect(LevelCatalog.chapter(7).length, 100);
    expect(LevelCatalog.byId(799).powerUps, greaterThan(0));
  });

  test('every level builds and is solvable by construction', () {
    for (final spec in LevelCatalog.all) {
      final level = LevelRuntime.build(spec);
      final maze = level.maze;

      expect(maze.solution.first, maze.start, reason: 'level ${spec.id}');
      expect(maze.solution.last, maze.goal);
      expect(level.start, maze.startCenter);
      expect(level.exit, maze.goalCenter);

      final solutionCells = {
        for (final c in maze.solution) maze.indexOf(c.x, c.y),
      };

      // Holes never sit on the solution, so the main route stays open.
      for (final hole in level.holes) {
        final idx = maze.indexOf(
          hole.center.dx.floor(),
          hole.center.dy.floor(),
        );
        expect(
          solutionCells.contains(idx),
          isFalse,
          reason: 'level ${spec.id} hole blocks the path',
        );
        expect(hole.center.dx, inInclusiveRange(0, spec.cols.toDouble()));
        expect(hole.center.dy, inInclusiveRange(0, spec.rows.toDouble()));
      }

      final holeCells = {
        for (final h in level.holes)
          maze.indexOf(h.center.dx.floor(), h.center.dy.floor()),
      };

      // Orbs can live in side branches, but every one must be reachable.
      for (final orb in level.orbs) {
        final cell = Cell(orb.center.dx.floor(), orb.center.dy.floor());
        final idx = maze.indexOf(cell.x, cell.y);
        expect(
          maze.distanceAt(cell),
          greaterThanOrEqualTo(0),
          reason: 'level ${spec.id} orb is unreachable',
        );
        expect(
          holeCells.contains(idx),
          isFalse,
          reason: 'level ${spec.id} orb sits inside a hole',
        );
        expect(orb.center, isNot(level.start));
        expect(orb.center, isNot(level.exit));
      }

      // Every power-up pickup is reachable and never hidden inside a hazard.
      for (final pickup in level.powerUps) {
        final cell = Cell(pickup.center.dx.floor(), pickup.center.dy.floor());
        expect(
          maze.distanceAt(cell),
          greaterThanOrEqualTo(0),
          reason: 'level ${spec.id} power-up is unreachable',
        );
        expect(
          holeCells.contains(maze.indexOf(cell.x, cell.y)),
          isFalse,
          reason: 'level ${spec.id} power-up sits inside a hole',
        );
        expect(pickup.center, isNot(level.start));
        expect(pickup.center, isNot(level.exit));
      }

      expect(level.holes.length, lessThanOrEqualTo(spec.holes));
      expect(level.orbs.length, lessThanOrEqualTo(spec.orbs));
      expect(level.powerUps.length, lessThanOrEqualTo(spec.powerUps));

      // Requested mechanics must actually appear, not just be listed in the
      // spec. Late boards can run out of legal cells, so allow a small miss
      // only for the stacking-heavy mechanics.
      if (spec.gates > 0) {
        expect(level.gates.length, spec.gates, reason: 'gates ${spec.id}');
      }
      if (spec.flowPanels > 0) {
        expect(
          level.flowPanels.length,
          spec.flowPanels,
          reason: 'flow ${spec.id}',
        );
      }
      if (spec.sliders > 0) {
        expect(
          level.sliders.length,
          spec.sliders,
          reason: 'sliders ${spec.id}',
        );
      }
      if (spec.breakables > 0) {
        expect(
          level.breakables.length,
          greaterThan(0),
          reason: 'break ${spec.id}',
        );
      }
      if (spec.portalPairs > 0) {
        expect(
          level.portals.length,
          greaterThan(0),
          reason: 'portals ${spec.id}',
        );
      }
      if (spec.powerUps > 0) {
        expect(
          level.powerUps.length,
          greaterThan(0),
          reason: 'powerup ${spec.id}',
        );
      }
      if (spec.conveyors > 0) {
        expect(
          level.conveyors.length,
          greaterThan(0),
          reason: 'belt ${spec.id}',
        );
      }
      if (spec.bumpers > 0) {
        expect(
          level.bumpers.length,
          greaterThan(0),
          reason: 'bumper ${spec.id}',
        );
      }
      if (spec.magnets > 0) {
        expect(
          level.magnets.length,
          greaterThan(0),
          reason: 'magnet ${spec.id}',
        );
      }

      for (final gate in level.gates) {
        final rect = gate.rectAt(0);
        expect(rect.width, greaterThan(0));
        expect(rect.height, greaterThan(0));
        expect(rect.center.dx, inInclusiveRange(0, spec.cols.toDouble()));
        expect(rect.center.dy, inInclusiveRange(0, spec.rows.toDouble()));
        // Strict positioning: a gate must sit on the critical route, in a
        // genuine straight corridor, and never on the start/exit approach.
        final cell = Cell(gate.base.dx.floor(), gate.base.dy.floor());
        expect(
          solutionCells.contains(maze.indexOf(cell.x, cell.y)),
          isTrue,
          reason: 'gate off route on ${spec.id}',
        );
        final open = [
          for (final d in Dir.values)
            if (!maze.hasWall(cell.x, cell.y, d)) d,
        ];
        expect(open.length, 2, reason: 'gate not in a corridor on ${spec.id}');
        expect(
          (open.contains(Dir.east) && open.contains(Dir.west)) ||
              (open.contains(Dir.north) && open.contains(Dir.south)),
          isTrue,
          reason: 'gate not on a straight on ${spec.id}',
        );
        expect((gate.base - level.start).distance, greaterThan(1.5));
        expect((gate.base - level.exit).distance, greaterThan(1.5));
      }

      for (var i = 0; i < level.gates.length; i++) {
        for (var j = i + 1; j < level.gates.length; j++) {
          expect(
            (level.gates[i].base - level.gates[j].base).distance,
            greaterThan(1.2),
            reason: 'gates stacked on ${spec.id}',
          );
        }
      }

      for (final slider in level.sliders) {
        final cell = Cell(slider.base.dx.floor(), slider.base.dy.floor());
        expect(
          solutionCells.contains(maze.indexOf(cell.x, cell.y)),
          isTrue,
          reason: 'slider off route on ${spec.id}',
        );
        final open = [
          for (final d in Dir.values)
            if (!maze.hasWall(cell.x, cell.y, d)) d,
        ];
        expect(open.length, 2);
        expect(
          (open.contains(Dir.east) && open.contains(Dir.west)) ||
              (open.contains(Dir.north) && open.contains(Dir.south)),
          isTrue,
        );
      }

      for (final belt in level.conveyors) {
        final cell = Cell(
          belt.rect.center.dx.floor(),
          belt.rect.center.dy.floor(),
        );
        expect(
          solutionCells.contains(maze.indexOf(cell.x, cell.y)),
          isTrue,
          reason: 'belt off route on ${spec.id}',
        );
        expect(belt.direction.distance, closeTo(1.0, 1e-6));
        expect(belt.strength, greaterThan(0));
      }

      for (final magnet in level.magnets) {
        final cell = Cell(magnet.center.dx.floor(), magnet.center.dy.floor());
        expect(
          solutionCells.contains(maze.indexOf(cell.x, cell.y)),
          isTrue,
          reason: 'magnet off route on ${spec.id}',
        );
      }

      for (final bumper in level.bumpers) {
        final cell = Cell(bumper.center.dx.floor(), bumper.center.dy.floor());
        expect(
          solutionCells.contains(maze.indexOf(cell.x, cell.y)),
          isTrue,
          reason: 'bumper off route on ${spec.id}',
        );
      }

      for (final zone in level.tar) {
        final idx = maze.indexOf(
          zone.rect.center.dx.floor(),
          zone.rect.center.dy.floor(),
        );
        expect(
          solutionCells.contains(idx),
          isFalse,
          reason: 'tar on the main route on ${spec.id}',
        );
      }

      for (var i = 0; i < level.holes.length; i++) {
        for (var j = i + 1; j < level.holes.length; j++) {
          final a = level.holes[i].center;
          final b = level.holes[j].center;
          final manhattan =
              (a.dx.floor() - b.dx.floor()).abs() +
              (a.dy.floor() - b.dy.floor()).abs();
          expect(
            manhattan,
            greaterThanOrEqualTo(3),
            reason: 'holes merged on ${spec.id}',
          );
        }
      }

      for (final pair in level.portals) {
        expect(pair.a, isNot(pair.b));
        expect((pair.a - pair.b).distance, greaterThan(1.5));
      }

      for (final panel in level.flowPanels) {
        expect(panel.direction.distance, closeTo(1.0, 1e-6));
        expect(panel.rect.width, greaterThan(0));
        expect(panel.rect.height, greaterThan(0));
      }

      for (final wall in level.breakables) {
        expect(wall.rect.width, greaterThan(0));
        expect(wall.rect.height, greaterThan(0));
        expect(level.isBreakableBox(wall.rect), isTrue);
      }

      expect(spec.parMs, greaterThan(8000));
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('chapters introduce mechanics in a deliberate order', () {
    final first = LevelCatalog.chapter(0);
    expect(first.first.orbs, 0);
    expect(first.any((l) => l.orbs > 0), isTrue);
    expect(LevelCatalog.chapter(1).every((l) => l.orbs >= 2), isTrue);
    expect(
      LevelCatalog.chapter(2).every((l) => l.conveyors > 0 && l.bumpers > 0),
      isTrue,
    );
    expect(LevelCatalog.all.every((l) => l.iceZones == 0), isTrue);
    expect(
      LevelCatalog.all
          .where((l) => l.chapter < 5)
          .every((l) => l.tarZones == 0),
      isTrue,
    );
    expect(LevelCatalog.chapter(7).any((l) => l.tarZones > 0), isTrue);
    expect(LevelCatalog.chapter(3).every((l) => l.gates > 0), isTrue);
    expect(LevelCatalog.chapter(4).every((l) => l.portalPairs > 0), isTrue);
    expect(LevelCatalog.chapter(5).every((l) => l.flowPanels > 0), isTrue);
    expect(LevelCatalog.chapter(6).every((l) => l.breakables > 0), isTrue);
    expect(LevelCatalog.chapter(7).any((l) => l.blackout), isTrue);
    expect(LevelCatalog.all.any((l) => l.powerUps > 0), isTrue);
  });

  test('routes and hazard budgets grow through the acts', () {
    final opening = LevelCatalog.chapter(7).take(20).toList();
    final finale = LevelCatalog.chapter(7).skip(80).toList();
    double avgTarget(List<LevelSpec> specs) =>
        specs.map(LevelCatalog.targetPathLength).reduce((a, b) => a + b) /
        specs.length;
    double avgPath(List<LevelSpec> specs) =>
        specs
            .map((s) => LevelRuntime.build(s).maze.solution.length)
            .reduce((a, b) => a + b) /
        specs.length;
    int hazards(LevelSpec s) =>
        s.gates +
        s.sliders +
        s.bumpers +
        s.magnets +
        s.conveyors +
        s.flowPanels +
        s.breakables;

    expect(avgTarget(finale), greaterThan(avgTarget(opening)));
    expect(avgPath(finale), greaterThan(avgPath(opening)));
    expect(
      avgPath(LevelCatalog.chapter(7)),
      greaterThan(avgPath(LevelCatalog.chapter(0)) * 1.5),
    );
    expect(
      finale.map(hazards).reduce((a, b) => a + b),
      greaterThan(opening.map(hazards).reduce((a, b) => a + b)),
    );
    for (final spec in LevelCatalog.all) {
      expect(LevelCatalog.targetPathLength(spec), greaterThanOrEqualTo(22));
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'late chapters stay readable instead of growing into a wall of cells',
    () {
      for (final spec in LevelCatalog.all) {
        expect(spec.cols, inInclusiveRange(5, 14));
        expect(spec.rows, inInclusiveRange(6, 18));
        expect(spec.cols * spec.rows, lessThan(280));
        expect(spec.seed, greaterThan(0));
        expect(spec.difficulty, inInclusiveRange(1, 10));
        expect(Dir.values.length, 4);
      }
    },
  );

  test('acts ramp within each chapter without repeating a seed', () {
    final seeds = <int>{};
    for (final spec in LevelCatalog.all) {
      expect(
        seeds.add(spec.seed),
        isTrue,
        reason: 'duplicate seed on level ${spec.id}',
      );
      expect(spec.act, spec.indexInChapter ~/ 20);
      if (spec.indexInChapter == 99) {
        expect(spec.isChapterBoss, isTrue);
      }
    }
  });

  test('star thresholds are ordered', () {
    final spec = LevelCatalog.byId(400);
    expect(spec.starsFor(spec.parMs), 3);
    expect(spec.starsFor((spec.parMs * 1.2).round()), 2);
    expect(spec.starsFor((spec.parMs * 2).round()), 1);
  });

  test('daily challenge is deterministic per day and solvable', () {
    final a = DailyChallenge.specFor(DateTime(2026, 10, 23));
    final b = DailyChallenge.specFor(DateTime(2026, 10, 23));
    final c = DailyChallenge.specFor(DateTime(2026, 10, 24));

    expect(a.seed, b.seed);
    expect(a.seed, isNot(c.seed));
    expect(a.id, -1);
    expect(a.powerUps, greaterThan(0));

    final level = LevelRuntime.build(a);
    expect(level.maze.solution.first, level.maze.start);
    expect(level.maze.solution.last, level.maze.goal);
  });
}
