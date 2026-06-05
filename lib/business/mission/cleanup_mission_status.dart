/// The states a "Misión Recoge Juguetes" run can be in.
///
/// Phase 7 redesign: the flow is **automatic and progressive**. The robot
/// scans by itself, guides one toy at a time, re-scans when it runs out of
/// known toys, and asks the child "¿ves otro juguete?" — completing only
/// when the child confirms. There is no adult inspection/area step.
///
/// Transitions:
///
///     idle
///       │ "Nueva misión"
///       ▼
///     scanning ──(found toys)──► active ◄───────────────┐
///       │ (nothing after retries)        │ "Ya lo recogí"│
///       ▼                                 ▼               │
///     waitingForChildTap            (pending left? next) ─┘
///                                         │ (none left)
///                                         ▼
///                                    rescanning ──(found)──► active
///                                         │ (nothing)
///                                         ▼
///                                    askingIfMoreToys
///                                     │ Sí → rescanning / waitingForChildTap
///                                     │ No, terminé → completed
///                                     ▼
///                                    completed (sticky)
///
/// `targetLost` is a transient guard while the model briefly loses the
/// current toy. `cancelled` is a back-out. `error` is set when YOLO fails.
enum CleanupMissionStatus {
  /// Before a mission starts, or after reset.
  idle,

  /// Robot is scanning the area automatically to find some toys.
  scanning,

  /// A toy is marked and the child is being guided to pick it up. There is
  /// ALWAYS a current target while in this state.
  active,

  /// The live tracker has lost sight of the current toy for longer than the
  /// grace window (`RealtimeDetectionConfig.targetLostFrames`). The highlight
  /// stays on its last-known box (dimmed) and the coach says "Buscando el
  /// juguete…"; re-acquiring the toy returns to [active]. Guidance is never
  /// dropped and the mission never completes from a loss — only the child's
  /// "Ya lo recogí" advances it.
  targetLost,

  /// The target stopped being seen and the robot is deducing whether it was
  /// picked up (auto-collect evaluation). The yellow box is hidden and the
  /// coach says "Estoy mirando si ya lo recogiste…". Modelled inside
  /// [targetLost] for transitions; surfaced here only when a manual fallback
  /// confirmation ("¿Lo recogiste? Sí / Todavía no") is needed because the
  /// scene was too ambiguous to decide automatically — the EXCEPTION, not the
  /// normal flow.
  confirmingPickup,

  /// Ran out of known toys — scanning again to find more before deciding
  /// the mission is over.
  rescanning,

  /// After the last known toy was collected, the robot does a short sweep to
  /// CONFIRM the floor is actually clean before celebrating ("Estoy revisando
  /// el área…"). If it finds another valid toy the mission continues; if the
  /// area was genuinely seen and no toys remain, the mission auto-completes.
  /// This is what lets the app finish on its own instead of asking.
  cleanAreaVerification,

  /// The post-pickup sweep SAW the area but the fixed challenge GOAL is not yet
  /// met (collectedToyCount < targetPickupGoal). The mission must NOT complete
  /// here — the absolute goal rule overrides "the area looks clean". The robot
  /// keeps sweeping and tells the child to point at another area; a toy turning
  /// up resumes the hunt automatically. Only reachable for goal missions, never
  /// in free/record mode.
  needsMoreToysForGoal,

  /// Re-scan found nothing new. Ask the child "¿Ves otro juguete?".
  askingIfMoreToys,

  /// No toys found automatically — ask the child to tap a toy on screen.
  waitingForChildTap,

  /// The child confirmed "No, terminé". Sticky.
  completed,

  /// The mission was cancelled / backed out.
  cancelled,

  /// YOLO failed to load or initialize.
  error,
}

extension CleanupMissionStatusX on CleanupMissionStatus {
  /// A mission is live (camera + guidance) in any of these states.
  bool get isMissionLive =>
      this == CleanupMissionStatus.active ||
      this == CleanupMissionStatus.targetLost ||
      this == CleanupMissionStatus.confirmingPickup ||
      this == CleanupMissionStatus.rescanning ||
      this == CleanupMissionStatus.cleanAreaVerification ||
      this == CleanupMissionStatus.needsMoreToysForGoal ||
      this == CleanupMissionStatus.askingIfMoreToys ||
      this == CleanupMissionStatus.waitingForChildTap;

  /// The robot is actively sweeping for toys (live detections drawn).
  bool get isScanningPhase =>
      this == CleanupMissionStatus.scanning ||
      this == CleanupMissionStatus.rescanning ||
      this == CleanupMissionStatus.cleanAreaVerification ||
      this == CleanupMissionStatus.needsMoreToysForGoal;

  /// There should be a highlighted current target in these states.
  bool get expectsCurrentTarget =>
      this == CleanupMissionStatus.active ||
      this == CleanupMissionStatus.targetLost;
}
