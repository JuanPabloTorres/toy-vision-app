import '../tracking/tracked_toy.dart';
import 'mission/cleanup_mission_status.dart';

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
    );
  }
}
