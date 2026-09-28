import '../../domain/scene/room_snapshot.dart';
import '../../domain/scene/room_world_model.dart';
import '../../domain/toy/toy_track.dart';

abstract interface class TargetSelector {
  int? selectNext({
    required RoomSnapshot snapshot,
    required RoomWorldModel tracking,
    required Set<int> excludedTrackIds,
  });
}

/// Prefers toys that are confirmed, currently visible, large on screen, and
/// stable. It never invents a target when all remaining toys are off-camera.
class VisibleStableTargetSelector implements TargetSelector {
  const VisibleStableTargetSelector();

  @override
  int? selectNext({
    required RoomSnapshot snapshot,
    required RoomWorldModel tracking,
    required Set<int> excludedTrackIds,
  }) {
    final candidates = snapshot.toys
        .where((toy) => !excludedTrackIds.contains(toy.trackId))
        .map((toy) => tracking.activeTracks[toy.trackId])
        .whereType<ToyTrack>()
        .where((track) => track.confirmedToy && track.isVisible)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((left, right) {
      final leftScore = left.lastBounds.area * 2 +
          left.confidence +
          (left.isStable ? 1.0 : 0.0);
      final rightScore = right.lastBounds.area * 2 +
          right.confidence +
          (right.isStable ? 1.0 : 0.0);
      return rightScore.compareTo(leftScore);
    });
    return candidates.first.id;
  }
}
