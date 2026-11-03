import 'dart:math';

import 'package:flutter/painting.dart';

import 'maze.dart';
import 'powerups.dart';

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
    required this.powerUps,
    required this.act,
    required this.parMs,
    this.code,
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
  final int powerUps;

  /// The 20-level act inside the chapter (0–4). Acts are the real difficulty
  /// ramp; the raw grid stops growing once a cell would get too small to read.
  final int act;
  final int parMs;

  /// Optional label override used by the daily challenge.
  final String? code;

  String get number => code ?? '${id + 1}'.padLeft(2, '0');

  bool get isMilestone => indexInChapter % 10 == 9;

  bool get isActBoss => indexInChapter % 20 == 19;

  bool get isChapterBoss => indexInChapter == 99;

  String get actName => switch (act) {
    0 => 'OPENING',
    1 => 'ASCENT',
    2 => 'PRESSURE',
    3 => 'ELITE',
    _ => 'FINALE',
  };

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
    if (powerUps > 0) out.add('Powers');
    return out;
  }

  /// A rough 1–10 read on a level's density. Route length, hazard count and
  /// mechanic layering all contribute, so a bigger grid is not automatically
  /// harder than a tightly packed small one.
  int get difficulty {
    var score = 1;
    score += act;
    score += max(0, (cols * rows - 35) ~/ 45);
    score += holes ~/ 3;
    if (orbs > 0) score += 1;
    score += (gates + portalPairs + flowPanels + breakables + sliders) ~/ 2;
    score += (conveyors + magnets) ~/ 2;
    if (bumpers > 1) score += 1;
    if (blackout) score += 1;
    if (isMilestone) score += 1;
    if (isChapterBoss) score += 1;
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
  static const int levelsPerChapter = 100;
  static const int total = chapterCount * levelsPerChapter;

  static List<LevelSpec>? _cache;
  static final Map<int, List<LevelSpec>> _chapterCache = {};

  static List<LevelSpec> get all => _cache ??= _build();

  static LevelSpec byId(int id) => all[id.clamp(0, total - 1)];

  static List<LevelSpec> chapter(int index) =>
      _chapterCache[index] ??= all.where((l) => l.chapter == index).toList();

  static int _lerpInt(int a, int b, double t) => (a + (b - a) * t).round();

  /// Minimum route length the generator aims for. A level is allowed to be
  /// longer than this, but never accept a short braid-created sprint.
  ///
  /// Route length grows through the 20-level acts; the physical board stops
  /// growing once cells would become too small to read on a phone.
  static int targetPathLengthFor(
    int cols,
    int rows,
    int chapter,
    int indexInChapter,
  ) {
    final act = (indexInChapter ~/ 20).clamp(0, 4);
    final cells = cols * rows;
    final ramp = 7.0 + chapter * 2.0 + act * 3.0;
    return max(22, (cells * 0.54).round() + ramp.round());
  }

  static int targetPathLength(LevelSpec spec) => targetPathLengthFor(
    spec.cols,
    spec.rows,
    spec.chapter,
    spec.indexInChapter,
  );

  static List<LevelSpec> _build() {
    final levels = <LevelSpec>[];

    // Deliberately capped sizes. The old late-game boards reached 23×25,
    // which drew a ~16 px cell on a phone and read as visual noise. Difficulty
    // now comes from longer routes, more acts, tighter par and better-placed
    // hazards instead of shrinking the cell.
    const baseCols = [5, 6, 7, 8, 9, 9, 10, 10];
    const maxCols = [7, 8, 9, 10, 11, 11, 12, 13];
    const baseRows = [6, 7, 8, 9, 10, 11, 11, 12];
    const maxRows = [8, 10, 11, 12, 13, 14, 15, 17];

    for (var c = 0; c < chapterCount; c++) {
      for (var i = 0; i < levelsPerChapter; i++) {
        // Five acts of twenty levels. The grid ramps across the act, then the
        // next act starts a little larger and denser.
        final act = (i ~/ 20).clamp(0, 4);
        final withinAct = (i % 20) / 19.0;
        final p = (act + withinAct) / 5.0;
        final elite = i % 10 == 9 ? 1 : 0;

        var cols = _lerpInt(baseCols[c], maxCols[c], p);
        var rows = _lerpInt(baseRows[c], maxRows[c], p);
        // Small deterministic silhouette changes keep consecutive acts from
        // looking like the same board at a new scale.
        if (i % 5 == 2 && rows < maxRows[c]) rows += 1;
        if (i % 7 == 4 && cols < maxCols[c]) cols += 1;
        if (i == 99) {
          // One chapter-finale board may break the cap, but never enough to
          // make the cell unreadable.
          cols = min(maxCols[c] + 1, 14);
          rows = min(maxRows[c] + 1, 18);
        }

        // Teaching cadence: introduce a mechanic, repeat it through an act,
        // then layer the next idea on top. Counts scale by act, not by the raw
        // 100-level index, so level 90 is not wallpaper.
        final orbs = switch (c) {
          0 => i < 24 ? 0 : 2 + (i - 24) ~/ 20,
          1 => 3 + act,
          _ => min(12, 4 + c ~/ 3 + act + elite),
        };
        final holes = min(20, 3 + c + act * 2 + elite);

        // Surface-speed zones are a deliberate late-game tax on detours: tar
        // only appears away from the main route, so it lengthens the required
        // orb hunt instead of making the whole board feel sluggish.
        const ice = 0;
        final tar = switch (c) {
          5 => act >= 2 ? 1 : 0,
          6 => 1 + act ~/ 2,
          7 => 2 + act ~/ 2,
          _ => 0,
        };

        final gates = switch (c) {
          3 => 2 + act,
          4 || 6 || 7 => 1 + act,
          5 => act >= 2 ? 1 + act ~/ 2 : 0,
          _ => 0,
        };
        final portals = switch (c) {
          4 => 1 + (act >= 2 ? 1 : 0) + (act >= 4 ? 1 : 0),
          5 => act >= 3 ? 1 : 0,
          7 => 2,
          _ => 0,
        };
        final flow = switch (c) {
          5 => 1 + act ~/ 2,
          7 => 2,
          _ => 0,
        };
        final breakables = switch (c) {
          6 => 1 + act ~/ 2,
          7 => 2,
          _ => 0,
        };
        final bumpers = switch (c) {
          0 => i >= 55 ? 1 + elite : 0,
          1 => i >= 75 ? 1 : 0,
          2 => 2 + act,
          5 || 6 => 2 + act ~/ 2,
          7 => 3,
          _ => 0,
        };
        final conveyors = switch (c) {
          1 => i >= 65 ? 1 : 0,
          2 => 2 + act,
          5 || 6 => 2 + act ~/ 2,
          7 => 3,
          _ => 0,
        };
        final sliders = switch (c) {
          5 => act >= 3 ? 1 : 0,
          6 => 1 + act,
          7 => 3,
          _ => 0,
        };
        final magnets = switch (c) {
          6 => 1 + act ~/ 2,
          7 => 3 + act ~/ 2,
          _ => 0,
        };
        // Blackout is a spice, not the whole second half of a 100-level
        // chapter: it appears on milestone boards and the final stretch.
        final blackout = c == 7 && ((i >= 30 && i % 4 == 0) || i >= 88);

        final braid = c == 0
            ? (i < 4 ? 0 : 1)
            : min(3, 1 + act ~/ 2 + c ~/ 4 + elite);

        final powerUps = switch (c) {
          0 => i >= 18 ? 1 + (i >= 55 ? 1 : 0) : 0,
          1 => 1 + act ~/ 2,
          _ => min(6, 2 + act + elite),
        };

        // Par is based on the route the generator is aiming for, not the raw
        // cell count, so longer mazes actually get the time they need. Elite
        // boards get a slightly tighter target to keep three stars meaningful.
        final targetPath = targetPathLengthFor(cols, rows, c, i);
        final parSeconds =
            6.0 +
            targetPath * 0.38 +
            orbs * 1.25 +
            holes * 0.10 +
            gates * 1.7 +
            portals * 1.1 +
            flow * 0.9 +
            conveyors * 1.0 +
            sliders * 1.7 +
            magnets * 0.9 +
            breakables * 1.1 +
            tar * 1.3 +
            (blackout ? 4.0 : 0) +
            c * 0.35 +
            act * 0.55;

        levels.add(
          LevelSpec(
            id: levels.length,
            chapter: c,
            indexInChapter: i,
            cols: cols,
            rows: rows,
            seed: 10007 + c * 1013 + i * 137 + cols * 17 + rows * 7,
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
            powerUps: powerUps,
            act: act,
            parMs: (parSeconds * 1000 * (elite == 1 ? 0.94 : 1.0)).round(),
          ),
        );
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
    this.halfLong = 0.42,
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
  double solidity(double time) =>
      ((openness(time) - 0.22) / 0.44).clamp(0.0, 1.0);

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

  Offset partnerOf(Offset point) =>
      (point - a).distance < (point - b).distance ? b : a;
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
    this.halfLong = 0.19,
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
    required this.powerUps,
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
  final List<PowerUpPickup> powerUps;
  final Offset start;
  final Offset exit;

  int get orbCount => orbs.length;

  /// True when [box] is one of the breakable wall sections. Those sections are
  /// removed from the static wall set and simulated separately.
  bool isBreakableBox(Rect box) {
    for (final b in breakables) {
      final sameCenter = (b.rect.center - box.center).distance < 1e-6;
      final sameAxis =
          (b.rect.width > b.rect.height) == (box.width > box.height);
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
    for (var attempt = 1; attempt < 32 && bestLength < target; attempt++) {
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

    int openCount(Cell c) {
      var n = 0;
      for (final d in Dir.values) {
        if (!maze.hasWall(c.x, c.y, d)) n++;
      }
      return n;
    }

    bool touchesRoute(Cell c) {
      for (final d in Dir.values) {
        final n = maze.neighbor(c.x, c.y, d);
        if (n != null && pathSet.contains(maze.indexOf(n.x, n.y))) return true;
      }
      return false;
    }

    // Multi-source BFS from the solution gives every cell's distance to the
    // main route. This is the single cheapest proxy for "is this detour worth
    // taking?" and is reused for holes, branch orbs and power-up placement.
    final routeDistance = List<int>.filled(maze.cellCount, -1);
    final routeQueue = <int>[];
    for (final c in solution) {
      final idx = maze.indexOf(c.x, c.y);
      routeDistance[idx] = 0;
      routeQueue.add(idx);
    }
    for (var head = 0; head < routeQueue.length; head++) {
      final idx = routeQueue[head];
      final x = idx % spec.cols;
      final y = idx ~/ spec.cols;
      for (final d in Dir.values) {
        if (maze.hasWall(x, y, d)) continue;
        final n = maze.neighbor(x, y, d);
        if (n == null) continue;
        final ni = maze.indexOf(n.x, n.y);
        if (routeDistance[ni] != -1) continue;
        routeDistance[ni] = routeDistance[idx] + 1;
        routeQueue.add(ni);
      }
    }

    // Holes are placed first so orbs can be routed around them. They never sit
    // on the route (that would make the level impossible), but a hole buried
    // at the end of a long dead end is decoration. Score cells by how close
    // they sit to a route decision, so a bad line ends the run in view.
    final holeCandidates = <Cell>[];
    for (var y = 0; y < spec.rows; y++) {
      for (var x = 0; x < spec.cols; x++) {
        final idx = maze.indexOf(x, y);
        if (pathSet.contains(idx)) continue;
        if (idx == maze.indexOf(maze.start.x, maze.start.y)) continue;
        if (idx == maze.indexOf(maze.goal.x, maze.goal.y)) continue;
        // Keep the spawn and the exit approach readable without doing a BFS
        // per candidate.
        if (maze.distanceAt(Cell(x, y)) < 2) continue;
        if ((Cell(x, y).center - exit).distance < 2.4) continue;
        holeCandidates.add(Cell(x, y));
      }
    }

    var holeScore = 0;
    int scoreHole(Cell c) {
      holeScore = openCount(c) == 1 ? 3 : 0;
      for (final d in Dir.values) {
        final n = maze.neighbor(c.x, c.y, d);
        if (n == null) continue;
        final ni = maze.indexOf(n.x, n.y);
        if (pathSet.contains(ni)) {
          holeScore += 7;
          // A hole beside a junction catches the player exactly when they are
          // choosing a branch, which is stricter than a hole in plain corridor.
          if (openCount(n) >= 3) holeScore += 7;
          if ((n.center - exit).distance < 4) holeScore += 3;
          if ((n.center - start).distance < 3) holeScore -= 3;
        } else if (routeDistance[ni] == 1) {
          holeScore += 1;
        }
      }
      return holeScore;
    }

    final rankedHoles =
        [
          for (final cell in holeCandidates)
            (cell, scoreHole(cell), rnd.nextDouble()),
        ]..sort((a, b) {
          final byScore = b.$2.compareTo(a.$2);
          return byScore != 0 ? byScore : a.$3.compareTo(b.$3);
        });

    final holes = <Hole>[];
    for (final (cell, _, _) in rankedHoles) {
      if (holes.length >= spec.holes) break;
      // Never merge two pits into one unreadable mass: keep a full cell of
      // clear floor between holes.
      var tooClose = false;
      for (final other in holes) {
        final ox = other.center.dx.floor();
        final oy = other.center.dy.floor();
        if ((ox - cell.x).abs() + (oy - cell.y).abs() < 3) {
          tooClose = true;
          break;
        }
      }
      if (tooClose) continue;
      // Small jitter and a larger radius keep the pit inside its own cell while
      // making rim clips count.
      final jitter = Offset(
        (rnd.nextDouble() - 0.5) * 0.10,
        (rnd.nextDouble() - 0.5) * 0.10,
      );
      holes.add(Hole(cell.center + jitter, 0.29 + rnd.nextDouble() * 0.05));
    }
    final holeCells = {
      for (final h in holes)
        maze.indexOf(h.center.dx.floor(), h.center.dy.floor()),
    };

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
    final mainOrbCount = spec.chapter >= 1 && spec.orbs >= 3
        ? (spec.orbs * 0.55).round()
        : spec.orbs;

    if (mainOrbCount > 0 && solution.length > 2) {
      final usable = solution.length - 2;
      final count = min(mainOrbCount, usable);
      for (var k = 1; k <= count; k++) {
        var idx = (k * (usable + 1) / (count + 1)).round();
        idx = idx.clamp(1, solution.length - 2);
        while (usedOrbCells.contains(
              maze.indexOf(solution[idx].x, solution[idx].y),
            ) &&
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
      // Put branch orbs at the *end* of real detours. A one-cell pocket just
      // off the route is a free pickup; a deep branch is a time/risk decision.
      final rankedBranches =
          [
            for (final cell in branchCandidates)
              (
                cell,
                routeDistance[maze.indexOf(cell.x, cell.y)],
                openCount(cell) == 1 ? 2 : 0,
                rnd.nextDouble(),
              ),
          ]..sort((a, b) {
            final byDepth = b.$2.compareTo(a.$2);
            if (byDepth != 0) return byDepth;
            final byDeadEnd = b.$3.compareTo(a.$3);
            return byDeadEnd != 0 ? byDeadEnd : a.$4.compareTo(b.$4);
          });
      for (final (cell, _, _, _) in rankedBranches) {
        if (orbs.length >= spec.orbs) break;
        final idx = maze.indexOf(cell.x, cell.y);
        if (!usedOrbCells.add(idx)) continue;
        orbs.add(Orb(cell.center, 0.13));
      }
    }
    final orbCells = {
      for (final o in orbs)
        maze.indexOf(o.center.dx.floor(), o.center.dy.floor()),
    };

    // Ice stays out of the catalog: it made the marble feel vague. Tar is a
    // late-game detour tax only — it is never allowed on the solution, so the
    // required orb hunt takes longer without turning the main line to treacle.
    final zoneUsed = <int>{};
    final ice = <Zone>[];
    final tar = <Zone>[];
    if (spec.tarZones > 0) {
      final rankedTar = <(Cell, int, double)>[];
      for (var y = 0; y < spec.rows; y++) {
        for (var x = 0; x < spec.cols; x++) {
          final idx = maze.indexOf(x, y);
          if (pathSet.contains(idx)) continue;
          if (holeCells.contains(idx) || orbCells.contains(idx)) continue;
          final depth = routeDistance[idx];
          if (depth < 2) continue;
          final cell = Cell(x, y);
          if ((cell.center - start).distance < 2.0) continue;
          if ((cell.center - exit).distance < 2.0) continue;
          if (!clearPathToSolution(cell)) continue;
          rankedTar.add((cell, depth, rnd.nextDouble()));
        }
      }
      rankedTar.sort((a, b) {
        final byDepth = b.$2.compareTo(a.$2);
        return byDepth != 0 ? byDepth : a.$3.compareTo(b.$3);
      });
      for (final (cell, _, _) in rankedTar) {
        if (tar.length >= spec.tarZones) break;
        final idx = maze.indexOf(cell.x, cell.y);
        if (!zoneUsed.add(idx)) continue;
        tar.add(
          Zone(Rect.fromCenter(center: cell.center, width: 1.0, height: 1.0)),
        );
      }
      // Branch-heavy boards satisfy the depth rule easily; a cramped board may
      // not, so fall back to a one-cell detour rather than dropping the hazard.
      if (tar.length < spec.tarZones) {
        final fallback = <Cell>[
          for (var y = 0; y < spec.rows; y++)
            for (var x = 0; x < spec.cols; x++)
              if (!pathSet.contains(maze.indexOf(x, y)) &&
                  !holeCells.contains(maze.indexOf(x, y)) &&
                  !orbCells.contains(maze.indexOf(x, y)) &&
                  routeDistance[maze.indexOf(x, y)] >= 1)
                Cell(x, y),
        ]..shuffle(rnd);
        for (final cell in fallback) {
          if (tar.length >= spec.tarZones) break;
          final idx = maze.indexOf(cell.x, cell.y);
          if (!zoneUsed.add(idx)) continue;
          tar.add(
            Zone(Rect.fromCenter(center: cell.center, width: 1.0, height: 1.0)),
          );
        }
      }
    }

    // How critical is each point on the route? The score combines junctions,
    // side-branch entrances, proximity to the exit and the routes that branch
    // orbs force the player to walk. Hazards placed on high scores gate the
    // decisions that actually matter instead of decorating empty corridor.
    final solutionIndex = <int, int>{
      for (var i = 0; i < solution.length; i++)
        maze.indexOf(solution[i].x, solution[i].y): i,
    };

    // Straight-run and turn metadata. Strict obstacle positioning uses these:
    // a gate/slider needs a genuine corridor to close, a conveyor needs a long
    // run, and a bumper is most readable on the outside of a turn.
    bool sameLine(Cell a, Cell b) => a.x == b.x || a.y == b.y;
    final straightBefore = List<int>.filled(solution.length, 1);
    for (var i = 1; i < solution.length; i++) {
      if (sameLine(solution[i - 1], solution[i])) {
        straightBefore[i] = straightBefore[i - 1] + 1;
      }
    }
    final straightAfter = List<int>.filled(solution.length, 1);
    for (var i = solution.length - 2; i >= 0; i--) {
      if (sameLine(solution[i], solution[i + 1])) {
        straightAfter[i] = straightAfter[i + 1] + 1;
      }
    }
    final straightRun = <int>[
      for (var i = 0; i < solution.length; i++)
        straightBefore[i] + straightAfter[i] - 1,
    ];
    bool isTurnAt(int i) {
      if (i <= 0 || i >= solution.length - 1) return false;
      final ax = solution[i].x - solution[i - 1].x;
      final ay = solution[i].y - solution[i - 1].y;
      final bx = solution[i + 1].x - solution[i].x;
      final by = solution[i + 1].y - solution[i].y;
      return ax != bx || ay != by;
    }

    final routeCritical = List<double>.filled(solution.length, 0);
    for (var i = 0; i < solution.length; i++) {
      final cell = solution[i];
      var score = 0.0;
      if (openCount(cell) >= 3) score += 2.0;
      if (touchesRoute(cell)) score += 1.0;
      if (isTurnAt(i)) score += 1.0;
      if (straightRun[i] >= 4) score += 0.5;
      if (i > solution.length - 5) score += 1.5;
      if (i < 5) score -= 0.75;
      routeCritical[i] = score;
    }

    List<Cell>? pathToRoute(Cell from) {
      final startIdx = maze.indexOf(from.x, from.y);
      final parent = <int, int>{};
      final seen = <int>{startIdx};
      final queue = <int>[startIdx];
      for (var head = 0; head < queue.length; head++) {
        final idx = queue[head];
        if (pathSet.contains(idx) && idx != startIdx) {
          final path = <Cell>[];
          var cur = idx;
          while (true) {
            path.add(Cell(cur % spec.cols, cur ~/ spec.cols));
            final p = parent[cur];
            if (p == null) break;
            cur = p;
          }
          return path;
        }
        final x = idx % spec.cols;
        final y = idx ~/ spec.cols;
        for (final d in Dir.values) {
          if (maze.hasWall(x, y, d)) continue;
          final n = maze.neighbor(x, y, d);
          if (n == null) continue;
          final ni = maze.indexOf(n.x, n.y);
          if (!seen.add(ni)) continue;
          parent[ni] = idx;
          queue.add(ni);
        }
      }
      return null;
    }

    for (final orb in orbs) {
      final cell = Cell(orb.center.dx.floor(), orb.center.dy.floor());
      if (solutionIndex.containsKey(maze.indexOf(cell.x, cell.y))) continue;
      final path = pathToRoute(cell);
      if (path == null) continue;
      for (var k = 0; k < path.length; k++) {
        final idx = maze.indexOf(path[k].x, path[k].y);
        final routeIndex = solutionIndex[idx];
        if (routeIndex == null) continue;
        routeCritical[routeIndex] += k == path.length - 1 ? 3.0 : 1.0;
      }
    }

    final criticalOrder =
        [
          for (var i = 3; i < solution.length - 4; i++)
            if ((solution[i].center - start).distance >= 1.6 &&
                (solution[i].center - exit).distance >= 1.6)
              (i, solution[i], routeCritical[i], rnd.nextDouble()),
        ]..sort((a, b) {
          final byCritical = b.$3.compareTo(a.$3);
          return byCritical != 0 ? byCritical : a.$4.compareTo(b.$4);
        });

    // One cell, one interactive object. This is the anti-clutter rule: a gate
    // and a magnet can both be good ideas, just not on the same tile.
    final occupied = <int>{};
    int interactiveCount() => occupied.length;

    bool freeCell(Cell cell, {int spacing = 2}) {
      final idx = maze.indexOf(cell.x, cell.y);
      if (holeCells.contains(idx) || orbCells.contains(idx)) return false;
      for (final other in occupied) {
        final ox = other % spec.cols;
        final oy = other ~/ spec.cols;
        if ((ox - cell.x).abs() + (oy - cell.y).abs() < spacing) return false;
      }
      return true;
    }

    void reserve(Cell cell) => occupied.add(maze.indexOf(cell.x, cell.y));

    // Hazards are also capped by route length. Late boards are long, not
    // wallpapered; short early boards still get enough to teach the mechanic.
    final hazardBudget = max(
      6,
      min(40, solution.length ~/ 4 + 6 + spec.act * 2),
    );

    // Gates sit in straight corridor sections, never on the start or exit. The
    // first pass enforces generous spacing and a real corridor run; a relaxed
    // second pass only runs when a small board cannot satisfy the requested
    // count, so late boards stay readable and early boards stay consistent.
    final gates = <Gate>[];
    final gateCells = <Cell>[];
    void placeGates({required int spacing, required int minRun}) {
      for (final (i, cell, _, _) in criticalOrder) {
        if (gates.length >= spec.gates) return;
        if (interactiveCount() >= hazardBudget) return;
        if (straightRun[i] < minRun) continue;
        if (!freeCell(cell, spacing: spacing)) continue;
        final open = <Dir>[
          for (final d in Dir.values)
            if (!maze.hasWall(cell.x, cell.y, d)) d,
        ];
        if (open.length != 2) continue;
        final horizontal = open.contains(Dir.east) && open.contains(Dir.west);
        final vertical = open.contains(Dir.north) && open.contains(Dir.south);
        if (!horizontal && !vertical) continue;
        gateCells.add(cell);
        reserve(cell);
        gates.add(
          Gate(
            base: cell.center,
            spansVertically: horizontal,
            amplitude: 0.15,
            // Faster sweep: the powered-down window is shorter, so the player has
            // to read the cycle instead of strolling through.
            speed: 2.15 + rnd.nextDouble() * 0.55,
            phase: rnd.nextDouble() * pi * 2,
          ),
        );
      }
    }

    placeGates(spacing: 4, minRun: 3);
    if (gates.length < spec.gates) placeGates(spacing: 2, minRun: 2);

    // One-way flow panels: always aligned with the solution direction, so the
    // intended route remains possible while the reverse path is blocked. They
    // only go on a true straight, never on a corner where a diagonal direction
    // would not match the membrane rectangle.
    final flowPanels = <FlowPanel>[];
    final flowCells = <Cell>[];
    void placeFlow({required int spacing, required int minRun}) {
      for (final (i, cell, _, _) in criticalOrder) {
        if (flowPanels.length >= spec.flowPanels) return;
        if (interactiveCount() >= hazardBudget) return;
        if (straightRun[i] < minRun) continue;
        if (!freeCell(cell, spacing: spacing)) continue;
        final open = <Dir>[
          for (final d in Dir.values)
            if (!maze.hasWall(cell.x, cell.y, d)) d,
        ];
        if (open.length != 2) continue;
        final horizontal = open.contains(Dir.east) && open.contains(Dir.west);
        final vertical = open.contains(Dir.north) && open.contains(Dir.south);
        if (!horizontal && !vertical) continue;

        final travel = solution[i + 1].center - solution[i - 1].center;
        final aligned = horizontal
            ? travel.dy.abs() < 1e-6
            : travel.dx.abs() < 1e-6;
        if (!aligned || travel.distance < 1e-6) continue;
        final direction = travel / travel.distance;
        flowCells.add(cell);
        reserve(cell);
        flowPanels.add(
          FlowPanel(
            rect: horizontal
                ? Rect.fromCenter(
                    center: cell.center,
                    width: 0.10,
                    height: 0.82,
                  )
                : Rect.fromCenter(
                    center: cell.center,
                    width: 0.82,
                    height: 0.10,
                  ),
            direction: direction,
          ),
        );
      }
    }

    placeFlow(spacing: 3, minRun: 3);
    if (flowPanels.length < spec.flowPanels) placeFlow(spacing: 2, minRun: 2);

    // Conveyor belts: long straights only, with enough corridor on both sides
    // that a belt can never shove the marble straight into a corner. About half
    // run against the intended route, so the player has to fight the belt
    // instead of being carried through the level.
    final conveyors = <Conveyor>[];
    final conveyorCells = <Cell>[];
    void placeConveyors({
      required int spacing,
      required int minRun,
      required bool longRun,
    }) {
      for (final (i, cell, _, _) in criticalOrder) {
        if (conveyors.length >= spec.conveyors) return;
        if (interactiveCount() >= hazardBudget) return;
        if (straightRun[i] < minRun) continue;
        if (longRun && (straightBefore[i] < 2 || straightAfter[i] < 2)) {
          continue;
        }
        if (!freeCell(cell, spacing: spacing)) continue;
        final open = <Dir>[
          for (final d in Dir.values)
            if (!maze.hasWall(cell.x, cell.y, d)) d,
        ];
        if (open.length != 2) continue;
        final horizontal = open.contains(Dir.east) && open.contains(Dir.west);
        final vertical = open.contains(Dir.north) && open.contains(Dir.south);
        if (!horizontal && !vertical) continue;

        final travel = solution[i + 1].center - solution[i - 1].center;
        final aligned = horizontal
            ? travel.dy.abs() < 1e-6
            : travel.dx.abs() < 1e-6;
        if (!aligned || travel.distance < 1e-6) continue;
        final along = travel / travel.distance;
        final against = rnd.nextDouble() < 0.45;
        conveyorCells.add(cell);
        reserve(cell);
        conveyors.add(
          Conveyor(
            rect: Rect.fromCenter(
              center: cell.center,
              width: 0.98,
              height: 0.98,
            ),
            direction: against ? -along : along,
            strength: against
                ? 11.0 + rnd.nextDouble() * 2.5
                : 9.5 + rnd.nextDouble() * 2.0,
          ),
        );
      }
    }

    placeConveyors(spacing: 3, minRun: 4, longRun: true);
    if (conveyors.length < spec.conveyors) {
      placeConveyors(spacing: 2, minRun: 2, longRun: false);
    }

    // Sliding walls: a short bar with a gap that sweeps across a corridor. The
    // bar is always solid, so the pass window is the timing of the gap. The
    // amplitude and half-length are chosen so the fully-open side still clears
    // the marble (0.45 > 0.38 diameter) with a small margin.
    final sliders = <Slider>[];
    final sliderCells = <Cell>[];
    void placeSliders({required int spacing, required int minRun}) {
      for (final (i, cell, _, _) in criticalOrder) {
        if (sliders.length >= spec.sliders) return;
        if (interactiveCount() >= hazardBudget) return;
        if (straightRun[i] < minRun) continue;
        if (!freeCell(cell, spacing: spacing)) continue;
        final open = <Dir>[
          for (final d in Dir.values)
            if (!maze.hasWall(cell.x, cell.y, d)) d,
        ];
        if (open.length != 2) continue;
        final horizontal = open.contains(Dir.east) && open.contains(Dir.west);
        final vertical = open.contains(Dir.north) && open.contains(Dir.south);
        if (!horizontal && !vertical) continue;

        sliderCells.add(cell);
        reserve(cell);
        sliders.add(
          Slider(
            base: cell.center,
            // Horizontal corridor -> vertical bar that slides up/down.
            slidesVertically: horizontal,
            amplitude: 0.22,
            speed: 2.05 + rnd.nextDouble() * 0.60,
            phase: rnd.nextDouble() * pi * 2,
            halfLong: 0.20,
            halfThin: 0.095,
          ),
        );
      }
    }

    placeSliders(spacing: 4, minRun: 3);
    if (sliders.length < spec.sliders) placeSliders(spacing: 2, minRun: 2);

    // Breakable walls sit on an existing wall between two cells that are far
    // apart along the solution. Smashing one opens a real shortcut. Levels
    // without such an edge fall back to any wall beside the route, so every
    // FRACTURE level teaches the mechanic.
    final breakables = <BreakableWall>[];
    final shortcutCandidates = <(Cell, Cell, Dir, int)>[];
    for (var i = 0; i < solution.length; i++) {
      for (var j = i + 8; j < solution.length; j++) {
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
        // The gap is the shortcut's value: two cells that are adjacent on the
        // board but far apart on the route are exactly where a smash pays off.
        shortcutCandidates.add((a, b, d, j - i));
      }
    }
    shortcutCandidates.sort((a, b) => b.$4.compareTo(a.$4));

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

    bool tryPlace(Cell a, Cell b, Dir d, {required bool strict}) {
      final box = maze.wallBoxAt(a.x, a.y, d, kWallThickness);
      if (box == null) return false;
      final c = box.center;
      if (strict) {
        if ((c - start).distance < 2.0 || (c - exit).distance < 2.2) {
          return false;
        }
        if (holes.any((h) => (h.center - c).distance < 1.4)) return false;
        if (orbs.any((o) => (o.center - c).distance < 1.0)) return false;
        if (gates.any((g) => (g.base - c).distance < 1.6)) return false;
        if (flowPanels.any((p) => (p.rect.center - c).distance < 1.6)) {
          return false;
        }
        if (conveyors.any((b) => (b.rect.center - c).distance < 1.4)) {
          return false;
        }
        if (sliders.any((s) => (s.base - c).distance < 1.6)) return false;
        if (breakables.any((w) => (w.rect.center - c).distance < 2.2)) {
          return false;
        }
      }
      breakables.add(BreakableWall(rect: box, from: a, to: b));
      return true;
    }

    for (final (a, b, d, _) in shortcutCandidates) {
      if (breakables.length >= spec.breakables) break;
      tryPlace(a, b, d, strict: true);
    }
    for (final (a, b, d) in fallbackCandidates) {
      if (breakables.length >= spec.breakables) break;
      tryPlace(a, b, d, strict: true);
    }
    // Last resort: relax the geometry checks rather than ship a FRACTURE
    // level with no breakable wall at all.
    for (final (a, b, d, _) in shortcutCandidates) {
      if (breakables.length >= spec.breakables) break;
      tryPlace(a, b, d, strict: false);
    }
    // Portals pair a deep detour with a cell that sits near the route and the
    // exit. That turns a long orb branch into a deliberate "collect, then
    // portal out" play instead of set dressing.
    final portals = <PortalPair>[];
    final portalRanked =
        [
          for (final c in holeCandidates)
            if (!holeCells.contains(maze.indexOf(c.x, c.y)) &&
                !orbCells.contains(maze.indexOf(c.x, c.y)) &&
                routeDistance[maze.indexOf(c.x, c.y)] >= 3 &&
                (c.center - exit).distance >= 1.5 &&
                !breakables.any(
                  (w) => (w.rect.center - c.center).distance < 1.4,
                ) &&
                !gates.any((g) => (g.base - c.center).distance < 1.5) &&
                !sliders.any((s) => (s.base - c.center).distance < 1.5) &&
                !conveyors.any(
                  (b) => (b.rect.center - c.center).distance < 1.2,
                ))
              (c, routeDistance[maze.indexOf(c.x, c.y)], rnd.nextDouble()),
        ]..sort((a, b) {
          final byDepth = b.$2.compareTo(a.$2);
          return byDepth != 0 ? byDepth : a.$3.compareTo(b.$3);
        });
    final portalCandidates = [for (final (c, _, _) in portalRanked) c];
    for (var p = 0; p < spec.portalPairs && portalCandidates.length >= 2; p++) {
      final a = portalCandidates.removeAt(0);
      Cell? b;
      var best = -1e9;
      for (final candidate in portalCandidates) {
        final spread = (candidate.center - a.center).distance;
        if (spread < 3.0) continue;
        final routeBonus = touchesRoute(candidate) ? 2.0 : 0.0;
        final exitBonus = (candidate.center - exit).distance < 6 ? 2.0 : 0.0;
        final score = spread + routeBonus + exitBonus;
        if (score > best) {
          best = score;
          b = candidate;
        }
      }
      if (b == null) break;
      portalCandidates.remove(b);
      portals.add(PortalPair(a.center, b.center));
    }
    if (portals.isEmpty && spec.portalPairs > 0) {
      // Small boards may not have two genuinely deep detours. Keep the mechanic
      // available rather than shipping a PORTAL level with no portal.
      final fallback = <Cell>[
        for (var y = 0; y < spec.rows; y++)
          for (var x = 0; x < spec.cols; x++)
            if (!holeCells.contains(maze.indexOf(x, y)) &&
                !orbCells.contains(maze.indexOf(x, y)) &&
                routeDistance[maze.indexOf(x, y)] >= 1 &&
                (Cell(x, y).center - start).distance > 1.0 &&
                (Cell(x, y).center - exit).distance > 1.0)
              Cell(x, y),
      ]..shuffle(rnd);
      if (fallback.length >= 2) {
        final a = fallback.first;
        Cell? b;
        var best = -1.0;
        for (final candidate in fallback.skip(1)) {
          final spread = (candidate.center - a.center).distance;
          if (spread > best) {
            best = spread;
            b = candidate;
          }
        }
        if (b != null) portals.add(PortalPair(a.center, b.center));
      }
    }

    // Bumpers go on the route, not in dead ends. They are placed on the
    // *outside* of corners and against the wall of a straight, so a hit
    // redirects the marble at exactly the moment the player is committing to a
    // turn. The post never spans the corridor: a full-width post is just wall.
    final bumpers = <Bumper>[];
    final bumperCells = <Cell>[];
    void placeBumpers({required int spacing, required bool strict}) {
      for (final (i, cell, _, _) in criticalOrder) {
        if (bumpers.length >= spec.bumpers) return;
        if (interactiveCount() >= hazardBudget) return;
        if (!freeCell(cell, spacing: spacing)) continue;
        if (strict && !isTurnAt(i) && straightRun[i] < 3) continue;
        final open = <Dir>[
          for (final d in Dir.values)
            if (!maze.hasWall(cell.x, cell.y, d)) d,
        ];
        if (open.length != 2) continue;

        final incoming = cell.center - solution[i - 1].center;
        final outgoing = solution[i + 1].center - cell.center;
        final horizontalStraight =
            incoming.dx.abs() > 0.5 && outgoing.dx.abs() > 0.5;
        final verticalStraight =
            incoming.dy.abs() > 0.5 && outgoing.dy.abs() > 0.5;
        Offset offset;
        if (horizontalStraight) {
          offset = Offset(0, rnd.nextBool() ? 0.32 : -0.32);
        } else if (verticalStraight) {
          offset = Offset(rnd.nextBool() ? 0.32 : -0.32, 0);
        } else {
          // Outside of the corner: push against the far wall so the safe line
          // is the tight inside line.
          final outside = -(incoming + outgoing);
          offset = outside.distance < 1e-6
              ? const Offset(0, 0)
              : outside * 0.30;
        }

        // Never park a post on the rim of a pit: a bounce should redirect the
        // marble, not turn a near miss into an unavoidable fall.
        var center = cell.center + offset;
        if (holes.any((h) => (h.center - center).distance < 0.95)) {
          center = cell.center - offset;
        }
        if (holes.any((h) => (h.center - center).distance < 0.95)) continue;

        bumperCells.add(cell);
        reserve(cell);
        bumpers.add(Bumper(center, 0.10));
      }
    }

    placeBumpers(spacing: 3, strict: true);
    if (bumpers.length < spec.bumpers) placeBumpers(spacing: 2, strict: false);

    // Magnets sit on the route so their pull or push changes the line through
    // a corridor. An attractor is never allowed beside a pit; a repulsor is
    // preferred next to a branch orb, so the easy line is actively defended.
    final magnets = <Magnet>[];
    final magnetCells = <Cell>[];
    void placeMagnets({required int spacing}) {
      for (final (_, cell, _, _) in criticalOrder) {
        if (magnets.length >= spec.magnets) return;
        if (interactiveCount() >= hazardBudget) return;
        if (!freeCell(cell, spacing: spacing)) continue;
        final nearBranchOrb = orbs.any(
          (o) =>
              (o.center - cell.center).distance < 2.6 &&
              !solutionIndex.containsKey(
                maze.indexOf(o.center.dx.floor(), o.center.dy.floor()),
              ),
        );
        final nearHole = holes.any(
          (h) => (h.center - cell.center).distance < 1.5,
        );
        magnetCells.add(cell);
        reserve(cell);
        magnets.add(
          Magnet(
            center: cell.center,
            radius: 1.25,
            strength: 7.8 + rnd.nextDouble() * 2.2,
            attract: !nearBranchOrb && !nearHole && rnd.nextBool(),
          ),
        );
      }
    }

    placeMagnets(spacing: 3);
    if (magnets.length < spec.magnets) placeMagnets(spacing: 2);

    // Power-ups live on optional detours. First choice is a deep dead end the
    // player has to pay time to visit; only small boards fall back to a route
    // cell, and even then never on a hazard tile.
    final powerUps = <PowerUpPickup>[];
    if (spec.powerUps > 0) {
      final usedPowerCells = <int>{};
      final detours =
          [
            for (var y = 0; y < spec.rows; y++)
              for (var x = 0; x < spec.cols; x++)
                if (!pathSet.contains(maze.indexOf(x, y)) &&
                    !holeCells.contains(maze.indexOf(x, y)) &&
                    !orbCells.contains(maze.indexOf(x, y)) &&
                    !tar.any((z) => z.rect.contains(Cell(x, y).center)))
                  (
                    Cell(x, y),
                    routeDistance[maze.indexOf(x, y)],
                    openCount(Cell(x, y)) == 1 ? 2 : 0,
                    rnd.nextDouble(),
                  ),
          ]..sort((a, b) {
            final byDepth = b.$2.compareTo(a.$2);
            if (byDepth != 0) return byDepth;
            final byDeadEnd = b.$3.compareTo(a.$3);
            return byDeadEnd != 0 ? byDeadEnd : a.$4.compareTo(b.$4);
          });

      PowerUpType typeFor(int k) {
        final rotation = (spec.seed ~/ 17 + k) % PowerUpType.values.length;
        if (spec.blackout && k == 0) return PowerUpType.reveal;
        if (k == 0 && (spec.gates > 0 || spec.sliders > 0)) {
          return PowerUpType.phase;
        }
        if (k == 1 && spec.orbs >= 4) return PowerUpType.magnet;
        return PowerUpType.values[rotation];
      }

      for (final (cell, _, _, _) in detours) {
        if (powerUps.length >= spec.powerUps) break;
        final idx = maze.indexOf(cell.x, cell.y);
        if (!usedPowerCells.add(idx)) continue;
        powerUps.add(PowerUpPickup(cell.center, typeFor(powerUps.length)));
      }
      if (powerUps.length < spec.powerUps) {
        // Tiny boards have almost no dead ends. Put a single pickup on a safe
        // route cell rather than dropping the mechanic entirely.
        for (final (_, cell, _, _) in criticalOrder) {
          if (powerUps.length >= spec.powerUps) break;
          final idx = maze.indexOf(cell.x, cell.y);
          if (!usedPowerCells.add(idx)) continue;
          if (occupied.contains(idx)) continue;
          powerUps.add(PowerUpPickup(cell.center, typeFor(powerUps.length)));
        }
      }
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
      powerUps: powerUps,
      start: start,
      exit: exit,
    );
  }
}
