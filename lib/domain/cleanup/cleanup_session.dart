import '../scene/room_snapshot.dart';

enum CleanupStatus { active, completed, failed }

class CleanupSession {
  CleanupSession({
    required this.id,
    required this.initialSnapshot,
    required this.startedAt,
    required this.confirmedCollected,
    required this.collectedTrackIds,
    required this.status,
    this.completedAt,
  });

  factory CleanupSession.start({
    required String id,
    required RoomSnapshot snapshot,
    required DateTime startedAt,
  }) =>
      CleanupSession(
        id: id,
        initialSnapshot: snapshot,
        startedAt: startedAt,
        confirmedCollected: 0,
        collectedTrackIds: const {},
        status: CleanupStatus.active,
      );

  final String id;
  final RoomSnapshot initialSnapshot;
  final DateTime startedAt;
  final int confirmedCollected;
  final Set<int> collectedTrackIds;
  final CleanupStatus status;
  final DateTime? completedAt;

  int get remainingEstimate =>
      (initialSnapshot.toys.length - confirmedCollected).clamp(
        0,
        initialSnapshot.toys.length,
      );

  CleanupSession collect(int trackId) {
    if (status != CleanupStatus.active || collectedTrackIds.contains(trackId)) {
      return this;
    }
    final ids = {...collectedTrackIds, trackId};
    return CleanupSession(
      id: id,
      initialSnapshot: initialSnapshot,
      startedAt: startedAt,
      confirmedCollected: ids.length,
      collectedTrackIds: Set<int>.unmodifiable(ids),
      status: status,
      completedAt: completedAt,
    );
  }

  CleanupSession withExpandedSnapshot(RoomSnapshot snapshot) => CleanupSession(
        id: id,
        initialSnapshot: snapshot,
        startedAt: startedAt,
        confirmedCollected: confirmedCollected,
        collectedTrackIds: collectedTrackIds,
        status: status,
        completedAt: completedAt,
      );

  CleanupSession complete(DateTime at) => CleanupSession(
        id: id,
        initialSnapshot: initialSnapshot,
        startedAt: startedAt,
        confirmedCollected: confirmedCollected,
        collectedTrackIds: collectedTrackIds,
        status: CleanupStatus.completed,
        completedAt: at,
      );
}
