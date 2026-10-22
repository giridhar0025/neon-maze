import 'package:flutter_test/flutter_test.dart';
import 'package:neon_maze/game/maze.dart';

void main() {
  test('every generated maze is fully connected and symmetric', () {
    for (var seed = 0; seed < 20; seed++) {
      final maze = Maze.generate(cols: 8, rows: 9, seed: seed, braid: 2);

      // Flood fill from the start.
      final seen = <int>{maze.indexOf(0, 0)};
      final queue = <int>[maze.indexOf(0, 0)];
      var head = 0;
      while (head < queue.length) {
        final idx = queue[head++];
        final x = idx % maze.cols;
        final y = idx ~/ maze.cols;
        for (final d in Dir.values) {
          if (maze.hasWall(x, y, d)) continue;
          final n = maze.neighbor(x, y, d);
          expect(n, isNotNull, reason: 'open wall must lead inside the board');
          final ni = maze.indexOf(n!.x, n.y);
          if (seen.add(ni)) queue.add(ni);
        }
      }
      expect(seen.length, maze.cellCount, reason: 'seed $seed left islands');

      // Walls must exist on both sides of every edge.
      for (var y = 0; y < maze.rows; y++) {
        for (var x = 0; x < maze.cols; x++) {
          for (final d in Dir.values) {
            final n = maze.neighbor(x, y, d);
            if (n == null) {
              expect(maze.hasWall(x, y, d), isTrue, reason: 'border must be sealed');
              continue;
            }
            expect(
              maze.hasWall(x, y, d),
              maze.hasWall(n.x, n.y, d.opposite),
              reason: 'asymmetric wall at ($x,$y) $d',
            );
          }
        }
      }
    }
  });

  test('solution starts at the start, ends at the goal, and is walkable', () {
    for (var seed = 0; seed < 20; seed++) {
      final maze = Maze.generate(cols: 7, rows: 6, seed: seed);
      final solution = maze.solution;

      expect(solution.first, maze.start);
      expect(solution.last, maze.goal);
      expect(solution.length, greaterThan(1));

      for (var i = 0; i < solution.length - 1; i++) {
        final a = solution[i];
        final b = solution[i + 1];
        final dx = (a.x - b.x).abs();
        final dy = (a.y - b.y).abs();
        expect(dx + dy, 1, reason: 'solution jumped between non-adjacent cells');
        final dir = dx == 1
            ? (b.x > a.x ? Dir.east : Dir.west)
            : (b.y > a.y ? Dir.south : Dir.north);
        expect(maze.hasWall(a.x, a.y, dir), isFalse);
      }
    }
  });

  test('goal is the farthest reachable cell', () {
    final maze = Maze.generate(cols: 9, rows: 9, seed: 42, braid: 1);
    final goalDistance = maze.distanceAt(maze.goal);
    for (var y = 0; y < maze.rows; y++) {
      for (var x = 0; x < maze.cols; x++) {
        expect(maze.distanceAt(Cell(x, y)), lessThanOrEqualTo(goalDistance));
      }
    }
  });

  test('wall boxes seal the outer border', () {
    final maze = Maze.generate(cols: 6, rows: 6, seed: 3);
    final boxes = maze.wallBoxes(0.14);
    expect(boxes, isNotEmpty);
    // Every box must intersect or touch the board bounds.
    for (final box in boxes) {
      expect(box.left, greaterThanOrEqualTo(-0.07));
      expect(box.top, greaterThanOrEqualTo(-0.07));
      expect(box.right, lessThanOrEqualTo(6.07));
      expect(box.bottom, lessThanOrEqualTo(6.07));
    }
  });
}
