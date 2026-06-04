import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for all app audio: gentle Home background music and
/// short, friendly UI sound effects. Deliberately small and defensive:
///   - every call is wrapped — a missing/unsupported asset only logs,
///   - SFX are debounced so rapid taps don't machine-gun,
///   - Home music NEVER plays during the camera/mission (battery + focus):
///     callers stop it before mounting the mission screen.
///
/// This supersedes the old single-purpose CelebrationSoundService; the
/// mission-complete chime is [playMissionComplete] here.
class AppAudioService {
  AppAudioService();

  // Asset paths are relative to `assets/` (audioplayers AssetSource).
  static const String _homeMusic = 'audio/home_theme_loop.wav';
  static const String _missionMusic = 'audio/mission_playground_loop.wav';
  /// Public so the settings layer can read the SAME key (single source of
  /// truth for the sound on/off preference — no duplicate store). This service
  /// remains the runtime authority that actually mutes the players.
  static const String mutedPrefKey = 'toyvision.sound.muted';
  static const String _tapSfx = 'audio/button_tap_pop.wav';
  static const String _successSfx = 'audio/button_success_chime.wav';
  static const String _completeSfx = 'audio/mission_complete_reward.wav';

  /// One looping music track at a time (Home theme OR mission playground —
  /// never both). A separate player from SFX so taps can overlap.
  final AudioPlayer _music = AudioPlayer(playerId: 'app_music');

  /// One-shot effects (taps, chimes, celebration).
  final AudioPlayer _sfx = AudioPlayer(playerId: 'app_sfx');

  bool _muted = false;
  String? _playingMusic; // asset currently looping, or null
  bool _preloaded = false;
  DateTime? _lastTapAt;

  bool get isMuted => _muted;

  /// Inverse of [isMuted] — "sound enabled" reads more naturally in settings.
  bool get isSoundEnabled => !_muted;

  /// Load the saved mute preference (defaults to NOT muted). Call once at
  /// startup; returns the value so the UI provider can seed itself.
  Future<bool> loadMutedPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _muted = prefs.getBool(mutedPrefKey) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('AppAudio: load pref failed: $e');
    }
    return _muted;
  }

  Future<void> _savePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(mutedPrefKey, _muted);
    } catch (e) {
      if (kDebugMode) debugPrint('AppAudio: save pref failed: $e');
    }
  }

  /// Warm up the players + asset decoders so the first tap and the music
  /// start without lag. Safe to call repeatedly; tolerant of missing assets.
  Future<void> preload() async {
    if (_preloaded) return;
    _preloaded = true;
    try {
      await _sfx.setPlayerMode(PlayerMode.lowLatency); // near-instant taps
      await _sfx.setSource(AssetSource(_tapSfx));
      await _music.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      if (kDebugMode) debugPrint('AppAudio: preload failed: $e');
    }
  }

  /// Soft looping Home theme (low volume).
  Future<void> playHomeMusic() => _playMusic(_homeMusic, volume: 0.22);

  /// Stop the Home theme (leaving Home / before the camera).
  Future<void> stopHomeMusic() => _stopMusicIf(_homeMusic);

  /// Fun playground loop while a mission runs (the child asked for it).
  Future<void> playMissionMusic() => _playMusic(_missionMusic, volume: 0.3);

  /// Stop the mission playground loop (leaving the mission).
  Future<void> stopMissionMusic() => _stopMusicIf(_missionMusic);

  Future<void> _playMusic(String asset, {required double volume}) async {
    if (_muted || _playingMusic == asset) return;
    _playingMusic = asset;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.play(AssetSource(asset), volume: volume);
      if (kDebugMode) debugPrint('AppAudio: music start $asset');
    } catch (e) {
      _playingMusic = null;
      if (kDebugMode) debugPrint('AppAudio: music $asset failed: $e');
    }
  }

  Future<void> _stopMusicIf(String asset) async {
    if (_playingMusic != asset) return;
    _playingMusic = null;
    try {
      await _music.stop();
      if (kDebugMode) debugPrint('AppAudio: music stop $asset');
    } catch (e) {
      if (kDebugMode) debugPrint('AppAudio: stop music failed: $e');
    }
  }

  /// Short "pop" for a button press. Debounced so fast taps don't stack.
  Future<void> playButtonTap() =>
      _playSfx(_tapSfx, debounce: true, volume: 0.6);

  /// A slightly louder pop for the main call-to-action (Nueva misión,
  /// Comenzar). Same asset, a touch more presence.
  Future<void> playPrimaryAction() =>
      _playSfx(_tapSfx, debounce: true, volume: 0.75);

  /// Happy two-note chime for a positive confirm (e.g. "Ya lo recogí").
  Future<void> playButtonSuccess() => _playSfx(_successSfx, volume: 0.6);

  /// The celebration reward chime when a mission completes.
  Future<void> playMissionComplete() => _playSfx(_completeSfx, volume: 0.7);

  /// A soft, low pop for a gentle "couldn't do that" cue. Reuses the tap
  /// asset at low volume so we never need a harsh error buzzer.
  Future<void> playErrorSoft() => _playSfx(_tapSfx, volume: 0.35);

  Future<void> _playSfx(
    String asset, {
    bool debounce = false,
    double volume = 0.6,
  }) async {
    if (_muted) return;
    if (debounce) {
      final now = DateTime.now();
      if (_lastTapAt != null &&
          now.difference(_lastTapAt!) < const Duration(milliseconds: 120)) {
        return;
      }
      _lastTapAt = now;
    }
    try {
      await _sfx.stop();
      await _sfx.play(AssetSource(asset), volume: volume);
    } catch (e) {
      if (kDebugMode) debugPrint('AppAudio: sfx $asset failed: $e');
    }
  }

  /// Mute/unmute everything. Muting stops whatever music is playing.
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (muted && _playingMusic != null) {
      await _stopMusicIf(_playingMusic!);
    }
    await _savePreference();
    if (kDebugMode) debugPrint('AppAudio: muted=$muted');
  }

  /// Settings-friendly inverse of [setMuted].
  Future<void> setSoundEnabled(bool enabled) => setMuted(!enabled);

  void dispose() {
    _music.dispose();
    _sfx.dispose();
  }
}

/// App-wide singleton audio service.
final appAudioServiceProvider = Provider<AppAudioService>((ref) {
  final service = AppAudioService();
  ref.onDispose(service.dispose);
  return service;
});

/// UI mirror of the mute state (so a speaker icon rebuilds). Kept in memory
/// for now; persist later if a settings store is added. Toggle via a handler
/// that also calls [AppAudioService.setMuted].
final audioMutedProvider = StateProvider<bool>((ref) => false);
