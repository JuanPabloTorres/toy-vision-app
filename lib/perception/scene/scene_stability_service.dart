import '../../core/math/vector_math.dart';
import '../../domain/scene/scene_descriptor.dart';
import '../../domain/scene/scene_state.dart';
import '../perception_models.dart';

class SceneStabilityService {
  List<double>? _previousEmbedding;
  List<double>? _stableAnchorEmbedding;
  int _stableFrames = 0;

  SceneDescriptor evaluate(
    FrameAnalysis analysis,
    DateTime timestamp, {
    bool allowAnchorUpdate = true,
  }) {
    final previous = _previousEmbedding;
    final rawSimilarity = previous == null
        ? 0.0
        : cosineSimilarity(previous, analysis.sceneEmbedding);
    final similarity = rawSimilarity.clamp(0.0, 1.0);
    final motion = (1 - similarity).clamp(0.0, 1.0);
    late final SceneState state;
    if (analysis.isObscured) {
      state = SceneState.obscured;
      _stableFrames = 0;
    } else if (previous == null) {
      state = SceneState.unstable;
      _stableFrames = 0;
    } else if (similarity < 0.58) {
      state = SceneState.changed;
      _stableFrames = 0;
    } else if (similarity < 0.88 || analysis.sharpness < 0.0025) {
      state = SceneState.moving;
      _stableFrames = 0;
    } else {
      _stableFrames += 1;
      state = _stableFrames >= 2 ? SceneState.stable : SceneState.unstable;
      if (_stableFrames >= 2 &&
          (_stableAnchorEmbedding == null || allowAnchorUpdate)) {
        _stableAnchorEmbedding = List<double>.from(analysis.sceneEmbedding);
      }
    }
    final anchor = _stableAnchorEmbedding;
    final anchorSimilarity = anchor == null
        ? 0.0
        : cosineSimilarity(anchor, analysis.sceneEmbedding).clamp(0.0, 1.0);
    _previousEmbedding = analysis.sceneEmbedding;
    return SceneDescriptor(
      embedding: analysis.sceneEmbedding,
      state: state,
      similarityToPrevious: similarity,
      motion: motion,
      sharpness: analysis.sharpness,
      luminance: analysis.luminance,
      coverage: analysis.coverage,
      timestamp: timestamp,
      stableFrameCount: _stableFrames,
      similarityToStableAnchor: anchorSimilarity,
    );
  }

  void reset() {
    _previousEmbedding = null;
    _stableAnchorEmbedding = null;
    _stableFrames = 0;
  }
}
