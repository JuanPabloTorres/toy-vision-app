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

  /// Debug-only sibling of [validate] that also accumulates a reject-reason
  /// histogram into [reasons]. Behavior on accepted detections is identical
  /// to [validate]; on rejections it increments one of:
  /// `unknown`, `not_toy`, `ignored`, `low_confidence`, `invalid_box`.
  ///
  /// Pure observation — no business decision differs. Used by the Phase 3.5.1
  /// debug diagnostics to surface why baseline detections never reach the UI.
  List<DetectionResult> validateWithReasons(
    List<RawDetection> raw,
    Map<String, int> reasons,
  ) {
    final results = <DetectionResult>[];
    for (final d in raw) {
      final reason = _rejectReason(d);
      if (reason == null) {
        final def = registry.lookup(d.label);
        results.add(
          DetectionResult(
            label: d.label,
            displayName: def.displayName,
            confidence: d.confidence,
            box: d.box,
          ),
        );
      } else {
        reasons.update(reason, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return results;
  }

  String? _rejectReason(RawDetection d) {
    if (!registry.isKnown(d.label)) return 'unknown';
    final def = registry.lookup(d.label);
    if (d.label == 'not_toy') return 'not_toy';
    if (def.isIgnored) return 'ignored';
    if (!def.countsAsToy) return 'not_toy';
    if (d.confidence < def.minimumConfidence) return 'low_confidence';
    if (!d.box.isValid) return 'invalid_box';
    return null;
  }
}
