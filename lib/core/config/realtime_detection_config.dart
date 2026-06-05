/// Single source of truth for all real-time detection thresholds and tunables.
///
/// Per governance, thresholds must never be scattered across files. Every layer
/// that needs a threshold reads it from an instance of this config.
class RealtimeDetectionConfig {
  const RealtimeDetectionConfig({
    this.minimumStableFrames = 3,
    this.maximumMissingFrames = 10,
    this.overlayGraceFrames = 3,
    this.iouMatchThreshold = 0.45,
    this.trackMatchMinScore = 0.30,
    this.trackMatchMaxCenterDistance = 0.25,
    this.targetInferenceFps = 8,
    this.initialScanDuration = const Duration(milliseconds: 5000),
    this.rescanDuration = const Duration(milliseconds: 3000),
    this.targetSmoothing = 1.0,
    this.targetLostFrames = 0,
    this.targetRescanFrames = 24,
    this.targetMinVisibleConfidence = 0.0,
    this.targetMatchMinScore = 0.25,
    this.targetMatchMaxCenterDistance = 0.25,
    this.autoCollectMinMissedFrames = 10,
    this.autoCollectMinSecondsSinceLastSeen =
        const Duration(milliseconds: 800),
    this.autoCollectEvaluatingFrames = 4,
    this.cleanAreaVerificationDuration = const Duration(milliseconds: 3000),
    this.allowTargetSwitchWhenNewValidToyVisible = true,
    this.minFramesBeforeTargetSwitch = 10,
    this.minSecondsBeforeTargetSwitch = const Duration(milliseconds: 1000),
  });

  /// Frames a tracked toy must be seen before it is counted.
  final int minimumStableFrames;

  /// Frames a tracked toy may be missing before it is dropped from tracking.
  final int maximumMissingFrames;

  /// Frames a briefly-missing toy keeps its box on screen (temporal
  /// smoothing) so the overlay doesn't flicker when the model drops a
  /// detection for a frame or two. Must be `< maximumMissingFrames`.
  final int overlayGraceFrames;

  /// Minimum IoU for a detection to match an existing tracked toy by overlap
  /// alone. Also the bar above which a *differently-labelled* detection is
  /// still treated as the same physical toy (the model relabelled it between
  /// frames) — strong spatial overlap outweighs a flickering class name.
  final double iouMatchThreshold;

  /// Minimum combined association score for a detection to be matched to an
  /// existing tracked toy. The score blends overlap, center proximity and size
  /// similarity (`IoU·0.5 + proximity·0.4 + sizeSimilarity·0.1`) so a toy keeps
  /// its identity under camera motion even when frame-to-frame IoU dips below
  /// [iouMatchThreshold] — the fix for the "yellow box jumps / re-IDs" bug.
  final double trackMatchMinScore;

  /// Normalized center-distance beyond which a detection cannot be the same
  /// toy as a track that does not overlap it at all. Bounds how far a single
  /// camera pan may move a toy between processed frames before the tracker
  /// treats it as a different object.
  final double trackMatchMaxCenterDistance;

  /// Consecutive frames the current target must be unseen before the robot may
  /// AUTO-COLLECT it (deduce the child picked it up). Combined with
  /// [autoCollectMinSecondsSinceLastSeen] and scene checks so a brief model
  /// blip never auto-collects. At ≈8 fps, 16 frames ≈ 2 seconds.
  final int autoCollectMinMissedFrames;

  /// Minimum wall-clock time since the target was last seen before an
  /// auto-collect may fire — a second guard (independent of FPS) against
  /// collecting on a momentary loss.
  final Duration autoCollectMinSecondsSinceLastSeen;

  /// Frames-missing at which the coach switches from "No lo veo ahora…" to
  /// "Estoy mirando si ya lo recogiste…" (the auto-collect evaluation phase).
  final int autoCollectEvaluatingFrames;

  /// Real-time length of the "clean area" sweep after the last toy is
  /// collected: the robot scans this long to confirm nothing is left before
  /// auto-completing the mission. 2–4 s feels like a deliberate double-check
  /// without dragging.
  final Duration cleanAreaVerificationDuration;

  /// When the active target is lost and a DIFFERENT, new valid toy is visible,
  /// switch to it (the old toy stays pending) instead of staying stuck. Lets
  /// the robot follow the child to another area.
  final bool allowTargetSwitchWhenNewValidToyVisible;

  /// Consecutive frames the active target must be unseen before the robot may
  /// switch to a new visible toy. Short enough to feel responsive, long enough
  /// that a one-frame blip never re-points the highlight.
  final int minFramesBeforeTargetSwitch;

  /// Wall-clock guard mirroring [minFramesBeforeTargetSwitch] (FPS-independent).
  final Duration minSecondsBeforeTargetSwitch;

  /// Target inference rate (frames processed per second). Range 5–10.
  final int targetInferenceFps;

  /// Real-time length of the initial automatic scan. The scan window is
  /// measured by the WALL CLOCK (not frame count) so a fast device still
  /// scans long enough to accumulate several toys before guiding. Frame
  /// count is kept only as a diagnostic.
  final Duration initialScanDuration;

  /// Real-time length of a re-scan (when the known toys run out).
  final Duration rescanDuration;

  /// Smoothing factor for the live highlight while guiding (`Rect.lerp`-style):
  /// 1 snaps the "Recoge este" frame straight onto the detection every frame
  /// (so it sits exactly where the scan's green frame sat — tight on the toy);
  /// lower values glide and damp jitter at the cost of lag. Defaults to a snap
  /// because a frame that hugs the toy matters more here than perfect smoothness.
  final double targetSmoothing;

  /// Consecutive frames the current target may go undetected before the
  /// "Recoge este" highlight is HIDDEN and the mission flips to `targetLost`
  /// ("No lo veo ahora…"). Default 0 = the box is shown ONLY when the detector
  /// sees the target this frame — never a stale last-known box pointing at
  /// empty floor. Raise to 1–2 to allow a very brief last-position hold that
  /// damps single-frame model blips.
  final int targetLostFrames;

  /// Consecutive frames the target may stay lost before the mission
  /// automatically RE-SCANS to look for valid candidates (the target stays
  /// pending, so reappearing re-selects it; otherwise the rescan may pick
  /// another valid pending toy). Never auto-completes. Must be
  /// `> targetLostFrames`. At ≈8 fps, 24 frames ≈ 3 seconds.
  final int targetRescanFrames;

  /// Minimum confidence for the current target to be drawn. The detection
  /// already cleared the model's threshold; this is an extra guard so a very
  /// low-confidence sighting never paints the "Recoge este" box. Default 0
  /// (no extra gate).
  final double targetMinVisibleConfidence;

  /// Minimum match score (overlap-weighted, see the controller's live matcher)
  /// for a detection to be accepted as the current target. Guards against the
  /// highlight snapping onto an unrelated toy.
  final double targetMatchMinScore;

  /// Normalized center-distance over which the proximity term of the live
  /// target match decays to zero. Lets a toy that shifted with a camera pan
  /// re-associate even when boxes no longer overlap, without matching a toy
  /// on the far side of the frame.
  final double targetMatchMaxCenterDistance;

  /// Interval between processed frames derived from [targetInferenceFps].
  Duration get frameInterval =>
      Duration(milliseconds: (1000 / targetInferenceFps).round());

  static const RealtimeDetectionConfig defaults = RealtimeDetectionConfig();
}
