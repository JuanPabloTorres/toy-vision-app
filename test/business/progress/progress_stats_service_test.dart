import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/progress/achievement.dart';
import 'package:toyvision_realtime/business/progress/progress_stats_service.dart';
import 'package:toyvision_realtime/storage/mission_record.dart';

MissionRecord _record({
  required DateTime date,
  int initial = 5,
  int collected = 5,
  bool completed = true,
}) =>
    MissionRecord(
      id: date.microsecondsSinceEpoch.toString(),
      date: date,
      initialToyCount: initial,
      collectedToyCount: collected,
      completed: completed,
      durationSeconds: 60,
      starsEarned: MissionRecord.starsFor(
        completed: completed,
        initialToyCount: initial,
        collectedToyCount: collected,
      ),
    );

Map<String, bool> _unlocked(List<Achievement> achievements) => {
      for (final a in achievements) a.id: a.unlocked,
    };

void main() {
  const service = ProgressStatsService();
  final now = DateTime(2026, 6, 2, 12);

  group('empty history', () {
    test('all aggregates are zero and the full catalog is locked', () {
      final s = service.summarize(const [], now);
      expect(s.totalMissionsCompleted, 0);
      expect(s.totalToysCollected, 0);
      expect(s.currentStreakDays, 0);
      expect(s.totalStars, 0);
      expect(s.daysByDate, isEmpty);
      expect(s.achievements, isNotEmpty); // catalog still shown…
      expect(s.achievements.every((a) => !a.unlocked), isTrue); // …all locked
    });
  });

  group('totals and per-day bucketing', () {
    test('sums toys/stars and counts completed missions', () {
      final s = service.summarize(
        [
          _record(date: DateTime(2026, 6, 2, 9), initial: 6, collected: 6),
          _record(
            date: DateTime(2026, 6, 2, 18),
            initial: 4,
            collected: 2,
            completed: false,
          ),
        ],
        now,
      );

      expect(s.totalToysCollected, 8);
      expect(s.totalMissionsCompleted, 1);
      // 3 stars (completed, 6 toys) + 1 star (showed up) = 4
      expect(s.totalStars, 4);

      final day = s.forDay(DateTime(2026, 6, 2))!;
      expect(day.toysCollected, 8);
      expect(day.missionsTotal, 2);
      expect(day.missionsCompleted, 1);
      expect(day.hasCompleted, isTrue);
    });

    test('a day with only an incomplete mission reads as partial', () {
      final s = service.summarize(
        [_record(date: DateTime(2026, 6, 1, 10), completed: false)],
        now,
      );
      final day = s.forDay(DateTime(2026, 6, 1))!;
      expect(day.hasCompleted, isFalse);
      expect(day.hasPartial, isTrue);
    });
  });

  group('current streak', () {
    test('counts consecutive completed days ending today', () {
      final s = service.summarize(
        [
          _record(date: DateTime(2026, 6, 2, 9)),
          _record(date: DateTime(2026, 6, 1, 9)),
          _record(date: DateTime(2026, 5, 31, 9)),
        ],
        now,
      );
      expect(s.currentStreakDays, 3);
    });

    test('today still empty keeps yesterday-anchored streak alive', () {
      final s = service.summarize(
        [
          _record(date: DateTime(2026, 6, 1, 9)),
          _record(date: DateTime(2026, 5, 31, 9)),
        ],
        now,
      );
      expect(s.currentStreakDays, 2);
    });

    test('a gap breaks the streak', () {
      final s = service.summarize(
        [
          _record(date: DateTime(2026, 6, 2, 9)),
          // no June 1
          _record(date: DateTime(2026, 5, 31, 9)),
        ],
        now,
      );
      expect(s.currentStreakDays, 1);
    });

    test('an incomplete day does not extend the streak', () {
      final s = service.summarize(
        [
          _record(date: DateTime(2026, 6, 2, 9), completed: false),
          _record(date: DateTime(2026, 6, 1, 9)),
        ],
        now,
      );
      // Today is incomplete → not counted; yesterday completed → streak 1.
      expect(s.currentStreakDays, 1);
    });
  });

  group('achievements', () {
    test('first mission + five toys + perfect day on a 5-toy mission', () {
      final s = service.summarize(
        [_record(date: DateTime(2026, 6, 2, 9), initial: 5, collected: 5)],
        now,
      );
      final m = _unlocked(s.achievements);
      expect(m['first_mission'], isTrue);
      expect(m['five_toys'], isTrue);
      expect(m['perfect_day'], isTrue);
      expect(m['ten_missions'], isFalse);
      expect(m['fifty_toys'], isFalse);
    });

    test('streak_3 unlocks at a 3-day streak', () {
      final s = service.summarize(
        [
          _record(date: DateTime(2026, 6, 2, 9)),
          _record(date: DateTime(2026, 6, 1, 9)),
          _record(date: DateTime(2026, 5, 31, 9)),
        ],
        now,
      );
      expect(_unlocked(s.achievements)['streak_3'], isTrue);
    });
  });
}
