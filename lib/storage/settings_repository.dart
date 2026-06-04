import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../business/app_audio_service.dart';
import 'app_settings.dart';
import 'persistence/json_store.dart';
import 'persistence/shared_preferences_provider.dart';

/// Local preferences store for the Parents section and playful audio.
///
/// Single-source-of-truth split:
///  - **sound** stays owned by [AppAudioService] (the runtime authority that
///    actually mutes the players, persisting the same `mutedPrefKey`). This
///    store mirrors and delegates to it, so there is never a second sound key.
///  - **music / haptics / parentMode** are owned and persisted here as JSON.
///
/// First-run defaults are [AppSettings.defaults] (sound/music/haptics on,
/// parent mode off) — no explicit "seed on first launch" step is needed
/// because an absent store simply resolves to those defaults.
abstract class SettingsRepository {
  AppSettings getSettings();
  void updateSoundEnabled(bool enabled);
  void updateMusicEnabled(bool enabled);
  void updateHapticsEnabled(bool enabled);
  void updateParentModeEnabled(bool enabled);

  /// Restore the store-owned settings (music / haptics / parentMode) to their
  /// first-run defaults. Sound is the audio service's domain — the data-reset
  /// service flips it separately — so it is NOT touched here.
  void resetToDefaults();
}

/// In-memory default + test double — a pure mirror with no SharedPreferences
/// or audio dependency. Production overrides this with
/// [PersistentSettingsRepository] in `main()`.
class InMemorySettingsRepository extends Notifier<AppSettings>
    implements SettingsRepository {
  @override
  AppSettings build() => AppSettings.defaults;

  @override
  AppSettings getSettings() => state;

  @override
  void updateSoundEnabled(bool enabled) =>
      state = state.copyWith(soundEnabled: enabled);

  @override
  void updateMusicEnabled(bool enabled) =>
      state = state.copyWith(musicEnabled: enabled);

  @override
  void updateHapticsEnabled(bool enabled) =>
      state = state.copyWith(hapticsEnabled: enabled);

  @override
  void updateParentModeEnabled(bool enabled) =>
      state = state.copyWith(parentModeEnabled: enabled);

  @override
  void resetToDefaults() => state = AppSettings.defaults;
}

/// Disk-backed subclass — seeds sound from the audio key + the rest from JSON,
/// delegates sound writes to [AppAudioService], and write-throughs the rest.
class PersistentSettingsRepository extends InMemorySettingsRepository {
  /// Namespaced + versioned for forward-compatible migrations.
  static const String storageKey = 'toyvision.settings.v1';

  late final JsonStore _store;

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    _store = JsonStore(prefs);
    // Sound is the audio service's key (muted == !soundEnabled). Read it here
    // so the settings view stays consistent with what the audio service uses.
    final soundEnabled = !(prefs.getBool(AppAudioService.mutedPrefKey) ?? false);
    final json = _store.readObject(storageKey);
    if (json == null) {
      return AppSettings.defaults.copyWith(soundEnabled: soundEnabled);
    }
    return AppSettings.fromJson(json, soundEnabled: soundEnabled);
  }

  @override
  void updateSoundEnabled(bool enabled) {
    // Route through the audio service: it mutes the live players AND persists
    // the shared key. Then mirror into our state — no separate sound write.
    ref.read(appAudioServiceProvider).setSoundEnabled(enabled);
    super.updateSoundEnabled(enabled);
  }

  @override
  void updateMusicEnabled(bool enabled) {
    super.updateMusicEnabled(enabled);
    _persist();
  }

  @override
  void updateHapticsEnabled(bool enabled) {
    super.updateHapticsEnabled(enabled);
    _persist();
  }

  @override
  void updateParentModeEnabled(bool enabled) {
    super.updateParentModeEnabled(enabled);
    _persist();
  }

  @override
  void resetToDefaults() {
    super.resetToDefaults(); // state = AppSettings.defaults
    lastWrite = _store.remove(storageKey);
  }

  /// The write triggered by the last (store-owned) mutation; `await` in tests.
  Future<void> lastWrite = Future<void>.value();

  void _persist() {
    lastWrite = _store.writeObject(storageKey, state.toJson());
  }
}

final settingsProvider =
    NotifierProvider<InMemorySettingsRepository, AppSettings>(
  InMemorySettingsRepository.new,
);
