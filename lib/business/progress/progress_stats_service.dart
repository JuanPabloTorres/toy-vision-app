import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../storage/mission_history_repository.dart';
import '../../storage/mission_record.dart';
import 'achievement.dart';
import 'progress_summary.dart';

/// Pure aggregator that turns the raw completed-mission history into the
/// [ProgressSummary] the dashboard renders. No Flutter, no storage engine
/// — just records in, summary out, so it is trivially unit-testable.
class ProgressStatsService {
  const ProgressStatsService();

  ProgressSummary summarize(List<MissionRecord> records, DateTime now) {
    // Note: the empty-history case falls through the normal path — folds
    // yield zero, streak is zero, and the achievement catalog resolves to
    // all-locked, so the dashboard always has the full catalog to show.
    final daysByDate = _bucketByDay(records);

    final totalMissionsCompleted = records.where((r) => r.completed).length;
    final totalToysCollected =
        records.fold<int>(0, (sum, r) => sum + r.collectedToyCount);
    final totalStars = records.fold<int>(0, (sum, r) => sum + r.starsEarned);
    final currentStreakDays = _currentStreak(daysByDate, now);

    final bestSingleMissionToys = records
        .map((r) => r.collectedToyCount)
        .fold<int>(0, (best, c) => c > best ? c : best);
    final hadPerfectFivePlusDay = records.any(
      (r) =>
          r.completed &&
          r.initialToyCount >= 5 &&
          r.collectedToyCount >= r.initialToyCount,
    );

    final achievements = AchievementCatalog.evaluate(
      AchievementContext(
        totalMissionsCompleted: totalMissionsCompleted,
        totalToysCollected: totalToysCollected,
        currentStreakDays: currentStreakDays,
        bestSingleMissionToys: bestSingleMissionToys,
        hadPerfectFivePlusDay: hadPerfectFivePlusDay,
      ),
    );

    return ProgressSummary(
      totalMissionsCompleted: totalMissionsCompleted,
      totalToysCollected: totalToysCollected,
      currentStreakDays: currentStreakDays,
      totalStars: totalStars,
      daysByDate: daysByDate,
      achievements: achievements,
    );
  }

  Map<DateTime, DailyProgress> _bucketByDay(List<MissionRecord> records) {
    final acc = <DateTime, DailyProgress>{};
    for (final r in records) {
      final key = r.day;
      final existing = acc[key];
      acc[key] = DailyProgress(
        day: key,
        toysCollected: (existing?.toysCollected ?? 0) + r.collectedToyCount,
        missionsTotal: (existing?.missionsTotal ?? 0) + 1,
        missionsCompleted:
            (existing?.missionsCompleted ?? 0) + (r.completed ? 1 : 0),
      );
    }
    return acc;
  }

  /// Consecutive days, each with at least one *completed* mission, ending
  /// today. Today is allowed to still be empty (the streak counts from
  /// yesterday) so it doesn't read as broken before the first mission of
  /// the day — but a gap on any earlier day ends the count.
  int _currentStreak(Map<DateTime, DailyProgress> daysByDate, DateTime now) {
    bool completedOn(DateTime day) =>
        daysByDate[DateTime(day.year, day.month, day.day)]?.hasCompleted ??
        false;

    final today = DateTime(now.year, now.month, now.day);
    var cursor = today;
    // If today has nothing yet, the streak can still be alive from
    // yesterday backwards.
    if (!completedOn(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (completedOn(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

/// Recomputes the dashboard summary whenever the mission history changes.
/// `DateTime.now()` is read at build time, which is fine for a derived
/// view provider (it rebuilds on every history mutation).
final progressSummaryProvider = Provider<ProgressSummary>((ref) {
  final records = ref.watch(missionHistoryProvider);
  return const ProgressStatsService().summarize(records, DateTime.now());
});
