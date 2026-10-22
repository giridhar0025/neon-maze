import 'package:flutter_test/flutter_test.dart';
import 'package:neon_maze/game/tilt.dart';

void main() {
  const g = 9.80665;

  test('a flat phone maps to a level board', () {
    expect(TiltController.screenTiltFromSensor(0, 0), Offset.zero);
  });

  test('lowering the right edge tilts the board right', () {
    // Right edge down => device +x points down => accelerometer x is negative.
    final tilt = TiltController.screenTiltFromSensor(-g * 0.5, 0);
    expect(tilt.dx, closeTo(0.5, 1e-6));
    expect(tilt.dy, closeTo(0.0, 1e-6));
  });

  test('raising the top edge tilts the board down', () {
    // Top edge up => accelerometer y is positive; screen y points down.
    final tilt = TiltController.screenTiltFromSensor(0, g * 0.5);
    expect(tilt.dy, closeTo(0.5, 1e-6));
    expect(tilt.dx, closeTo(0.0, 1e-6));
  });

  test('a 30 degree tilt is about half scale', () {
    final ax = -g * 0.5; // sin(30 deg)
    final tilt = TiltController.screenTiltFromSensor(ax, 0);
    expect(tilt.distance, closeTo(0.5, 0.01));
  });

  test('inverted axes cancel the mapping', () {
    final tilt = TiltController.screenTiltFromSensor(g * 0.25, -g * 0.25);
    expect(tilt.dx, closeTo(-0.25, 1e-6));
    expect(tilt.dy, closeTo(-0.25, 1e-6));
  });
}
