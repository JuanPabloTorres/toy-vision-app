import '../detection/models/bounding_box.dart';
import '../detection/models/raw_detection.dart';

/// Builders for deterministic fake detections used in unit and scenario tests.
///
/// Keeping these in the app (not just under test/) lets future tooling and
/// debug builds reuse the same fixtures the tests rely on.
class FakeDetections {
  FakeDetections._();

  static BoundingBox box({
    double x = 0.1,
    double y = 0.1,
    double width = 0.2,
    double height = 0.2,
  }) =>
      BoundingBox(x: x, y: y, width: width, height: height);

  static RawDetection raw({
    String label = 'toy_car',
    double confidence = 0.9,
    BoundingBox? box,
  }) =>
      RawDetection(
        label: label,
        confidence: confidence,
        box: box ?? FakeDetections.box(),
      );

  static RawDetection toyCar({double confidence = 0.9, BoundingBox? box}) =>
      raw(label: 'toy_car', confidence: confidence, box: box);

  static RawDetection person({BoundingBox? box}) =>
      raw(label: 'person', confidence: 0.97, box: box);

  /// A registered toy label below its confidence threshold (stuffed_animal
  /// requires ≥0.40; 0.30 triggers the `low_confidence` reject bucket).
  /// Kept under the historical name so existing call-sites don't churn.
  static RawDetection lowConfidenceDoll({BoundingBox? box}) =>
      raw(label: 'stuffed_animal', confidence: 0.30, box: box);

  static RawDetection unknownObject({BoundingBox? box}) =>
      raw(label: 'spaceship', confidence: 0.99, box: box);
}
