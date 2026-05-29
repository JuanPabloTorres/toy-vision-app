import 'dart:math' as math;

import '../models/bounding_box.dart';
import '../models/raw_detection.dart';
import 'toy_detector.dart';

/// Deterministic mock detector used for the mock-first MVP phase.
///
/// Emits a small set of fake, smoothly moving detections so the camera shell,
/// overlay, tracking, and counting can be exercised and tested without a real
/// model. Motion is driven by an internal frame counter (no randomness), so the
/// sequence is reproducible for scenario tests.
///
/// The set intentionally includes a `person` detection (which the business
/// layer must ignore) and a low-confidence toy (below threshold) to prove the
/// validation gate works end to end.
class MockToyDetector implements ToyDetector {
  MockToyDetector({this.emitPerson = true, this.emitLowConfidenceToy = true});

  /// Whether to emit a `person` detection each frame (must be ignored).
  final bool emitPerson;

  /// Whether to emit a toy below its confidence threshold (must be rejected).
  final bool emitLowConfidenceToy;

  int _frame = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<RawDetection>> detect() async {
    final detections = detectAt(_frame);
    _frame++;
    return detections;
  }

  /// Pure, frame-indexed detection generator. Exposed for deterministic tests.
  List<RawDetection> detectAt(int frame) {
    final t = frame.toDouble();
    final detections = <RawDetection>[];

    // Toy car drifting horizontally across the lower third.
    final carX = 0.10 + 0.30 * (0.5 + 0.5 * math.sin(t * 0.12));
    detections.add(
      RawDetection(
        label: 'toy_car',
        confidence: 0.91,
        box: BoundingBox(x: carX, y: 0.62, width: 0.20, height: 0.14),
      ),
    );

    // Stuffed animal bobbing vertically on the right.
    final bearY = 0.20 + 0.18 * (0.5 + 0.5 * math.sin(t * 0.09 + 1.0));
    detections.add(
      RawDetection(
        label: 'stuffed_animal',
        confidence: 0.84,
        box: BoundingBox(x: 0.60, y: bearY, width: 0.22, height: 0.24),
      ),
    );

    if (emitPerson) {
      // A person standing in frame — must never be counted.
      detections.add(
        const RawDetection(
          label: 'person',
          confidence: 0.96,
          box: BoundingBox(x: 0.40, y: 0.05, width: 0.20, height: 0.55),
        ),
      );
    }

    if (emitLowConfidenceToy) {
      // A doll the model is unsure about — below its confidence threshold.
      detections.add(
        const RawDetection(
          label: 'doll',
          confidence: 0.31,
          box: BoundingBox(x: 0.05, y: 0.30, width: 0.12, height: 0.16),
        ),
      );
    }

    return detections;
  }

  /// Reset the internal frame counter (used by the controller's reset action).
  void resetFrames() => _frame = 0;

  @override
  void dispose() {}
}
