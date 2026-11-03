import 'levels.dart';

/// The daily challenge is a deterministic but date-seeded remix of a late-act
/// level from one chapter. It uses the same generator as the campaign, so it
/// is always fair and solvable, while the seed changes every day.
class DailyChallenge {
  const DailyChallenge._();

  static int dayNumber(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    return utc.difference(DateTime.utc(2026, 1, 1)).inDays;
  }

  static LevelSpec specFor(DateTime date) {
    final day = dayNumber(date);
    final chapter = day % LevelCatalog.chapterCount;
    final levels = LevelCatalog.chapter(chapter);

    // Pick from the last two acts so the daily always has a real mix of
    // mechanics, then reseed it so it is never identical to the campaign.
    final base = levels[60 + (day * 13) % (LevelCatalog.levelsPerChapter - 60)];
    final seed = 700001 + day * 7919 + chapter * 131;

    return LevelSpec(
      id: -1,
      chapter: base.chapter,
      indexInChapter: base.indexInChapter,
      cols: base.cols,
      rows: base.rows,
      seed: seed,
      braid: base.braid + 1,
      holes: base.holes,
      orbs: base.orbs,
      iceZones: base.iceZones,
      tarZones: base.tarZones,
      gates: base.gates,
      portalPairs: base.portalPairs,
      bumpers: base.bumpers,
      flowPanels: base.flowPanels,
      breakables: base.breakables,
      conveyors: base.conveyors,
      sliders: base.sliders,
      magnets: base.magnets,
      blackout: base.blackout,
      powerUps: base.powerUps + 1,
      act: base.act,
      parMs: base.parMs,
      code: 'D${(day % 99) + 1}',
    );
  }
}
