import 'bounding_box.dart';

/// A detection that has passed business validation (category known + counts as
/// toy, confidence above the category threshold, and a valid box).
///
/// Produced by ToyDetectionRules from a RawDetection. The tracking and counting
/// layers operate on these validated results, never on raw model output.
class DetectionResult {
  const DetectionResult({
    required this.label,
    required this.displayName,
    required this.confidence,
    required this.box,
  });

  final String label;
  final String displayName;
  final double confidence;
  final BoundingBox box;

  @override
  String toString() =>
      'DetectionResult(label: $label, confidence: ${confidence.toStringAsFixed(2)})';
}
