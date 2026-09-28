import '../../domain/scene/scene_state.dart';
import '../../domain/toy/toy_track.dart';
import '../perception_models.dart';

class OcclusionReasoner {
  const OcclusionReasoner();

  bool isOccluded(
    ToyTrack track,
    FrameAnalysis analysis,
    SceneState sceneState,
  ) {
    if (sceneState != SceneState.stable || analysis.isObscured) return true;
    for (final candidate in analysis.candidates) {
      final overlap = track.lastBounds.intersectionOverUnion(candidate.bounds);
      if (overlap >= 0.45 &&
          candidate.bounds.area >= track.lastBounds.area * 1.35) {
        return true;
      }
    }
    return false;
  }
}
