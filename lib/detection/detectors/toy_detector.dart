import '../models/raw_detection.dart';

/// Strategy interface for interchangeable detection engines.
///
/// The app depends only on this abstraction. Phase 1 ships [MockToyDetector];
/// Phase 2 adds a TFLite-backed implementation behind an adapter. Implementations
/// return raw detections only and never decide counts or toy validity.
abstract class ToyDetector {
  /// Prepare the detector (load weights, warm up). Mock is a no-op.
  Future<void> initialize();

  /// Produce raw detections for the current frame.
  ///
  /// Phase 1 is frame-source agnostic (the mock advances internally). When the
  /// real camera frame stream is wired in Phase 2, the concrete TFLite detector
  /// will be adapted to this contract.
  Future<List<RawDetection>> detect();

  /// Release any held resources.
  void dispose();
}
