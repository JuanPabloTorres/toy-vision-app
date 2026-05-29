import '../detection/models/detection_result.dart';
import '../detection/models/raw_detection.dart';
import 'toy_category_registry.dart';

/// Validates raw detections against category, confidence, and box rules.
///
/// This is the first half of the counting decision: it turns raw model output
/// into validated [DetectionResult]s, discarding anything that is not a known,
/// countable toy with sufficient confidence and a valid box. People, pets, and
/// other ignored categories are filtered here and never reach tracking.
class ToyDetectionRules {
  const ToyDetectionRules(this.registry);

  final ToyCategoryRegistry registry;

  /// Keep only detections that pass category + confidence + box validation.
  List<DetectionResult> validate(List<RawDetection> raw) {
    final results = <DetectionResult>[];
    for (final d in raw) {
      if (isValidToy(d)) {
        final def = registry.lookup(d.label);
        results.add(
          DetectionResult(
            label: d.label,
            displayName: def.displayName,
            confidence: d.confidence,
            box: d.box,
          ),
        );
      }
    }
    return results;
  }

  /// True only when [d] passes every per-detection gate:
  /// known label, counts as toy, not ignored, confidence >= threshold,
  /// and a valid bounding box.
  bool isValidToy(RawDetection d) {
    final def = registry.lookup(d.label);
    if (def.isIgnored) return false;
    if (!def.countsAsToy) return false;
    if (d.confidence < def.minimumConfidence) return false;
    if (!d.box.isValid) return false;
    return true;
  }
}
