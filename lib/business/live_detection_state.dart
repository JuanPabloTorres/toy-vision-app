import '../tracking/tracked_toy.dart';
import 'mission/cleanup_mission_status.dart';
import 'mission/mission_state_machine.dart';
import 'mission/scene_stability_service.dart';

/// YOLO model lifecycle, surfaced to the UI as a status indicator.
/// Independent of [CleanupMissionStatus].
enum ModelStatus { initializing, ready, error }

/// Immutable per-category and total count summary.
class ToyCountSummary {
  const ToyCountSummary({required this.total, required this.perCategory});

  final int total;
  final Map<String, int> perCategory;

  static const ToyCountSummary empty =
      ToyCountSummary(total: 0, perCategory: {});
}

class DetectionDiagnosticRow {
  const DetectionDiagnosticRow({
    required this.rawLabel,
    required this.confidence,
    required this.mappedLabel,
    required this.identityType,
    required this.countsAsToy,
    required this.rejectReason,
  });

  final String rawLabel;
  final double confidence;
  final String? mappedLabel;
  final String? identityType;
  final bool countsAsToy;
  final String? rejectReason;
}

class MissionDebugSnapshot {
  const MissionDebugSnapshot({
    required this.modelLoaded,
    required this.configuredModelPath,
    required this.loadedModelPath,
    required this.modelTask,
    required this.isCustomToyModel,
    required this.modelConfidenceThreshold,
    required this.modelIouThreshold,
    required this.cameraResolution,
    required this.loadedLabelCount,
    required this.loadedLabelsPreview,
    required this.flowState,
    required this.activeTargetId,
    required this.visibleToyCount,
    required this.baselineToyCount,
    required this.remainingToyCount,
    required this.rawDetectionsCount,
    required this.mappedDetectionsCount,
    required this.validToyCount,
    required this.unknownToyCount,
    required this.greenOverlayCount,
    required this.recallVerdict,
    required this.rejectedDetectionsCount,
    required this.rejectionReasons,
    required this.rawDetections,
    required this.targetConfidence,
    required this.targetMissingFrameCount,
    required this.frameIntervalMs,
    required this.approxFps,
    required this.sceneStabilityStatus,
    required this.sceneStabilityReason,
    required this.sceneStabilityScore,
    required this.guardDecision,
    required this.guardReason,
    required this.completedAllowed,
  });

  final bool modelLoaded;
  final String configuredModelPath;
  final String? loadedModelPath;
  final String? modelTask;
  final bool isCustomToyModel;
  final double modelConfidenceThreshold;
  final double modelIouThreshold;
  final String cameraResolution;
  final int loadedLabelCount;
  final List<String> loadedLabelsPreview;
  final MissionFlowState flowState;
  final int? activeTargetId;
  final int visibleToyCount;
  final int? baselineToyCount;
  final int remainingToyCount;
  final int rawDetectionsCount;
  final int mappedDetectionsCount;
  final int validToyCount;
  final int unknownToyCount;

  /// Toy boxes the overlay is painting this frame (from [MissionVisionSnapshot]).
  /// Equal to [visibleToyCount] during a scan/clean-area sweep; the Lab shows
  /// both so the painter↔guard agreement is visible.
  final int greenOverlayCount;

  /// One-line answer to "which gate is failing?" — computed from the funnel
  /// (raw → mapped → valid → visible). E.g. "YOLO sees only non-toys" vs
  /// "rules drop mapped toys (low confidence)".
  final String recallVerdict;

  final int rejectedDetectionsCount;
  final Map<String, int> rejectionReasons;
  final List<DetectionDiagnosticRow> rawDetections;
  final double? targetConfidence;
  final int targetMissingFrameCount;
  final int? frameIntervalMs;
  final double? approxFps;
  final SceneStabilityStatus? sceneStabilityStatus;
  final SceneStabilityReason? sceneStabilityReason;
  final double? sceneStabilityScore;
  final String guardDecision;
  final String guardReason;
  final bool completedAllowed;
}

/// Immutable snapshot the UI renders. Produced by `ToyCleanupController`
/// after the pipeline (mapper → rules → tracker → fusion → mission state)
/// runs.
///
/// The UI never derives game state from this object — every field (status,
/// target id, copy, counts) is pre-baked. In the Phase 7 progressive flow
/// there is no frozen "initial count": the known-toy list grows as the
/// robot re-scans, so the UI shows "Juguete X" and "Recogidos: A", not
/// "X de Y".
class LiveDetectionState {
  const LiveDetectionState({
    required this.status,
    required this.missionStatus,
    required this.visibleToys,
    required this.summary,
    required this.guidanceMessage,
    required this.currentTargetToyId,
    required this.knownToyCount,
    required this.collectedToyCount,
    required this.currentTargetIndex,
    required this.targetPickupGoal,
    required this.hasReachedGoal,
    required this.personalBestToyCount,
    required this.isNewRecord,
    required this.debugSnapshot,
  });

  // --- Model lifecycle ---
  final ModelStatus status;

  // --- Mission state machine ---
  final CleanupMissionStatus missionStatus;

  // --- Overlay set (current target + known pending toys) ---
  final List<TrackedToy> visibleToys;
  final ToyCountSummary summary;

  // --- UI hints ---

  /// The toy the child is being asked to pick up. Always non-null while
  /// [missionStatus] expects a target.
  final int? currentTargetToyId;

  /// Total toys the mission has discovered so far (grows with re-scans).
  final int knownToyCount;

  /// How many toys the child has confirmed collected.
  final int collectedToyCount;

  /// 1-based "Juguete X" label for the current target.
  final int currentTargetIndex;

  /// Pickup target for this mission's challenge, or `null` in free/record mode.
  /// This is a CHALLENGE goal — never "how many toys are in the room".
  final int? targetPickupGoal;

  /// True once [collectedToyCount] has reached [targetPickupGoal]. The mission
  /// celebrates but does NOT end — the child may keep collecting for a record.
  final bool hasReachedGoal;

  /// The child's best pickup count from previous missions (before this one).
  /// Drives the "Récord" line and the "¡Nuevo récord!" celebration.
  final int personalBestToyCount;

  /// True when [collectedToyCount] has passed [personalBestToyCount] — a new
  /// personal record is being set right now.
  final bool isNewRecord;

  final MissionDebugSnapshot? debugSnapshot;

  /// Pickups still needed to reach the challenge goal (0 once reached, null in
  /// free mode). "Te faltan N para el reto" — NOT toys left in the room.
  int? get pickupsToGoal {
    final goal = targetPickupGoal;
    if (goal == null) return null;
    final remaining = goal - collectedToyCount;
    return remaining > 0 ? remaining : 0;
  }

  /// Free/record mode: no fixed goal, every pickup is a record attempt.
  bool get isRecordMode => targetPickupGoal == null;

  // --- Coach copy ---
  final String guidanceMessage;

  int get totalCount => summary.total;
  bool get hasVisibleToys => visibleToys.isNotEmpty;

  /// Whether the "Recoge este" highlight should be painted: there is a chosen
  /// target AND the controller put it in [visibleToys] this frame (i.e. it has
  /// current on-screen evidence). The controller already gates this — it only
  /// adds the target to [visibleToys] when seen — so the UI/overlay can rely
  /// on this single flag and never paints a stale box.
  bool get shouldShowTargetOverlay =>
      currentTargetToyId != null &&
      visibleToys.any((t) => t.id == currentTargetToyId);

  /// Progress is indeterminate during a progressive mission (the total is
  /// not known) and full when completed.
  double? get missionProgress =>
      missionStatus == CleanupMissionStatus.completed ? 1.0 : null;

  factory LiveDetectionState.initial() => const LiveDetectionState(
        status: ModelStatus.initializing,
        missionStatus: CleanupMissionStatus.idle,
        visibleToys: [],
        summary: ToyCountSummary.empty,
        guidanceMessage: '',
        currentTargetToyId: null,
        knownToyCount: 0,
        collectedToyCount: 0,
        currentTargetIndex: 0,
        // Default challenge goal = normal (5). The controller overrides this
        // per mission from the chosen MissionGoal; kept literal so this stays
        // a const initial state.
        targetPickupGoal: 5,
        hasReachedGoal: false,
        personalBestToyCount: 0,
        isNewRecord: false,
        debugSnapshot: null,
      );

  LiveDetectionState copyWith({
    ModelStatus? status,
    CleanupMissionStatus? missionStatus,
    List<TrackedToy>? visibleToys,
    ToyCountSummary? summary,
    String? guidanceMessage,
    int? currentTargetToyId,
    bool clearCurrentTarget = false,
    int? knownToyCount,
    int? collectedToyCount,
    int? currentTargetIndex,
    int? targetPickupGoal,
    bool clearTargetPickupGoal = false,
    bool? hasReachedGoal,
    int? personalBestToyCount,
    bool? isNewRecord,
    MissionDebugSnapshot? debugSnapshot,
  }) {
    return LiveDetectionState(
      status: status ?? this.status,
      missionStatus: missionStatus ?? this.missionStatus,
      visibleToys: visibleToys ?? this.visibleToys,
      summary: summary ?? this.summary,
      guidanceMessage: guidanceMessage ?? this.guidanceMessage,
      currentTargetToyId: clearCurrentTarget
          ? null
          : (currentTargetToyId ?? this.currentTargetToyId),
      knownToyCount: knownToyCount ?? this.knownToyCount,
      collectedToyCount: collectedToyCount ?? this.collectedToyCount,
      currentTargetIndex: currentTargetIndex ?? this.currentTargetIndex,
      targetPickupGoal: clearTargetPickupGoal
          ? null
          : (targetPickupGoal ?? this.targetPickupGoal),
      hasReachedGoal: hasReachedGoal ?? this.hasReachedGoal,
      personalBestToyCount: personalBestToyCount ?? this.personalBestToyCount,
      isNewRecord: isNewRecord ?? this.isNewRecord,
      debugSnapshot: debugSnapshot ?? this.debugSnapshot,
    );
  }
}
