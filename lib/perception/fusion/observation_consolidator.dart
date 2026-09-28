import '../../domain/toy/toy_observation.dart';

class ConsolidatedObservations {
  ConsolidatedObservations({
    required List<ToyObservation> accepted,
    required List<ToyObservation> uncertain,
  })  : accepted = List.unmodifiable(accepted),
        uncertain = List.unmodifiable(uncertain);

  final List<ToyObservation> accepted;
  final List<ToyObservation> uncertain;

  List<ToyObservation> get all => [...accepted, ...uncertain];
}

/// Collapses multiple hypotheses that describe the same physical region.
///
/// Native detectors can emit nested boxes and the hybrid proposal path can
/// describe that same object again. Those are hypotheses, not extra toys. The
/// consolidation is label-free and only merges regions with very strong
/// geometric agreement, preserving nearby toys as separate observations.
class ObservationConsolidator {
  const ObservationConsolidator({
    this.minimumIntersectionOverUnion = 0.62,
    this.minimumContainment = 0.90,
    this.minimumCentroidSimilarity = 0.94,
  });

  final double minimumIntersectionOverUnion;
  final double minimumContainment;
  final double minimumCentroidSimilarity;

  ConsolidatedObservations consolidate({
    required Iterable<ToyObservation> accepted,
    required Iterable<ToyObservation> uncertain,
  }) {
    final ranked = [...accepted, ...uncertain]
      ..sort((left, right) => _priority(right).compareTo(_priority(left)));
    final kept = <ToyObservation>[];
    for (final candidate in ranked) {
      final duplicate = kept.any((existing) {
        final iou = existing.bounds.intersectionOverUnion(candidate.bounds);
        final containment =
            existing.bounds.intersectionOverSmaller(candidate.bounds);
        final centroid = existing.bounds.centroidSimilarity(candidate.bounds);
        return centroid >= minimumCentroidSimilarity &&
            (iou >= minimumIntersectionOverUnion ||
                containment >= minimumContainment);
      });
      if (!duplicate) kept.add(candidate);
    }
    return ConsolidatedObservations(
      accepted:
          kept.where((observation) => observation.isConfirmedToy).toList(),
      uncertain:
          kept.where((observation) => !observation.isConfirmedToy).toList(),
    );
  }

  double _priority(ToyObservation observation) {
    final confirmed = observation.isConfirmedToy ? 10.0 : 0.0;
    final semantic =
        observation.source == ObservationSource.openSetProposal ? 0.0 : 2.0;
    return confirmed +
        semantic +
        observation.toyProbability +
        observation.detectionConfidence * 0.5 +
        observation.spatialStability * 0.25;
  }
}
