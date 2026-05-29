import '../detection/models/bounding_box.dart';

/// Identity of a single toy followed across frames.
///
/// The tracking engine owns the lifecycle of these objects. `framesSeen`
/// supports stability decisions; `framesMissing` supports brief-disappearance
/// handling; `hasBeenCounted` prevents the counting service from counting the
/// same physical toy more than once.
class TrackedToy {
  TrackedToy({
    required this.id,
    required this.label,
    required this.displayName,
    required this.box,
    required this.confidence,
    this.framesSeen = 1,
    this.framesMissing = 0,
    this.hasBeenCounted = false,
  });

  final int id;
  final String label;
  final String displayName;

  BoundingBox box;
  double confidence;
  int framesSeen;
  int framesMissing;
  bool hasBeenCounted;

  /// Visible in the most recent processed frame.
  bool get isVisible => framesMissing == 0;
}
