import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/widgets.dart' show AppLifecycleState, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../business/live_detection_state.dart';
import '../business/review/candidate_review_controller.dart';
import '../business/toy_category_registry.dart';
import '../business/toy_counting_service.dart';
import '../business/toy_detection_rules.dart';
import '../core/config/realtime_detection_config.dart';
import '../detection/debug/detection_diagnostics.dart';
import '../detection/detectors/fallback_toy_detector.dart';
import '../detection/detectors/mlkit/mlkit_object_detector.dart';
import '../detection/detectors/mock_toy_detector.dart';
import '../detection/detectors/remote/remote_vision_detector.dart';
import '../detection/detectors/toy_detector.dart';
import '../detection/models/raw_detection.dart';
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

/// Which detector the live pipeline uses.
///
/// - [mock] — deterministic fake detections (development / fallback).
/// - [mlkitWithFallback] — Google ML Kit on-device, with mock as fallback.
///   Kept available but its generic 5-category output is rarely useful for
///   toys.
/// - [remoteVisionServer] — Phase 5.0: open-vocabulary detection via the
///   user's local Python server on the LAN. Detections come back with
///   toy-specific labels mapped to the registry.
enum ToyDetectorMode { mock, mlkitWithFallback, remoteVisionServer }

/// Controls the active [ToyDetectorMode]. Default is [ToyDetectorMode.mock];
/// flipping to [ToyDetectorMode.mlkitWithFallback] is opt-in for dev/QA via
/// [toggle] (wired through the on-screen `DetectorModeChip`).
///
/// Holds no inference state; rebuilding [toyDetectorProvider] is what swaps
/// the detector, and the controller (which watches that provider) rebuilds
/// itself on the change.
class ToyDetectorModeController extends Notifier<ToyDetectorMode> {
  /// Phase 5.0 product reset: the **default mode is Object Assist** (ML Kit
  /// on-device). Mock is no longer the user-facing default — it remains only
  /// as the automatic fallback inside [FallbackToyDetector] when ML Kit can't
  /// initialize. The UI no longer exposes a toggle.
  @override
  ToyDetectorMode build() => ToyDetectorMode.mlkitWithFallback;

  /// Set the mode explicitly (e.g. from tests).
  void set(ToyDetectorMode mode) => state = mode;

  /// Cycle through the three detector modes. Intended for dev/QA only —
  /// the on-screen chip uses this to let the user move between Demo,
  /// Object Assist (ML Kit), and Open-Vocab (local Python server).
  ///
  /// Cycle: mock → mlkitWithFallback → remoteVisionServer → mock.
  void toggle() {
    final previous = state;
    final next = switch (previous) {
      ToyDetectorMode.mock => ToyDetectorMode.mlkitWithFallback,
      ToyDetectorMode.mlkitWithFallback => ToyDetectorMode.remoteVisionServer,
      ToyDetectorMode.remoteVisionServer => ToyDetectorMode.mock,
    };
    state = next;
    if (kDebugMode) {
      debugPrint(
        'ToyVisionDX: lifecycle.mode.toggle previous=${previous.name} '
        'next=${next.name}',
      );
    }
  }
}

final toyDetectorModeProvider =
    NotifierProvider<ToyDetectorModeController, ToyDetectorMode>(
  ToyDetectorModeController.new,
);

/// Builds the active detector for the selected mode.
///
/// - [ToyDetectorMode.mock]: the proven [MockToyDetector].
/// - [ToyDetectorMode.mlkitWithFallback]: Google ML Kit on-device, wrapped
///   in [FallbackToyDetector] so a plugin failure falls back to mock.
/// - [ToyDetectorMode.remoteVisionServer]: Phase 5.0 open-vocabulary
///   detector via the user's local Python server; wrapped in
///   [FallbackToyDetector] so a connection failure (server offline,
///   wrong IP, Wi-Fi off) silently falls back to mock instead of
///   freezing the live loop.
final toyDetectorProvider = Provider<ToyDetector>((ref) {
  final mode = ref.watch(toyDetectorModeProvider);
  if (kDebugMode) {
    debugPrint(
      'ToyVisionDX: lifecycle.provider.rebuild mode=${mode.name}',
    );
  }
  switch (mode) {
    case ToyDetectorMode.mock:
      return MockToyDetector();
    case ToyDetectorMode.mlkitWithFallback:
      return FallbackToyDetector(
        primary: MlKitObjectDetector(),
        fallback: MockToyDetector(),
      );
    case ToyDetectorMode.remoteVisionServer:
      return FallbackToyDetector(
        primary: RemoteVisionDetector(),
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
  ToyDetector? _detector;

  @override
  LiveDetectionState build() {
    // Watch the detector so this controller rebuilds whenever the mode is
    // toggled. Capture as a field so it can be disposed cleanly on tear-down.
    _detector = ref.watch(toyDetectorProvider);
    ref.onDispose(() {
      // Phase 4.2.1: do NOT pauseStream here. That call is fire-and-forget,
      // and it raced with the next controller's `_maybeStartStream` — leaving
      // the new ML Kit detector with no camera frames after a mode toggle.
      // The next controller now owns the stream swap atomically inside
      // `_maybeStartStream`; the camera service handles its own teardown
      // when the container itself disposes.
      if (kDebugMode) {
        debugPrint('CandidateDX: live.onDispose dispose detector');
      }
      _detector?.dispose();
      _detector = null;
    });
    ref.listen<CameraStatus>(cameraStatusProvider, (_, next) {
      if (next == CameraStatus.ready) _maybeStartStream();
    });
    Future.microtask(_init);
    return LiveDetectionState.initial();
  }

  FrameProcessingService get _frames =>
      ref.read(frameProcessingServiceProvider);
  ToyDetectionRules get _rules => ref.read(toyDetectionRulesProvider);
  ToyTrackingEngine get _engine => ref.read(trackingEngineProvider);
  ToyCountingService get _counting => ref.read(countingServiceProvider);
  CameraControllerService get _camera =>
      ref.read(cameraStatusProvider.notifier);

  Future<void> _init() async {
    final detector = _detector;
    if (detector == null) return;
    if (kDebugMode) debugPrint('CandidateDX: live._init.start');
    try {
      await detector.initialize();
      state = state.copyWith(status: ModelStatus.ready);
      if (kDebugMode) {
        debugPrint(
          'CandidateDX: live._init.detectorReady status=${state.status.name}',
        );
      }
      // Always (re)attach the stream with this controller's callback. On cold
      // start the camera service is still initializing and this becomes a
      // no-op (the listener below fires once it's ready). On a mode toggle
      // the previous controller's onDispose paused the stream, so we must
      // explicitly resume it here — otherwise no frames ever reach the new
      // detector and the live loop appears frozen.
      await _maybeStartStream();
    } catch (e) {
      state = state.copyWith(status: ModelStatus.error);
      if (kDebugMode) debugPrint('CandidateDX: live._init.error $e');
    }
  }

  Future<void> _maybeStartStream() async {
    if (state.isPaused) return;
    final svc = _camera;
    if (kDebugMode) {
      debugPrint(
        'CandidateDX: live._maybeStartStream.enter '
        'cameraStatus=${ref.read(cameraStatusProvider).name} '
        'cameraStreaming=${svc.isStreaming}',
      );
    }
    // Stop any in-flight stream first so the camera plugin definitely uses
    // this controller's callback (not the now-disposed previous one). The
    // service short-circuits both calls when no stream is active.
    try {
      await svc.pauseStream();
      await svc.startStream(processIncomingFrame);
      if (kDebugMode) {
        debugPrint(
          'CandidateDX: live._maybeStartStream.done '
          'cameraStreaming=${svc.isStreaming}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CandidateDX: live._maybeStartStream.error $e');
      }
      rethrow;
    }
  }

  /// Handle one camera frame. Public for testing; in production it is the image
  /// stream callback. Honors pause, throttle, and skip-if-busy before running
  /// the validate → track → count pipeline.
  @visibleForTesting
  Future<void> processIncomingFrame(CameraImage? image) async {
    if (state.isPaused) return;
    // Guard the mode-toggle window: the new detector is being initialized via
    // `_init`'s `await detector.initialize()`, but the camera stream may still
    // deliver frames before init finishes. Skip them rather than calling
    // `detect()` on a not-yet-ready detector (the FallbackToyDetector throws
    // "initialize() not called" in that window).
    if (state.status != ModelStatus.ready) return;

    final List<RawDetection>? raw;
    try {
      raw = await _frames.process(image);
    } catch (_) {
      // Detector swapped under us (rare race during mode toggle). Drop the
      // frame instead of crashing the live loop.
      return;
    }
    if (raw == null) return; // throttled or skipped

    // Debug-only Phase 3.5.1: capture per-frame validation reasons alongside
    // the raw count so the diagnostics line below can attribute drops.
    final useDiagnostics = DetectionDiagnostics.enabled;
    final rejectReasons = useDiagnostics ? <String, int>{} : null;
    final validated = useDiagnostics
        ? _rules.validateWithReasons(raw, rejectReasons!)
        : _rules.validate(raw);
    final tracked = _engine.update(validated);
    final summary = _counting.update(tracked);
    final visible = tracked.where((t) => t.isVisible).toList(growable: false);

    // Phase 4.2: feed the candidate-review service the latest visible
    // tracking ids. Their stable ids let the user's confirm/reject decisions
    // survive across frames. Validate→track→count above is unchanged.
    final frameIndex = _frames.acceptedFrames - 1;
    if (kDebugMode) {
      debugPrint(
        'CandidateDX: live.processIncomingFrame raw=${raw.length} '
        'validated=${validated.length} tracked=${tracked.length} '
        'visible=${visible.length} frameIndex=$frameIndex',
      );
    }
    ref
        .read(candidateReviewControllerProvider.notifier)
        .ingest(visible, frameIndex);

    if (useDiagnostics) {
      final mode = ref.read(toyDetectorModeProvider);
      final activeDetector = _detector;
      final usingFallback =
          activeDetector is FallbackToyDetector && activeDetector.usingFallback;
      DetectionDiagnostics.emitFrame(
        mode: mode.name,
        usingFallback: usingFallback,
        rawDetections: raw.length,
        validatedCount: validated.length,
        rejectReasons: rejectReasons ?? const {},
        topRaw: raw,
      );
    }

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

  /// Clear tracking, counts, throttle, and candidate-review state, restarting
  /// the count from zero. Does not change the user's pause state.
  void reset() {
    _engine.reset();
    _counting.reset();
    _frames.reset();
    ref.read(candidateReviewControllerProvider.notifier).reset();
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
