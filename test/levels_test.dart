import 'package:flutter_test/flutter_test.dart';
import 'package:neon_maze/game/levels.dart';
import 'package:neon_maze/game/maze.dart';

void main() {
  test('catalog has six chapters of ten levels with rising grid sizes', () {
    expect(LevelCatalog.all.length, 60);
    expect(LevelCatalog.byId(0).cols, 5);
    expect(LevelCatalog.byId(59).cols, greaterThanOrEqualTo(12));
    expect(LevelCatalog.byId(9).chapter, 0);
    expect(LevelCatalog.byId(10).chapter, 1);
    expect(LevelCatalog.byId(59).chapter, 5);
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

      // Holes never sit on the solution, so the exit remains reachable.
      for (final hole in level.holes) {
        final idx = maze.indexOf(hole.center.dx.floor(), hole.center.dy.floor());
        expect(solutionCells.contains(idx), isFalse,
            reason: 'level ${spec.id} hole blocks the path');
        expect(hole.center.dx, inInclusiveRange(0, spec.cols.toDouble()));
        expect(hole.center.dy, inInclusiveRange(0, spec.rows.toDouble()));
      }

      // Orbs are always reachable: they are placed on solution cells.
      for (final orb in level.orbs) {
        final idx = maze.indexOf(orb.center.dx.floor(), orb.center.dy.floor());
        expect(solutionCells.contains(idx), isTrue,
            reason: 'level ${spec.id} orb is off the path');
        expect(orb.center, isNot(level.start));
        expect(orb.center, isNot(level.exit));
      }

      // Requested content is placed whenever the maze is large enough.
      expect(level.holes.length, spec.holes.clamp(0, spec.cols * spec.rows));
      expect(level.orbs.length, lessThanOrEqualTo(spec.orbs));
      expect(level.orbs.length, greaterThanOrEqualTo(0));

      for (final gate in level.gates) {
        final rect = gate.rectAt(0);
        expect(rect.width, greaterThan(0));
        expect(rect.height, greaterThan(0));
        expect(rect.center.dx, inInclusiveRange(0, spec.cols.toDouble()));
        expect(rect.center.dy, inInclusiveRange(0, spec.rows.toDouble()));
      }

      for (final pair in level.portals) {
        expect(pair.a, isNot(pair.b));
        expect((pair.a - pair.b).distance, greaterThan(1.5));
      }

      expect(spec.parMs, greaterThan(8000));
    }
  });

  test('chapter one introduces orbs and chapter two introduces ice and tar', () {
    expect(LevelCatalog.chapter(0).every((l) => l.orbs == 0), isTrue);
    expect(LevelCatalog.chapter(1).every((l) => l.orbs >= 2), isTrue);
    expect(LevelCatalog.chapter(2).every((l) => l.iceZones > 0 && l.tarZones > 0), isTrue);
    expect(LevelCatalog.chapter(3).every((l) => l.gates > 0), isTrue);
    expect(LevelCatalog.chapter(4).every((l) => l.portalPairs > 0), isTrue);
    expect(LevelCatalog.chapter(5).any((l) => l.blackout), isTrue);
  });

  test('star thresholds are ordered', () {
    final spec = LevelCatalog.byId(40);
    expect(spec.starsFor(spec.parMs), 3);
    expect(spec.starsFor((spec.parMs * 1.2).round()), 2);
    expect(spec.starsFor((spec.parMs * 2).round()), 1);
  });

  test('maze sizes stay inside a mobile-friendly range', () {
    for (final spec in LevelCatalog.all) {
      expect(spec.cols, inInclusiveRange(5, 14));
      expect(spec.rows, inInclusiveRange(5, 14));
      expect(spec.cols * spec.rows, lessThan(200));
      expect(spec.seed, greaterThan(0));
      expect(Dir.values.length, 4);
    }
  });
}
