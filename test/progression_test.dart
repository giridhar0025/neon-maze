import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:neon_maze/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('progress unlocks one level at a time', () async {
    final store = await AppStore.load();

    expect(store.continueLevelId, 0);
    expect(store.isUnlocked(0), isTrue);
    expect(store.isUnlocked(1), isFalse);
    expect(store.isUnlocked(2), isFalse);

    await store.recordWin(0, 2, 14000);
    expect(store.isUnlocked(1), isTrue);
    expect(store.isUnlocked(2), isFalse);
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
    await store.updateSettings(store.settings.copyWith(
      preset: SensitivityPreset.expert,
      deadzone: 0.09,
      invertY: true,
      colorblind: true,
      haptics: false,
    ));

    final reloaded = await AppStore.load();
    expect(reloaded.settings.preset, SensitivityPreset.expert);
    expect(reloaded.settings.deadzone, closeTo(0.09, 1e-9));
    expect(reloaded.settings.invertY, isTrue);
    expect(reloaded.settings.colorblind, isTrue);
    expect(reloaded.settings.haptics, isFalse);
    expect(reloaded.settings.calX, 0);
  });

  test('calibration offset survives a restart', () async {
    final store = await AppStore.load();
    await store.updateSettings(store.settings.copyWith(calX: -0.03, calY: 0.045));
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
    expect(store.isUnlocked(1), isFalse);
  });

  test('sensitivity presets scale score and gain', () {
    expect(SensitivityPreset.easy.scoreMultiplier, lessThan(SensitivityPreset.expert.scoreMultiplier));
    expect(SensitivityPreset.easy.gain, lessThan(SensitivityPreset.expert.gain));
    const settings = GameSettings();
    expect(settings.gain, closeTo(SensitivityPreset.medium.gain, 1e-9));
  });
}
