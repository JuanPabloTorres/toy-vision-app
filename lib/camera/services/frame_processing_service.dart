import 'package:camera/camera.dart';

import '../../core/config/realtime_detection_config.dart';
import '../../detection/detectors/toy_detector.dart';
import '../../detection/models/detection_frame.dart';
import '../../detection/models/raw_detection.dart';

/// Gates the inference path so frames are throttled to the target rate and
/// processed at most one at a time.
///
/// Enforces the real-time performance rules: frames arriving faster than
/// [RealtimeDetectionConfig.targetInferenceFps] are dropped, and while one
/// inference is in flight new frames are skipped (never queued). It runs the
/// current [ToyDetector] and returns RAW detections; validation/tracking/
/// counting happen downstream. It never stores or uploads a frame.
class FrameProcessingService {
  FrameProcessingService({
    required this.detector,
    required this.config,
    int Function()? clock,
  }) : _clock = clock ?? _defaultClock();

  final ToyDetector detector;
  final RealtimeDetectionConfig config;

  /// Monotonic milliseconds source. Injected in tests for deterministic timing.
  final int Function() _clock;

  bool _busy = false;
  int _acceptedFrames = 0;
  int _lastAcceptedMs = -1 << 30;

  bool get isBusy => _busy;
  int get acceptedFrames => _acceptedFrames;

  /// Process one incoming camera frame.
  ///
  /// Returns the raw detections, or `null` when the frame is dropped because
  /// inference is already running (skip-if-busy) or it arrived sooner than the
  /// throttle interval. [image] may be null in mock/test paths.
  Future<List<RawDetection>?> process(CameraImage? image) async {
    if (_busy) return null; // skip-if-busy: never run concurrent inference

    final now = _clock();
    if (now - _lastAcceptedMs < config.frameInterval.inMilliseconds) {
      return null; // throttled to target FPS
    }
    _lastAcceptedMs = now;

    _busy = true;
    try {
      final frame = DetectionFrame(
        cameraImage: image,
        frameIndex: _acceptedFrames++,
        capturedAt: DateTime.now(),
      );
      return await detector.detect(frame);
    } finally {
      _busy = false;
    }
  }

  /// Reset throttle state and the accepted-frame counter (used by reset).
  void reset() {
    _acceptedFrames = 0;
    _lastAcceptedMs = -1 << 30;
    _busy = false;
  }

  static int Function() _defaultClock() {
    final sw = Stopwatch()..start();
    return () => sw.elapsedMilliseconds;
  }
}
