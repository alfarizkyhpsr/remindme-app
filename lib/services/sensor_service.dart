import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class SensorService {
  static final StreamController<void> _shakeController = StreamController<void>.broadcast();
  static Stream<void> get onShake => _shakeController.stream;

  // Raw gyro Y-axis stream untuk game (angular velocity dalam rad/s)
  static final StreamController<double> _gyroRawController = StreamController<double>.broadcast();
  static Stream<double> get onGyroRaw => _gyroRawController.stream;

  static void init() {
    int lastShakeTime = 0;

    try {
      userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastShakeTime < 500) return;

        double force = event.x.abs() + event.y.abs() + event.z.abs();
        if (force > 15) {
          _shakeController.add(null);
          lastShakeTime = now;
        }
      });
    } catch (e) {
      // Ignore sensor errors on unsupported platforms
    }

    try {
      gyroscopeEventStream().listen((GyroscopeEvent event) {
        // Raw stream untuk game — emit setiap event tanpa throttle
        _gyroRawController.add(event.y);
      });
    } catch (e) {
      // Ignore sensor errors on unsupported platforms
    }
  }
}