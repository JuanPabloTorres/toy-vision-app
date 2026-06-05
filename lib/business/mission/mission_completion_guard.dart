import 'scene_stability_service.dart';

class TargetCollectionEvidence {
  const TargetCollectionEvidence({
    required this.missedFrames,
    required this.requiredMissedFrames,
    required this.timeSinceLastSeen,
    required this.requiredTimeSinceLastSeen,
    required this.sceneStability,
    required this.targetStillVisibleNearby,
    required this.hasNewUncollectedVisible,
    this.sceneHadAnchors = true,
  });

  final int missedFrames;
  final int requiredMissedFrames;
  final Duration timeSinceLastSeen;
  final Duration requiredTimeSinceLastSeen;
  final SceneStabilityStatus sceneStability;
  final bool targetStillVisibleNearby;
  final bool hasNewUncollectedVisible;

  /// Whether the scene had reliable anchors (other tracked objects) when the
  /// target was last seen. The lone-toy base case has NONE — there is nothing
  /// to prove the camera held still — so the scene check can only return
  /// `insufficientEvidence`. Defaults to `true` so existing callers keep the
  /// strict "needs a stable scene" behavior; the lone-toy fallback only opens
  /// when this is explicitly `false`.
  final bool sceneHadAnchors;
}

class MissionCompletionEvidence {
  const MissionCompletionEvidence({
    required this.pendingToyCount,
    required this.visibleToyCount,
    required this.validatedToyDetectionsInSweep,
    required this.sceneStability,
    required this.sawOnlyRawNonToyDetections,
    this.greenOverlayDetectionCount = 0,
  });

  final int pendingToyCount;
  final int visibleToyCount;
  final int validatedToyDetectionsInSweep;
  final SceneStabilityStatus sceneStability;
  final bool sawOnlyRawNonToyDetections;

  /// Toy boxes the overlay is painting this frame (from the single
  /// [MissionVisionSnapshot]). FASE 2 rule #1, made structural: if the child
  /// can see a green box, the mission can NEVER complete. Defaults to 0 so the
  /// rule is a no-op for callers that don't yet supply it.
  final int greenOverlayDetectionCount;
}

/// Centralizes mission safety decisions so the controller only orchestrates
/// state transitions. The guard is intentionally conservative: uncertainty
/// keeps the mission alive instead of pretending a pickup or clean area.
class MissionCompletionGuard {
  const MissionCompletionGuard();

  bool canAutoCollectTarget(TargetCollectionEvidence evidence) {
    if (evidence.missedFrames < evidence.requiredMissedFrames) return false;
    if (evidence.timeSinceLastSeen < evidence.requiredTimeSinceLastSeen) {
      return false;
    }
    // The toy is back where it was → it was NOT picked up.
    if (evidence.targetStillVisibleNearby) return false;
    // A different, new valid toy is in view → the child moved on to it; that is
    // a target SWITCH, handled elsewhere, not a pickup of THIS toy.
    if (evidence.hasNewUncollectedVisible) return false;
    // Otherwise: the marked toy has been gone for a sustained window and
    // nothing compatible is where it was → the child took it. We deliberately
    // do NOT require a "stable scene" here: when a child reaches in to grab a
    // toy, the model briefly sees a hand/arm (a non-toy "movement" signal), and
    // an over-cautious scene gate would then NEVER count the pickup. The two
    // structural guards above (toy-still-there, new-toy-visible) are what
    // distinguish a real pickup from a re-acquire or a pan to another toy.
    // [sceneStability]/[sceneHadAnchors] remain on the evidence for diagnostics
    // only.
    return true;
  }

  bool canCompleteMission(MissionCompletionEvidence evidence) {
    // The initial baseline ("how many toys there were") is diagnostic only and
    // NEVER gates completion: the camera sees only part of the room, so an
    // over-counted baseline must not keep the mission alive. Completion is
    // decided purely by what the camera SEES now — a clean, stable visible
    // area — and is blocked the moment a toy is in view.
    //
    // Rule #1 (structural): if the overlay is painting a green toy box, the
    // mission cannot complete. Checked first and independently of the tracked
    // count so the painter and the guard can never disagree.
    if (evidence.greenOverlayDetectionCount > 0) return false;
    if (evidence.visibleToyCount > 0) return false;
    if (evidence.validatedToyDetectionsInSweep > 0) return false;
    if (evidence.sawOnlyRawNonToyDetections) return false;
    return evidence.sceneStability == SceneStabilityStatus.stable;
  }
}
