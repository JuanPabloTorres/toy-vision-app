import '../../domain/scene/scene_descriptor.dart';
import '../../domain/scene/spatial_observation.dart';
import '../../domain/toy/toy_track.dart';
import '../scene/background_reveal_detector.dart';

class SensorFusionEvidence {
  const SensorFusionEvidence({
    required this.deviceMotion,
    required this.backgroundRevealScore,
    required this.cameraTrackingGood,
    required this.motionAvailable,
    this.depthChangeScore,
  });

  final double deviceMotion;
  final double backgroundRevealScore;
  final double? depthChangeScore;
  final bool cameraTrackingGood;
  final bool motionAvailable;

  bool get backgroundRevealed => backgroundRevealScore >= 0.45;
  bool get depthConfirmsRemoval => (depthChangeScore ?? 0) >= 0.55;
}

/// Combines independent physical signals without owning gameplay decisions.
class SensorFusionEngine {
  const SensorFusionEngine({
    this.backgroundRevealDetector = const BackgroundRevealDetector(),
  });

  final BackgroundRevealDetector backgroundRevealDetector;

  SensorFusionEvidence evaluateRemoval({
    required ToyTrack track,
    required SceneDescriptor scene,
    required List<double>? currentRegionEmbedding,
    required SpatialObservation spatial,
  }) {
    final backgroundReveal = backgroundRevealDetector.score(
      objectEmbedding: track.visualEmbedding,
      currentRegionEmbedding: currentRegionEmbedding,
    );
    final cameraTrackingGood =
        spatial.cameraTrackingGood && scene.motion <= 0.55;
    return SensorFusionEvidence(
      deviceMotion: spatial.normalizedMotion,
      backgroundRevealScore: backgroundReveal,
      depthChangeScore:
          spatial.depthAvailable ? spatial.depthChangeScore : null,
      cameraTrackingGood: cameraTrackingGood,
      motionAvailable: spatial.motionAvailable,
    );
  }
}
