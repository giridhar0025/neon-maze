import 'dart:math';

import 'package:flutter/painting.dart';

import 'maze.dart';

class LevelSpec {
  const LevelSpec({
    required this.id,
    required this.chapter,
    required this.indexInChapter,
    required this.cols,
    required this.rows,
    required this.seed,
    required this.braid,
    required this.holes,
    required this.orbs,
    required this.iceZones,
    required this.tarZones,
    required this.gates,
    required this.portalPairs,
    required this.bumpers,
    required this.blackout,
    required this.parMs,
  });

  final int id;
  final int chapter;
  final int indexInChapter;
  final int cols;
  final int rows;
  final int seed;
  final int braid;
  final int holes;
  final int orbs;
  final int iceZones;
  final int tarZones;
  final int gates;
  final int portalPairs;
  final int bumpers;
  final bool blackout;
  final int parMs;

  String get number => '${id + 1}'.padLeft(2, '0');

  String get chapterName => 'Chapter ${chapter + 1}';

  List<String> get mechanics {
    final out = <String>[];
    if (holes > 0) out.add('Holes');
    if (orbs > 0) out.add('Orbs');
    if (iceZones > 0) out.add('Ice');
    if (tarZones > 0) out.add('Tar');
    if (gates > 0) out.add('Gates');
    if (portalPairs > 0) out.add('Portals');
    if (bumpers > 0) out.add('Bumpers');
    if (blackout) out.add('Blackout');
    return out;
  }

  int starsFor(int timeMs) {
    if (timeMs <= parMs) return 3;
    if (timeMs <= (parMs * 1.55).round()) return 2;
    return 1;
  }
}

class LevelCatalog {
  const LevelCatalog._();

  static const int chapterCount = 6;
  static const int levelsPerChapter = 10;
  static const int total = chapterCount * levelsPerChapter;

  static List<LevelSpec>? _cache;

  static List<LevelSpec> get all => _cache ??= _build();

  static LevelSpec byId(int id) => all[id.clamp(0, total - 1)];

  static List<LevelSpec> chapter(int index) =>
      all.where((l) => l.chapter == index).toList();

  static List<LevelSpec> _build() {
    final levels = <LevelSpec>[];
    const baseCols = [5, 6, 7, 8, 9, 10];
    const growth = [3, 3, 3, 3, 3, 3];

    for (var c = 0; c < chapterCount; c++) {
      for (var i = 0; i < levelsPerChapter; i++) {
        final t = i / (levelsPerChapter - 1);
        final cols = baseCols[c] + (t * growth[c]).round();
        final rows = (cols - (i.isEven ? 0 : 1)).clamp(5, 14);

        final orbs = c == 0 ? 0 : 2 + i ~/ 3;
        final holes = c == 0 ? 1 + i ~/ 3 : 3 + i ~/ 3;
        final ice = c == 2 ? 1 + i ~/ 4 : 0;
        final tar = c == 2 ? 1 + i ~/ 5 : 0;
        final gates = (c == 3 || c == 4 || c == 5) ? 1 + i ~/ 4 : 0;
        final portals = c == 4 ? (i >= 6 ? 2 : 1) : (c == 5 ? 1 : 0);
        final bumpers = c == 5 ? 2 + i ~/ 4 : 0;
        final blackout = c == 5 && i >= 3;

        final parSeconds = 11 +
            cols * 0.55 +
            orbs * 1.05 +
            gates * 1.5 +
            (blackout ? 3 : 0) +
            c * 0.6;

        levels.add(LevelSpec(
          id: levels.length,
          chapter: c,
          indexInChapter: i,
          cols: cols,
          rows: rows,
          seed: 9001 + c * 977 + i * 131 + cols * 17 + rows * 7,
          braid: 1 + c,
          holes: holes,
          orbs: orbs,
          iceZones: ice,
          tarZones: tar,
          gates: gates,
          portalPairs: portals,
          bumpers: bumpers,
          blackout: blackout,
          parMs: (parSeconds * 1000).round(),
        ));
      }
    }
    return levels;
  }
}

class Hole {
  const Hole(this.center, this.radius);

  final Offset center;
  final double radius;
}

class Orb {
  const Orb(this.center, this.radius);

  final Offset center;
  final double radius;
}

class Zone {
  const Zone(this.rect);

  final Rect rect;
}

class Gate {
  const Gate({
    required this.base,
    required this.spansVertically,
    required this.amplitude,
    required this.speed,
    required this.phase,
    this.halfLong = 0.44,
    this.halfThin = 0.05,
  });

  final Offset base;
  final bool spansVertically;
  final double amplitude;
  final double speed;
  final double phase;
  final double halfLong;
  final double halfThin;

  double get period => speed == 0 ? 1 : (2 * pi / speed);

  /// Gates are only solid for part of their cycle. This is what makes a level
  /// with a gate solvable: the barrier powers down and the marble slips through.
  bool isActive(double time) => sin(time * speed + phase) > -0.2;

  double openness(double time) => (sin(time * speed + phase) + 1) / 2;

  Offset centerAt(double time) {
    final sway = sin(time * speed + phase) * amplitude;
    return base + (spansVertically ? Offset(sway, 0) : Offset(0, sway));
  }

  Rect rectAt(double time) {
    final c = centerAt(time);
    return spansVertically
        ? Rect.fromCenter(center: c, width: halfThin * 2, height: halfLong * 2)
        : Rect.fromCenter(center: c, width: halfLong * 2, height: halfThin * 2);
  }
}

class PortalPair {
  const PortalPair(this.a, this.b);

  final Offset a;
  final Offset b;

  Offset partnerOf(Offset point) => (point - a).distance < (point - b).distance ? b : a;
}

class Bumper {
  const Bumper(this.center, this.radius);

  final Offset center;
  final double radius;
}

/// A level spec resolved into concrete geometry and hazards.
class LevelRuntime {
  LevelRuntime._({
    required this.spec,
    required this.maze,
    required this.holes,
    required this.orbs,
    required this.ice,
    required this.tar,
    required this.gates,
    required this.portals,
    required this.bumpers,
    required this.start,
    required this.exit,
  });

  final LevelSpec spec;
  final Maze maze;
  final List<Hole> holes;
  final List<Orb> orbs;
  final List<Zone> ice;
  final List<Zone> tar;
  final List<Gate> gates;
  final List<PortalPair> portals;
  final List<Bumper> bumpers;
  final Offset start;
  final Offset exit;

  int get orbCount => orbs.length;

  static LevelRuntime build(LevelSpec spec) {
    final maze = Maze.generate(
      cols: spec.cols,
      rows: spec.rows,
      seed: spec.seed,
      braid: spec.braid,
    );
    final rnd = Random(spec.seed ^ 0x5f3759df);
    final solution = maze.solution;
    final pathSet = {for (final c in solution) maze.indexOf(c.x, c.y)};

    final start = maze.startCenter;
    final exit = maze.goalCenter;

    // Orbs are spread evenly along the solution, never at the endpoints.
    final orbs = <Orb>[];
    if (spec.orbs > 0 && solution.length > 2) {
      final usable = solution.length - 2;
      final count = min(spec.orbs, usable);
      final used = <int>{};
      for (var k = 1; k <= count; k++) {
        var idx = (k * (usable + 1) / (count + 1)).round();
        idx = idx.clamp(1, solution.length - 2);
        while (used.contains(idx) && idx < solution.length - 2) {
          idx++;
        }
        used.add(idx);
        orbs.add(Orb(solution[idx].center, 0.13));
      }
    }
    final orbCells = {for (final o in orbs) maze.indexOf(o.center.dx.floor(), o.center.dy.floor())};

    // Holes live off the solution so every generated level stays solvable.
    final holeCandidates = <Cell>[];
    for (var y = 0; y < spec.rows; y++) {
      for (var x = 0; x < spec.cols; x++) {
        final idx = maze.indexOf(x, y);
        if (pathSet.contains(idx)) continue;
        if (idx == maze.indexOf(maze.start.x, maze.start.y)) continue;
        if (idx == maze.indexOf(maze.goal.x, maze.goal.y)) continue;
        // Keep the spawn cell readable.
        if (maze.distanceBetween(maze.start, Cell(x, y)) < 2) continue;
        holeCandidates.add(Cell(x, y));
      }
    }
    holeCandidates.shuffle(rnd);
    final holes = <Hole>[];
    for (final cell in holeCandidates.take(spec.holes)) {
      final jitter = Offset(
        (rnd.nextDouble() - 0.5) * 0.28,
        (rnd.nextDouble() - 0.5) * 0.28,
      );
      holes.add(Hole(cell.center + jitter, 0.30 + rnd.nextDouble() * 0.05));
    }
    final holeCells = {for (final h in holes) maze.indexOf(h.center.dx.floor(), h.center.dy.floor())};

    // Ice prefers the solution so it actually changes how you drive.
    final zoneUsed = <int>{};
    final ice = <Zone>[];
    final iceCandidates = <Cell>[
      for (final c in solution.skip(2).take(max(0, solution.length - 4))) c,
    ];
    iceCandidates.shuffle(rnd);
    for (final cell in iceCandidates) {
      final idx = maze.indexOf(cell.x, cell.y);
      if (ice.length >= spec.iceZones) break;
      if (holeCells.contains(idx) || orbCells.contains(idx)) continue;
      if (!zoneUsed.add(idx)) continue;
      ice.add(Zone(Rect.fromCenter(
        center: cell.center,
        width: 1.02,
        height: 1.02,
      )));
    }

    final tar = <Zone>[];
    final tarCandidates = <Cell>[
      ...holeCandidates,
      for (final c in solution.skip(1).take(max(0, solution.length - 2))) c,
    ]..shuffle(rnd);
    for (final cell in tarCandidates) {
      final idx = maze.indexOf(cell.x, cell.y);
      if (tar.length >= spec.tarZones) break;
      if (holeCells.contains(idx) || orbCells.contains(idx)) continue;
      if (!zoneUsed.add(idx)) continue;
      tar.add(Zone(Rect.fromCenter(center: cell.center, width: 1.05, height: 1.05)));
    }

    // Gates sit in straight corridor sections, never on the start or exit.
    final gates = <Gate>[];
    final gateCells = <Cell>[];
    for (final cell in solution.skip(2).take(max(0, solution.length - 4))) {
      if (gates.length >= spec.gates) break;
      final open = <Dir>[
        for (final d in Dir.values)
          if (!maze.hasWall(cell.x, cell.y, d)) d,
      ];
      if (open.length != 2) continue;
      final horizontal = open.contains(Dir.east) && open.contains(Dir.west);
      final vertical = open.contains(Dir.north) && open.contains(Dir.south);
      if (!horizontal && !vertical) continue;
      if (gateCells.any((c) => (c.center - cell.center).distance < 2.0)) continue;
      gateCells.add(cell);
      gates.add(Gate(
        base: cell.center,
        spansVertically: horizontal,
        amplitude: 0.10,
        speed: 1.35 + rnd.nextDouble() * 0.35,
        phase: rnd.nextDouble() * pi * 2,
      ));
    }

    // Portals pair two off-path cells that are far apart.
    final portals = <PortalPair>[];
    final portalCandidates = holeCandidates
        .where((c) => !holeCells.contains(maze.indexOf(c.x, c.y)))
        .toList();
    for (var p = 0; p < spec.portalPairs && portalCandidates.length >= 2; p++) {
      final a = portalCandidates.removeAt(rnd.nextInt(portalCandidates.length));
      Cell? b;
      var best = -1.0;
      for (final candidate in portalCandidates) {
        final d = (candidate.center - a.center).distance;
        if (d > best) {
          best = d;
          b = candidate;
        }
      }
      if (b == null) break;
      portalCandidates.remove(b);
      portals.add(PortalPair(a.center, b.center));
    }

    final bumpers = <Bumper>[];
    final bumperCandidates = holeCandidates
        .where((c) => !holeCells.contains(maze.indexOf(c.x, c.y)))
        .where((c) => !portals.any((p) => (p.a - c.center).distance < 1.2 || (p.b - c.center).distance < 1.2))
        .toList()
      ..shuffle(rnd);
    for (final cell in bumperCandidates.take(spec.bumpers)) {
      bumpers.add(Bumper(cell.center, 0.24));
    }

    return LevelRuntime._(
      spec: spec,
      maze: maze,
      holes: holes,
      orbs: orbs,
      ice: ice,
      tar: tar,
      gates: gates,
      portals: portals,
      bumpers: bumpers,
      start: start,
      exit: exit,
    );
  }
}
