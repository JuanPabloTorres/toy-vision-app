import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../business/live_detection_state.dart';
import '../business/toy_category_registry.dart';
import '../business/toy_counting_service.dart';
import '../business/toy_detection_rules.dart';
import '../core/config/realtime_detection_config.dart';
import '../detection/detectors/fallback_toy_detector.dart';
import '../detection/detectors/mock_toy_detector.dart';
import '../detection/detectors/tflite/tflite_toy_detector.dart';
import '../detection/detectors/toy_detector.dart';
import '../detection/models/toy_model_config.dart';
import '../tracking/toy_tracking_engine.dart';
import 'models/camera_status.dart';
import 'services/camera_controller_service.dart';
import 'services/frame_processing_service.dart';

final realtimeConfigProvider = Provider<RealtimeDetectionConfig>(
  (ref) => RealtimeDetectionConfig.defaults,
);

final toyCategoryRegistryProvider = Provider<ToyCategoryRegistry>(
  (ref) => ToyCategoryRegistry.standard(),
);

/// Which detector the live pipeline uses. Defaults to [ToyDetectorMode.mock];
/// the TFLite path is opt-in and only becomes active once it passes its config
/// and adapter checks — and even then it falls back to the mock if the model is
/// unavailable.
enum ToyDetectorMode { mock, tfliteWithFallback }

final toyDetectorModeProvider =
    Provider<ToyDetectorMode>((ref) => ToyDetectorMode.mock);

final toyModelConfigProvider =
    Provider<ToyModelConfig>((ref) => ToyModelConfig.defaults);

/// Builds the active detector for the selected mode.
///
/// - [ToyDetectorMode.mock]: the proven [MockToyDetector] (default).
/// - [ToyDetectorMode.tfliteWithFallback]: attempt [TfliteToyDetector], falling
///   back to the mock if the model/runtime is unavailable. No native TFLite
///   runtime is wired in this phase, so this currently resolves to the mock.
final toyDetectorProvider = Provider<ToyDetector>((ref) {
  switch (ref.watch(toyDetectorModeProvider)) {
    case ToyDetectorMode.mock:
      return MockToyDetector();
    case ToyDetectorMode.tfliteWithFallback:
      return FallbackToyDetector(
        primary: TfliteToyDetector(
          config: ref.watch(toyModelConfigProvider),
          registry: ref.watch(toyCategoryRegistryProvider),
        ),
        fallback: MockToyDetector(),
      );
  }
});

final toyDetectionRulesProvider = Provider<ToyDetectionRules>(
  (ref) => ToyDetectionRules(ref.watch(toyCategoryRegistryProvider)),
);

final trackingEngineProvider = Provider<ToyTrackingEngine>(
  (ref) => ToyTrackingEngine(config: ref.watch(realtimeConfigProvider)),
);

final countingServiceProvider = Provider<ToyCountingService>(
  (ref) => ToyCountingService(config: ref.watch(realtimeConfigProvider)),
);

final frameProcessingServiceProvider = Provider<FrameProcessingService>(
  (ref) => FrameProcessingService(
    detector: ref.watch(toyDetectorProvider),
    config: ref.watch(realtimeConfigProvider),
  ),
);

final liveDetectionControllerProvider =
    NotifierProvider<LiveDetectionController, LiveDetectionState>(
  LiveDetectionController.new,
);

/// Orchestrates the live detection loop and exposes an immutable
/// [LiveDetectionState] for the UI.
///
/// This is the only place the pipeline is wired together
/// (camera frame → throttle/skip → detect → validate → track → count → state).
/// It owns no business math itself; validation, tracking, and counting live in
/// their own layers, and frame access lives in the camera layer.
class LiveDetectionController extends Notifier<LiveDetectionState> {
  @override
  LiveDetectionState build() {
    ref.listen<CameraStatus>(cameraStatusProvider, (_, next) {
      if (next == CameraStatus.ready) _maybeStartStream();
    });
    Future.microtask(_init);
    return LiveDetectionState.initial();
  }

  ToyDetector get _detector => ref.read(toyDetectorProvider);
  FrameProcessingService get _frames =>
      ref.read(frameProcessingServiceProvider);
  ToyDetectionRules get _rules => ref.read(toyDetectionRulesProvider);
  ToyTrackingEngine get _engine => ref.read(trackingEngineProvider);
  ToyCountingService get _counting => ref.read(countingServiceProvider);
  CameraControllerService get _camera =>
      ref.read(cameraStatusProvider.notifier);

  Future<void> _init() async {
    try {
      await _detector.initialize();
      state = state.copyWith(status: ModelStatus.ready);
      // Camera may already be ready before this controller was built.
      if (ref.read(cameraStatusProvider) == CameraStatus.ready) {
        await _maybeStartStream();
      }
    } catch (_) {
      state = state.copyWith(status: ModelStatus.error);
    }
  }

  Future<void> _maybeStartStream() async {
    if (state.isPaused) return;
    await _camera.startStream(processIncomingFrame);
  }

  /// Handle one camera frame. Public for testing; in production it is the image
  /// stream callback. Honors pause, throttle, and skip-if-busy before running
  /// the validate → track → count pipeline.
  @visibleForTesting
  Future<void> processIncomingFrame(CameraImage? image) async {
    if (state.isPaused) return;

    final raw = await _frames.process(image);
    if (raw == null) return; // throttled or skipped

    final validated = _rules.validate(raw);
    final tracked = _engine.update(validated);
    final summary = _counting.update(tracked);
    final visible = tracked.where((t) => t.isVisible).toList(growable: false);

    state = state.copyWith(
      status: ModelStatus.ready,
      visibleToys: visible,
      summary: summary,
    );
  }

  void pause() {
    state = state.copyWith(isPaused: true);
    _camera.pauseStream();
  }

  void resume() {
    state = state.copyWith(isPaused: false);
    _camera.resumeStream(processIncomingFrame);
  }

  void togglePause() => state.isPaused ? resume() : pause();

  /// Clear tracking, counts, and throttle state and restart the count from zero.
  /// Does not change the user's pause state.
  void reset() {
    _engine.reset();
    _counting.reset();
    _frames.reset();
    state = state.copyWith(
      visibleToys: const [],
      summary: ToyCountSummary.empty,
    );
  }

  /// React to app lifecycle changes: release the stream when backgrounded and
  /// resume it on return (unless the user paused). The camera service keeps the
  /// controller initialized so the preview survives brief backgrounding.
  void handleAppLifecycle(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.resumed:
        if (!state.isPaused) _camera.resumeStream(processIncomingFrame);
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _camera.pauseStream();
    }
  }
}
