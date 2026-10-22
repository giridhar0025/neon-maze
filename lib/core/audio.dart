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
}
