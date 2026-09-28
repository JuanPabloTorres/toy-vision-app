import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/domain/toy/toy_observation.dart';
import 'package:toyvision_realtime/perception/fusion/toy_candidate_fusion.dart';
import 'package:toyvision_realtime/perception/perception_models.dart';

void main() {
  test('persistent open-set pixels remain unconfirmed without semantics', () {
    final fusion = ToyCandidateFusion();
    final start = DateTime.utc(2026);
    CandidateFusionResult? result;
    for (var frame = 0; frame < 3; frame++) {
      result = fusion.evaluate(
        _analysis(
          source: ObservationSource.openSetProposal,
          knownClass: frame == 1 ? 'definitely-not-a-toy-keyword' : null,
          detectorConfidence: 0,
          proposalConfidence: 0.92,
        ),
        frameId: frame,
        timestamp: start.add(Duration(milliseconds: frame * 200)),
        sceneContextScore: 1,
      );
    }
    expect(
      result!.accepted,
      isEmpty,
      reason: 'persistence and objectness do not establish toy semantics',
    );
    expect(result.uncertain, hasLength(1));
    expect(result.uncertain.single.source, ObservationSource.openSetProposal);
  });

  test('changing a class name cannot change a numeric fusion decision', () {
    CandidateFusionResult run(String label) {
      final fusion = ToyCandidateFusion();
      late CandidateFusionResult result;
      for (var frame = 0; frame < 3; frame++) {
        result = fusion.evaluate(
          _analysis(knownClass: label),
          frameId: frame,
          timestamp: DateTime.utc(2026).add(
            Duration(milliseconds: frame * 200),
          ),
          sceneContextScore: 1,
        );
      }
      return result;
    }

    final toyWord = run('toy car');
    final unrelatedWord = run('toilet');
    expect(toyWord.accepted.length, unrelatedWord.accepted.length);
    expect(
      toyWord.accepted.single.toyProbability,
      closeTo(unrelatedWord.accepted.single.toyProbability, 1e-9),
    );
  });

  test('persistent stable detector evidence can replace grid proposal support',
      () {
    final fusion = ToyCandidateFusion();
    final start = DateTime.utc(2026);
    late CandidateFusionResult result;
    for (var frame = 0; frame < 3; frame++) {
      result = fusion.evaluate(
        _analysis(
          detectorConfidence: 0.76,
          proposalConfidence: 0,
        ),
        frameId: frame,
        timestamp: start.add(Duration(milliseconds: frame * 200)),
        sceneContextScore: 1,
      );
    }

    expect(result.accepted, hasLength(1));
    expect(result.accepted.single.toyProbability, greaterThanOrEqualTo(0.70));
  });

  test('fused temporal evidence can confirm a moderate detector candidate', () {
    final fusion = ToyCandidateFusion();
    final start = DateTime.utc(2026);
    late CandidateFusionResult result;
    for (var frame = 0; frame < 3; frame++) {
      result = fusion.evaluate(
        _analysis(
          detectorConfidence: 0.63,
          proposalConfidence: 0,
        ),
        frameId: frame,
        timestamp: start.add(Duration(milliseconds: frame * 200)),
        sceneContextScore: 1,
      );
    }

    expect(result.accepted, hasLength(1));
    expect(result.accepted.single.toyProbability, greaterThanOrEqualTo(0.70));
  });

  test('persistence cannot promote weak detector evidence by itself', () {
    final fusion = ToyCandidateFusion();
    final start = DateTime.utc(2026);
    late CandidateFusionResult result;
    for (var frame = 0; frame < 3; frame++) {
      result = fusion.evaluate(
        _analysis(
          detectorConfidence: 0.49,
          proposalConfidence: 0,
        ),
        frameId: frame,
        timestamp: start.add(Duration(milliseconds: frame * 200)),
        sceneContextScore: 1,
      );
    }

    expect(result.accepted, isEmpty);
    expect(
      result.uncertain.single.confirmationBlockers,
      contains('semantic_confidence_insufficient'),
    );
  });

  test('candidate stability recovers after a camera pan settles', () {
    final fusion = ToyCandidateFusion();
    final start = DateTime.utc(2026);
    late CandidateFusionResult result;
    for (var frame = 0; frame < 10; frame++) {
      result = fusion.evaluate(
        _analysis(
          detectorConfidence: 0.72,
          proposalConfidence: 0,
          x: 0.20 + frame * 0.02,
        ),
        frameId: frame,
        timestamp: start.add(Duration(milliseconds: frame * 200)),
        sceneContextScore: 0.55,
      );
    }
    expect(result.accepted, isEmpty);

    for (var frame = 10; frame < 13; frame++) {
      result = fusion.evaluate(
        _analysis(
          detectorConfidence: 0.72,
          proposalConfidence: 0,
          x: 0.38,
        ),
        frameId: frame,
        timestamp: start.add(Duration(milliseconds: frame * 200)),
        sceneContextScore: 1,
      );
    }

    expect(result.accepted, hasLength(1));
    expect(result.accepted.single.spatialStability, greaterThanOrEqualTo(0.8));
  });
}

FrameAnalysis _analysis({
  ObservationSource source = ObservationSource.detector,
  String? knownClass,
  double detectorConfidence = 0.9,
  double proposalConfidence = 0.8,
  double x = 0.2,
}) =>
    FrameAnalysis(
      embeddingExtractorIdentifier: 'test-embedding',
      candidates: [
        VisualCandidate(
          bounds: NormalizedBox(x: x, y: 0.2, width: 0.2, height: 0.2),
          detectorConfidence: detectorConfidence,
          proposalConfidence: proposalConfidence,
          embedding: const [1, 0, 0, 0],
          source: source,
          knownClass: knownClass,
        ),
      ],
      sceneEmbedding: const [1, 0],
      trackedRegionEmbeddings: const {},
      sharpness: 0.2,
      luminance: 0.5,
      coverage: 1,
      sourceWidth: 320,
      sourceHeight: 240,
      decodeAndEmbeddingUs: 100,
    );
