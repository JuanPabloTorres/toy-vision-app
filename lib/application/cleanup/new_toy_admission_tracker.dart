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
  final Set<int> _pendingTrackIds = {};

  int get pendingCount => _pendingTrackIds.length;

  Set<int> observe(
    RoomWorldModel world, {
    required Set<int> knownTrackIds,
  }) {
    final provisional = world.activeTracks.values.where((track) {
      return !knownTrackIds.contains(track.id) &&
          track.source == ObservationSource.detector &&
          track.confirmedToy;
    }).toList(growable: false);
    // A detector-confirmed identity must block the clean-window immediately,
    // even before it is old/confident enough to expand the mission. This
    // closes the race where RoomClean could be emitted during its first few
    // visible frames. It does not return the UI to cleaning by itself.
    _pendingTrackIds
      ..clear()
      ..addAll(provisional.map((track) => track.id));

    final eligible = provisional.where((track) {
      return track.visibleFrames >= policy.minimumVisibleFrames &&
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
      _pendingTrackIds.remove(trackId);
    }
    return admitted;
  }

  void reset() {
    _stableSince.clear();
    _pendingTrackIds.clear();
  }
}
