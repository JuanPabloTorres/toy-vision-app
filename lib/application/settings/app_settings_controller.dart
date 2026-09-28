import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/progress/progress_models.dart';
import '../../infrastructure/persistence/shared_preferences_provider.dart';
import '../history/cleanup_history_provider.dart';
import '../home/home_progress.dart';

class AppSettingsState {
  const AppSettingsState({
    this.soundEnabled = true,
    this.voiceEnabled = true,
    this.musicEnabled = true,
    this.animationsEnabled = true,
    this.kidModeEnabled = true,
  });

  final bool soundEnabled;
  final bool voiceEnabled;
  final bool musicEnabled;
  final bool animationsEnabled;
  final bool kidModeEnabled;

  AppSettingsState copyWith({
    bool? soundEnabled,
    bool? voiceEnabled,
    bool? musicEnabled,
    bool? animationsEnabled,
    bool? kidModeEnabled,
  }) =>
      AppSettingsState(
        soundEnabled: soundEnabled ?? this.soundEnabled,
        voiceEnabled: voiceEnabled ?? this.voiceEnabled,
        musicEnabled: musicEnabled ?? this.musicEnabled,
        animationsEnabled: animationsEnabled ?? this.animationsEnabled,
        kidModeEnabled: kidModeEnabled ?? this.kidModeEnabled,
      );
}

class AppSettingsController extends Notifier<AppSettingsState> {
  static const _soundKey = 'toyvision.settings.sound';
  static const _voiceKey = 'toyvision.settings.voice';
  static const _musicKey = 'toyvision.settings.music';
  static const _animationsKey = 'toyvision.settings.animations';
  static const _kidModeKey = 'toyvision.settings.kid_mode';

  @override
  AppSettingsState build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    return AppSettingsState(
      soundEnabled: preferences.getBool(_soundKey) ?? true,
      voiceEnabled: preferences.getBool(_voiceKey) ?? true,
      musicEnabled: preferences.getBool(_musicKey) ?? true,
      animationsEnabled: preferences.getBool(_animationsKey) ?? true,
      kidModeEnabled: preferences.getBool(_kidModeKey) ?? true,
    );
  }

  Future<void> setSound(bool value) => _update(
        state.copyWith(soundEnabled: value),
        _soundKey,
        value,
      );

  Future<void> setVoice(bool value) => _update(
        state.copyWith(voiceEnabled: value),
        _voiceKey,
        value,
      );

  Future<void> setMusic(bool value) => _update(
        state.copyWith(musicEnabled: value),
        _musicKey,
        value,
      );

  Future<void> setAnimations(bool value) => _update(
        state.copyWith(animationsEnabled: value),
        _animationsKey,
        value,
      );

  Future<void> setKidMode(bool value) => _update(
        state.copyWith(kidModeEnabled: value),
        _kidModeKey,
        value,
      );

  Future<void> resetProgress() async {
    await ref
        .read(progressRepositoryProvider)
        .clear(ProgressIdentity.primaryChildId);
    ref.invalidate(homeProgressProvider);
  }

  Future<void> _update(
    AppSettingsState next,
    String key,
    bool value,
  ) async {
    state = next;
    await ref.read(sharedPreferencesProvider).setBool(key, value);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettingsState>(
  AppSettingsController.new,
);
