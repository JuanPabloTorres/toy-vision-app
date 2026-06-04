import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/toy_category_registry.dart';
import 'package:toyvision_realtime/business/toy_detection_rules.dart';
import 'package:toyvision_realtime/detection/models/bounding_box.dart';
import 'package:toyvision_realtime/testing/fake_detections.dart';

void main() {
  final rules = ToyDetectionRules(ToyCategoryRegistry.standard());

  test('keeps a valid, confident toy', () {
    final result = rules.validate([FakeDetections.toyCar(confidence: 0.9)]);
    expect(result, hasLength(1));
    expect(result.single.label, 'toy_car');
    expect(result.single.displayName, 'Carrito');
  });

  test('rejects a person (ignored category)', () {
    expect(rules.validate([FakeDetections.person()]), isEmpty);
  });

  test('rejects a toy below its confidence threshold', () {
    expect(rules.validate([FakeDetections.lowConfidenceDoll()]), isEmpty);
    expect(rules.isValidToy(FakeDetections.lowConfidenceDoll()), isFalse);
  });

  test('rejects an unknown label', () {
    expect(rules.validate([FakeDetections.unknownObject()]), isEmpty);
  });

  test('rejects an invalid bounding box', () {
    final degenerate = FakeDetections.raw(
      box: const BoundingBox(x: 0.1, y: 0.1, width: 0, height: 0.2),
    );
    final outOfFrame = FakeDetections.raw(
      box: const BoundingBox(x: 0.9, y: 0.1, width: 0.5, height: 0.2),
    );
    expect(rules.isValidToy(degenerate), isFalse);
    expect(rules.isValidToy(outOfFrame), isFalse);
  });

  test('filters a mixed frame down to only valid toys', () {
    final result = rules.validate([
      FakeDetections.toyCar(confidence: 0.9),
      FakeDetections.person(),
      FakeDetections.lowConfidenceDoll(),
      FakeDetections.unknownObject(),
    ]);
    expect(result, hasLength(1));
    expect(result.single.label, 'toy_car');
  });

  test('validateWithReasons attributes each rejection to a reason bucket', () {
    final reasons = <String, int>{};
    final result = rules.validateWithReasons(
      [
        FakeDetections.toyCar(confidence: 0.9),
        FakeDetections.person(),
        FakeDetections.lowConfidenceDoll(),
        FakeDetections.unknownObject(),
      ],
      reasons,
    );
    expect(result, hasLength(1));
    expect(result.single.label, 'toy_car');
    expect(reasons['ignored'], 1);
    expect(reasons['low_confidence'], 1);
    expect(reasons['unknown'], 1);
  });
}
