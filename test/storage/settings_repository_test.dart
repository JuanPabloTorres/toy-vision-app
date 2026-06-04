import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toyvision_realtime/business/app_audio_service.dart';
import 'package:toyvision_realtime/storage/app_settings.dart';
import 'package:toyvision_realtime/storage/persistence/shared_preferences_provider.dart';
import 'package:toyvision_realtime/storage/settings_repository.dart';

ProviderContainer _container(SharedPreferences prefs) => ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(PersistentSettingsRepository.new),
      ],
    );

PersistentSettingsRepository _repo(ProviderContainer c) =>
    c.read(settingsProvider.notifier) as PersistentSettingsRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first run resolves to defaults (sound/music/haptics on)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    addTearDown(c.dispose);
    final s = c.read(settingsProvider);
    expect(s.soundEnabled, isTrue);
    expect(s.musicEnabled, isTrue);
    expect(s.hapticsEnabled, isTrue);
    expect(s.parentModeEnabled, isFalse);
  });

  test('music / haptics / parentMode persist across a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final c1 = _container(prefs);
    final repo = _repo(c1);
    repo.updateMusicEnabled(false);
    repo.updateHapticsEnabled(false);
    repo.updateParentModeEnabled(true);
    await repo.lastWrite;
    c1.dispose();

    final c2 = _container(prefs);
    addTearDown(c2.dispose);
    final s = c2.read(settingsProvider);
    expect(s.musicEnabled, isFalse);
    expect(s.hapticsEnabled, isFalse);
    expect(s.parentModeEnabled, isTrue);
  });

  test('soundEnabled is seeded from the audio service mute key', () async {
    SharedPreferences.setMockInitialValues({
      AppAudioService.mutedPrefKey: true, // muted == sound OFF
    });
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    addTearDown(c.dispose);
    expect(c.read(settingsProvider).soundEnabled, isFalse);
  });

  test('resetToDefaults restores store-owned settings on disk', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final c1 = _container(prefs);
    final repo = _repo(c1);
    repo.updateMusicEnabled(false);
    repo.updateParentModeEnabled(true);
    await repo.lastWrite;
    repo.resetToDefaults();
    await repo.lastWrite;
    expect(c1.read(settingsProvider), AppSettings.defaults);
    c1.dispose();

    // A fresh launch must also see the defaults (JSON key was removed).
    final c2 = _container(prefs);
    addTearDown(c2.dispose);
    final s = c2.read(settingsProvider);
    expect(s.musicEnabled, isTrue);
    expect(s.parentModeEnabled, isFalse);
  });

  group('privacy', () {
    test('serialized settings carry no sensitive or media fields', () {
      final json = const AppSettings(
        soundEnabled: false,
        musicEnabled: false,
        hapticsEnabled: true,
        parentModeEnabled: true,
      ).toJson();

      // Sound lives in the audio key, never duplicated into settings JSON.
      expect(json.containsKey('soundEnabled'), isFalse);
      // No image/frame/camera metadata may ever be stored.
      for (final forbidden in const [
        'image',
        'frame',
        'photo',
        'bitmap',
        'path',
        'boundingBox',
      ]) {
        expect(
          json.keys.any((k) => k.toLowerCase().contains(forbidden)),
          isFalse,
          reason: 'settings JSON must not contain "$forbidden"',
        );
      }
    });
  });
}
