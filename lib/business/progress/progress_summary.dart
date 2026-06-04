import 'achievement.dart';

/// Aggregated stats for a single calendar day, used by the progress
/// calendar and the day-detail screen.
class DailyProgress {
  const DailyProgress({
    required this.day,
    required this.toysCollected,
    required this.missionsTotal,
    required this.missionsCompleted,
  });

  /// Midnight of the day this bucket represents.
  final DateTime day;

  final int toysCollected;

  /// Every mission recorded on this day (completed or ended early).
  final int missionsTotal;

  /// Missions on this day that were fully completed.
  final int missionsCompleted;

  /// At least one mission was fully completed this day → green.
  bool get hasCompleted => missionsCompleted > 0;

  /// A mission ran but none was fully completed → partial (yellow).
  bool get hasPartial => missionsTotal > 0 && missionsCompleted == 0;
}

/// The full computed view the progress dashboard renders. Built once from
/// the mission history by [ProgressStatsService] so the UI never does
/// arithmetic.
class ProgressSummary {
  const ProgressSummary({
    required this.totalMissionsCompleted,
    required this.totalToysCollected,
    required this.currentStreakDays,
    required this.totalStars,
    required this.daysByDate,
    required this.achievements,
  });

  /// Every completed mission across all of history.
  final int totalMissionsCompleted;

  /// Every toy collected across all of history (completed or not).
  final int totalToysCollected;

  /// Consecutive days, ending today (or yesterday if today is still
  /// empty), with at least one completed mission.
  final int currentStreakDays;

  final int totalStars;

  /// Day buckets keyed by midnight `DateTime`. Empty days are absent.
  final Map<DateTime, DailyProgress> daysByDate;

  final List<Achievement> achievements;

  static const ProgressSummary empty = ProgressSummary(
    totalMissionsCompleted: 0,
    totalToysCollected: 0,
    currentStreakDays: 0,
    totalStars: 0,
    daysByDate: {},
    achievements: [],
  );

  int get unlockedAchievementsCount =>
      achievements.where((a) => a.unlocked).length;

  /// Bucket for a specific day, or null if nothing happened that day.
  DailyProgress? forDay(DateTime day) =>
      daysByDate[DateTime(day.year, day.month, day.day)];
}
