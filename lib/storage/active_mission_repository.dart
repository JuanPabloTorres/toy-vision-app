import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_mission_record.dart';
import 'persistence/json_store.dart';
import 'persistence/shared_preferences_provider.dart';

/// Persists the single in-progress cleanup mission (or `null` when none is
/// running) so an interrupted mission can be recovered on next launch.
///
/// Lifecycle is driven by the mission controller at exactly three one-shot
/// points — [begin] on "Nueva misión", [updateBaseline] once the opening scan
/// settles, and [clear] when the mission ends or is reset. It is never written
/// per frame, so it stays clear of the live detection loop.
abstract class ActiveMissionRepository {
  /// The active mission, or `null` when none is in progress.
  ActiveMissionRecord? get current;

  /// Begin a mission at [startedAt]. Replaces any prior (stale) active record.
  void begin(DateTime startedAt);

  /// Record the baseline toy count once the opening scan has settled.
  void updateBaseline(int baselineToyCount);

  /// End the active mission (completed, ended early, or reset).
  void clear();
}

/// In-memory default + test double (no SharedPreferences mock required).
/// Production overrides this with [PersistentActiveMissionRepository] in
/// `main()`. Exposed as a Riverpod `Notifier` so any "resume your mission?"
/// affordance can simply watch [activeMissionProvider].
class InMemoryActiveMissionRepository extends Notifier<ActiveMissionRecord?>
    implements ActiveMissionRepository {
  @override
  ActiveMissionRecord? build() => null;

  @override
  ActiveMissionRecord? get current => state;

  @override
  void begin(DateTime startedAt) {
    state = ActiveMissionRecord(startedAt: startedAt);
  }

  @override
  void updateBaseline(int baselineToyCount) {
    final active = state;
    if (active == null) return;
    state = active.copyWith(baselineToyCount: baselineToyCount);
  }

  @override
  void clear() => state = null;
}

/// Disk-backed subclass — a drop-in for the in-memory base (same `Notifier`
/// shape) that seeds from disk and write-throughs every mutation.
class PersistentActiveMissionRepository extends InMemoryActiveMissionRepository {
  /// Namespaced + versioned for forward-compatible migrations.
  static const String storageKey = 'toyvision.activeMission.v1';

  late final JsonStore _store;

  @override
  ActiveMissionRecord? build() {
    _store = JsonStore(ref.watch(sharedPreferencesProvider));
    final json = _store.readObject(storageKey);
    if (json == null) return null;
    try {
      return ActiveMissionRecord.fromJson(json);
    } catch (_) {
      return null; // tolerate a shape change across versions
    }
  }

  @override
  void begin(DateTime startedAt) {
    super.begin(startedAt);
    _persist();
  }

  @override
  void updateBaseline(int baselineToyCount) {
    super.updateBaseline(baselineToyCount);
    _persist();
  }

  @override
  void clear() {
    super.clear();
    _persist();
  }

  /// The write triggered by the last mutation; `await` it in tests.
  Future<void> lastWrite = Future<void>.value();

  void _persist() {
    lastWrite = _store.writeObject(storageKey, state?.toJson());
  }
}

final activeMissionProvider =
    NotifierProvider<InMemoryActiveMissionRepository, ActiveMissionRecord?>(
  InMemoryActiveMissionRepository.new,
);
