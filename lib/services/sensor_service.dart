import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class SensorService {
  static final StreamController<void> _shakeController = StreamController<void>.broadcast();
  static Stream<void> get onShake => _shakeController.stream;

  static final StreamController<double> _tiltController = StreamController<double>.broadcast();
  static Stream<double> get onTilt => _tiltController.stream;

  static void init() {
    int lastShakeTime = 0;
    int lastTiltTime = 0;

    try {
      userAccelerometerEvents.listen((UserAccelerometerEvent event) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastShakeTime < 500) return; // Throttle to 500ms

        double force = event.x.abs() + event.y.abs() + event.z.abs();
        if (force > 15) { // Adjusted sensitivity for userAccelerometer
          _shakeController.add(null);
          lastShakeTime = now;
        }
      });
    } catch (e) {
      // Ignore sensor errors on unsupported platforms
    }

    try {
      gyroscopeEvents.listen((GyroscopeEvent event) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastTiltTime < 1000) return; // Throttle to 1s

        if (event.y.abs() > 2.5) {
          _tiltController.add(event.y);
          lastTiltTime = now;
        }
      });
    } catch (e) {
      // Ignore sensor errors on unsupported platforms
    }
  }
}
