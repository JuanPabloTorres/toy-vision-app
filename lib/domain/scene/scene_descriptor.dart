import 'scene_state.dart';
import 'spatial_observation.dart';

class SceneDescriptor {
  SceneDescriptor({
    required List<double> embedding,
    required this.state,
    required this.similarityToPrevious,
    required this.motion,
    required this.sharpness,
    required this.luminance,
    required this.coverage,
    required this.timestamp,
    this.stableFrameCount = 0,
    this.similarityToStableAnchor = 0,
    this.spatial = const SpatialObservation.unavailable(),
  }) : embedding = List<double>.unmodifiable(embedding);

  final List<double> embedding;
  final SceneState state;
  final double similarityToPrevious;
  final double motion;
  final double sharpness;
  final double luminance;
  final double coverage;
  final DateTime timestamp;
  final int stableFrameCount;
  final double similarityToStableAnchor;
  final SpatialObservation spatial;

  bool get canVerifyDisappearance =>
      state == SceneState.stable &&
      stableFrameCount >= 4 &&
      spatial.cameraTrackingGood;
}
