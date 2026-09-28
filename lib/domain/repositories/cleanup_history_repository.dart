import '../cleanup/cleanup_session.dart';

class CleanupSessionSummary {
  const CleanupSessionSummary({
    required this.id,
    required this.startedAt,
    required this.completedAt,
    required this.initialToyCount,
    required this.confirmedCollected,
    this.starsAwarded = 0,
  });

  factory CleanupSessionSummary.fromSession(CleanupSession session) {
    final completedAt = session.completedAt;
    if (completedAt == null) {
      throw StateError('Only completed cleanup sessions can be persisted');
    }
    return CleanupSessionSummary(
      id: session.id,
      startedAt: session.startedAt,
      completedAt: completedAt,
      initialToyCount: session.initialSnapshot.toys.length,
      confirmedCollected: session.confirmedCollected,
    );
  }

  final String id;
  final DateTime startedAt;
  final DateTime completedAt;
  final int initialToyCount;
  final int confirmedCollected;
  final int starsAwarded;
}

abstract interface class CleanupHistoryRepository {
  Future<List<CleanupSessionSummary>> load();
  Future<void> clear();
}
