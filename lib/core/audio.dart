import 'package:audioplayers/audioplayers.dart';

/// Tiny round-robin SFX player so overlapping effects never cut each other off.
class Sfx {
  Sfx({this.enabled = true});

  bool enabled;
  final List<AudioPlayer> _players = [];
  int _next = 0;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    for (var i = 0; i < 4; i++) {
      try {
        final player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
        _players.add(player);
      } catch (_) {
        // Some platforms (notably web) reject low-latency mode. Keep going.
      }
    }
  }

  Future<void> play(String name, {double volume = 0.75}) async {
    if (!enabled || _players.isEmpty) return;
    final player = _players[_next++ % _players.length];
    try {
      await player.stop();
      await player.play(AssetSource('audio/$name'), volume: volume);
    } catch (_) {
      // Audio is never allowed to break gameplay.
    }
  }

  Future<void> dispose() async {
    for (final player in _players) {
      await player.dispose();
    }
    _players.clear();
  }
}

class SfxNames {
  const SfxNames._();

  static const tap = 'ui_tap.wav';
  static const bump = 'wall_bump.wav';
  static const orb = 'orb_pickup.wav';
  static const clear = 'level_clear.wav';
  static const fall = 'fall.wav';
  static const star = 'star.wav';
  static const powerUp = 'powerup.wav';
  static const shield = 'shield.wav';
  static const mission = 'mission.wav';
}

enum MusicTrack {
  menu('menu_loop.wav'),
  gameplay('game_loop.wav'),
  blackout('blackout_loop.wav');

  const MusicTrack(this.file);

  final String file;
}

/// One looping music player shared by every screen. SFX use their own
/// round-robin pool so a pickup never cuts the soundtrack.
class Music {
  Music._();

  static final Music instance = Music._();

  AudioPlayer? _player;
  MusicTrack? _track;
  bool _enabled = true;
  bool _paused = false;
  double _volume = 0.42;

  MusicTrack? get track => _track;

  Future<void> configure({required bool enabled, required double volume}) async {
    _enabled = enabled;
    _volume = volume.clamp(0.0, 1.0);
    final player = _player;
    if (player == null) {
      // Music was off when the track was requested. Starting it now makes the
      // settings toggle take effect without waiting for a screen change.
      if (_enabled && _track != null) await play(_track!);
      return;
    }
    if (!_enabled) {
      await player.pause();
    } else {
      await player.setVolume(_volume);
      if (_paused) {
        await player.resume();
        _paused = false;
      }
    }
  }

  Future<void> play(MusicTrack track) async {
    final sameTrack = _track == track && _player != null;
    _track = track;
    if (!_enabled) return;
    if (sameTrack) {
      if (_paused) await resume();
      return;
    }
    if (_player != null) {
      try {
        await _player!.stop();
        await _player!.dispose();
      } catch (_) {}
      _player = null;
    }
    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_volume);
      await player.play(AssetSource('audio/${track.file}'));
      _player = player;
      _paused = false;
    } catch (_) {
      // Music is optional; never let it break a run.
    }
  }

  Future<void> pause() async {
    if (_player == null || _paused) return;
    _paused = true;
    try {
      await _player!.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (_player == null || !_paused || !_enabled) return;
    _paused = false;
    try {
      await _player!.resume();
      await _player!.setVolume(_volume);
    } catch (_) {}
  }

  Future<void> stop() async {
    _track = null;
    _paused = false;
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.stop();
      await player.dispose();
    } catch (_) {}
  }
}
