import '../../domain/toy/toy_observation.dart';
import '../embeddings/toy_prototype_store.dart';
import '../perception_models.dart';
import '../toy_confirmation_policy.dart';
import 'candidate_temporal_memory.dart';
import 'observation_consolidator.dart';

class CandidateFusionResult {
  CandidateFusionResult({
    required List<ToyObservation> accepted,
    required List<ToyObservation> uncertain,
  })  : accepted = List.unmodifiable(accepted),
        uncertain = List.unmodifiable(uncertain);

  final List<ToyObservation> accepted;
  final List<ToyObservation> uncertain;
}

/// Fuses numeric evidence only. Detector labels are retained for diagnostics
/// and child-friendly descriptions but never participate in acceptance.
class ToyCandidateFusion {
  ToyCandidateFusion({
    ToyPrototypeStore? prototypeStore,
    CandidateTemporalMemory? temporalMemory,
    ObservationConsolidator? observationConsolidator,
    this.policy = ToyConfirmationPolicy.conservative,
    this.uncertaintyThreshold = 0.42,
  })  : prototypeStore = prototypeStore ?? ToyPrototypeStore(),
        temporalMemory = temporalMemory ?? CandidateTemporalMemory(),
        observationConsolidator =
            observationConsolidator ?? const ObservationConsolidator();

  final ToyPrototypeStore prototypeStore;
  final CandidateTemporalMemory temporalMemory;
  final ObservationConsolidator observationConsolidator;
  final ToyConfirmationPolicy policy;
  final double uncertaintyThreshold;

  CandidateFusionResult evaluate(
    FrameAnalysis analysis, {
    required int frameId,
    required DateTime timestamp,
    required double sceneContextScore,
  }) {
    final temporalEvidence = temporalMemory.scoreAndUpdate(
      analysis.candidates,
      timestamp,
    );
    final accepted = <ToyObservation>[];
    final uncertain = <ToyObservation>[];
    for (var index = 0; index < analysis.candidates.length; index++) {
      final candidate = analysis.candidates[index];
      final prototypeSimilarity =
          prototypeStore.nearestSimilarity(candidate.embedding);
      final isOpenSet = candidate.source == ObservationSource.openSetProposal;
      // The perceptual embedding is an identity descriptor, not a semantic
      // toy classifier. Consequently prototype similarity may help explain
      // identity but cannot bootstrap or confirm toy-likeness.
      final score = (isOpenSet
              ? temporalEvidence[index].persistence * 0.45 +
                  candidate.proposalConfidence * 0.35 +
                  sceneContextScore * 0.20
              : candidate.detectorConfidence * 0.45 +
                  temporalEvidence[index].persistence * 0.20 +
                  temporalEvidence[index].spatialStability * 0.15 +
                  candidate.proposalConfidence * 0.10 +
                  sceneContextScore * 0.10)
          .clamp(0.0, 1.0);
      final blockers = <String>[
        if (isOpenSet) 'semantic_evidence_unavailable',
        if (!isOpenSet &&
            candidate.detectorConfidence < policy.minimumSemanticConfidence &&
            score < policy.minimumFusedToyProbability)
          'semantic_confidence_insufficient',
        if (temporalEvidence[index].persistence < 1)
          'temporal_confirmation_incomplete',
        if (temporalEvidence[index].spatialStability <
            policy.minimumSpatialStability)
          'object_not_spatially_stable',
        if (sceneContextScore < 0.9) 'scene_not_stable',
        if (!isOpenSet &&
            candidate.detectorConfidence <
                policy.veryStrongSemanticConfidence &&
            candidate.proposalConfidence < policy.minimumProposalSupport &&
            score < policy.minimumFusedToyProbability)
          'independent_object_proposal_missing',
      ];
      final confirmed = blockers.isEmpty;
      final observation = ToyObservation(
        bounds: candidate.bounds,
        detectionConfidence: candidate.detectorConfidence,
        proposalConfidence: candidate.proposalConfidence,
        embeddingSimilarity: prototypeSimilarity,
        temporalPersistence: temporalEvidence[index].persistence,
        spatialStability: temporalEvidence[index].spatialStability,
        sceneContextScore: sceneContextScore,
        toyProbability: score,
        stage: confirmed
            ? ToyEvidenceStage.confirmedToy
            : ToyEvidenceStage.candidate,
        confirmationBlockers: blockers,
        knownClass: candidate.knownClass,
        embedding: candidate.embedding,
        frameId: frameId,
        timestamp: timestamp,
        source: candidate.source,
      );
      if (confirmed) {
        accepted.add(observation);
        prototypeStore.learn(candidate.embedding);
      } else if (score >= uncertaintyThreshold) {
        uncertain.add(observation);
      }
    }
    final consolidated = observationConsolidator.consolidate(
      accepted: accepted,
      uncertain: uncertain,
    );
    return CandidateFusionResult(
      accepted: consolidated.accepted,
      uncertain: consolidated.uncertain,
    );
  }

  void reset() {
    prototypeStore.clear();
    temporalMemory.clear();
  }
}
