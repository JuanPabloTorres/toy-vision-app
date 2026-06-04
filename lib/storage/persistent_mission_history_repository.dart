import 'mission_history_repository.dart';
import 'mission_record.dart';
import 'persistence/json_store.dart';
import 'persistence/shared_preferences_provider.dart';

/// Disk-backed [MissionHistoryRepository]. It is a drop-in replacement for
/// [InMemoryMissionHistoryRepository]: same Riverpod `Notifier` shape, same
/// synchronous `List<MissionRecord>` state, same inherited aggregate getters
/// (`totalStars`, `collectedToday`, `hasCompletedOn`, ...). The only
/// difference is that `build()` seeds from disk and every mutation
/// write-throughs.
///
/// Wiring (in `main()`):
/// ```dart
/// missionHistoryProvider.overrideWith(PersistentMissionHistoryRepository.new)
/// ```
/// The in-memory base class remains the default + the test double, so the
/// existing repository tests keep running without a SharedPreferences mock.
///
/// Privacy: a [MissionRecord] is counts + timestamps + flags only — never a
/// frame, image, or bounding box. See [MissionRecord].
class PersistentMissionHistoryRepository extends InMemoryMissionHistoryRepository {
  /// Namespaced + versioned so a future schema change can migrate cleanly.
  static const String storageKey = 'toyvision.missionHistory.v1';

  late final JsonStore _store;

  @override
  List<MissionRecord> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    _store = JsonStore(prefs);
    return _load();
  }

  List<MissionRecord> _load() {
    return _store
        .readObjectList(storageKey)
        .map(MissionRecord.fromJson)
        .toList(growable: false);
  }

  @override
  void add(MissionRecord record) {
    super.add(record); // updates `state` (newest-first), notifies watchers
    _persist();
  }

  @override
  void clear() {
    super.clear();
    _persist();
  }

  /// The fire-and-forget write triggered by the last mutation. Exposed so
  /// tests can `await repo.lastWrite` before asserting on disk contents.
  Future<void> lastWrite = Future<void>.value();

  void _persist() {
    lastWrite = _store.writeObjectList(
      storageKey,
      state.map((r) => r.toJson()).toList(growable: false),
    );
  }
}
