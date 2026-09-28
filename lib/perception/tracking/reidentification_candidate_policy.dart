import '../../core/math/vector_math.dart';
import '../../domain/toy/toy_observation.dart';
import '../../domain/toy/toy_track.dart';

/// Decides whether a current observation can plausibly be the same physical
/// toy as a missing confirmed track.
///
/// Open-set grid regions are deliberately excluded. They describe visually
/// interesting pixels but carry no semantic evidence that a toy reappeared;
/// allowing them here made ordinary floor/background patches permanently
/// block otherwise valid pickup verification.
class ReidentificationCandidatePolicy {
  const ReidentificationCandidatePolicy();

  bool hasPlausibleCandidate({
    required ToyTrack missingTrack,
    required Iterable<ToyObservation> observations,
  }) {
    for (final observation in observations) {
      if (observation.source == ObservationSource.openSetProposal) continue;
      final embedding = cosineSimilarity(
        observation.embedding,
        missingTrack.visualEmbedding,
      );
      final nearby = observation.bounds.centroidSimilarity(
            missingTrack.lastBounds,
          ) >=
          0.72;
      final compatibleSize = observation.bounds.sizeSimilarity(
            missingTrack.lastBounds,
          ) >=
          0.25;
      if ((nearby && embedding >= 0.82) ||
          (compatibleSize && embedding >= 0.90)) {
        return true;
      }
    }
    return false;
  }
}
