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
    final cleanupWord = run('shirt on floor');
    expect(toyWord.accepted.length, cleanupWord.accepted.length);
    expect(
      toyWord.accepted.single.toyProbability,
      closeTo(cleanupWord.accepted.single.toyProbability, 1e-9),
    );
  });

  test('three small stable items survive normal detector box jitter', () {
    final fusion = ToyCandidateFusion();
    final start = DateTime.utc(2026);
    late CandidateFusionResult result;
    for (var frame = 0; frame < 3; frame++) {
      result = fusion.evaluate(
        _multiItemAnalysis(frame),
        frameId: frame,
        timestamp: start.add(Duration(milliseconds: frame * 200)),
        sceneContextScore: 1,
      );
    }

    expect(result.accepted, hasLength(3));
    expect(
      result.accepted.map((item) => item.spatialStability),
      everyElement(greaterThanOrEqualTo(0.8)),
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

  test('low-confidence proposal remains unconfirmed despite strong objectness',
      () {
    final fusion = ToyCandidateFusion();
    final start = DateTime.utc(2026);
    late CandidateFusionResult result;
    for (var frame = 0; frame < 3; frame++) {
      result = fusion.evaluate(
        _analysis(
          detectorConfidence: 0.14,
          proposalConfidence: 0.92,
        ),
        frameId: frame,
        timestamp: start.add(Duration(milliseconds: frame * 200)),
        sceneContextScore: 1,
      );
    }

    expect(result.accepted, isEmpty);
    expect(result.uncertain, hasLength(1));
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

FrameAnalysis _multiItemAnalysis(int frame) {
  final jitter = frame.isEven ? 0.0 : 0.018;
  return FrameAnalysis(
    embeddingExtractorIdentifier: 'test-embedding',
    candidates: [
      for (var index = 0; index < 3; index++)
        VisualCandidate(
          bounds: NormalizedBox(
            x: 0.08 + index * 0.30 + jitter,
            y: 0.62,
            width: 0.10,
            height: 0.10,
          ),
          detectorConfidence: 0.62,
          proposalConfidence: 0.35,
          embedding: [
            index == 0 ? 1 : 0,
            index == 1 ? 1 : 0,
            index == 2 ? 1 : 0,
          ],
          source: ObservationSource.detector,
          knownClass: index == 0 ? 'toy' : 'cleanup item',
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
}
