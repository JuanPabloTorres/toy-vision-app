import 'normalized_box.dart';
import 'toy_observation.dart';

enum TrackPresence {
  candidate,
  visible,
  occluded,
  missingCandidate,
  confirmedMissing,
  collected,
}

/// Child-game lifecycle projected from the lower-level tracker presence and
/// confirmation evidence.
enum ToyTrackStatus {
  candidate,
  confirmed,
  visible,
  temporarilyLost,
  verifyingRemoval,
  collected,
}

class ToyTrack {
  ToyTrack({
    required this.id,
    required this.lastBounds,
    required this.initialBounds,
    required List<double> visualEmbedding,
    required this.visibleFrames,
    required this.missingFrames,
    required this.confidence,
    required this.presence,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.updatedAt,
    required this.source,
    required this.confirmedToy,
    required this.confirmedAt,
    required this.interactionEvidence,
    this.knownClass,
    this.lastInteractionAt,
    this.missingSince,
    this.collectedAt,
    this.lostDuringCameraMotion = false,
    this.cameraMotionAtLoss = 0,
  }) : visualEmbedding = List<double>.unmodifiable(visualEmbedding);

  factory ToyTrack.fromObservation(int id, ToyObservation observation) =>
      ToyTrack(
        id: id,
        lastBounds: observation.bounds,
        initialBounds: observation.bounds,
        visualEmbedding: observation.embedding,
        visibleFrames: 1,
        missingFrames: 0,
        confidence: observation.toyProbability,
        presence: TrackPresence.candidate,
        firstSeenAt: observation.timestamp,
        lastSeenAt: observation.timestamp,
        updatedAt: observation.timestamp,
        source: observation.source,
        confirmedToy: observation.isConfirmedToy,
        confirmedAt: observation.isConfirmedToy ? observation.timestamp : null,
        interactionEvidence: 0,
        knownClass: observation.knownClass,
      );

  final int id;
  final NormalizedBox lastBounds;
  final NormalizedBox initialBounds;
  final List<double> visualEmbedding;
  final int visibleFrames;
  final int missingFrames;
  final double confidence;
  final TrackPresence presence;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final DateTime updatedAt;
  final ObservationSource source;
  final bool confirmedToy;
  final DateTime? confirmedAt;
  final double interactionEvidence;
  final DateTime? lastInteractionAt;
  final String? knownClass;
  final DateTime? missingSince;
  final DateTime? collectedAt;
  final bool lostDuringCameraMotion;
  final double cameraMotionAtLoss;

  bool get isVisible =>
      presence == TrackPresence.visible || presence == TrackPresence.candidate;
  bool get isStable => confirmedToy && visibleFrames >= 6 && confidence >= 0.68;

  ToyTrackStatus get status {
    if (presence == TrackPresence.collected) return ToyTrackStatus.collected;
    if (presence == TrackPresence.occluded) {
      return ToyTrackStatus.temporarilyLost;
    }
    if (presence == TrackPresence.missingCandidate ||
        presence == TrackPresence.confirmedMissing) {
      return ToyTrackStatus.verifyingRemoval;
    }
    if (presence == TrackPresence.visible) return ToyTrackStatus.visible;
    if (confirmedToy) return ToyTrackStatus.confirmed;
    return ToyTrackStatus.candidate;
  }

  ToyTrack copyWith({
    NormalizedBox? lastBounds,
    List<double>? visualEmbedding,
    int? visibleFrames,
    int? missingFrames,
    double? confidence,
    TrackPresence? presence,
    DateTime? lastSeenAt,
    DateTime? updatedAt,
    ObservationSource? source,
    bool? confirmedToy,
    DateTime? confirmedAt,
    double? interactionEvidence,
    DateTime? lastInteractionAt,
    String? knownClass,
    DateTime? missingSince,
    bool clearMissingSince = false,
    DateTime? collectedAt,
    bool? lostDuringCameraMotion,
    double? cameraMotionAtLoss,
  }) =>
      ToyTrack(
        id: id,
        lastBounds: lastBounds ?? this.lastBounds,
        initialBounds: initialBounds,
        visualEmbedding: visualEmbedding ?? this.visualEmbedding,
        visibleFrames: visibleFrames ?? this.visibleFrames,
        missingFrames: missingFrames ?? this.missingFrames,
        confidence: confidence ?? this.confidence,
        presence: presence ?? this.presence,
        firstSeenAt: firstSeenAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        updatedAt: updatedAt ?? this.updatedAt,
        source: source ?? this.source,
        confirmedToy: confirmedToy ?? this.confirmedToy,
        confirmedAt: confirmedAt ?? this.confirmedAt,
        interactionEvidence: interactionEvidence ?? this.interactionEvidence,
        lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
        knownClass: knownClass ?? this.knownClass,
        missingSince:
            clearMissingSince ? null : (missingSince ?? this.missingSince),
        collectedAt: collectedAt ?? this.collectedAt,
        lostDuringCameraMotion:
            lostDuringCameraMotion ?? this.lostDuringCameraMotion,
        cameraMotionAtLoss: cameraMotionAtLoss ?? this.cameraMotionAtLoss,
      );
}
