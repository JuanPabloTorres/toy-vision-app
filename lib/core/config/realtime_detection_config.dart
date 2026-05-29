/// Single source of truth for all real-time detection thresholds and tunables.
///
/// Per governance, thresholds must never be scattered across files. Every layer
/// that needs a threshold reads it from an instance of this config.
class RealtimeDetectionConfig {
  const RealtimeDetectionConfig({
    this.minimumStableFrames = 3,
    this.maximumMissingFrames = 10,
    this.iouMatchThreshold = 0.45,
    this.targetInferenceFps = 8,
  });

  /// Frames a tracked toy must be seen before it is counted.
  final int minimumStableFrames;

  /// Frames a tracked toy may be missing before it is dropped from tracking.
  final int maximumMissingFrames;

  /// Minimum IoU for a detection to match an existing tracked toy.
  final double iouMatchThreshold;

  /// Target inference rate (frames processed per second). Range 5–10.
  final int targetInferenceFps;

  /// Interval between processed frames derived from [targetInferenceFps].
  Duration get frameInterval =>
      Duration(milliseconds: (1000 / targetInferenceFps).round());

  static const RealtimeDetectionConfig defaults = RealtimeDetectionConfig();
}
