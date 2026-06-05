import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/mission/scene_stability_service.dart';
import 'package:toyvision_realtime/detection/models/bounding_box.dart';
import 'package:toyvision_realtime/tracking/tracked_toy.dart';

TrackedToy _toy(
  int id, {
  double x = 0.1,
  double y = 0.1,
  String label = 'stuffed_animal',
}) =>
    TrackedToy(
      id: id,
      label: label,
      displayName: 'Juguete',
      box: BoundingBox(x: x, y: y, width: 0.2, height: 0.2),
      confidence: 0.9,
    );

void main() {
  late SceneStabilityService service;

  setUp(() {
    service = SceneStabilityService();
  });

  test('no anchors plus raw non-toy context is insufficient evidence', () {
    final status = service.evaluate(
      anchorBoxes: const {},
      visibleToys: const [],
      rawClassNames: const ['chair'],
    );

    expect(status, SceneStabilityStatus.insufficientEvidence);
  });

  test('no reliable anchors returns an explainable insufficient result', () {
    final result = service.evaluateDetailed(
      anchorBoxes: const {},
      visibleToys: const [],
      rawClassNames: const ['chair'],
      targetMissing: true,
    );

    expect(result.status, SceneStabilityStatus.insufficientEvidence);
    expect(
      result.reason,
      SceneStabilityReason.insufficientBecauseNoReliableAnchors,
    );
  });

  test('persisting anchors in nearly the same place means stable', () {
    final status = service.evaluate(
      anchorBoxes: const {
        2: BoundingBox(x: 0.6, y: 0.2, width: 0.2, height: 0.2),
      },
      visibleToys: [_toy(2, x: 0.61, y: 0.21)],
    );

    expect(status, SceneStabilityStatus.stable);
  });

  test('camera stable with anchors persisted becomes sustained stable', () {
    SceneStabilityResult result = service.evaluateDetailed(
      anchorBoxes: const {
        2: BoundingBox(x: 0.6, y: 0.2, width: 0.2, height: 0.2),
      },
      visibleToys: [_toy(2, x: 0.61, y: 0.21)],
    );
    for (var i = 0; i < 3; i++) {
      result = service.evaluateDetailed(
        anchorBoxes: const {
          2: BoundingBox(x: 0.6, y: 0.2, width: 0.2, height: 0.2),
        },
        visibleToys: [_toy(2, x: 0.61, y: 0.21)],
      );
    }

    expect(result.status, SceneStabilityStatus.stable);
    expect(
      result.reason,
      SceneStabilityReason.stableBecauseAnchorsPersisted,
    );
    expect(result.score, greaterThanOrEqualTo(0.75));
  });

  test('anchors disappearing while unrelated raw classes appear means moved',
      () {
    final status = service.evaluate(
      anchorBoxes: const {
        2: BoundingBox(x: 0.6, y: 0.2, width: 0.2, height: 0.2),
      },
      visibleToys: const [],
      rawClassNames: const ['chair', 'tv'],
    );

    expect(status, SceneStabilityStatus.probablyMoved);
  });

  test('camera moved with anchor loss explains the movement', () {
    final result = service.evaluateDetailed(
      anchorBoxes: const {
        2: BoundingBox(x: 0.6, y: 0.2, width: 0.2, height: 0.2),
      },
      visibleToys: const [],
      rawClassNames: const ['chair', 'tv'],
      targetMissing: true,
    );

    expect(result.status, SceneStabilityStatus.probablyMoved);
    expect(
      result.reason,
      SceneStabilityReason.movedBecauseUnrelatedRawAppearedAfterTargetLoss,
    );
  });

  test('anchors shifting too far means moved', () {
    final status = service.evaluate(
      anchorBoxes: const {
        2: BoundingBox(x: 0.2, y: 0.2, width: 0.2, height: 0.2),
      },
      visibleToys: [_toy(2, x: 0.72, y: 0.2)],
    );

    expect(status, SceneStabilityStatus.probablyMoved);
  });

  test('camera moved slowly with gradual spatial drift is still detected', () {
    const anchors = {
      2: BoundingBox(x: 0.2, y: 0.2, width: 0.2, height: 0.2),
      3: BoundingBox(x: 0.6, y: 0.2, width: 0.2, height: 0.2),
    };
    service.evaluateDetailed(
      anchorBoxes: anchors,
      visibleToys: [_toy(2, x: 0.24, y: 0.2), _toy(3, x: 0.64, y: 0.2)],
    );
    service.evaluateDetailed(
      anchorBoxes: anchors,
      visibleToys: [_toy(2, x: 0.32, y: 0.2), _toy(3, x: 0.72, y: 0.2)],
    );
    final result = service.evaluateDetailed(
      anchorBoxes: anchors,
      visibleToys: [_toy(2, x: 0.43, y: 0.2), _toy(3, x: 0.83, y: 0.2)],
    );

    expect(result.status, SceneStabilityStatus.probablyMoved);
    expect(
      result.reason,
      SceneStabilityReason.movedBecauseSpatialDistributionChanged,
    );
  });

  test('target disappears but the rest of the scene stays consistent', () {
    SceneStabilityResult result = service.evaluateDetailed(
      anchorBoxes: const {
        2: BoundingBox(x: 0.62, y: 0.2, width: 0.2, height: 0.2),
      },
      visibleToys: [_toy(2, x: 0.62, y: 0.2)],
      rawClassNames: const ['teddy bear'],
      targetMissing: true,
    );
    for (var i = 0; i < 3; i++) {
      result = service.evaluateDetailed(
        anchorBoxes: const {
          2: BoundingBox(x: 0.62, y: 0.2, width: 0.2, height: 0.2),
        },
        visibleToys: [_toy(2, x: 0.62, y: 0.2)],
        rawClassNames: const ['teddy bear'],
        targetMissing: true,
      );
    }

    expect(result.status, SceneStabilityStatus.stable);
    expect(
      result.reason,
      SceneStabilityReason
          .stableBecauseTargetDisappearedButSceneStayedConsistent,
    );
  });
}
