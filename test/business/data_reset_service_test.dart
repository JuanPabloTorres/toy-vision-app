import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toyvision_realtime/business/data_reset_service.dart';
import 'package:toyvision_realtime/storage/active_mission_repository.dart';
import 'package:toyvision_realtime/storage/mission_history_repository.dart';
import 'package:toyvision_realtime/storage/mission_record.dart';
import 'package:toyvision_realtime/storage/persistence/shared_preferences_provider.dart';
import 'package:toyvision_realtime/storage/persistent_mission_history_repository.dart';
import 'package:toyvision_realtime/storage/settings_repository.dart';

MissionRecord _record(DateTime date) => MissionRecord(
      id: date.microsecondsSinceEpoch.toString(),
      date: date,
      initialToyCount: 5,
      collectedToyCount: 5,
      completed: true,
      durationSeconds: 30,
      starsEarned: 3,
    );

ProviderContainer _container(SharedPreferences prefs) => ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        missionHistoryProvider.overrideWith(
          PersistentMissionHistoryRepository.new,
        ),
        activeMissionProvider.overrideWith(
          PersistentActiveMissionRepository.new,
        ),
        settingsProvider.overrideWith(PersistentSettingsRepository.new),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resetProgress wipes missions + active marker, keeps preferences',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final c1 = _container(prefs);
    // Seed progress + a preference change.
    final history = c1.read(missionHistoryProvider.notifier)
        as PersistentMissionHistoryRepository;
    final active = c1.read(activeMissionProvider.notifier)
        as PersistentActiveMissionRepository;
    c1.read(settingsProvider.notifier).updateMusicEnabled(false);
    history.add(_record(DateTime(2026, 6, 3, 10)));
    active.begin(DateTime(2026, 6, 3, 10));
    await history.lastWrite;
    await active.lastWrite;

    c1.read(dataResetServiceProvider).resetProgress();
    await history.lastWrite;
    await active.lastWrite;

    // In-memory: progress gone, preference kept.
    expect(c1.read(missionHistoryProvider), isEmpty);
    expect(c1.read(activeMissionProvider), isNull);
    expect(c1.read(settingsProvider).musicEnabled, isFalse); // preserved
    c1.dispose();

    // On disk (fresh launch): progress stays gone, preference stays kept.
    final c2 = _container(prefs);
    addTearDown(c2.dispose);
    expect(c2.read(missionHistoryProvider), isEmpty);
    expect(c2.read(activeMissionProvider), isNull);
    expect(c2.read(settingsProvider).musicEnabled, isFalse);
  });
}
