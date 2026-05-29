import '../models/detection_frame.dart';
import '../models/raw_detection.dart';

/// Strategy interface for interchangeable detection engines.
///
/// The app depends only on this abstraction. Phase 1/2a ship [MockToyDetector];
/// Phase 2b adds a TFLite-backed implementation behind an adapter.
///
/// Implementations return RAW detections only (label, confidence, box). They do
/// not validate, count, or decide toy-ness — the business layer does that. The
/// detector receives a [DetectionFrame] so a real model can read the camera
/// image without the camera plugin leaking elsewhere.
abstract class ToyDetector {
  /// Prepare the detector (load weights, warm up). Mock is a no-op.
  Future<void> initialize();

  /// Produce raw detections for [frame].
  Future<List<RawDetection>> detect(DetectionFrame frame);

  /// Release any held resources.
  void dispose();
}
