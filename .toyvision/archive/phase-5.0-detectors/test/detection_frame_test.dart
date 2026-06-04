import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/detection/detectors/mock_toy_detector.dart';
import 'package:toyvision_realtime/detection/models/detection_frame.dart';

void main() {
  final at = DateTime(2026, 5, 28);

  test('mock detector reads frameIndex from the DetectionFrame wrapper', () async {
    final mock = MockToyDetector();

    final f0 = await mock.detect(
      DetectionFrame(cameraImage: null, frameIndex: 0, capturedAt: at),
    );
    final f5 = await mock.detect(
      DetectionFrame(cameraImage: null, frameIndex: 5, capturedAt: at),
    );

    // Same content as the pure frame-indexed generator.
    final ref0 = mock.detectAt(0);
    expect(f0.map((d) => d.label), ref0.map((d) => d.label));
    expect(f0.first.box.x, closeTo(ref0.first.box.x, 1e-12));

    // Different frame index -> the moving toy is at a different position.
    expect(f5.first.box.x, isNot(closeTo(f0.first.box.x, 1e-9)));
  });

  test('a null camera image is accepted (mock ignores it)', () async {
    final mock = MockToyDetector();
    final result = await mock.detect(
      DetectionFrame(cameraImage: null, frameIndex: 3, capturedAt: at),
    );
    expect(result, isNotEmpty);
  });
}
