import 'scene_stability_service.dart';

/// The single, immutable source of truth for **what the camera saw this
/// frame** — the mission's "vision" at one instant.
///
/// FASE 3 of the mission refactor: before this object, the truth about
/// visible toys lived scattered across controller fields (`_lastVisibleIds`,
/// the overlay list, the completion evidence). The overlay and the completion
/// guard derived "is a toy on screen?" independently, so they *could* drift —
/// the painter could draw a green box while the guard believed the area was
/// clean. That divergence is exactly the bug the plan forbids:
///
///   greenOverlayDetections.isNotEmpty  =>  canCompleteMission = false
///
/// By routing BOTH the overlay and the guard through this one per-frame
/// snapshot, the invariant becomes structural: [greenOverlayCount] is the
/// exact number of toy boxes the painter draws, and the guard reads the same
/// number. They cannot disagree because there is only one source.
class MissionVisionSnapshot {
  const MissionVisionSnapshot({
    required this.frameIndex,
    required this.rawDetectionCount,
    required this.mappedDetectionCount,
    required this.visibleToyCount,
    required this.greenOverlayCount,
    required this.activeTargetId,
    required this.pendingPickupTargetId,
    required this.sceneStability,
  });

  /// Frame counter at the moment this snapshot was taken.
  final int frameIndex;

  /// Objects YOLO returned this frame (toy or not). 0 = a blank/covered view.
  final int rawDetectionCount;

  /// How many raw detections survived the toy mapper (non-toy COCO dropped).
  final int mappedDetectionCount;

  /// Validated, tracked toys visible this frame — the set the completion
  /// guard treats as "toys still on the floor".
  final int visibleToyCount;

  /// Toy boxes the [DetectionOverlayPainter] will actually draw this frame.
  /// During a scan/clean-area sweep this is the visible tracked toys; while
  /// guiding it is the single "Recoge este" target when on-screen, else 0.
  /// This is the field that makes "green box ⇒ cannot complete" structural.
  final int greenOverlayCount;

  /// The toy currently selected as the pick-up target, or null.
  final int? activeTargetId;

  /// A target awaiting clean-area verification (lost without a confident
  /// auto-collect). While set, the mission cannot complete. Null otherwise.
  final int? pendingPickupTargetId;

  /// Temporal scene-stability verdict for this frame, if evaluated.
  final SceneStabilityStatus? sceneStability;

  /// The neutral starting snapshot: nothing seen, no target.
  static const MissionVisionSnapshot empty = MissionVisionSnapshot(
    frameIndex: 0,
    rawDetectionCount: 0,
    mappedDetectionCount: 0,
    visibleToyCount: 0,
    greenOverlayCount: 0,
    activeTargetId: null,
    pendingPickupTargetId: null,
    sceneStability: null,
  );

  /// A toy box is being painted right now → the area is provably NOT clean.
  bool get hasGreenOverlay => greenOverlayCount > 0;

  /// A validated toy is on screen this frame.
  bool get hasVisibleToys => visibleToyCount > 0;

  /// The camera saw real context this frame (not a blank/covered view).
  bool get sawArea => rawDetectionCount > 0;

  /// There is a target or a pickup awaiting verification — the mission is
  /// mid-toy and must not complete.
  bool get hasUnresolvedTarget =>
      activeTargetId != null || pendingPickupTargetId != null;
}
