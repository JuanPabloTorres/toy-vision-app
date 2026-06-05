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

  test('unknownToy counts as a toy without inventing a specific name', () {
    final result = rules.validate([
      FakeDetections.raw(label: 'unknownToy', confidence: 0.8),
    ]);
    expect(result, hasLength(1));
    expect(result.single.label, 'unknownToy');
    expect(result.single.displayName, 'Juguete');
  });

  test('uncertain detections do not count as confirmed toys', () {
    final result = rules.validate([
      FakeDetections.raw(label: 'uncertain', confidence: 0.99),
    ]);
    expect(result, isEmpty);
    expect(
      rules
          .isValidToy(FakeDetections.raw(label: 'uncertain', confidence: 0.99)),
      isFalse,
    );
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
    expect(reasons['blockedCategory'], 1);
    expect(reasons['lowConfidence'], 1);
    expect(reasons['unknownLabel'], 1);
  });

  test('rejectReason exposes the single-detection gate decision', () {
    expect(rules.rejectReason(FakeDetections.toyCar(confidence: 0.9)), isNull);
    expect(rules.rejectReason(FakeDetections.person()), 'blockedCategory');
    expect(
      rules.rejectReason(FakeDetections.lowConfidenceDoll()),
      'lowConfidence',
    );
    expect(rules.rejectReason(FakeDetections.unknownObject()), 'unknownLabel');
  });

  test('tooSmall gate is OFF by default (recall unchanged)', () {
    final tiny = FakeDetections.toyCar(
      confidence: 0.9,
      box: const BoundingBox(x: 0.5, y: 0.5, width: 0.02, height: 0.02),
    );
    // Default rules: no size gate → a valid, confident toy still passes.
    expect(rules.isValidToy(tiny), isTrue);
    expect(rules.rejectReason(tiny), isNull);
  });

  test('tooSmall gate rejects sub-threshold boxes when enabled', () {
    final gated = ToyDetectionRules(
      ToyCategoryRegistry.standard(),
      minimumBoxAreaFraction: 0.01, // 1% of the frame
    );
    final tiny = FakeDetections.toyCar(
      confidence: 0.9,
      box: const BoundingBox(x: 0.5, y: 0.5, width: 0.02, height: 0.02),
    );
    final big = FakeDetections.toyCar(
      confidence: 0.9,
      box: const BoundingBox(x: 0.2, y: 0.2, width: 0.3, height: 0.3),
    );
    expect(gated.rejectReason(tiny), 'tooSmall');
    expect(gated.isValidToy(big), isTrue);
  });
}
