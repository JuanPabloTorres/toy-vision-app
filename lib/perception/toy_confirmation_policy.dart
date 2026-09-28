/// Corpus-calibratable safety policy. Every gate is applied globally; none is
/// selected from an individual acceptance example.
class ToyConfirmationPolicy {
  const ToyConfirmationPolicy({
    required this.minimumSemanticConfidence,
    required this.veryStrongSemanticConfidence,
    required this.minimumProposalSupport,
    required this.minimumSpatialStability,
    required this.minimumFusedToyProbability,
    required this.maximumSceneMaskObjectArea,
    required this.maximumSceneMaskCoverage,
  });

  static const conservative = ToyConfirmationPolicy(
    minimumSemanticConfidence: 0.68,
    veryStrongSemanticConfidence: 0.86,
    minimumProposalSupport: 0.20,
    minimumSpatialStability: 0.80,
    minimumFusedToyProbability: 0.70,
    maximumSceneMaskObjectArea: 0.35,
    maximumSceneMaskCoverage: 0.45,
  );

  final double minimumSemanticConfidence;
  final double veryStrongSemanticConfidence;
  final double minimumProposalSupport;
  final double minimumSpatialStability;
  final double minimumFusedToyProbability;
  final double maximumSceneMaskObjectArea;
  final double maximumSceneMaskCoverage;
}
