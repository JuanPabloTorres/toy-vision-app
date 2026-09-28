enum AudioChannel { music, effects, voice }

enum AudioCue {
  sessionStart,
  roomVerification,
  toyFound,
  toyCollected,
  encouragement,
  almostFinished,
  cleanupCompleted,
  detectionUncertain,
}

abstract interface class AudioFeedbackService {
  Future<void> play(AudioCue cue);
  Future<void> stop(AudioChannel channel);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}
