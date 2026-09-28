import '../../domain/toy/toy_track.dart';

/// Decides when the stable scene anchor may follow the child's new viewpoint.
///
/// Between pickups the child must be free to pan toward the next toy. During
/// an actual pickup episode, however, the pre-removal view is frozen so a
/// camera pan cannot be mistaken for an emptied local region.
class SceneAnchorUpdatePolicy {
  const SceneAnchorUpdatePolicy({
    this.minimumInteractionEvidence = 0.12,
  });

  final double minimumInteractionEvidence;

  bool canUpdate({
    required bool discoveryMode,
    required Iterable<ToyTrack> tracks,
  }) {
    if (discoveryMode) return true;
    return !tracks.any((track) {
      final disappearanceEpisode = track.presence == TrackPresence.occluded ||
          track.presence == TrackPresence.missingCandidate ||
          track.presence == TrackPresence.confirmedMissing;
      return disappearanceEpisode &&
          track.confirmedToy &&
          track.lastInteractionAt != null &&
          track.interactionEvidence >= minimumInteractionEvidence;
    });
  }
}
