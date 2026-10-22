import 'dart:math';

import 'package:flutter/painting.dart';

import 'maze.dart';

/// Physical wall thickness in world units. Level generation and simulation
/// both use this so breakable sections line up exactly with maze geometry.
const double kWallThickness = 0.14;

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
    required this.flowPanels,
    required this.breakables,
    required this.conveyors,
    required this.sliders,
    required this.magnets,
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
  final int flowPanels;
  final int breakables;
  final int conveyors;
  final int sliders;
  final int magnets;
  final bool blackout;
  final int parMs;

  String get number => '${id + 1}'.padLeft(2, '0');

  String get chapterName => 'Chapter ${chapter + 1}';

  String get mechanicIcon {
    if (blackout) return 'blackout';
    if (magnets > 0) return 'magnet';
    if (sliders > 0) return 'slider';
    if (conveyors > 0) return 'conveyor';
    if (breakables > 0) return 'fracture';
    if (flowPanels > 0) return 'flow';
    if (portalPairs > 0) return 'portal';
    if (gates > 0) return 'gate';
    if (iceZones > 0 || tarZones > 0) return 'surface';
    if (orbs > 0) return 'orb';
    return 'hole';
  }

  List<String> get mechanics {
    final out = <String>[];
    if (holes > 0) out.add('Holes');
    if (orbs > 0) out.add('Orbs');
    if (iceZones > 0) out.add('Ice');
    if (tarZones > 0) out.add('Tar');
    if (gates > 0) out.add('Gates');
    if (portalPairs > 0) out.add('Portals');
    if (flowPanels > 0) out.add('Flow');
    if (conveyors > 0) out.add('Conveyors');
    if (sliders > 0) out.add('Sliders');
    if (magnets > 0) out.add('Magnets');
    if (breakables > 0) out.add('Breakable');
    if (bumpers > 0) out.add('Bumpers');
    if (blackout) out.add('Blackout');
    return out;
  }

  /// A rough 1–10 read on a level's density. Route length, hazard count and
  /// mechanic layering all contribute, so a bigger grid is not automatically
  /// harder than a tightly packed small one.
  int get difficulty {
    var score = 1;
    score += max(0, (cols * rows - 25) ~/ 18);
    score += holes ~/ 2;
    if (orbs > 0) score += 1;
    score += gates + portalPairs + flowPanels + breakables + sliders;
    score += conveyors + magnets;
    if (bumpers > 1) score += 1;
    if (iceZones > 0) score += 1;
    if (blackout) score += 2;
    return score.clamp(1, 10);
  }

  int starsFor(int timeMs) {
    if (timeMs <= parMs) return 3;
    if (timeMs <= (parMs * 1.55).round()) return 2;
    return 1;
  }
}

class LevelCatalog {
  const LevelCatalog._();

  static const int chapterCount = 8;
  static const int levelsPerChapter = 10;
  static const int total = chapterCount * levelsPerChapter;

  static List<LevelSpec>? _cache;

  static List<LevelSpec> get all => _cache ??= _build();

  static LevelSpec byId(int id) => all[id.clamp(0, total - 1)];

  static List<LevelSpec> chapter(int index) =>
      all.where((l) => l.chapter == index).toList();

  /// Minimum route length the generator aims for. A level is allowed to be
  /// longer than this, but never accept a short braid-created sprint.
  static int targetPathLengthFor(int cols, int rows, int chapter, int indexInChapter) {
    final cells = cols * rows;
    final ramp = 6 + chapter * 2 + (indexInChapter * 0.4).round();
    return max(18, (cells * 0.42).round() + ramp);
  }

  static int targetPathLength(LevelSpec spec) => targetPathLengthFor(
        spec.cols,
        spec.rows,
        spec.chapter,
        spec.indexInChapter,
      );

  static List<LevelSpec> _build() {
    final levels = <LevelSpec>[];

    // Bigger boards are the point now: early levels stay readable, late
    // chapters grow into genuinely large labyrinths with long routes.
    const baseCols = [5, 7, 8, 10, 12, 13, 15, 16];
    const growth = [2, 3, 4, 4, 5, 6, 6, 8];

    for (var c = 0; c < chapterCount; c++) {
      for (var i = 0; i < levelsPerChapter; i++) {
        final t = i / (levelsPerChapter - 1);
        final cols = (baseCols[c] + (t * growth[c]).round()).clamp(5, 24);
        final rows = (cols + (c >= 4 ? 2 : 0) + (i.isEven ? 0 : 1)).clamp(5, 27);

        // Teaching cadence: introduce a mechanic, repeat it, then layer the
        // next one on top. Late chapters combine the whole vocabulary.
        final orbs = switch (c) {
          0 => 0,
          1 => 2 + i ~/ 3,
          2 || 3 => 3 + i ~/ 4,
          4 || 5 => 4 + i ~/ 4,
          _ => 5 + i ~/ 4,
        };
        final holes = switch (c) {
          0 => 2 + i ~/ 3,
          1 => 3 + i ~/ 3,
          2 => 4 + i ~/ 4,
          _ => 5 + i ~/ 4,
        };
        // Surface-speed zones are out: they made the marble feel vague without
        // adding a clear decision. The catalog now uses visible forces (belts,
        // bumpers, magnets) instead.
        final ice = 0;
        final tar = 0;
        final gates = switch (c) {
          3 => 2 + i ~/ 3,
          4 => 2 + i ~/ 5,
          6 => 2 + i ~/ 5,
          7 => 2 + i ~/ 5,
          _ => 0,
        };
        final portals = c == 4 ? (i >= 6 ? 2 : 1) : (c == 7 ? 1 : 0);
        final flow = c == 5 ? 1 + i ~/ 3 : (c == 7 ? 1 : 0);
        final breakables = c == 6 ? 1 + i ~/ 3 : (c == 7 ? 1 : 0);
        final bumpers = c == 2
            ? 2 + i ~/ 5
            : (c == 5
                ? 2 + i ~/ 4
                : (c == 6 ? 2 + i ~/ 6 : (c == 7 ? 3 : 0)));
        final conveyors = c == 2
            ? 2 + i ~/ 5
            : (c == 5
                ? 2 + i ~/ 4
                : (c == 6 ? 2 + i ~/ 5 : (c == 7 ? 2 + i ~/ 4 : 0)));
        final sliders = c == 6 ? 2 + i ~/ 4 : (c == 7 ? 3 : 0);
        final magnets = c == 7 ? 2 + i ~/ 4 : 0;
        final blackout = c == 7 && i >= 2;
        final braid = switch (c) {
          0 => i < 3 ? 0 : 1,
          1 => 1,
          2 => 1 + i ~/ 5,
          3 => 2,
          4 => 2 + i ~/ 5,
          5 => 2,
          6 => 3,
          _ => 3,
        };

        // Par is based on the route the generator is aiming for, not the raw
        // cell count, so longer mazes actually get the time they need.
        final targetPath = targetPathLengthFor(cols, rows, c, i);
        final parSeconds = 5.5 +
            targetPath * 0.40 +
            orbs * 1.0 +
            holes * 0.10 +
            gates * 1.3 +
            portals * 1.0 +
            flow * 0.8 +
            conveyors * 0.7 +
            sliders * 1.1 +
            magnets * 0.8 +
            breakables * 0.9 +
            ice * 0.6 +
            tar * 0.5 +
            (blackout ? 3.5 : 0) +
            c * 0.35;

        levels.add(LevelSpec(
          id: levels.length,
          chapter: c,
          indexInChapter: i,
          cols: cols,
          rows: rows,
          seed: 9001 + c * 977 + i * 131 + cols * 17 + rows * 7,
          braid: braid,
          holes: holes,
          orbs: orbs,
          iceZones: ice,
          tarZones: tar,
          gates: gates,
          portalPairs: portals,
          bumpers: bumpers,
          flowPanels: flow,
          breakables: breakables,
          conveyors: conveyors,
          sliders: sliders,
          magnets: magnets,
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
  bool isActive(double time) => solidity(time) > 0.5;

  double openness(double time) => (sin(time * speed + phase) + 1) / 2;

  /// 0 = fully powered down, 1 = fully solid. The transition is smooth so the
  /// barrier grows and shrinks instead of snapping on and off.
  double solidity(double time) => ((openness(time) - 0.28) / 0.44).clamp(0.0, 1.0);

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

  /// Collision rect scaled by [solidity], so the gap opens progressively.
  Rect collisionRectAt(double time) {
    final full = rectAt(time);
    final s = solidity(time);
    return Rect.fromCenter(
      center: full.center,
      width: max(0.01, full.width * s),
      height: max(0.01, full.height * s),
    );
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

/// A one-way membrane across a corridor. The marble can travel in
/// [direction] but is blocked when it tries to enter against the arrows.
class FlowPanel {
  const FlowPanel({required this.rect, required this.direction});

  final Rect rect;

  /// Unit vector of the allowed direction of travel.
  final Offset direction;
}

/// A wall segment that opens into a shortcut after a hard enough impact.
class BreakableWall {
  BreakableWall({required this.rect, required this.from, required this.to});

  final Rect rect;
  final Cell from;
  final Cell to;
  bool broken = false;
}

/// A floor belt that adds a constant force in [direction]. The marble can ride
/// it or fight it, which changes the line through a corridor.
class Conveyor {
  const Conveyor({
    required this.rect,
    required this.direction,
    this.strength = 7.0,
  });

  final Rect rect;
  final Offset direction;
  final double strength;
}

/// A short moving wall with a gap. It slides across a corridor, so the player
/// has to time the open side instead of simply waiting for it to disappear.
class Slider {
  const Slider({
    required this.base,
    required this.slidesVertically,
    required this.amplitude,
    required this.speed,
    required this.phase,
    this.halfLong = 0.22,
    this.halfThin = 0.095,
  });

  final Offset base;
  final bool slidesVertically;
  final double amplitude;
  final double speed;
  final double phase;
  final double halfLong;
  final double halfThin;

  Offset centerAt(double time) {
    final sway = sin(time * speed + phase) * amplitude;
    return base + (slidesVertically ? Offset(0, sway) : Offset(sway, 0));
  }

  Rect rectAt(double time) {
    final c = centerAt(time);
    return slidesVertically
        ? Rect.fromCenter(center: c, width: halfThin * 2, height: halfLong * 2)
        : Rect.fromCenter(center: c, width: halfLong * 2, height: halfThin * 2);
  }
}

/// A radial force field. Attractors pull the marble in; repulsors shove it out.
class Magnet {
  const Magnet({
    required this.center,
    required this.radius,
    required this.strength,
    required this.attract,
  });

  final Offset center;
  final double radius;
  final double strength;
  final bool attract;
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
    required this.flowPanels,
    required this.breakables,
    required this.conveyors,
    required this.sliders,
    required this.magnets,
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
  final List<FlowPanel> flowPanels;
  final List<BreakableWall> breakables;
  final List<Conveyor> conveyors;
  final List<Slider> sliders;
  final List<Magnet> magnets;
  final Offset start;
  final Offset exit;

  int get orbCount => orbs.length;

  /// True when [box] is one of the breakable wall sections. Those sections are
  /// removed from the static wall set and simulated separately.
  bool isBreakableBox(Rect box) {
    for (final b in breakables) {
      final sameCenter = (b.rect.center - box.center).distance < 1e-6;
      final sameAxis = (b.rect.width > b.rect.height) == (box.width > box.height);
      if (sameCenter && sameAxis) return true;
    }
    return false;
  }

  static LevelRuntime build(LevelSpec spec) {
    final target = LevelCatalog.targetPathLength(spec);
    var maze = Maze.generate(
      cols: spec.cols,
      rows: spec.rows,
      seed: spec.seed,
      braid: spec.braid,
    );
    var bestLength = maze.solution.length;
    // Search a handful of deterministic seeds for a route that meets the
    // level's length target. A braided maze can otherwise collapse into a very
    // short sprint even on a large board.
    for (var attempt = 1; attempt < 24 && bestLength < target; attempt++) {
      final candidate = Maze.generate(
        cols: spec.cols,
        rows: spec.rows,
        seed: spec.seed + attempt * 7919,
        braid: spec.braid,
      );
      final length = candidate.solution.length;
      if (length > bestLength) {
        maze = candidate;
        bestLength = length;
      }
    }
    final rnd = Random(maze.seed ^ 0x5f3759df);
    final solution = maze.solution;
    final pathSet = {for (final c in solution) maze.indexOf(c.x, c.y)};

    final start = maze.startCenter;
    final exit = maze.goalCenter;

    // Holes are placed first so orbs can be routed around them.
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

    bool clearPathToSolution(Cell from) {
      final startIndex = maze.indexOf(from.x, from.y);
      final queue = <int>[startIndex];
      final seen = <int>{startIndex};
      var head = 0;
      while (head < queue.length) {
        final idx = queue[head++];
        if (pathSet.contains(idx)) return true;
        final x = idx % spec.cols;
        final y = idx ~/ spec.cols;
        for (final d in Dir.values) {
          if (maze.hasWall(x, y, d)) continue;
          final n = maze.neighbor(x, y, d);
          if (n == null) continue;
          final ni = maze.indexOf(n.x, n.y);
          if (holeCells.contains(ni)) continue;
          if (seen.add(ni)) queue.add(ni);
        }
      }
      return false;
    }

    // Orbs: most sit on the main path, while later chapters place a few in
    // side branches so "collect all" becomes a routing decision instead of a
    // straight sprint.
    final orbs = <Orb>[];
    final usedOrbCells = <int>{};
    final mainOrbCount = spec.chapter >= 2 && spec.orbs >= 3
        ? spec.orbs - max(1, (spec.orbs * 0.4).floor())
        : spec.orbs;

    if (mainOrbCount > 0 && solution.length > 2) {
      final usable = solution.length - 2;
      final count = min(mainOrbCount, usable);
      for (var k = 1; k <= count; k++) {
        var idx = (k * (usable + 1) / (count + 1)).round();
        idx = idx.clamp(1, solution.length - 2);
        while (usedOrbCells.contains(maze.indexOf(solution[idx].x, solution[idx].y)) &&
            idx < solution.length - 2) {
          idx++;
        }
        usedOrbCells.add(maze.indexOf(solution[idx].x, solution[idx].y));
        orbs.add(Orb(solution[idx].center, 0.13));
      }
    }

    final branchTarget = spec.orbs - orbs.length;
    if (branchTarget > 0) {
      final branchCandidates = <Cell>[];
      for (var y = 0; y < spec.rows; y++) {
        for (var x = 0; x < spec.cols; x++) {
          final idx = maze.indexOf(x, y);
          if (pathSet.contains(idx)) continue;
          if (holeCells.contains(idx)) continue;
          if (usedOrbCells.contains(idx)) continue;
          if (idx == maze.indexOf(maze.start.x, maze.start.y)) continue;
          if (idx == maze.indexOf(maze.goal.x, maze.goal.y)) continue;
          if (!clearPathToSolution(Cell(x, y))) continue;
          branchCandidates.add(Cell(x, y));
        }
      }
      branchCandidates.shuffle(rnd);
      for (final cell in branchCandidates) {
        if (orbs.length >= spec.orbs) break;
        final idx = maze.indexOf(cell.x, cell.y);
        if (!usedOrbCells.add(idx)) continue;
        orbs.add(Orb(cell.center, 0.13));
      }
    }
    final orbCells = {for (final o in orbs) maze.indexOf(o.center.dx.floor(), o.center.dy.floor())};

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
      if (orbCells.contains(maze.indexOf(cell.x, cell.y))) continue;
      gateCells.add(cell);
      gates.add(Gate(
        base: cell.center,
        spansVertically: horizontal,
        amplitude: 0.10,
        // Faster sweep: the powered-down window is shorter, so the player has
        // to read the cycle instead of strolling through.
        speed: 1.95 + rnd.nextDouble() * 0.50,
        phase: rnd.nextDouble() * pi * 2,
      ));
    }

    // One-way flow panels: always aligned with the solution direction, so the
    // intended route remains possible while the reverse path is blocked.
    final flowPanels = <FlowPanel>[];
    final flowCells = <Cell>[];
    for (var i = 2; i < solution.length - 4; i++) {
      if (flowPanels.length >= spec.flowPanels) break;
      final cell = solution[i];
      final idx = maze.indexOf(cell.x, cell.y);
      if (holeCells.contains(idx) || orbCells.contains(idx)) continue;
      if (gateCells.contains(cell)) continue;
      final open = <Dir>[
        for (final d in Dir.values)
          if (!maze.hasWall(cell.x, cell.y, d)) d,
      ];
      if (open.length != 2) continue;
      final horizontal = open.contains(Dir.east) && open.contains(Dir.west);
      final vertical = open.contains(Dir.north) && open.contains(Dir.south);
      if (!horizontal && !vertical) continue;
      if (flowCells.any((c) => (c.center - cell.center).distance < 1.8)) continue;

      final travel = solution[i + 1].center - solution[i - 1].center;
      final direction = travel.distance < 1e-6
          ? (horizontal ? const Offset(1, 0) : const Offset(0, 1))
          : travel / travel.distance;
      flowCells.add(cell);
      flowPanels.add(FlowPanel(
        rect: horizontal
            ? Rect.fromCenter(center: cell.center, width: 0.10, height: 0.82)
            : Rect.fromCenter(center: cell.center, width: 0.82, height: 0.10),
        direction: direction,
      ));
    }

    // Conveyor belts: place on straight solution cells and point them along
    // the intended route, so they can be ridden for speed or fought for control.
    final conveyors = <Conveyor>[];
    final conveyorCells = <Cell>[];
    for (var i = 2; i < solution.length - 4; i++) {
      if (conveyors.length >= spec.conveyors) break;
      final cell = solution[i];
      final idx = maze.indexOf(cell.x, cell.y);
      if (holeCells.contains(idx) || orbCells.contains(idx)) continue;
      if (gateCells.contains(cell) || flowCells.contains(cell)) continue;
      final open = <Dir>[
        for (final d in Dir.values)
          if (!maze.hasWall(cell.x, cell.y, d)) d,
      ];
      if (open.length != 2) continue;
      final horizontal = open.contains(Dir.east) && open.contains(Dir.west);
      final vertical = open.contains(Dir.north) && open.contains(Dir.south);
      if (!horizontal && !vertical) continue;
      if (conveyorCells.any((c) => (c.center - cell.center).distance < 1.6)) continue;

      final travel = solution[i + 1].center - solution[i - 1].center;
      final direction = travel.distance < 1e-6
          ? (horizontal ? const Offset(1, 0) : const Offset(0, 1))
          : travel / travel.distance;
      conveyorCells.add(cell);
      conveyors.add(Conveyor(
        rect: Rect.fromCenter(center: cell.center, width: 0.98, height: 0.98),
        direction: direction,
        strength: 9.0 + rnd.nextDouble() * 2.0,
      ));
    }

    // Sliding walls: a short bar with a gap that sweeps across a corridor.
    final sliders = <Slider>[];
    final sliderCells = <Cell>[];
    for (var i = 2; i < solution.length - 4; i++) {
      if (sliders.length >= spec.sliders) break;
      final cell = solution[i];
      final idx = maze.indexOf(cell.x, cell.y);
      if (holeCells.contains(idx) || orbCells.contains(idx)) continue;
      if (gateCells.contains(cell) || flowCells.contains(cell)) continue;
      if (conveyorCells.contains(cell)) continue;
      final open = <Dir>[
        for (final d in Dir.values)
          if (!maze.hasWall(cell.x, cell.y, d)) d,
      ];
      if (open.length != 2) continue;
      final horizontal = open.contains(Dir.east) && open.contains(Dir.west);
      final vertical = open.contains(Dir.north) && open.contains(Dir.south);
      if (!horizontal && !vertical) continue;
      if (sliderCells.any((c) => (c.center - cell.center).distance < 1.8)) continue;

      sliderCells.add(cell);
      sliders.add(Slider(
        base: cell.center,
        // Horizontal corridor -> vertical bar that slides up/down.
        slidesVertically: horizontal,
        // A longer sweep and a faster bar leave a smaller gap to time.
        amplitude: 0.30,
        speed: 1.65 + rnd.nextDouble() * 0.50,
        phase: rnd.nextDouble() * pi * 2,
      ));
    }

    // Breakable walls sit on an existing wall between two cells that are far
    // apart along the solution. Smashing one opens a real shortcut. Levels
    // without such an edge fall back to any wall beside the route, so every
    // FRACTURE level teaches the mechanic.
    final breakables = <BreakableWall>[];
    final shortcutCandidates = <(Cell, Cell, Dir)>[];
    for (var i = 0; i < solution.length; i++) {
      for (var j = i + 4; j < solution.length; j++) {
        final a = solution[i];
        final b = solution[j];
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        if (dx.abs() + dy.abs() != 1) continue;
        final d = dx == 1
            ? Dir.east
            : dx == -1
                ? Dir.west
                : dy == 1
                    ? Dir.south
                    : Dir.north;
        if (!maze.hasWall(a.x, a.y, d)) continue;
        shortcutCandidates.add((a, b, d));
      }
    }
    shortcutCandidates.shuffle(rnd);

    final fallbackCandidates = <(Cell, Cell, Dir)>[];
    for (var y = 0; y < spec.rows; y++) {
      for (var x = 0; x < spec.cols; x++) {
        if (!pathSet.contains(maze.indexOf(x, y))) continue;
        for (final d in Dir.values) {
          final n = maze.neighbor(x, y, d);
          if (n == null || !maze.hasWall(x, y, d)) continue;
          fallbackCandidates.add((Cell(x, y), n, d));
        }
      }
    }
    fallbackCandidates.shuffle(rnd);

    bool tryPlace((Cell, Cell, Dir) edge, {required bool strict}) {
      final (a, b, d) = edge;
      final box = maze.wallBoxAt(a.x, a.y, d, kWallThickness);
      if (box == null) return false;
      final c = box.center;
      if (strict) {
        if ((c - start).distance < 1.2 || (c - exit).distance < 1.2) return false;
        if (gates.any((g) => (g.base - c).distance < 1.2)) return false;
        if (flowPanels.any((p) => (p.rect.center - c).distance < 1.2)) return false;
      }
      if (breakables.any((w) => (w.rect.center - c).distance < 1.2)) return false;
      breakables.add(BreakableWall(rect: box, from: a, to: b));
      return true;
    }

    for (final edge in shortcutCandidates) {
      if (breakables.length >= spec.breakables) break;
      tryPlace(edge, strict: true);
    }
    for (final edge in fallbackCandidates) {
      if (breakables.length >= spec.breakables) break;
      tryPlace(edge, strict: true);
    }
    // Last resort: relax the geometry checks rather than ship a FRACTURE
    // level with no breakable wall at all.
    for (final edge in [...shortcutCandidates, ...fallbackCandidates]) {
      if (breakables.length >= spec.breakables) break;
      tryPlace(edge, strict: false);
    }
    // Portals pair off-path cells that are far apart. With branch orbs they
    // become useful route tools, not just set dressing.
    final portals = <PortalPair>[];
    final portalCandidates = holeCandidates
        .where((c) => !holeCells.contains(maze.indexOf(c.x, c.y)))
        .where((c) => !orbCells.contains(maze.indexOf(c.x, c.y)))
        .where((c) => !breakables.any((w) => (w.rect.center - c.center).distance < 1.2))
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
        .where((c) => !orbCells.contains(maze.indexOf(c.x, c.y)))
        .where((c) => !portals.any((p) => (p.a - c.center).distance < 1.2 || (p.b - c.center).distance < 1.2))
        .where((c) => !breakables.any((w) => (w.rect.center - c.center).distance < 1.2))
        .toList()
      ..shuffle(rnd);
    for (final cell in bumperCandidates.take(spec.bumpers)) {
      // A small post the marble can actually get past: a post wider than the
      // corridor is a wall, not a bumper.
      bumpers.add(Bumper(cell.center, 0.13));
    }

    // Magnets sit on the route so their pull or push changes the line through
    // a corridor; the strength is deliberately low enough to fight with tilt.
    final magnets = <Magnet>[];
    final magnetCells = <Cell>[];
    for (var i = 3; i < solution.length - 4; i++) {
      if (magnets.length >= spec.magnets) break;
      final cell = solution[i];
      final idx = maze.indexOf(cell.x, cell.y);
      if (holeCells.contains(idx) || orbCells.contains(idx)) continue;
      if (gateCells.contains(cell) ||
          flowCells.contains(cell) ||
          conveyorCells.contains(cell) ||
          sliderCells.contains(cell)) {
        continue;
      }
      if (magnetCells.any((c) => (c.center - cell.center).distance < 2.2)) continue;
      magnetCells.add(cell);
      magnets.add(Magnet(
        center: cell.center,
        radius: 1.15,
        strength: 6.2 + rnd.nextDouble() * 1.8,
        attract: rnd.nextBool(),
      ));
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
      flowPanels: flowPanels,
      breakables: breakables,
      conveyors: conveyors,
      sliders: sliders,
      magnets: magnets,
      start: start,
      exit: exit,
    );
  }
}
