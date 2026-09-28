import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../../application/feedback/audio_feedback_service.dart';

class AudioplayersAudioFeedbackService implements AudioFeedbackService {
  AudioplayersAudioFeedbackService()
      : _music = AudioPlayer(playerId: 'cleanup_music'),
        _effects = AudioPlayer(playerId: 'cleanup_effects'),
        _voice = AudioPlayer(playerId: 'tobi_voice');

  final AudioPlayer _music;
  final AudioPlayer _effects;
  final AudioPlayer _voice;
  double _volume = 1;
  bool _musicPlaying = false;
  int _voiceGeneration = 0;
  Future<void>? _configuration;
  AudioCue? _lastCue;
  DateTime? _lastCueAt;
  AudioCue? _lastVoiceCue;
  DateTime? _lastVoiceAt;
  Object? _lastError;

  Object? get lastError => _lastError;

  static const _missionLoop = 'audio/tobi_adventure_loop.wav';
  static const _success = 'audio/button_success_chime.wav';
  static const _tap = 'audio/button_tap_pop.wav';
  static const _complete = 'audio/mission_complete_reward.wav';
  static const _voiceAssets = <AudioCue, String>{
    AudioCue.sessionStart: 'audio/tobi_session_start.wav',
    AudioCue.roomVerification: 'audio/tobi_room_verification.wav',
    AudioCue.toyFound: 'audio/tobi_toy_collected.wav',
    AudioCue.toyCollected: 'audio/tobi_toy_collected.wav',
    AudioCue.encouragement: 'audio/tobi_almost_finished.wav',
    AudioCue.almostFinished: 'audio/tobi_almost_finished.wav',
    AudioCue.cleanupCompleted: 'audio/tobi_cleanup_completed.wav',
    AudioCue.detectionUncertain: 'audio/tobi_detection_uncertain.wav',
  };
  static const _voiceCooldowns = <AudioCue, Duration>{
    AudioCue.toyCollected: Duration(milliseconds: 1200),
    AudioCue.detectionUncertain: Duration(seconds: 8),
  };

  @override
  Future<void> play(
    AudioCue cue, {
    Set<AudioChannel> enabledChannels = allAudioChannels,
  }) async {
    final now = DateTime.now();
    if (_lastCue == cue &&
        _lastCueAt != null &&
        now.difference(_lastCueAt!) < const Duration(milliseconds: 180)) {
      return;
    }
    _lastCue = cue;
    _lastCueAt = now;
    await _attempt(() async {
      await _ensureConfigured();
      if (cue == AudioCue.cleanupCompleted) {
        await _music.stop();
        _musicPlaying = false;
      } else if (cue == AudioCue.sessionStart &&
          enabledChannels.contains(AudioChannel.music)) {
        await _startMusic();
      }

      final playback = <Future<void>>[];
      if (enabledChannels.contains(AudioChannel.effects)) {
        playback.add(_playEffect(cue));
      }
      if (enabledChannels.contains(AudioChannel.voice)) {
        playback.add(_playVoice(cue));
      }
      await Future.wait(playback);
    });
  }

  Future<void> _ensureConfigured() => _configuration ??= () async {
        final context = AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build();
        await Future.wait([
          _music.setAudioContext(context),
          _effects.setAudioContext(context),
          _voice.setAudioContext(context),
        ]);
      }();

  Future<void> _startMusic() async {
    if (_musicPlaying) return;
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.play(
      AssetSource(_missionLoop),
      volume: _volume * 0.24,
    );
    _musicPlaying = true;
  }

  Future<void> _playEffect(AudioCue cue) async {
    final (asset, gain) = switch (cue) {
      AudioCue.toyFound ||
      AudioCue.toyCollected ||
      AudioCue.encouragement ||
      AudioCue.almostFinished =>
        (_success, 0.68),
      AudioCue.cleanupCompleted => (_complete, 0.8),
      AudioCue.detectionUncertain => (_tap, 0.28),
      AudioCue.sessionStart || AudioCue.roomVerification => (null, 0.0),
    };
    if (asset == null) return;
    await _effects.stop();
    await _effects.play(AssetSource(asset), volume: _volume * gain);
  }

  Future<void> _playVoice(AudioCue cue) async {
    final asset = _voiceAssets[cue];
    if (asset == null) return;
    final now = DateTime.now();
    final cooldown = _voiceCooldowns[cue];
    if (_lastVoiceCue == cue &&
        _lastVoiceAt != null &&
        cooldown != null &&
        now.difference(_lastVoiceAt!) < cooldown) {
      return;
    }
    _lastVoiceCue = cue;
    _lastVoiceAt = now;
    final generation = ++_voiceGeneration;
    await _voice.stop();
    if (_musicPlaying) await _music.setVolume(_volume * 0.09);
    await _voice.play(AssetSource(asset), volume: _volume * 0.92);
    unawaited(
      _voice.onPlayerComplete.first.then((_) async {
        if (generation == _voiceGeneration && _musicPlaying) {
          await _music.setVolume(_volume * 0.24);
        }
      }),
    );
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _attempt(() async {
      await _music.setVolume(_volume * 0.24);
      await _effects.setVolume(_volume);
      await _voice.setVolume(_volume * 0.92);
    });
  }

  @override
  Future<void> stop(AudioChannel channel) async {
    await _attempt(() async {
      switch (channel) {
        case AudioChannel.music:
          await _music.stop();
          _musicPlaying = false;
        case AudioChannel.effects:
          await _effects.stop();
        case AudioChannel.voice:
          _voiceGeneration += 1;
          await _voice.stop();
      }
    });
  }

  @override
  Future<void> dispose() async {
    await _attempt(() async {
      await _music.dispose();
      await _effects.dispose();
      await _voice.dispose();
    });
  }

  Future<void> _attempt(Future<void> Function() operation) async {
    try {
      await operation();
      _lastError = null;
    } catch (error) {
      // Feedback is non-critical: perception and cleanup must remain available.
      _lastError = error;
    }
  }
}
