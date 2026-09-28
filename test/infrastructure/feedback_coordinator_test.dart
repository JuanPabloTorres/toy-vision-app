import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/application/events/domain_event_bus.dart';
import 'package:toyvision_realtime/application/feedback/audio_feedback_service.dart';
import 'package:toyvision_realtime/domain/cleanup/cleanup_event.dart';
import 'package:toyvision_realtime/infrastructure/feedback/cleanup_feedback_coordinator.dart';
import 'package:toyvision_realtime/presentation/feedback/animation_director.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('domain events drive audio and visual adapters together', () async {
    final container = ProviderContainer();
    final events = DomainEventBus();
    final audio = _RecordingAudio();
    final coordinator = CleanupFeedbackCoordinator(
      audio: audio,
      events: events.events,
      animate: container.read(animationDirectorProvider.notifier).handle,
      enabledChannels: () => const {
        AudioChannel.effects,
        AudioChannel.voice,
      },
    );
    addTearDown(() async {
      await coordinator.dispose();
      await events.dispose();
      container.dispose();
    });

    events.publishAll([ToyCollected(DateTime.utc(2026), 7)]);
    await _flushEvents();

    expect(audio.cues, [AudioCue.toyCollected]);
    expect(audio.channels.single, {
      AudioChannel.effects,
      AudioChannel.voice,
    });
    var animation = container.read(animationDirectorProvider);
    expect(animation.tobiState, TobiState.foundToy);
    expect(animation.modelAnimation, 'clap');
    expect(animation.riveTrigger, 'star_burst');
    expect(animation.lottieEffect, 'assets/lottie/toy_collected.json');

    events.publishAll([CleanupCompleted(DateTime.utc(2026), 1)]);
    await _flushEvents();

    expect(audio.cues.last, AudioCue.cleanupCompleted);
    animation = container.read(animationDirectorProvider);
    expect(animation.tobiState, TobiState.finished);
    expect(animation.modelAnimation, 'celebrate');
    expect(animation.riveTrigger, 'celebrate');
    expect(animation.lottieEffect, 'assets/lottie/celebration.json');
  });
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

class _RecordingAudio implements AudioFeedbackService {
  final List<AudioCue> cues = [];
  final List<Set<AudioChannel>> channels = [];

  @override
  Future<void> play(
    AudioCue cue, {
    Set<AudioChannel> enabledChannels = allAudioChannels,
  }) async {
    cues.add(cue);
    channels.add(enabledChannels);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop(AudioChannel channel) async {}

  @override
  Future<void> dispose() async {}
}
