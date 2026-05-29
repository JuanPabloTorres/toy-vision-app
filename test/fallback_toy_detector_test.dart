import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/detection/detectors/fallback_toy_detector.dart';
import 'package:toyvision_realtime/detection/detectors/toy_detector.dart';
import 'package:toyvision_realtime/detection/models/bounding_box.dart';
import 'package:toyvision_realtime/detection/models/detection_frame.dart';
import 'package:toyvision_realtime/detection/models/raw_detection.dart';

/// Detector that fails to initialize, like an unavailable TFLite model.
class _FailingDetector implements ToyDetector {
  @override
  Future<void> initialize() async => throw Exception('model unavailable');

  @override
  Future<List<RawDetection>> detect(DetectionFrame frame) async => const [];

  @override
  void dispose() {}
}

/// Detector that initializes and returns a fixed, tagged detection.
class _TaggingDetector implements ToyDetector {
  _TaggingDetector(this.tag);
  final String tag;
  bool initialized = false;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<List<RawDetection>> detect(DetectionFrame frame) async => [
        RawDetection(
          label: tag,
          confidence: 0.9,
          box: const BoundingBox(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
        ),
      ];

  @override
  void dispose() {}
}

void main() {
  DetectionFrame frame() => DetectionFrame(
        cameraImage: null,
        frameIndex: 0,
        capturedAt: DateTime(2026, 5, 29),
      );

  test('uses the primary detector when it initializes successfully', () async {
    final detector = FallbackToyDetector(
      primary: _TaggingDetector('primary'),
      fallback: _TaggingDetector('fallback'),
    );
    await detector.initialize();
    expect(detector.usingFallback, isFalse);
    final out = await detector.detect(frame());
    expect(out.single.label, 'primary');
  });

  test('falls back when the primary fails to initialize', () async {
    final fallback = _TaggingDetector('fallback');
    final detector = FallbackToyDetector(
      primary: _FailingDetector(),
      fallback: fallback,
    );
    await detector.initialize();
    expect(detector.usingFallback, isTrue);
    expect(fallback.initialized, isTrue);
    final out = await detector.detect(frame());
    expect(out.single.label, 'fallback');
  });

  test('detect before initialize throws StateError', () {
    final detector = FallbackToyDetector(
      primary: _TaggingDetector('primary'),
      fallback: _TaggingDetector('fallback'),
    );
    expect(() => detector.detect(frame()), throwsStateError);
  });
}
