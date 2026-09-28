import '../../domain/cleanup/cleanup_session.dart';
import '../../domain/scene/room_snapshot.dart';
import '../../domain/scene/room_world_model.dart';
import '../../perception/perception_models.dart';
import '../../perception/room_discovery/room_discovery_session.dart';
import 'room_clean_verifier.dart';

enum CleanupPhase {
  idle,
  ready,
  discovering,
  cleaning,
  verifyingRemoval,
  verifyingRoom,
  completed,
  paused,
  error,
}

enum VisionStatus {
  stopped,
  initializing,
  running,
  error,
}

class CleanupState {
  const CleanupState({
    required this.phase,
    required this.message,
    required this.visionStatus,
    this.worldModel,
    this.initialSnapshot,
    this.session,
    this.metrics,
    this.latestPerception,
    this.discoveryProgress = const RoomDiscoveryProgress.empty(),
    this.completionEvidence,
    this.activeTargetTrackId,
    this.errorMessage,
  });

  const CleanupState.idle()
      : phase = CleanupPhase.idle,
        message = '¡Vamos a recoger!',
        visionStatus = VisionStatus.stopped,
        worldModel = null,
        initialSnapshot = null,
        session = null,
        metrics = null,
        latestPerception = null,
        discoveryProgress = const RoomDiscoveryProgress.empty(),
        completionEvidence = null,
        activeTargetTrackId = null,
        errorMessage = null;

  final CleanupPhase phase;
  final String message;
  final VisionStatus visionStatus;
  final RoomWorldModel? worldModel;
  final RoomSnapshot? initialSnapshot;
  final CleanupSession? session;
  final PerceptionMetrics? metrics;
  final PerceptionResult? latestPerception;
  final RoomDiscoveryProgress discoveryProgress;
  final CompletionEvidence? completionEvidence;
  final int? activeTargetTrackId;
  final String? errorMessage;

  bool get modelReady => visionStatus == VisionStatus.running;

  int get collected => session?.confirmedCollected ?? 0;
  int get remainingEstimate =>
      session?.remainingEstimate ?? initialSnapshot?.toys.length ?? 0;

  CleanupState copyWith({
    CleanupPhase? phase,
    String? message,
    VisionStatus? visionStatus,
    RoomWorldModel? worldModel,
    RoomSnapshot? initialSnapshot,
    CleanupSession? session,
    PerceptionMetrics? metrics,
    PerceptionResult? latestPerception,
    RoomDiscoveryProgress? discoveryProgress,
    CompletionEvidence? completionEvidence,
    int? activeTargetTrackId,
    bool clearActiveTarget = false,
    String? errorMessage,
    bool clearError = false,
  }) =>
      CleanupState(
        phase: phase ?? this.phase,
        message: message ?? this.message,
        visionStatus: visionStatus ?? this.visionStatus,
        worldModel: worldModel ?? this.worldModel,
        initialSnapshot: initialSnapshot ?? this.initialSnapshot,
        session: session ?? this.session,
        metrics: metrics ?? this.metrics,
        latestPerception: latestPerception ?? this.latestPerception,
        discoveryProgress: discoveryProgress ?? this.discoveryProgress,
        completionEvidence: completionEvidence ?? this.completionEvidence,
        activeTargetTrackId: clearActiveTarget
            ? null
            : (activeTargetTrackId ?? this.activeTargetTrackId),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}
