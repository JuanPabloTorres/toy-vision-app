import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toyvision_realtime/app/toyvision_app.dart';
import 'package:toyvision_realtime/application/cleanup/cleanup_controller.dart';
import 'package:toyvision_realtime/application/cleanup/cleanup_state.dart';
import 'package:toyvision_realtime/application/feedback/audio_feedback_service.dart';
import 'package:toyvision_realtime/application/history/cleanup_history_provider.dart';
import 'package:toyvision_realtime/application/home/home_progress.dart';
import 'package:toyvision_realtime/domain/progress/progress_models.dart';
import 'package:toyvision_realtime/domain/repositories/progress_repository.dart';
import 'package:toyvision_realtime/infrastructure/feedback/cleanup_feedback_coordinator.dart';
import 'package:toyvision_realtime/infrastructure/persistence/shared_preferences_provider.dart';
import 'package:toyvision_realtime/infrastructure/tflite/yolo_model_config.dart';
import 'package:toyvision_realtime/presentation/cleanup/cleanup_screen.dart';
import 'package:toyvision_realtime/presentation/home/home_screen.dart';
import 'package:toyvision_realtime/presentation/widgets/tobi_3d_stage.dart';

void main() {
  testWidgets('child flow opens one camera game in ready phase',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'toyvision.onboarding.completed.v1': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final audio = _SilentAudio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          progressRepositoryProvider.overrideWithValue(_EmptyProgress()),
          audioFeedbackServiceProvider.overrideWithValue(audio),
          resolvedYoloConfigProvider.overrideWith(
            (ref) async => const YoloModelConfig(),
          ),
          tobi3dEnabledProvider.overrideWithValue(false),
          cameraSurfaceEnabledProvider.overrideWithValue(false),
        ],
        child: const ToyVisionApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('TU AVENTURA'), findsOneWidget);
    expect(find.text('Ruta al cuarto limpio'), findsOneWidget);
    expect(find.text('Explora el cuarto'), findsOneWidget);
    expect(find.text('Encuentra lo que hay que recoger'), findsOneWidget);
    expect(find.text('Ponlos en su lugar'), findsOneWidget);
    expect(find.text('¡Cuarto brillante!'), findsOneWidget);
    expect(find.text('¡EMPIEZA AQUÍ!'), findsOneWidget);
    expect(find.byKey(const Key('start-cleanup')), findsOneWidget);
    expect(find.text('Progreso'), findsOneWidget);
    expect(find.text('Desafíos'), findsNothing);

    await tester.tap(find.byKey(const Key('start-cleanup')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('¡Vamos a recoger!'), findsOneWidget);
    expect(find.text('Buscando cosas por recoger…'), findsNothing);

    final context = tester.element(find.byType(CameraGameScreen));
    final container = ProviderScope.containerOf(context);
    expect(find.byKey(const Key('begin-room-scan')), findsOneWidget);
    expect(find.text('ESTOY LISTO'), findsOneWidget);

    await tester.tap(find.byKey(const Key('begin-room-scan')));
    await tester.pump();
    expect(find.text('Preparando la visión…'), findsOneWidget);
    expect(find.text('Encontrar'), findsOneWidget);
    expect(find.text('Recoger'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
    expect(
      container.read(cleanupControllerProvider).phase,
      CleanupPhase.discovering,
    );
    expect(find.byKey(const Key('leave-cleanup')), findsOneWidget);

    await tester.tap(find.byKey(const Key('leave-cleanup')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CameraGameScreen), findsNothing);
    expect(find.text('Ruta al cuarto limpio'), findsOneWidget);
    expect(
      container.read(cleanupControllerProvider).phase,
      CleanupPhase.idle,
    );
    expect(audio.stopped, containsAll(AudioChannel.values));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home path stays usable on a small screen with larger text',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'toyvision.onboarding.completed.v1': true,
    });
    final preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          audioFeedbackServiceProvider.overrideWithValue(_SilentAudio()),
          tobi3dEnabledProvider.overrideWithValue(false),
          homeProgressProvider.overrideWith(
            (ref) async => const HomeProgress(
              totalStars: 12,
              currentStreak: 3,
              completedSessions: 2,
            ),
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(home: HomeScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('start-cleanup')), findsOneWidget);
    expect(find.byKey(const Key('progress-action')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _SilentAudio implements AudioFeedbackService {
  final List<AudioChannel> stopped = [];

  @override
  Future<void> dispose() async {}

  @override
  Future<void> play(
    AudioCue cue, {
    Set<AudioChannel> enabledChannels = allAudioChannels,
  }) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop(AudioChannel channel) async => stopped.add(channel);
}

class _EmptyProgress implements ProgressRepository {
  @override
  Future<void> clear(String childId) async {}

  @override
  Future<CleanupCompletionResult> completeCleanup(
    CleanupCompletionRequest request,
    CleanupCompletionDecider decide,
  ) =>
      throw UnimplementedError();

  @override
  Future<ChildProgress> getProgress(String childId) async =>
      ChildProgress.empty(childId);
}
