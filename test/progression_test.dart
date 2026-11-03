import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:neon_maze/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('progress records wins and testing mode opens the catalog', () async {
    final store = await AppStore.load();

    expect(store.continueLevelId, 0);
    expect(store.isUnlocked(0), isTrue);
    expect(store.isUnlocked(1), AppStore.unlockAllLevels);
    expect(store.isUnlocked(2), AppStore.unlockAllLevels);
    // The QA build must open the whole 800-level catalog out of the box.
    expect(AppStore.unlockAllLevels, isTrue);
    expect(store.isUnlocked(399), isTrue);
    expect(store.isUnlocked(799), isTrue);

    await store.recordWin(0, 2, 14000);
    expect(store.isUnlocked(1), isTrue);
    expect(store.isUnlocked(2), AppStore.unlockAllLevels);
    expect(store.starsFor(0), 2);
    expect(store.bestMsFor(0), 14000);

    await store.recordWin(1, 3, 12000);
    expect(store.isUnlocked(2), isTrue);
    expect(store.continueLevelId, 2);
    expect(store.clearedCount, 2);
    expect(store.totalStars, 5);
  });

  test('a better time replaces the best, a worse time does not', () async {
    final store = await AppStore.load();
    await store.recordWin(0, 1, 20000);
    expect(store.bestMsFor(0), 20000);
    expect(store.starsFor(0), 1);

    final improved = await store.recordWin(0, 3, 9000);
    expect(improved, isTrue);
    expect(store.bestMsFor(0), 9000);
    expect(store.starsFor(0), 3);

    final worse = await store.recordWin(0, 1, 25000);
    expect(worse, isFalse);
    expect(store.bestMsFor(0), 9000);
    expect(store.starsFor(0), 3, reason: 'stars never regress');
  });

  test('old feel settings migrate to sane defaults once', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.nm.settings.v1': jsonEncode(
        const GameSettings(
          preset: SensitivityPreset.expert,
          gainAdjust: 0.3,
          deadzone: 0.09,
          calX: 0.2,
          calY: -0.1,
        ).toJson(),
      ),
    });

    final store = await AppStore.load();
    expect(store.settings.preset, SensitivityPreset.medium);
    expect(store.settings.gainAdjust, 0.0);
    expect(store.settings.deadzone, closeTo(0.025, 1e-9));
    expect(store.settings.calX, 0.0);
    expect(store.settings.calY, 0.0);
  });

  test('settings round-trip through persistence', () async {
    final store = await AppStore.load();
    await store.updateSettings(
      store.settings.copyWith(
        preset: SensitivityPreset.expert,
        deadzone: 0.09,
        invertY: true,
        colorblind: true,
        haptics: false,
        music: false,
        musicVolume: 0.2,
        marbleSkin: 2,
      ),
    );

    final reloaded = await AppStore.load();
    expect(reloaded.settings.preset, SensitivityPreset.expert);
    expect(reloaded.settings.deadzone, closeTo(0.09, 1e-9));
    expect(reloaded.settings.invertY, isTrue);
    expect(reloaded.settings.colorblind, isTrue);
    expect(reloaded.settings.haptics, isFalse);
    expect(reloaded.settings.music, isFalse);
    expect(reloaded.settings.musicVolume, closeTo(0.2, 1e-9));
    expect(reloaded.settings.marbleSkin, 2);
    expect(reloaded.settings.calX, 0);
  });

  test('calibration offset survives a restart', () async {
    final store = await AppStore.load();
    await store.updateSettings(
      store.settings.copyWith(calX: -0.03, calY: 0.045),
    );
    final reloaded = await AppStore.load();
    expect(reloaded.settings.calX, closeTo(-0.03, 1e-9));
    expect(reloaded.settings.calY, closeTo(0.045, 1e-9));
  });

  test('reset clears stars, best times and tutorial state', () async {
    final store = await AppStore.load();
    await store.recordWin(0, 3, 8000);
    await store.markTutorialSeen();
    expect(store.totalStars, 3);

    await store.resetProgress();
    expect(store.totalStars, 0);
    expect(store.clearedCount, 0);
    expect(store.tutorialSeen, isFalse);
    expect(store.isUnlocked(1), AppStore.unlockAllLevels);
  });

  test('daily challenge pays once per day and builds a streak', () async {
    final store = await AppStore.load();
    final day1 = DateTime(2026, 10, 23, 12);
    expect(
      await store.completeDaily(30000, now: day1),
      AppStore.dailyRewardSparks,
    );
    expect(store.sparks, AppStore.dailyRewardSparks);
    expect(store.dailyStreak, 1);
    expect(store.dailyCompleted, isTrue);

    // Replaying the same day is allowed but pays no sparks.
    expect(await store.completeDaily(28000, now: day1), 0);
    expect(store.dailyBestMs, 28000);

    final day2 = DateTime(2026, 10, 24, 12);
    expect(
      await store.completeDaily(31000, now: day2),
      AppStore.dailyRewardSparks,
    );
    expect(store.dailyStreak, 2);

    // Missing a full day breaks the streak.
    await store.rollDailyIfNeeded(now: DateTime(2026, 10, 26, 12));
    expect(store.dailyStreak, 0);
    expect(store.dailyCompleted, isFalse);
  });

  test('daily missions track play and can be claimed once', () async {
    final store = await AppStore.load();
    await store.recordWin(0, 3, 10000, orbs: 12);
    await store.recordWin(1, 3, 10000, orbs: 12);
    await store.recordWin(2, 2, 10000, orbs: 12);

    final clears = store.dailyMissions.firstWhere((m) => m.id == 'clears');
    expect(clears.complete, isTrue);
    expect(clears.progress, 3);

    expect(await store.claimMission('clears'), clears.reward);
    expect(await store.claimMission('clears'), 0);
    expect(store.sparks, clears.reward);

    final orbs = store.dailyMissions.firstWhere((m) => m.id == 'orbs');
    expect(orbs.progress, 36);
    expect(orbs.complete, isTrue);
  });

  test('sparks unlock cosmetic marble skins', () async {
    final store = await AppStore.load();
    for (var day = 23; day <= 26; day++) {
      await store.completeDaily(30000, now: DateTime(2026, 10, day, 12));
    }
    expect(store.sparks, AppStore.dailyRewardSparks * 4);

    expect(await store.buySkin(1), isTrue);
    expect(store.settings.marbleSkin, 1);
    expect(store.ownsSkin(1), isTrue);
    expect(store.sparks, AppStore.dailyRewardSparks * 4 - 250);

    // Not enough sparks for the most expensive finish.
    expect(await store.buySkin(4), isFalse);
    expect(store.ownsSkin(4), isFalse);
  });

  test('daily meta survives a restart', () async {
    final store = await AppStore.load();
    await store.completeDaily(25000, now: DateTime.now());
    final reloaded = await AppStore.load();
    expect(reloaded.sparks, AppStore.dailyRewardSparks);
    expect(reloaded.dailyCompleted, isTrue);
    expect(reloaded.dailyBestMs, 25000);
    expect(reloaded.dailyStreak, 1);
  });

  test('sensitivity presets scale score and gain', () {
    expect(
      SensitivityPreset.easy.scoreMultiplier,
      lessThan(SensitivityPreset.expert.scoreMultiplier),
    );
    expect(
      SensitivityPreset.easy.gain,
      lessThan(SensitivityPreset.expert.gain),
    );
    const settings = GameSettings();
    expect(settings.gain, closeTo(SensitivityPreset.medium.gain, 1e-9));
  });
}
