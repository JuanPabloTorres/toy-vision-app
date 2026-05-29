/// Camera/device orientation metadata and the clockwise quarter-turns needed to
/// make a sensor frame upright.
///
/// This is pure math: it computes *how much* rotation would be required, but
/// applying it is opt-in. Production currently uses [none] (no rotation) until
/// real-device QA confirms the correct values — we do not guess visual
/// correctness. Sensor/device degrees are expected to be multiples of 90.
class FrameOrientation {
  const FrameOrientation({
    this.sensorOrientationDegrees = 0,
    this.deviceOrientationDegrees = 0,
    this.isFrontCamera = false,
  });

  /// Camera sensor's mounting rotation (Android: `CameraDescription.sensorOrientation`).
  final int sensorOrientationDegrees;

  /// Current device UI rotation in degrees (0/90/180/270).
  final int deviceOrientationDegrees;

  final bool isFrontCamera;

  /// Clockwise quarter-turns (0..3) to rotate the sensor image upright.
  ///
  /// Back camera: `(sensor - device) mod 360`. Front camera is mirrored, so the
  /// device rotation adds instead of subtracts: `(sensor + device) mod 360`.
  /// These follow the standard Android camera formulas and must be confirmed on
  /// a physical device before being trusted for display.
  int get quarterTurns {
    final raw = isFrontCamera
        ? (sensorOrientationDegrees + deviceOrientationDegrees) % 360
        : (sensorOrientationDegrees - deviceOrientationDegrees + 360) % 360;
    return ((raw ~/ 90) % 4 + 4) % 4;
  }

  /// Conservative default: no rotation. Used in production until device QA.
  static const FrameOrientation none = FrameOrientation();
}
