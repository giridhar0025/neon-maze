import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LevelRecord {
  const LevelRecord({required this.stars, required this.bestMs, this.plays = 0});

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
    this.reduceMotion = false,
    this.colorblind = false,
    this.autoCalibrate = true,
    this.leftHanded = false,
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
  final bool reduceMotion;
  final bool colorblind;
  final bool autoCalibrate;
  final bool leftHanded;

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
    bool? reduceMotion,
    bool? colorblind,
    bool? autoCalibrate,
    bool? leftHanded,
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
      reduceMotion: reduceMotion ?? this.reduceMotion,
      colorblind: colorblind ?? this.colorblind,
      autoCalibrate: autoCalibrate ?? this.autoCalibrate,
      leftHanded: leftHanded ?? this.leftHanded,
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
        'rm': reduceMotion,
        'cb': colorblind,
        'ac': autoCalibrate,
        'lh': leftHanded,
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
        reduceMotion: j['rm'] as bool? ?? false,
        colorblind: j['cb'] as bool? ?? false,
        autoCalibrate: j['ac'] as bool? ?? true,
        leftHanded: j['lh'] as bool? ?? false,
        calX: (j['cx'] as num?)?.toDouble() ?? 0,
        calY: (j['cy'] as num?)?.toDouble() ?? 0,
      );
}

/// Persistent player state: settings, per-level records, onboarding.
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs, this._records, this.settings, this.tutorialSeen, this.lastLevelId);

  static const _kRecords = 'nm.records.v1';
  static const _kSettings = 'nm.settings.v1';
  static const _kTutorial = 'nm.tutorial.v1';
  static const _kLast = 'nm.last.v1';

  final SharedPreferences _prefs;
  final Map<int, LevelRecord> _records;
  GameSettings settings;
  bool tutorialSeen;
  int? lastLevelId;

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
        settings = GameSettings.fromJson(jsonDecode(rawSettings) as Map<String, dynamic>);
      } catch (_) {
        settings = const GameSettings();
      }
    }

    return AppStore._(
      prefs,
      records,
      settings,
      prefs.getBool(_kTutorial) ?? false,
      prefs.getInt(_kLast),
    );
  }

  int get totalStars => _records.values.fold(0, (sum, r) => sum + r.stars);

  int get clearedCount => _records.values.where((r) => r.stars > 0).length;

  LevelRecord? recordFor(int levelId) => _records[levelId];

  int starsFor(int levelId) => _records[levelId]?.stars ?? 0;

  int bestMsFor(int levelId) => _records[levelId]?.bestMs ?? 0;

  /// Levels unlock sequentially: the first unplayed level is available.
  bool isUnlocked(int levelId) {
    if (levelId <= 0) return true;
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
    return next;
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
  Future<bool> recordWin(int levelId, int stars, int timeMs) async {
    final previous = _records[levelId];
    final isBest = previous == null || previous.bestMs <= 0 || timeMs < previous.bestMs;
    _records[levelId] = LevelRecord(
      stars: stars > (previous?.stars ?? 0) ? stars : (previous?.stars ?? 0),
      bestMs: isBest ? timeMs : previous.bestMs,
      plays: (previous?.plays ?? 0) + 1,
    );
    notifyListeners();
    await _persistRecords();
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

  Future<void> _persistRecords() async {
    final out = <String, dynamic>{
      for (final entry in _records.entries) '${entry.key}': entry.value.toJson(),
    };
    await _prefs.setString(_kRecords, jsonEncode(out));
  }
}
