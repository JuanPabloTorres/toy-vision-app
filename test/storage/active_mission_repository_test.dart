import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toyvision_realtime/storage/active_mission_repository.dart';
import 'package:toyvision_realtime/storage/persistence/shared_preferences_provider.dart';

ProviderContainer _container(SharedPreferences prefs) => ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeMissionProvider.overrideWith(
          PersistentActiveMissionRepository.new,
        ),
      ],
    );

PersistentActiveMissionRepository _repo(ProviderContainer c) =>
    c.read(activeMissionProvider.notifier) as PersistentActiveMissionRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('no active mission by default', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    addTearDown(c.dispose);
    expect(c.read(activeMissionProvider), isNull);
  });

  test('an in-progress mission is recoverable after a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final startedAt = DateTime(2026, 6, 3, 14, 30);

    // App "crashes" mid-mission: begin was called, clear was not.
    final c1 = _container(prefs);
    final repo = _repo(c1);
    repo.begin(startedAt);
    repo.updateBaseline(4);
    await repo.lastWrite;
    c1.dispose();

    // Next launch sees the active mission to resume or close.
    final c2 = _container(prefs);
    addTearDown(c2.dispose);
    final recovered = c2.read(activeMissionProvider);
    expect(recovered, isNotNull);
    expect(recovered!.startedAt, startedAt);
    expect(recovered.baselineToyCount, 4);
  });

  test('clearing a completed mission leaves nothing to recover', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final c1 = _container(prefs);
    final repo = _repo(c1);
    repo.begin(DateTime(2026, 6, 3, 14));
    await repo.lastWrite;
    repo.clear();
    await repo.lastWrite;
    c1.dispose();

    final c2 = _container(prefs);
    addTearDown(c2.dispose);
    expect(c2.read(activeMissionProvider), isNull);
  });

  test('begin replaces a stale prior marker', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    addTearDown(c.dispose);
    final repo = _repo(c);
    repo.begin(DateTime(2026, 6, 1));
    repo.begin(DateTime(2026, 6, 3));
    expect(c.read(activeMissionProvider)!.startedAt, DateTime(2026, 6, 3));
    expect(c.read(activeMissionProvider)!.baselineToyCount, isNull);
  });
}
