import 'dart:math' as math;

import '../../core/math/vector_math.dart';
import '../../domain/scene/scene_state.dart';
import '../../domain/toy/toy_observation.dart';
import '../../domain/toy/toy_track.dart';
import '../perception_models.dart';
import 'track_associator.dart';

class TrackingUpdate {
  TrackingUpdate({
    required List<ToyTrack> tracks,
    required List<TrackTransition> transitions,
    required List<TrackAssociation> associations,
  })  : tracks = List.unmodifiable(tracks),
        transitions = List.unmodifiable(transitions),
        associations = List.unmodifiable(associations);

  final List<ToyTrack> tracks;
  final List<TrackTransition> transitions;
  final List<TrackAssociation> associations;
}

class ToyTracker {
  ToyTracker({TrackAssociator? associator})
      : associator = associator ?? const TrackAssociator();

  final TrackAssociator associator;
  final List<ToyTrack> _tracks = [];
  int _nextId = 1;

  List<ToyTrack> get tracks => List.unmodifiable(_tracks);

  TrackingUpdate update(
    List<ToyObservation> observations,
    DateTime timestamp,
    SceneState sceneState,
  ) {
    // Open-set regions are proposals, not semantic toy observations. They may
    // support fusion, but cannot move or keep a confirmed identity alive.
    final trackingObservations = observations
        .where(
          (observation) =>
              observation.source != ObservationSource.openSetProposal,
        )
        .toList(growable: false);
    final matches = associator.associate(_tracks, trackingObservations);
    final matchedTracks = <int>{};
    final matchedObservations = <int>{};
    final transitions = <TrackTransition>[];
    for (final match in matches) {
      matchedTracks.add(match.trackIndex);
      matchedObservations.add(match.observationIndex);
      final previous = _tracks[match.trackIndex];
      final observation = trackingObservations[match.observationIndex];
      final reappeared = previous.presence == TrackPresence.occluded ||
          previous.presence == TrackPresence.missingCandidate ||
          previous.presence == TrackPresence.confirmedMissing;
      final visibleFrames = previous.visibleFrames + 1;
      final movementEvidence = math.max(
        ((1 - previous.lastBounds.centroidSimilarity(observation.bounds)) * 4)
            .clamp(0.0, 1.0),
        (1 - previous.lastBounds.sizeSimilarity(observation.bounds))
            .clamp(0.0, 1.0),
      );
      // Bounding-box movement is meaningful interaction evidence only while
      // the camera view itself is stationary. Otherwise a small phone pan can
      // look exactly like the child moving the object and can freeze the
      // wrong scene anchor for the following disappearance check.
      final semanticMovementObserved = previous.confirmedToy &&
          observation.source != ObservationSource.openSetProposal &&
          sceneState == SceneState.stable;
      final interactionEvidence = math.max(
        previous.interactionEvidence * 0.75,
        semanticMovementObserved ? movementEvidence : 0.0,
      );
      _tracks[match.trackIndex] = previous.copyWith(
        lastBounds: observation.bounds,
        // Once identity is confirmed, keep its visual template fixed. Blending
        // every later crop lets a chain of plausible matches drift onto a
        // different physical object.
        visualEmbedding: !previous.confirmedToy && observation.isConfirmedToy
            ? blendEmbeddings(
                previous.visualEmbedding,
                observation.embedding,
              )
            : previous.visualEmbedding,
        visibleFrames: visibleFrames,
        missingFrames: 0,
        confidence: observation.isConfirmedToy
            ? previous.confidence * 0.7 + observation.toyProbability * 0.3
            : previous.confidence * 0.995,
        presence: visibleFrames >= 3
            ? TrackPresence.visible
            : TrackPresence.candidate,
        lastSeenAt: timestamp,
        updatedAt: timestamp,
        source: previous.source == ObservationSource.detector
            ? ObservationSource.detector
            : observation.source,
        knownClass: observation.knownClass,
        confirmedToy: previous.confirmedToy || observation.isConfirmedToy,
        confirmedAt: previous.confirmedAt ??
            (observation.isConfirmedToy ? timestamp : null),
        interactionEvidence: interactionEvidence,
        lastInteractionAt: semanticMovementObserved && movementEvidence >= 0.12
            ? timestamp
            : previous.lastInteractionAt,
        clearMissingSince: true,
      );
      transitions.add(
        TrackTransition(
          reappeared
              ? TrackTransitionType.reappeared
              : TrackTransitionType.observed,
          previous.id,
        ),
      );
    }

    for (var index = 0; index < _tracks.length; index++) {
      if (matchedTracks.contains(index)) continue;
      final previous = _tracks[index];
      if (previous.presence == TrackPresence.collected) continue;
      final canSearch = sceneState == SceneState.stable;
      final continuingStableAbsence =
          previous.presence == TrackPresence.missingCandidate ||
              previous.presence == TrackPresence.confirmedMissing;
      final missingFrames = canSearch
          ? (continuingStableAbsence ? previous.missingFrames + 1 : 1)
          : 0;
      final presence =
          canSearch ? TrackPresence.missingCandidate : TrackPresence.occluded;
      _tracks[index] = previous.copyWith(
        missingFrames: missingFrames,
        presence: presence,
        updatedAt: timestamp,
        missingSince: canSearch
            ? (continuingStableAbsence
                ? previous.missingSince ?? timestamp
                : timestamp)
            : null,
        clearMissingSince: !canSearch,
      );
      if (missingFrames == 1) {
        transitions.add(
          TrackTransition(TrackTransitionType.temporarilyMissing, previous.id),
        );
      }
    }

    for (var index = 0; index < trackingObservations.length; index++) {
      if (matchedObservations.contains(index)) continue;
      if (!trackingObservations[index].isConfirmedToy) continue;
      final track =
          ToyTrack.fromObservation(_nextId++, trackingObservations[index]);
      _tracks.add(track);
      transitions.add(
        TrackTransition(TrackTransitionType.created, track.id),
      );
    }
    return TrackingUpdate(
      tracks: _tracks,
      transitions: transitions,
      associations: matches,
    );
  }

  void confirmMissing(int trackId, DateTime timestamp) {
    final index = _tracks.indexWhere((track) => track.id == trackId);
    if (index < 0) return;
    _tracks[index] = _tracks[index].copyWith(
      presence: TrackPresence.confirmedMissing,
      updatedAt: timestamp,
    );
  }

  void markCollected(int trackId, DateTime timestamp) {
    final index = _tracks.indexWhere((track) => track.id == trackId);
    if (index < 0) return;
    _tracks[index] = _tracks[index].copyWith(
      presence: TrackPresence.collected,
      collectedAt: timestamp,
      updatedAt: timestamp,
    );
  }

  void reset() {
    _tracks.clear();
    _nextId = 1;
  }
}
