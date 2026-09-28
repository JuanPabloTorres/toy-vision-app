import '../../domain/scene/room_world_model.dart';
import '../../domain/toy/toy_observation.dart';

class NewToyAdmissionPolicy {
  const NewToyAdmissionPolicy({
    this.minimumStableDuration = const Duration(milliseconds: 600),
    this.minimumVisibleFrames = 6,
    this.minimumConfidence = 0.75,
  });

  final Duration minimumStableDuration;
  final int minimumVisibleFrames;
  final double minimumConfidence;
}

/// Debounces detector-confirmed objects revealed after the initial snapshot.
///
/// Camera motion and weak/open-set proposals may request another look, but
/// cannot immediately expand the mission inventory or send the child back to
/// cleaning. A new identity must remain detector-backed in a settled view.
class NewToyAdmissionTracker {
  NewToyAdmissionTracker({
    this.policy = const NewToyAdmissionPolicy(),
  });

  final NewToyAdmissionPolicy policy;
  final Map<int, DateTime> _stableSince = {};

  int get pendingCount => _stableSince.length;

  Set<int> observe(
    RoomWorldModel world, {
    required Set<int> knownTrackIds,
  }) {
    final eligible = world.activeTracks.values.where((track) {
      return !knownTrackIds.contains(track.id) &&
          track.source == ObservationSource.detector &&
          track.confirmedToy &&
          track.visibleFrames >= policy.minimumVisibleFrames &&
          track.confidence >= policy.minimumConfidence &&
          world.scene.canVerifyDisappearance;
    }).toList(growable: false);
    final eligibleIds = eligible.map((track) => track.id).toSet();
    _stableSince.removeWhere((trackId, _) => !eligibleIds.contains(trackId));

    final admitted = <int>{};
    for (final track in eligible) {
      final since = _stableSince.putIfAbsent(track.id, () => world.updatedAt);
      if (world.updatedAt.difference(since) >= policy.minimumStableDuration) {
        admitted.add(track.id);
      }
    }
    for (final trackId in admitted) {
      _stableSince.remove(trackId);
    }
    return admitted;
  }

  void reset() => _stableSince.clear();
}
