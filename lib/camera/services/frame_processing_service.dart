import '../../business/toy_detection_rules.dart';
import '../../detection/detectors/toy_detector.dart';
import '../../detection/models/detection_result.dart';

/// Guards the inference path so frames are processed at most one at a time.
///
/// Enforces the real-time performance rule: while inference is running, new
/// frames are skipped rather than queued, preventing concurrent inference and
/// keeping the preview responsive.
class FrameProcessingService {
  FrameProcessingService({required this.detector, required this.rules});

  final ToyDetector detector;
  final ToyDetectionRules rules;

  bool _busy = false;

  bool get isBusy => _busy;

  /// Run one inference + validation pass. Returns `null` if a previous pass is
  /// still in flight (the frame is skipped).
  Future<List<DetectionResult>?> processFrame() async {
    if (_busy) return null;
    _busy = true;
    try {
      final raw = await detector.detect();
      return rules.validate(raw);
    } finally {
      _busy = false;
    }
  }
}
