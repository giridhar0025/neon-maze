import 'package:flutter_test/flutter_test.dart';
import 'package:neon_maze/game/levels.dart';
import 'package:neon_maze/game/maze.dart';

void main() {
  test('catalog has eight chapters of ten levels with rising grid sizes', () {
    expect(LevelCatalog.all.length, 80);
    expect(LevelCatalog.byId(0).cols, 5);
    expect(LevelCatalog.byId(79).cols, greaterThanOrEqualTo(16));
    expect(LevelCatalog.byId(9).chapter, 0);
    expect(LevelCatalog.byId(10).chapter, 1);
    expect(LevelCatalog.byId(59).chapter, 5);
    expect(LevelCatalog.byId(79).chapter, 7);
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
        final idx = maze.indexOf(hole.center.dx.floor(), hole.center.dy.floor());
        expect(solutionCells.contains(idx), isFalse,
            reason: 'level ${spec.id} hole blocks the path');
        expect(hole.center.dx, inInclusiveRange(0, spec.cols.toDouble()));
        expect(hole.center.dy, inInclusiveRange(0, spec.rows.toDouble()));
      }

      // Orbs can live in side branches now, but every one must be reachable.
      final holeCells = {
        for (final h in level.holes)
          maze.indexOf(h.center.dx.floor(), h.center.dy.floor()),
      };
      for (final orb in level.orbs) {
        final cell = Cell(orb.center.dx.floor(), orb.center.dy.floor());
        final idx = maze.indexOf(cell.x, cell.y);
        expect(maze.distanceAt(cell), greaterThanOrEqualTo(0),
            reason: 'level ${spec.id} orb is unreachable');
        expect(holeCells.contains(idx), isFalse,
            reason: 'level ${spec.id} orb sits inside a hole');
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
  });

  test('chapters introduce mechanics in a deliberate order', () {
    expect(LevelCatalog.chapter(0).every((l) => l.orbs == 0), isTrue);
    expect(LevelCatalog.chapter(1).every((l) => l.orbs >= 2), isTrue);
    expect(LevelCatalog.chapter(2).every((l) => l.conveyors > 0 && l.bumpers > 0), isTrue);
    expect(LevelCatalog.all.every((l) => l.iceZones == 0 && l.tarZones == 0), isTrue);
    expect(LevelCatalog.chapter(3).every((l) => l.gates > 0), isTrue);
    expect(LevelCatalog.chapter(4).every((l) => l.portalPairs > 0), isTrue);
    expect(LevelCatalog.chapter(5).every((l) => l.flowPanels > 0), isTrue);
    expect(LevelCatalog.chapter(6).every((l) => l.breakables > 0), isTrue);
    expect(LevelCatalog.chapter(7).any((l) => l.blackout), isTrue);
  });

  test('star thresholds are ordered', () {
    final spec = LevelCatalog.byId(40);
    expect(spec.starsFor(spec.parMs), 3);
    expect(spec.starsFor((spec.parMs * 1.2).round()), 2);
    expect(spec.starsFor((spec.parMs * 2).round()), 1);
  });

  test('maze sizes stay inside a large-board range', () {
    for (final spec in LevelCatalog.all) {
      expect(spec.cols, inInclusiveRange(5, 24));
      expect(spec.rows, inInclusiveRange(5, 27));
      expect(spec.cols * spec.rows, lessThan(700));
      expect(spec.seed, greaterThan(0));
      expect(spec.difficulty, inInclusiveRange(1, 10));
      expect(Dir.values.length, 4);
    }
  });
}
