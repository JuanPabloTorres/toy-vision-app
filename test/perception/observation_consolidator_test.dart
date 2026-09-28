import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/domain/toy/toy_observation.dart';
import 'package:toyvision_realtime/perception/fusion/observation_consolidator.dart';

void main() {
  test('collapses nested observations of one physical object', () {
    const consolidator = ObservationConsolidator();
    final result = consolidator.consolidate(
      accepted: [
        _observation(
          const NormalizedBox(x: 0.20, y: 0.20, width: 0.30, height: 0.30),
          probability: 0.94,
        ),
        _observation(
          const NormalizedBox(x: 0.21, y: 0.21, width: 0.28, height: 0.28),
          probability: 0.83,
        ),
      ],
      uncertain: const [],
    );

    expect(result.accepted, hasLength(1));
    expect(result.accepted.single.toyProbability, 0.94);
  });

  test('preserves separate neighboring physical objects', () {
    const consolidator = ObservationConsolidator();
    final result = consolidator.consolidate(
      accepted: [
        _observation(
          const NormalizedBox(x: 0.10, y: 0.20, width: 0.25, height: 0.25),
        ),
        _observation(
          const NormalizedBox(x: 0.32, y: 0.20, width: 0.25, height: 0.25),
        ),
      ],
      uncertain: const [],
    );

    expect(result.accepted, hasLength(2));
  });
}

ToyObservation _observation(
  NormalizedBox bounds, {
  double probability = 0.9,
}) =>
    ToyObservation(
      bounds: bounds,
      detectionConfidence: probability,
      proposalConfidence: 0.8,
      embeddingSimilarity: 0.9,
      temporalPersistence: 1,
      spatialStability: 1,
      sceneContextScore: 1,
      toyProbability: probability,
      stage: ToyEvidenceStage.confirmedToy,
      embedding: const [1, 0],
      frameId: 1,
      timestamp: DateTime.utc(2026),
      source: ObservationSource.detector,
    );
