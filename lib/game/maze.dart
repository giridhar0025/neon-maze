import 'dart:math';

import 'package:flutter/painting.dart';

enum Dir {
  north(0, -1),
  east(1, 0),
  south(0, 1),
  west(-1, 0);

  const Dir(this.dx, this.dy);

  final int dx;
  final int dy;

  int get bit => 1 << index;

  Dir get opposite => Dir.values[(index + 2) % 4];
}

class Cell {
  const Cell(this.x, this.y);

  final int x;
  final int y;

  Offset get center => Offset(x + 0.5, y + 0.5);

  @override
  bool operator ==(Object other) => other is Cell && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Cell($x, $y)';
}

/// A seeded perfect maze with optional braiding (extra loops).
///
/// Walls are stored per cell as a 4-bit mask. Distances are measured from the
/// start cell, and the goal is always the farthest reachable cell so that every
/// generated level has a non-trivial solution.
class Maze {
  Maze._(this.cols, this.rows, this.walls, this.seed)
      : start = const Cell(0, 0),
        goal = const Cell(0, 0);

  final int cols;
  final int rows;
  final int seed;

  /// Bitmask per cell; bit set means a wall exists in that direction.
  final List<int> walls;

  Cell start;
  Cell goal;

  late List<int> _dist;
  late List<int> _parent;

  int get cellCount => cols * rows;

  int indexOf(int x, int y) => y * cols + x;

  bool inside(int x, int y) => x >= 0 && y >= 0 && x < cols && y < rows;

  bool hasWall(int x, int y, Dir d) => (walls[indexOf(x, y)] & d.bit) != 0;

  Cell? neighbor(int x, int y, Dir d) {
    final nx = x + d.dx;
    final ny = y + d.dy;
    return inside(nx, ny) ? Cell(nx, ny) : null;
  }

  Offset get startCenter => start.center;

  Offset get goalCenter => goal.center;

  List<Cell> get solution {
    final path = <Cell>[];
    var current = indexOf(goal.x, goal.y);
    final startIndex = indexOf(start.x, start.y);
    var guard = cellCount + 2;
    while (guard-- > 0) {
      path.add(Cell(current % cols, current ~/ cols));
      if (current == startIndex) break;
      current = _parent[current];
    }
    return path.reversed.toList();
  }

  Set<int> get solutionIndices => {for (final c in solution) indexOf(c.x, c.y)};

  int distanceBetween(Cell a, Cell b) {
    // BFS distance, used for hazard placement heuristics.
    final queue = <int>[indexOf(a.x, a.y)];
    final seen = <int>{queue.first};
    var depth = 0;
    while (queue.isNotEmpty) {
      final next = <int>[];
      for (final idx in queue) {
        if (idx == indexOf(b.x, b.y)) return depth;
        final x = idx % cols;
        final y = idx ~/ cols;
        for (final d in Dir.values) {
          if (hasWall(x, y, d)) continue;
          final n = neighbor(x, y, d);
          if (n == null) continue;
          final ni = indexOf(n.x, n.y);
          if (seen.add(ni)) next.add(ni);
        }
      }
      queue
        ..clear()
        ..addAll(next);
      depth++;
    }
    return 1 << 30;
  }

  static Maze generate({
    required int cols,
    required int rows,
    required int seed,
    int braid = 0,
  }) {
    final rnd = Random(seed);
    final walls = List<int>.filled(cols * rows, 0xF);
    final visited = List<bool>.filled(cols * rows, false);

    int idx(int x, int y) => y * cols + x;

    // Iterative randomized depth-first carve.
    final stack = <Cell>[const Cell(0, 0)];
    visited[0] = true;
    while (stack.isNotEmpty) {
      final cur = stack.last;
      final options = <Dir>[];
      for (final d in Dir.values) {
        final nx = cur.x + d.dx;
        final ny = cur.y + d.dy;
        if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) continue;
        if (!visited[idx(nx, ny)]) options.add(d);
      }
      if (options.isEmpty) {
        stack.removeLast();
        continue;
      }
      final d = options[rnd.nextInt(options.length)];
      final nx = cur.x + d.dx;
      final ny = cur.y + d.dy;
      walls[idx(cur.x, cur.y)] &= ~d.bit;
      walls[idx(nx, ny)] &= ~d.opposite.bit;
      visited[idx(nx, ny)] = true;
      stack.add(Cell(nx, ny));
    }

    // Braiding: knock out extra walls to create loops and route choices.
    var extra = braid;
    var guard = cols * rows * 6;
    while (extra > 0 && guard-- > 0) {
      final x = rnd.nextInt(cols);
      final y = rnd.nextInt(rows);
      final d = Dir.values[rnd.nextInt(4)];
      final n = Cell(x + d.dx, y + d.dy);
      if (n.x < 0 || n.y < 0 || n.x >= cols || n.y >= rows) continue;
      if (!(Maze._wall(walls, cols, x, y, d))) continue;
      walls[idx(x, y)] &= ~d.bit;
      walls[idx(n.x, n.y)] &= ~d.opposite.bit;
      extra--;
    }

    final maze = Maze._(cols, rows, walls, seed);
    maze._computeDistances(idx(0, 0));

    // Goal is the farthest cell, tie-broken by the seeded RNG.
    var bestIndex = 0;
    var best = -1;
    for (var i = 0; i < walls.length; i++) {
      if (maze._dist[i] > best) {
        best = maze._dist[i];
        bestIndex = i;
      } else if (maze._dist[i] == best && rnd.nextBool()) {
        bestIndex = i;
      }
    }
    if (bestIndex == 0 && walls.length > 1) bestIndex = walls.length - 1;
    maze.goal = Cell(bestIndex % cols, bestIndex ~/ cols);
    return maze;
  }

  static bool _wall(List<int> walls, int cols, int x, int y, Dir d) =>
      (walls[y * cols + x] & d.bit) != 0;

  void _computeDistances(int startIndex) {
    _dist = List<int>.filled(cellCount, -1);
    _parent = List<int>.filled(cellCount, -1);
    _dist[startIndex] = 0;
    final queue = <int>[startIndex];
    var head = 0;
    while (head < queue.length) {
      final idx = queue[head++];
      final x = idx % cols;
      final y = idx ~/ cols;
      for (final d in Dir.values) {
        if (hasWall(x, y, d)) continue;
        final n = neighbor(x, y, d);
        if (n == null) continue;
        final ni = indexOf(n.x, n.y);
        if (_dist[ni] != -1) continue;
        _dist[ni] = _dist[idx] + 1;
        _parent[ni] = idx;
        queue.add(ni);
      }
    }
  }

  int distanceAt(Cell c) => _dist[indexOf(c.x, c.y)];

  /// Solid wall rectangles in world space, sealed at the corners.
  List<Rect> wallBoxes(double thickness) {
    final t = thickness;
    final boxes = <Rect>[];
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        if (hasWall(x, y, Dir.north)) {
          boxes.add(Rect.fromLTRB(x - t / 2, y - t / 2, x + 1 + t / 2, y + t / 2));
        }
        if (hasWall(x, y, Dir.west)) {
          boxes.add(Rect.fromLTRB(x - t / 2, y - t / 2, x + t / 2, y + 1 + t / 2));
        }
      }
    }
    for (var x = 0; x < cols; x++) {
      boxes.add(Rect.fromLTRB(
          x - t / 2, rows - t / 2, x + 1 + t / 2, rows + t / 2));
    }
    for (var y = 0; y < rows; y++) {
      boxes.add(Rect.fromLTRB(
          cols - t / 2, y - t / 2, cols + t / 2, y + 1 + t / 2));
    }
    return boxes;
  }

  /// Walls as segments, for rendering crisp edges rather than boxes.
  List<Rect> wallSegments(double thickness) {
    final t = thickness;
    final segments = <Rect>[];
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        if (hasWall(x, y, Dir.north)) {
          segments.add(Rect.fromLTRB(x.toDouble(), y - t / 2, (x + 1).toDouble(), y + t / 2));
        }
        if (hasWall(x, y, Dir.west)) {
          segments.add(Rect.fromLTRB(x - t / 2, y.toDouble(), x + t / 2, (y + 1).toDouble()));
        }
      }
    }
    for (var x = 0; x < cols; x++) {
      segments.add(Rect.fromLTRB(x.toDouble(), rows - t / 2, (x + 1).toDouble(), rows + t / 2));
    }
    for (var y = 0; y < rows; y++) {
      segments.add(Rect.fromLTRB(cols - t / 2, y.toDouble(), cols + t / 2, (y + 1).toDouble()));
    }
    return segments;
  }
}
