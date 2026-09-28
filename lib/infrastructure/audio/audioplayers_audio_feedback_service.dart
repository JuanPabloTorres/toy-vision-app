import 'package:audioplayers/audioplayers.dart';

import '../../application/feedback/audio_feedback_service.dart';

class AudioplayersAudioFeedbackService implements AudioFeedbackService {
  AudioplayersAudioFeedbackService()
      : _music = AudioPlayer(playerId: 'cleanup_music'),
        _effects = AudioPlayer(playerId: 'cleanup_effects');

  final AudioPlayer _music;
  final AudioPlayer _effects;
  double _volume = 1;
  AudioCue? _lastCue;
  DateTime? _lastCueAt;
  Object? _lastError;

  Object? get lastError => _lastError;

  static const _missionLoop = 'audio/mission_playground_loop.wav';
  static const _success = 'audio/button_success_chime.wav';
  static const _tap = 'audio/button_tap_pop.wav';
  static const _complete = 'audio/mission_complete_reward.wav';

  @override
  Future<void> play(AudioCue cue) async {
    final now = DateTime.now();
    if (_lastCue == cue &&
        _lastCueAt != null &&
        now.difference(_lastCueAt!) < const Duration(milliseconds: 180)) {
      return;
    }
    _lastCue = cue;
    _lastCueAt = now;
    await _attempt(() async {
      switch (cue) {
        case AudioCue.sessionStart:
        case AudioCue.roomVerification:
          await _music.setReleaseMode(ReleaseMode.loop);
          await _music.play(
            AssetSource(_missionLoop),
            volume: _volume * 0.28,
          );
        case AudioCue.toyFound:
        case AudioCue.toyCollected:
        case AudioCue.encouragement:
        case AudioCue.almostFinished:
          await _effects.stop();
          await _effects.play(AssetSource(_success), volume: _volume * 0.7);
        case AudioCue.cleanupCompleted:
          await _music.stop();
          await _effects.stop();
          await _effects.play(AssetSource(_complete), volume: _volume * 0.8);
        case AudioCue.detectionUncertain:
          await _effects.stop();
          await _effects.play(AssetSource(_tap), volume: _volume * 0.3);
      }
    });
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _attempt(() async {
      await _music.setVolume(_volume * 0.28);
      await _effects.setVolume(_volume);
    });
  }

  @override
  Future<void> stop(AudioChannel channel) async {
    await _attempt(() async {
      switch (channel) {
        case AudioChannel.music:
          await _music.stop();
        case AudioChannel.effects:
        case AudioChannel.voice:
          await _effects.stop();
      }
    });
  }

  @override
  Future<void> dispose() async {
    await _attempt(() async {
      await _music.dispose();
      await _effects.dispose();
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
