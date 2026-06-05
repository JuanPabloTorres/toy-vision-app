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
  const ToyDetectionRules(
    this.registry, {
    this.minimumBoxAreaFraction = 0.0,
  });

  final ToyCategoryRegistry registry;

  /// Optional minimum box area (as a fraction of the frame, width·height in
  /// `[0,1]` space) below which a detection is rejected as `tooSmall`. Default
  /// `0` keeps the gate OFF so recall is unchanged — it exists so the Detection
  /// Recall Lab can attribute a real reason if tiny noise boxes need filtering.
  final double minimumBoxAreaFraction;

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

  /// True only when [d] passes every per-detection gate. Defined as "has no
  /// reject reason" so the accept decision and the diagnostic reason can never
  /// disagree (single source of truth).
  bool isValidToy(RawDetection d) => _rejectReason(d) == null;

  /// Debug-only sibling of [validate] that also accumulates a reject-reason
  /// histogram into [reasons]. Behavior on accepted detections is identical
  /// to [validate]; on rejections it increments one of the recall-lab reasons:
  /// `unknownLabel`, `notToyLabel`, `blockedCategory`, `lowConfidence`,
  /// `invalidBoundingBox`, `tooSmall`.
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

  /// Returns the same reject reason used by [validateWithReasons] for a single
  /// mapped detection. Null means the detection is a valid toy.
  String? rejectReason(RawDetection detection) => _rejectReason(detection);

  String? _rejectReason(RawDetection d) {
    if (!registry.isKnown(d.label)) return 'unknownLabel';
    final def = registry.lookup(d.label);
    if (d.label == 'not_toy') return 'notToyLabel';
    if (def.isIgnored) return 'blockedCategory';
    if (!def.countsAsToy) return 'notToyLabel';
    if (d.confidence < def.minimumConfidence) return 'lowConfidence';
    if (!d.box.isValid) return 'invalidBoundingBox';
    if (minimumBoxAreaFraction > 0 &&
        d.box.width * d.box.height < minimumBoxAreaFraction) {
      return 'tooSmall';
    }
    return null;
  }
}
