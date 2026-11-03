import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/levels.dart';
import '../theme/skins.dart';

class LevelRecord {
  const LevelRecord({
    required this.stars,
    required this.bestMs,
    this.plays = 0,
  });

  final int stars;
  final int bestMs;
  final int plays;

  LevelRecord copyWith({int? stars, int? bestMs, int? plays}) => LevelRecord(
    stars: stars ?? this.stars,
    bestMs: bestMs ?? this.bestMs,
    plays: plays ?? this.plays,
  );

  Map<String, dynamic> toJson() => {'s': stars, 'b': bestMs, 'p': plays};

  static LevelRecord fromJson(Map<String, dynamic> json) => LevelRecord(
    stars: (json['s'] as num?)?.toInt() ?? 0,
    bestMs: (json['b'] as num?)?.toInt() ?? 0,
    plays: (json['p'] as num?)?.toInt() ?? 0,
  );
}

enum SensitivityPreset {
  easy('Easy', 0.82, 1.00),
  medium('Medium', 1.05, 1.15),
  hard('Hard', 1.25, 1.35),
  expert('Expert', 1.48, 1.60);

  const SensitivityPreset(this.label, this.gain, this.scoreMultiplier);

  final String label;
  final double gain;
  final double scoreMultiplier;

  static SensitivityPreset fromIndex(int i) =>
      SensitivityPreset.values[i.clamp(0, SensitivityPreset.values.length - 1)];
}

class GameSettings {
  const GameSettings({
    this.preset = SensitivityPreset.medium,
    this.gainAdjust = 0.0,
    this.deadzone = 0.025,
    this.invertX = false,
    this.invertY = false,
    this.haptics = true,
    this.sound = true,
    this.music = true,
    this.musicVolume = 0.42,
    this.reduceMotion = false,
    this.colorblind = false,
    this.autoCalibrate = true,
    this.leftHanded = false,
    this.marbleSkin = 0,
    this.calX = 0,
    this.calY = 0,
  });

  final SensitivityPreset preset;

  /// Fine trim applied on top of the preset, in the range -0.3..0.3.
  final double gainAdjust;
  final double deadzone;
  final bool invertX;
  final bool invertY;
  final bool haptics;
  final bool sound;
  final bool music;
  final double musicVolume;
  final bool reduceMotion;
  final bool colorblind;
  final bool autoCalibrate;
  final bool leftHanded;
  final int marbleSkin;

  /// Persisted "flat" offset in screen-tilt units, captured by calibration.
  final double calX;
  final double calY;

  double get gain => (preset.gain + gainAdjust).clamp(0.45, 1.9);

  double get scoreMultiplier => preset.scoreMultiplier;

  GameSettings copyWith({
    SensitivityPreset? preset,
    double? gainAdjust,
    double? deadzone,
    bool? invertX,
    bool? invertY,
    bool? haptics,
    bool? sound,
    bool? music,
    double? musicVolume,
    bool? reduceMotion,
    bool? colorblind,
    bool? autoCalibrate,
    bool? leftHanded,
    int? marbleSkin,
    double? calX,
    double? calY,
  }) {
    return GameSettings(
      preset: preset ?? this.preset,
      gainAdjust: gainAdjust ?? this.gainAdjust,
      deadzone: deadzone ?? this.deadzone,
      invertX: invertX ?? this.invertX,
      invertY: invertY ?? this.invertY,
      haptics: haptics ?? this.haptics,
      sound: sound ?? this.sound,
      music: music ?? this.music,
      musicVolume: musicVolume ?? this.musicVolume,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      colorblind: colorblind ?? this.colorblind,
      autoCalibrate: autoCalibrate ?? this.autoCalibrate,
      leftHanded: leftHanded ?? this.leftHanded,
      marbleSkin: marbleSkin ?? this.marbleSkin,
      calX: calX ?? this.calX,
      calY: calY ?? this.calY,
    );
  }

  Map<String, dynamic> toJson() => {
    'preset': preset.index,
    'gain': gainAdjust,
    'dz': deadzone,
    'ix': invertX,
    'iy': invertY,
    'hap': haptics,
    'snd': sound,
    'mus': music,
    'mv': musicVolume,
    'rm': reduceMotion,
    'cb': colorblind,
    'ac': autoCalibrate,
    'lh': leftHanded,
    'skin': marbleSkin,
    'cx': calX,
    'cy': calY,
  };

  static GameSettings fromJson(Map<String, dynamic> j) => GameSettings(
    preset: SensitivityPreset.fromIndex((j['preset'] as num?)?.toInt() ?? 1),
    gainAdjust: (j['gain'] as num?)?.toDouble() ?? 0,
    deadzone: (j['dz'] as num?)?.toDouble() ?? 0.025,
    invertX: j['ix'] as bool? ?? false,
    invertY: j['iy'] as bool? ?? false,
    haptics: j['hap'] as bool? ?? true,
    sound: j['snd'] as bool? ?? true,
    music: j['mus'] as bool? ?? true,
    musicVolume: (j['mv'] as num?)?.toDouble() ?? 0.42,
    reduceMotion: j['rm'] as bool? ?? false,
    colorblind: j['cb'] as bool? ?? false,
    autoCalibrate: j['ac'] as bool? ?? true,
    leftHanded: j['lh'] as bool? ?? false,
    marbleSkin: (j['skin'] as num?)?.toInt() ?? 0,
    calX: (j['cx'] as num?)?.toDouble() ?? 0,
    calY: (j['cy'] as num?)?.toDouble() ?? 0,
  );
}

class DailyMission {
  const DailyMission({
    required this.id,
    required this.title,
    required this.target,
    required this.reward,
    required this.progress,
    required this.claimed,
  });

  final String id;
  final String title;
  final int target;
  final int reward;
  final int progress;
  final bool claimed;

  bool get complete => progress >= target;

  double get fraction => target == 0 ? 1 : (progress / target).clamp(0.0, 1.0);
}

/// Persistent player state: settings, per-level records, onboarding, the
/// daily loop and cosmetic unlocks.
class AppStore extends ChangeNotifier {
  AppStore._(
    this._prefs,
    this._records,
    this.settings,
    this.tutorialSeen,
    this.lastLevelId,
    this.sparks,
    this.ownedSkins,
    this.dailyKey,
    this.dailyStreak,
    this.lastDailyWinKey,
    this.dailyBestMs,
    this.dailyCompleted,
    this.dailyClears,
    this.dailyOrbs,
    this.dailyStars,
    this.claimedMissions,
  );

  static const _kRecords = 'nm.records.v1';
  static const _kSettings = 'nm.settings.v1';
  static const _kTutorial = 'nm.tutorial.v1';
  static const _kLast = 'nm.last.v1';
  static const _kMeta = 'nm.meta.v1';
  static const _kSettingsVersion = 'nm.settingsVersion';
  static const int _settingsVersion = 3;

  static const int dailyRewardSparks = 80;

  final SharedPreferences _prefs;
  final Map<int, LevelRecord> _records;
  GameSettings settings;
  bool tutorialSeen;
  int? lastLevelId;

  int sparks;
  final Set<int> ownedSkins;
  String dailyKey;
  int dailyStreak;
  String lastDailyWinKey;
  int dailyBestMs;
  bool dailyCompleted;
  int dailyClears;
  int dailyOrbs;
  int dailyStars;
  final Set<String> claimedMissions;

  static String dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();

    final records = <int, LevelRecord>{};
    final rawRecords = prefs.getString(_kRecords);
    if (rawRecords != null) {
      try {
        final decoded = jsonDecode(rawRecords) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          final id = int.tryParse(key);
          if (id != null && value is Map<String, dynamic>) {
            records[id] = LevelRecord.fromJson(value);
          }
        });
      } catch (_) {
        // Corrupt save: start fresh rather than crash on launch.
      }
    }

    GameSettings settings = const GameSettings();
    final rawSettings = prefs.getString(_kSettings);
    if (rawSettings != null) {
      try {
        settings = GameSettings.fromJson(
          jsonDecode(rawSettings) as Map<String, dynamic>,
        );
      } catch (_) {
        settings = const GameSettings();
      }
    }

    // Physics was retuned; old sensitivity values and a stale calibration can
    // make the marble feel wrong. Migrate the *feel* settings once, preserving
    // progress, sound, haptics and accessibility choices.
    final storedVersion = prefs.getInt(_kSettingsVersion) ?? 0;
    if (storedVersion < _settingsVersion) {
      settings = settings.copyWith(
        preset: SensitivityPreset.medium,
        gainAdjust: 0.0,
        deadzone: const GameSettings().deadzone,
        calX: 0.0,
        calY: 0.0,
      );
      await prefs.setString(_kSettings, jsonEncode(settings.toJson()));
      await prefs.setInt(_kSettingsVersion, _settingsVersion);
    }

    // Daily/meta state. Corrupt or missing meta starts a clean day without
    // touching level progress.
    var sparks = 0;
    final ownedSkins = <int>{0};
    var dailyKey = '';
    var dailyStreak = 0;
    var lastDailyWinKey = '';
    var dailyBestMs = 0;
    var dailyCompleted = false;
    var dailyClears = 0;
    var dailyOrbs = 0;
    var dailyStars = 0;
    final claimedMissions = <String>{};

    final rawMeta = prefs.getString(_kMeta);
    if (rawMeta != null) {
      try {
        final j = jsonDecode(rawMeta) as Map<String, dynamic>;
        sparks = (j['sparks'] as num?)?.toInt() ?? 0;
        for (final v in (j['skins'] as List?) ?? const []) {
          if (v is num) ownedSkins.add(v.toInt());
        }
        dailyKey = j['dk'] as String? ?? '';
        dailyStreak = (j['ds'] as num?)?.toInt() ?? 0;
        lastDailyWinKey = j['dw'] as String? ?? '';
        dailyBestMs = (j['db'] as num?)?.toInt() ?? 0;
        dailyCompleted = j['dd'] as bool? ?? false;
        dailyClears = (j['dc'] as num?)?.toInt() ?? 0;
        dailyOrbs = (j['do'] as num?)?.toInt() ?? 0;
        dailyStars = (j['dt'] as num?)?.toInt() ?? 0;
        for (final v in (j['cm'] as List?) ?? const []) {
          if (v is String) claimedMissions.add(v);
        }
      } catch (_) {
        // Ignore corrupt meta.
      }
    }
    ownedSkins.add(0);

    final store = AppStore._(
      prefs,
      records,
      settings,
      prefs.getBool(_kTutorial) ?? false,
      prefs.getInt(_kLast),
      sparks,
      ownedSkins,
      dailyKey,
      dailyStreak,
      lastDailyWinKey,
      dailyBestMs,
      dailyCompleted,
      dailyClears,
      dailyOrbs,
      dailyStars,
      claimedMissions,
    );
    await store.rollDailyIfNeeded();
    return store;
  }

  /// Resets the daily counters when the calendar day changes. Called once at
  /// launch and again when the home screen resumes.
  Future<void> rollDailyIfNeeded({DateTime? now}) async {
    final today = dayKey(now ?? DateTime.now());
    if (dailyKey == today) return;
    final yesterday = dayKey(
      (now ?? DateTime.now()).subtract(const Duration(days: 1)),
    );
    dailyKey = today;
    dailyBestMs = 0;
    dailyCompleted = false;
    dailyClears = 0;
    dailyOrbs = 0;
    dailyStars = 0;
    claimedMissions.clear();
    if (lastDailyWinKey != yesterday && lastDailyWinKey != today) {
      dailyStreak = 0;
    }
    notifyListeners();
    await _persistMeta();
  }

  int get totalStars => _records.values.fold(0, (sum, r) => sum + r.stars);

  int get clearedCount => _records.values.where((r) => r.stars > 0).length;

  LevelRecord? recordFor(int levelId) => _records[levelId];

  int starsFor(int levelId) => _records[levelId]?.stars ?? 0;

  int bestMsFor(int levelId) => _records[levelId]?.bestMs ?? 0;

  /// Three rotating goals that reset at midnight. Progress is fed by normal
  /// level wins, so they reward play rather than a separate grind.
  List<DailyMission> get dailyMissions => [
    DailyMission(
      id: 'clears',
      title: 'Escape 3 mazes',
      target: 3,
      reward: 40,
      progress: dailyClears,
      claimed: claimedMissions.contains('clears'),
    ),
    DailyMission(
      id: 'orbs',
      title: 'Collect 30 energy orbs',
      target: 30,
      reward: 40,
      progress: dailyOrbs,
      claimed: claimedMissions.contains('orbs'),
    ),
    DailyMission(
      id: 'stars',
      title: 'Earn 8 stars',
      target: 8,
      reward: 60,
      progress: dailyStars,
      claimed: claimedMissions.contains('stars'),
    ),
  ];

  Future<int> claimMission(String id) async {
    DailyMission? mission;
    for (final m in dailyMissions) {
      if (m.id == id) {
        mission = m;
        break;
      }
    }
    if (mission == null || mission.claimed || !mission.complete) return 0;
    claimedMissions.add(id);
    sparks += mission.reward;
    notifyListeners();
    await _persistMeta();
    return mission.reward;
  }

  /// Pays the daily challenge once per day. Returns the sparks awarded (zero
  /// on a replay).
  Future<int> completeDaily(int timeMs, {int stars = 1, DateTime? now}) async {
    final date = now ?? DateTime.now();
    await rollDailyIfNeeded(now: date);
    final today = dayKey(date);
    final yesterday = dayKey(date.subtract(const Duration(days: 1)));
    var reward = 0;
    if (!dailyCompleted) {
      dailyCompleted = true;
      reward = dailyRewardSparks;
      sparks += reward;
      dailyClears += 1;
      dailyStars += stars;
      if (lastDailyWinKey == yesterday) {
        dailyStreak += 1;
      } else if (lastDailyWinKey != today) {
        dailyStreak = 1;
      }
      lastDailyWinKey = today;
    }
    if (dailyBestMs <= 0 || timeMs < dailyBestMs) dailyBestMs = timeMs;
    notifyListeners();
    await _persistMeta();
    return reward;
  }

  bool ownsSkin(int index) => index == 0 || ownedSkins.contains(index);

  Future<bool> buySkin(int index) async {
    if (index < 0 || index >= marbleSkins.length) return false;
    if (ownsSkin(index)) {
      await selectSkin(index);
      return true;
    }
    final price = marbleSkins[index].price;
    if (sparks < price) return false;
    sparks -= price;
    ownedSkins.add(index);
    notifyListeners();
    await _persistMeta();
    await updateSettings(settings.copyWith(marbleSkin: index));
    return true;
  }

  Future<void> selectSkin(int index) async {
    if (!ownsSkin(index)) return;
    await updateSettings(settings.copyWith(marbleSkin: index));
  }

  /// Every level is open by default while the game is in testing. Shipping a
  /// locked build is one flag away:
  /// `flutter build apk --release --dart-define=NM_UNLOCK_ALL=false`.
  static const bool unlockAllLevels = bool.fromEnvironment(
    'NM_UNLOCK_ALL',
    defaultValue: true,
  );

  /// Levels unlock sequentially; a level opens once every earlier level is
  /// cleared, so the player always has exactly one "next" level to play.
  bool isUnlocked(int levelId) {
    if (unlockAllLevels) return true;
    if (levelId <= 0) return true;
    if (levelId >= LevelCatalog.total) return false;
    // Every level up to the first uncleared one is open, plus one beyond it.
    var streak = 0;
    while (_records.containsKey(streak) && (_records[streak]?.stars ?? 0) > 0) {
      streak++;
    }
    return levelId <= streak;
  }

  int get continueLevelId {
    final last = lastLevelId;
    if (last != null && isUnlocked(last)) return last;
    var next = 0;
    while (_records.containsKey(next) && (_records[next]?.stars ?? 0) > 0) {
      next++;
    }
    // Everything cleared: stay on the final level instead of pointing past the
    // end of the catalog.
    return next.clamp(0, LevelCatalog.total - 1);
  }

  Future<void> markTutorialSeen() async {
    tutorialSeen = true;
    notifyListeners();
    await _prefs.setBool(_kTutorial, true);
  }

  Future<void> setLastLevel(int id) async {
    lastLevelId = id;
    await _prefs.setInt(_kLast, id);
  }

  Future<void> updateSettings(GameSettings next) async {
    settings = next;
    notifyListeners();
    await _prefs.setString(_kSettings, jsonEncode(next.toJson()));
  }

  /// Records a completed level. Returns true when this run set a new best time.
  Future<bool> recordWin(
    int levelId,
    int stars,
    int timeMs, {
    int orbs = 0,
    int powerUpsUsed = 0,
  }) async {
    final previous = _records[levelId];
    final isBest =
        previous == null || previous.bestMs <= 0 || timeMs < previous.bestMs;
    _records[levelId] = LevelRecord(
      stars: stars > (previous?.stars ?? 0) ? stars : (previous?.stars ?? 0),
      bestMs: isBest ? timeMs : previous.bestMs,
      plays: (previous?.plays ?? 0) + 1,
    );
    dailyClears += 1;
    dailyOrbs += orbs;
    dailyStars += stars;
    notifyListeners();
    await _persistRecords();
    await _persistMeta();
    return isBest;
  }

  Future<void> recordAttempt(int levelId) async {
    final previous = _records[levelId];
    _records[levelId] = LevelRecord(
      stars: previous?.stars ?? 0,
      bestMs: previous?.bestMs ?? 0,
      plays: (previous?.plays ?? 0) + 1,
    );
    notifyListeners();
    await _persistRecords();
  }

  Future<void> resetProgress() async {
    _records.clear();
    lastLevelId = null;
    tutorialSeen = false;
    notifyListeners();
    await _prefs.remove(_kRecords);
    await _prefs.remove(_kLast);
    await _prefs.remove(_kTutorial);
  }

  Future<void> _persistMeta() async {
    final out = <String, dynamic>{
      'sparks': sparks,
      'skins': ownedSkins.toList()..sort(),
      'dk': dailyKey,
      'ds': dailyStreak,
      'dw': lastDailyWinKey,
      'db': dailyBestMs,
      'dd': dailyCompleted,
      'dc': dailyClears,
      'do': dailyOrbs,
      'dt': dailyStars,
      'cm': claimedMissions.toList()..sort(),
    };
    await _prefs.setString(_kMeta, jsonEncode(out));
  }

  Future<void> _persistRecords() async {
    final out = <String, dynamic>{
      for (final entry in _records.entries)
        '${entry.key}': entry.value.toJson(),
    };
    await _prefs.setString(_kRecords, jsonEncode(out));
  }
}
