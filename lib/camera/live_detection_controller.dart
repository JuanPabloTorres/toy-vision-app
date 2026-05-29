import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../business/live_detection_state.dart';
import '../business/toy_category_registry.dart';
import '../business/toy_counting_service.dart';
import '../business/toy_detection_rules.dart';
import '../core/config/realtime_detection_config.dart';
import '../detection/detectors/mock_toy_detector.dart';
import '../detection/detectors/toy_detector.dart';
import '../tracking/toy_tracking_engine.dart';
import 'services/frame_processing_service.dart';

final realtimeConfigProvider = Provider<RealtimeDetectionConfig>(
  (ref) => RealtimeDetectionConfig.defaults,
);

final toyCategoryRegistryProvider = Provider<ToyCategoryRegistry>(
  (ref) => ToyCategoryRegistry.standard(),
);

/// Phase 1 uses the mock detector. Phase 2 swaps this single line for the
/// TFLite-backed detector (behind an adapter) — nothing else changes.
final toyDetectorProvider = Provider<ToyDetector>((ref) => MockToyDetector());

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
    rules: ref.watch(toyDetectionRulesProvider),
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
/// (detect → validate → track → count → state). It contains no business math
/// itself: validation, tracking, and counting all live in their own layers.
class LiveDetectionController extends Notifier<LiveDetectionState> {
  Timer? _timer;

  @override
  LiveDetectionState build() {
    ref.onDispose(_disposeLoop);
    Future.microtask(_start);
    return LiveDetectionState.initial();
  }

  RealtimeDetectionConfig get _config => ref.read(realtimeConfigProvider);
  ToyDetector get _detector => ref.read(toyDetectorProvider);
  FrameProcessingService get _frames =>
      ref.read(frameProcessingServiceProvider);
  ToyTrackingEngine get _engine => ref.read(trackingEngineProvider);
  ToyCountingService get _counting => ref.read(countingServiceProvider);

  Future<void> _start() async {
    try {
      await _detector.initialize();
      state = state.copyWith(status: ModelStatus.ready);
      _timer = Timer.periodic(_config.frameInterval, (_) => _tick());
    } catch (_) {
      state = state.copyWith(status: ModelStatus.error);
    }
  }

  Future<void> _tick() async {
    if (state.isPaused) return;
    final validated = await _frames.processFrame();
    if (validated == null) return; // skipped: inference still running

    final tracked = _engine.update(validated);
    final summary = _counting.update(tracked);
    final visible = tracked.where((t) => t.isVisible).toList(growable: false);

    state = state.copyWith(visibleToys: visible, summary: summary);
  }

  void pause() => state = state.copyWith(isPaused: true);

  void resume() => state = state.copyWith(isPaused: false);

  void togglePause() =>
      state = state.copyWith(isPaused: !state.isPaused);

  /// Clear tracking and counts and restart the count from zero.
  void reset() {
    _engine.reset();
    _counting.reset();
    final detector = _detector;
    if (detector is MockToyDetector) detector.resetFrames();
    state = state.copyWith(
      visibleToys: const [],
      summary: ToyCountSummary.empty,
      isPaused: false,
    );
  }

  void _disposeLoop() {
    _timer?.cancel();
    _timer = null;
    _detector.dispose();
  }
}
