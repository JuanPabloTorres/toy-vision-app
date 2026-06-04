import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mission_record.dart';

/// Repository contract for completed-mission history.
///
/// Phase 6.4 ships only the in-memory implementation; disk persistence
/// (shared_preferences / sqlite) is a documented follow-up. Keeping the
/// interface means the History/Home/Calendar UI depends on the
/// abstraction, not the storage engine.
abstract class MissionHistoryRepository {
  List<MissionRecord> get all;
  void add(MissionRecord record);
  void clear();
}

/// In-memory, session-lifetime history. Exposed as a Riverpod [Notifier]
/// so the Home cards, calendar, and History screen rebuild when a new
/// mission lands.
class InMemoryMissionHistoryRepository extends Notifier<List<MissionRecord>>
    implements MissionHistoryRepository {
  @override
  List<MissionRecord> build() => const [];

  @override
  List<MissionRecord> get all => state;

  @override
  void add(MissionRecord record) {
    state = [record, ...state]; // newest first
  }

  @override
  void clear() {
    state = const [];
  }

  // --- Derived aggregates the UI reads directly ---

  /// Total stars across every recorded mission (Home top-left counter).
  int get totalStars => state.fold(0, (sum, r) => sum + r.starsEarned);

  /// Toys collected today (for the "Misión del día" progress).
  int collectedToday(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return state
        .where((r) => r.day == today)
        .fold(0, (sum, r) => sum + r.collectedToyCount);
  }

  /// Whether a calendar day has at least one completed mission.
  bool hasCompletedOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return state.any((r) => r.day == d && r.completed);
  }

  /// Whether a calendar day has any mission record (completed or not).
  bool hasAnyOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return state.any((r) => r.day == d);
  }
}

final missionHistoryProvider =
    NotifierProvider<InMemoryMissionHistoryRepository, List<MissionRecord>>(
  InMemoryMissionHistoryRepository.new,
);

/// The daily goal used by the "Misión del día" card. Static for now;
/// could become a parent-controlled setting later.
const int kDailyToyGoal = 5;
