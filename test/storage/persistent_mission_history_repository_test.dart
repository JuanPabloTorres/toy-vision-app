import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toyvision_realtime/storage/mission_history_repository.dart';
import 'package:toyvision_realtime/storage/mission_record.dart';
import 'package:toyvision_realtime/storage/persistence/shared_preferences_provider.dart';
import 'package:toyvision_realtime/storage/persistent_mission_history_repository.dart';

MissionRecord _record(DateTime date, {int initial = 5, int collected = 5}) =>
    MissionRecord(
      id: date.microsecondsSinceEpoch.toString(),
      date: date,
      initialToyCount: initial,
      collectedToyCount: collected,
      completed: collected >= initial,
      durationSeconds: 42,
      starsEarned: MissionRecord.starsFor(
        completed: collected >= initial,
        initialToyCount: initial,
        collectedToyCount: collected,
      ),
    );

ProviderContainer _container(SharedPreferences prefs) => ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        missionHistoryProvider.overrideWith(
          PersistentMissionHistoryRepository.new,
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts empty when nothing is persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    addTearDown(c.dispose);
    expect(c.read(missionHistoryProvider), isEmpty);
  });

  test('a saved mission survives a restart (new container, same disk)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // First "launch": add a record and let the write-through complete.
    final c1 = _container(prefs);
    final repo = c1.read(missionHistoryProvider.notifier)
        as PersistentMissionHistoryRepository;
    repo.add(_record(DateTime(2026, 6, 3, 10), initial: 6, collected: 6));
    await repo.lastWrite;
    c1.dispose();

    // Second "launch": a fresh container reading the same prefs sees it.
    final c2 = _container(prefs);
    addTearDown(c2.dispose);
    final restored = c2.read(missionHistoryProvider);
    expect(restored, hasLength(1));
    expect(restored.first.collectedToyCount, 6);
    expect(restored.first.starsEarned, 3);
  });

  test('clear empties both memory and disk', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final c1 = _container(prefs);
    final repo = c1.read(missionHistoryProvider.notifier)
        as PersistentMissionHistoryRepository;
    repo.add(_record(DateTime(2026, 6, 3, 10)));
    await repo.lastWrite;
    repo.clear();
    await repo.lastWrite;
    c1.dispose();

    final c2 = _container(prefs);
    addTearDown(c2.dispose);
    expect(c2.read(missionHistoryProvider), isEmpty);
  });

  test('newest-first ordering is preserved across restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final c1 = _container(prefs);
    final repo = c1.read(missionHistoryProvider.notifier)
        as PersistentMissionHistoryRepository;
    final older = _record(DateTime(2026, 6, 1, 9));
    final newer = _record(DateTime(2026, 6, 2, 9));
    repo.add(older);
    repo.add(newer);
    await repo.lastWrite;
    c1.dispose();

    final c2 = _container(prefs);
    addTearDown(c2.dispose);
    expect(c2.read(missionHistoryProvider).first.id, newer.id);
  });
}
