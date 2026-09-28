import 'dart:math' as math;

/// Optional device/AR evidence captured close to a camera frame.
///
/// Motion sensors are available on the current Android camera path. Pose and
/// depth are capability hooks: they remain unavailable unless a camera owner
/// that can safely share frames with ARCore supplies them.
class SpatialObservation {
  const SpatialObservation({
    required this.timestamp,
    this.motionAvailable = false,
    this.orientationAvailable = false,
    this.poseAvailable = false,
    this.depthAvailable = false,
    this.gyroscopeRadPerSecond = 0,
    this.linearAccelerationMetersPerSecond2 = 0,
    this.yawDegrees,
    this.pitchDegrees,
    this.rollDegrees,
    this.poseTrackingGood = false,
    this.depthChangeScore,
    this.depthConsistency,
  });

  const SpatialObservation.unavailable()
      : timestamp = null,
        motionAvailable = false,
        orientationAvailable = false,
        poseAvailable = false,
        depthAvailable = false,
        gyroscopeRadPerSecond = 0,
        linearAccelerationMetersPerSecond2 = 0,
        yawDegrees = null,
        pitchDegrees = null,
        rollDegrees = null,
        poseTrackingGood = false,
        depthChangeScore = null,
        depthConsistency = null;

  final DateTime? timestamp;
  final bool motionAvailable;
  final bool orientationAvailable;
  final bool poseAvailable;
  final bool depthAvailable;
  final double gyroscopeRadPerSecond;
  final double linearAccelerationMetersPerSecond2;
  final double? yawDegrees;
  final double? pitchDegrees;
  final double? rollDegrees;
  final bool poseTrackingGood;
  final double? depthChangeScore;
  final double? depthConsistency;

  double get normalizedMotion {
    if (!motionAvailable) return 0;
    final rotation = (gyroscopeRadPerSecond / 1.5).clamp(0.0, 1.0);
    final translation =
        (linearAccelerationMetersPerSecond2 / 4.0).clamp(0.0, 1.0);
    return math.max(rotation, translation);
  }

  bool get cameraTrackingGood =>
      (!poseAvailable || poseTrackingGood) &&
      (!motionAvailable || normalizedMotion <= 0.55);
}
