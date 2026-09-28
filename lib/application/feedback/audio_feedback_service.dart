enum AudioChannel { music, effects, voice }

const allAudioChannels = <AudioChannel>{
  AudioChannel.music,
  AudioChannel.effects,
  AudioChannel.voice,
};

enum AudioCue {
  gameReady,
  uiTap,
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
  Future<void> play(
    AudioCue cue, {
    Set<AudioChannel> enabledChannels = allAudioChannels,
  });
  Future<void> stop(AudioChannel channel);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}
