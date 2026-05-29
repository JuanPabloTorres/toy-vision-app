import 'bounding_box.dart';

/// A single raw detection emitted by a [ToyDetector].
///
/// This is the unprocessed model output: label, confidence, and box only.
/// It carries no judgement about whether it counts as a toy — that decision
/// belongs to the business layer (ToyDetectionRules), never the detector.
class RawDetection {
  const RawDetection({
    required this.label,
    required this.confidence,
    required this.box,
  });

  final String label;
  final double confidence;
  final BoundingBox box;

  @override
  String toString() =>
      'RawDetection(label: $label, confidence: ${confidence.toStringAsFixed(2)})';
}
