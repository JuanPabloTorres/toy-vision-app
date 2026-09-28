import '../../core/math/vector_math.dart';
import '../../domain/toy/toy_observation.dart';
import '../../domain/toy/toy_track.dart';

class TrackAssociation {
  const TrackAssociation({
    required this.trackIndex,
    required this.trackId,
    required this.observationIndex,
    required this.score,
    required this.intersectionOverUnion,
    required this.centroidSimilarity,
    required this.embeddingSimilarity,
    required this.sizeSimilarity,
  });

  final int trackIndex;
  final int trackId;
  final int observationIndex;
  final double score;
  final double intersectionOverUnion;
  final double centroidSimilarity;
  final double embeddingSimilarity;
  final double sizeSimilarity;
}

class TrackAssociator {
  const TrackAssociator({this.minimumScore = 0.42});

  final double minimumScore;

  List<TrackAssociation> associate(
    List<ToyTrack> tracks,
    List<ToyObservation> observations,
  ) {
    final candidates = <TrackAssociation>[];
    for (var trackIndex = 0; trackIndex < tracks.length; trackIndex++) {
      final track = tracks[trackIndex];
      if (track.presence == TrackPresence.collected) continue;
      for (var observationIndex = 0;
          observationIndex < observations.length;
          observationIndex++) {
        final observation = observations[observationIndex];
        final embedding = cosineSimilarity(
          track.visualEmbedding,
          observation.embedding,
        ).clamp(0.0, 1.0);
        final iou = track.lastBounds.intersectionOverUnion(observation.bounds);
        final centroid =
            track.lastBounds.centroidSimilarity(observation.bounds);
        final size = track.lastBounds.sizeSimilarity(observation.bounds);
        final identitySize =
            track.initialBounds.sizeSimilarity(observation.bounds);
        final detectorTrackUsingOpenSetFallback =
            track.source == ObservationSource.detector &&
                observation.source == ObservationSource.openSetProposal;
        // A non-semantic grid region may keep a detector-created identity alive
        // briefly, but it must not drag that identity to another visually
        // similar patch. Detector observations remain the primary geometry.
        if (detectorTrackUsingOpenSetFallback &&
            (iou < 0.45 || centroid < 0.78 || size < 0.65)) {
          continue;
        }
        // A sequence of locally plausible matches must not shrink or grow a
        // confirmed identity into a different object. Losing the association
        // is safer than mutating the snapshot identity and later collecting a
        // false target.
        if (track.confirmedToy && identitySize < 0.30) {
          continue;
        }
        if (track.confirmedToy &&
            !observation.isConfirmedToy &&
            (size < 0.50 || (embedding < 0.85 && iou < 0.25))) {
          continue;
        }
        final score =
            iou * 0.35 + centroid * 0.25 + embedding * 0.30 + size * 0.10;
        if (score >= minimumScore) {
          candidates.add(
            TrackAssociation(
              trackIndex: trackIndex,
              trackId: track.id,
              observationIndex: observationIndex,
              score: score,
              intersectionOverUnion: iou,
              centroidSimilarity: centroid,
              embeddingSimilarity: embedding,
              sizeSimilarity: size,
            ),
          );
        }
      }
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final usedTracks = <int>{};
    final usedObservations = <int>{};
    final matches = <TrackAssociation>[];
    for (final candidate in candidates) {
      if (usedTracks.add(candidate.trackIndex) &&
          usedObservations.add(candidate.observationIndex)) {
        matches.add(candidate);
      }
    }
    return matches;
  }
}
