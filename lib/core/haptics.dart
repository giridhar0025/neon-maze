import 'package:flutter/services.dart';

/// Throttled haptic feedback so repeated bumper and breakable impacts do not
/// buzz forever. Wall grazes are intentionally silent.
class Haptics {
  Haptics({this.enabled = true});

  bool enabled;
  int _lastBumpMs = 0;

  void bump(double strength) {
    if (!enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBumpMs < 95) return;
    _lastBumpMs = now;
    if (strength > 2.4) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void orb() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }

  void portal() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  void fall() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  void win() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }

  void tap() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }
}

String formatDuration(int milliseconds) {
  final totalSeconds = milliseconds / 1000.0;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds - minutes * 60;
  if (minutes == 0) {
    return seconds.toStringAsFixed(2);
  }
  return '$minutes:${seconds.toStringAsFixed(2).padLeft(5, '0')}';
}

String formatBest(int milliseconds) {
  if (milliseconds <= 0) return '—';
  return '${formatDuration(milliseconds)}s';
}
