import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../data/store.dart';

/// Turns accelerometer readings (or pointer/keyboard fallback input) into a
/// normalized tilt vector in screen space: x right, y down, magnitude <= 1.
///
/// Calibration subtracts a captured "flat" offset, a dead zone removes hand
/// tremor, and sensitivity scales the result. The controller never filters the
/// physics; it only smooths the sensor so the marble feels connected.
class TiltController extends ChangeNotifier {
  TiltController(GameSettings settings)
      : _settings = settings,
        _zero = Offset(settings.calX, settings.calY),
        _hasStoredZero = settings.calX != 0 || settings.calY != 0;

  GameSettings _settings;
  StreamSubscription<AccelerometerEvent>? _sub;

  Offset _rawScreen = Offset.zero;
  Offset _filtered = Offset.zero;
  Offset _zero;
  bool _hasStoredZero;
  Offset _fallback = Offset.zero;

  bool _sensorSeen = false;
  bool _sensorFailed = false;
  bool _touchMode = false;
  String? _sensorError;

  bool get sensorAvailable => _sensorSeen && !_sensorFailed;
  bool get sensorFailed => _sensorFailed;
  String? get sensorError => _sensorError;
  bool get touchMode => _touchMode;
  bool get calibrated => _calibrated;
  bool _calibrated = false;

  Offset get rawTilt => _rawScreen;
  Offset get calibrationOffset => _zero;

  /// Filtered, calibrated, dead-zoned and sensitivity-scaled tilt.
  Offset get value {
    if (_touchMode || !sensorAvailable) return _fallback;
    var v = _filtered - _zero;

    final dz = _settings.deadzone.clamp(0.0, 0.35);
    final m = v.distance;
    if (m <= dz) {
      v = Offset.zero;
    } else if (dz > 0) {
      v = v / m * ((m - dz) / (1 - dz));
    }

    v = Offset(
      v.dx * _settings.gain * (_settings.invertX ? -1 : 1),
      v.dy * _settings.gain * (_settings.invertY ? -1 : 1),
    );
    final mag = v.distance;
    if (mag > 1) v = v / mag;
    return v;
  }

  void start() {
    if (_sub != null) return;
    try {
      _sub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
          .listen(
        _onEvent,
        onError: (Object error) {
          _sensorFailed = true;
          _sensorError = error.toString();
          notifyListeners();
        },
        cancelOnError: false,
      );
    } catch (error) {
      _sensorFailed = true;
      _sensorError = error.toString();
      notifyListeners();
    }
  }

  /// Maps raw accelerometer axes to screen tilt (x right, y down).
  ///
  /// Device frame: +x right, +y toward the top edge, +z out of the screen.
  /// A resting sensor reads -gravity, so lowering the right edge produces
  /// negative x and raising the top edge produces positive y. Screen space
  /// needs y down, so only x is negated.
  @visibleForTesting
  static Offset screenTiltFromSensor(double ax, double ay) =>
      Offset(-ax / 9.80665, ay / 9.80665);

  void _onEvent(AccelerometerEvent event) {
    final raw = screenTiltFromSensor(event.x, event.y);
    final clamped = _clampMagnitude(raw, 1.15);
    _rawScreen = clamped;
    if (!_sensorSeen) {
      _sensorSeen = true;
      if (!_hasStoredZero) {
        // First reading is a sane starting zero when nothing is saved.
        _zero = clamped;
      }
      _filtered = clamped;
      _calibrated = true;
    } else {
      _filtered = Offset.lerp(_filtered, clamped, 0.32)!;
    }
    notifyListeners();
  }

  /// Captures the current reading as "level". Hold the phone flat and tap.
  /// Returns the captured offset so callers can persist it.
  Offset calibrate() {
    _zero = _filtered;
    _hasStoredZero = true;
    _calibrated = true;
    notifyListeners();
    return _zero;
  }

  /// Slowly adapts the zero point while the marble is at rest, compensating for
  /// posture changes without fighting deliberate tilt.
  void autoZero(double amount) {
    if (!sensorAvailable || amount <= 0) return;
    _zero = Offset.lerp(_zero, _filtered, amount.clamp(0.0, 0.25))!;
  }

  /// Pointer/keyboard fallback. Values are in screen space, magnitude <= 1.
  void feedFallback(Offset tilt) {
    _fallback = _clampMagnitude(tilt, 1);
    notifyListeners();
  }

  void setTouchMode(bool enabled) {
    if (_touchMode == enabled) return;
    _touchMode = enabled;
    if (enabled) _fallback = Offset.zero;
    notifyListeners();
  }

  void applySettings(GameSettings settings) {
    final calibrationChanged =
        settings.calX != _settings.calX || settings.calY != _settings.calY;
    _settings = settings;
    if (calibrationChanged) {
      _zero = Offset(settings.calX, settings.calY);
      _hasStoredZero = settings.calX != 0 || settings.calY != 0;
    }
    notifyListeners();
  }

  static Offset _clampMagnitude(Offset v, double max) {
    final m = v.distance;
    if (m <= max || m == 0) return v;
    return v / m * max;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
