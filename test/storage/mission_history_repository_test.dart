import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/storage/mission_history_repository.dart';
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

void main() {
  group('MissionRecord.starsFor', () {
    test('1 star just for finishing (incomplete, few toys)', () {
      expect(
        MissionRecord.starsFor(
          completed: false,
          initialToyCount: 2,
          collectedToyCount: 1,
        ),
        1,
      );
    });

    test('2 stars when completed with few toys', () {
      expect(
        MissionRecord.starsFor(
          completed: true,
          initialToyCount: 3,
          collectedToyCount: 3,
        ),
        2,
      );
    });

    test('3 stars when completed with 5+ toys', () {
      expect(
        MissionRecord.starsFor(
          completed: true,
          initialToyCount: 6,
          collectedToyCount: 6,
        ),
        3,
      );
    });
  });

  group('InMemoryMissionHistoryRepository', () {
    ProviderContainer container() => ProviderContainer();

    test('starts empty', () {
      final c = container();
      addTearDown(c.dispose);
      expect(c.read(missionHistoryProvider), isEmpty);
    });

    test('add prepends newest-first and clear empties', () {
      final c = container();
      addTearDown(c.dispose);
      final repo = c.read(missionHistoryProvider.notifier);
      final older = _record(date: DateTime(2026, 6, 1, 9));
      final newer = _record(date: DateTime(2026, 6, 1, 18));
      repo.add(older);
      repo.add(newer);
      expect(c.read(missionHistoryProvider).first.id, newer.id);
      expect(c.read(missionHistoryProvider).length, 2);
      repo.clear();
      expect(c.read(missionHistoryProvider), isEmpty);
    });

    test('totalStars sums every record', () {
      final c = container();
      addTearDown(c.dispose);
      final repo = c.read(missionHistoryProvider.notifier);
      repo.add(_record(date: DateTime(2026, 6, 1), initial: 6, collected: 6));
      repo.add(
        _record(
          date: DateTime(2026, 6, 2),
          initial: 2,
          collected: 1,
          completed: false,
        ),
      );
      expect(repo.totalStars, 3 + 1);
    });

    test('collectedToday only counts today', () {
      final c = container();
      addTearDown(c.dispose);
      final repo = c.read(missionHistoryProvider.notifier);
      final now = DateTime(2026, 6, 1, 12);
      repo.add(_record(date: now, collected: 3));
      repo.add(_record(date: DateTime(2026, 5, 31, 12), collected: 9));
      expect(repo.collectedToday(now), 3);
    });

    test('hasCompletedOn / hasAnyOn reflect the records', () {
      final c = container();
      addTearDown(c.dispose);
      final repo = c.read(missionHistoryProvider.notifier);
      final day = DateTime(2026, 6, 1, 10);
      repo.add(_record(date: day, completed: false));
      expect(repo.hasAnyOn(day), isTrue);
      expect(repo.hasCompletedOn(day), isFalse);
      repo.add(_record(date: DateTime(2026, 6, 1, 20), completed: true));
      expect(repo.hasCompletedOn(day), isTrue);
    });

    test('JSON round-trips a record', () {
      final r = _record(date: DateTime(2026, 6, 1, 15, 30));
      final back = MissionRecord.fromJson(r.toJson());
      expect(back.id, r.id);
      expect(back.initialToyCount, r.initialToyCount);
      expect(back.collectedToyCount, r.collectedToyCount);
      expect(back.completed, r.completed);
      expect(back.starsEarned, r.starsEarned);
    });
  });
}
