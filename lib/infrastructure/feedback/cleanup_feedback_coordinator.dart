import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/cleanup/cleanup_controller.dart';
import '../../application/feedback/audio_feedback_service.dart';
import '../../application/settings/app_settings_controller.dart';
import '../../domain/cleanup/cleanup_event.dart';
import '../../presentation/feedback/animation_director.dart';
import '../audio/audioplayers_audio_feedback_service.dart';

class CleanupFeedbackCoordinator {
  CleanupFeedbackCoordinator({
    required AudioFeedbackService audio,
    required Stream<CleanupEvent> events,
    required void Function(CleanupEvent event) animate,
    Set<AudioChannel> Function()? enabledChannels,
    bool Function()? animationsEnabled,
  })  : _audio = audio,
        _animate = animate,
        _enabledChannels = enabledChannels ?? (() => allAudioChannels),
        _animationsEnabled = animationsEnabled ?? (() => true) {
    _subscription = events.listen(_handle);
  }

  final AudioFeedbackService _audio;
  final void Function(CleanupEvent event) _animate;
  final Set<AudioChannel> Function() _enabledChannels;
  final bool Function() _animationsEnabled;
  late final StreamSubscription<CleanupEvent> _subscription;

  Future<void> _handle(CleanupEvent event) async {
    if (_animationsEnabled()) _animate(event);
    if (event is CleanupStarted) {
      await _play(AudioCue.sessionStart);
    } else if (event is ToyCollected) {
      await _play(AudioCue.toyCollected);
      await HapticFeedback.lightImpact();
    } else if (event is RoomAlmostClean) {
      await _play(AudioCue.almostFinished);
    } else if (event is EmptyRoomVerificationStarted) {
      await _play(AudioCue.roomVerification);
    } else if (event is CleanupCompleted) {
      await _play(AudioCue.cleanupCompleted);
      await HapticFeedback.mediumImpact();
    } else if (event is PerceptionUncertain) {
      await _play(AudioCue.detectionUncertain);
    }
  }

  Future<void> _play(AudioCue cue) async {
    final channels = _enabledChannels();
    if (channels.isNotEmpty) {
      await _audio.play(cue, enabledChannels: channels);
    }
  }

  Future<void> dispose() async {
    await _subscription.cancel();
  }
}

final audioFeedbackServiceProvider = Provider<AudioFeedbackService>((ref) {
  final service = AudioplayersAudioFeedbackService();
  ref.onDispose(service.dispose);
  return service;
});

final cleanupFeedbackCoordinatorProvider =
    Provider<CleanupFeedbackCoordinator>((ref) {
  final coordinator = CleanupFeedbackCoordinator(
    audio: ref.watch(audioFeedbackServiceProvider),
    events: ref.watch(domainEventBusProvider).events,
    animate: ref.read(animationDirectorProvider.notifier).handle,
    enabledChannels: () {
      final settings = ref.read(appSettingsProvider);
      return <AudioChannel>{
        if (settings.musicEnabled) AudioChannel.music,
        if (settings.soundEnabled) AudioChannel.effects,
        if (settings.voiceEnabled) AudioChannel.voice,
      };
    },
    animationsEnabled: () => ref.read(appSettingsProvider).animationsEnabled,
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
