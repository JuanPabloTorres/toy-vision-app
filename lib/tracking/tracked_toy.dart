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

  /// Most recent class label/name. Mutable because the detector may relabel
  /// the same physical toy between frames (class flicker); the tracker keeps
  /// the identity ([id]) stable and just refreshes the label to the latest.
  String label;
  String displayName;

  BoundingBox box;
  double confidence;
  int framesSeen;
  int framesMissing;
  bool hasBeenCounted;

  /// Visible in the most recent processed frame.
  bool get isVisible => framesMissing == 0;
}
