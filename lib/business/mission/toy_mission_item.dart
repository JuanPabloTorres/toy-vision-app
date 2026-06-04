import '../../detection/models/bounding_box.dart';

/// Where a mission toy came from. The model only ever produces
/// [automaticDetection]; [childTap] is the fallback when the child taps a
/// toy the model missed. There is no adult "configure the area" step.
enum ToySource { automaticDetection, childTap }

/// Lifecycle of a single toy inside a live mission.
enum ToyItemStatus { pending, currentTarget, collected, skipped, lost }

/// A single toy the mission is tracking — the unit the child is guided to
/// pick up. Unlike the old frozen snapshot, the mission's toy list is
/// **living**: it grows as re-scans discover more toys, and items keep
/// their last-known [box] so the highlight can be drawn even when the model
/// loses sight of the toy for a few frames.
///
/// [box] is in normalized 0..1 coordinates so it re-draws correctly at any
/// preview size or after the detector drops/re-acquires the toy.
class ToyMissionItem {
  ToyMissionItem({
    required this.toyId,
    required this.source,
    required this.box,
    required this.orderIndex,
    required this.firstSeenFrame,
    this.label = 'toy',
    this.confidence = 1.0,
    this.status = ToyItemStatus.pending,
    int? lastSeenFrame,
    this.collectedAtFrame,
  }) : lastSeenFrame = lastSeenFrame ?? firstSeenFrame;

  final int toyId;
  final ToySource source;

  /// Generic label — the mission counts and guides, it does not classify.
  final String label;

  /// Last-known normalized box. Mutated when the live tracker re-acquires
  /// this toy so the highlight follows it.
  BoundingBox box;
  double confidence;

  /// Stable visual order (left→right, top→bottom roughly via insertion).
  final int orderIndex;

  ToyItemStatus status;

  /// Frame indices (the controller's monotonic frame counter) — used to
  /// decide visibility/target-lost without a wall clock (test-friendly).
  final int firstSeenFrame;
  int lastSeenFrame;
  int? collectedAtFrame;

  double get centerX => box.centerX;
  double get centerY => box.centerY;

  bool get isCollected => status == ToyItemStatus.collected;
  bool get isPending => status == ToyItemStatus.pending;
}
