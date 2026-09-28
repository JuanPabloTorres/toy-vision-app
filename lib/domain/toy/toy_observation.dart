import 'normalized_box.dart';

enum ObservationSource { detector, openSetProposal, fused }

/// Perception lifecycle. A geometric region is never a toy by implication.
enum ToyEvidenceStage { proposal, candidate, confirmedToy }

/// Numeric perception evidence for one physical-object hypothesis.
class ToyObservation {
  ToyObservation({
    required this.bounds,
    required this.detectionConfidence,
    required this.proposalConfidence,
    required this.embeddingSimilarity,
    required this.temporalPersistence,
    required this.spatialStability,
    required this.sceneContextScore,
    required this.toyProbability,
    required this.stage,
    required List<double> embedding,
    List<String> confirmationBlockers = const [],
    required this.frameId,
    required this.timestamp,
    required this.source,
    this.knownClass,
  })  : embedding = List<double>.unmodifiable(embedding),
        confirmationBlockers = List<String>.unmodifiable(confirmationBlockers);

  final NormalizedBox bounds;
  final double detectionConfidence;
  final double proposalConfidence;
  final double embeddingSimilarity;
  final double temporalPersistence;
  final double spatialStability;
  final double sceneContextScore;
  final double toyProbability;
  final ToyEvidenceStage stage;
  final List<String> confirmationBlockers;
  final String? knownClass;
  final List<double> embedding;
  final int frameId;
  final DateTime timestamp;
  final ObservationSource source;

  bool get isConfirmedToy => stage == ToyEvidenceStage.confirmedToy;
}
