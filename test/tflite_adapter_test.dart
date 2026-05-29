import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/tflite_model_output.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/tflite_toy_detector_adapter.dart';
import 'package:toyvision_realtime/detection/models/toy_model_config.dart';

void main() {
  const config = ToyModelConfig(
    assetPath: 'assets/models/toy_detector.tflite',
    inputWidth: 320,
    inputHeight: 320,
    labels: ['toy_car', 'doll'],
    minimumRawScore: 0.5,
  );
  const adapter = TfliteToyDetectorAdapter(config);

  test('converts [ymin,xmin,ymax,xmax] to top-left x,y,w,h', () {
    final out = adapter.toRawDetections(
      const TfliteModelOutput(
        boxes: [
          [0.2, 0.1, 0.6, 0.5],
        ],
        scores: [0.9],
        classes: [0],
      ),
    );
    expect(out, hasLength(1));
    expect(out.single.label, 'toy_car');
    expect(out.single.box.x, closeTo(0.1, 1e-9));
    expect(out.single.box.y, closeTo(0.2, 1e-9));
    expect(out.single.box.width, closeTo(0.4, 1e-9));
    expect(out.single.box.height, closeTo(0.4, 1e-9));
    expect(out.single.confidence, closeTo(0.9, 1e-9));
  });

  test('clamps out-of-range box coordinates into [0,1]', () {
    final out = adapter.toRawDetections(
      const TfliteModelOutput(
        boxes: [
          [-0.1, 0.0, 1.2, 0.5],
        ],
        scores: [0.8],
        classes: [0],
      ),
    );
    final box = out.single.box;
    expect(box.y, 0.0);
    expect(box.x, 0.0);
    expect(box.height, closeTo(1.0, 1e-9));
    expect(box.width, closeTo(0.5, 1e-9));
    expect(box.isValid, isTrue);
  });

  test('maps an out-of-range class index to "unknown"', () {
    final out = adapter.toRawDetections(
      const TfliteModelOutput(
        boxes: [
          [0.1, 0.1, 0.4, 0.4],
        ],
        scores: [0.9],
        classes: [99],
      ),
    );
    expect(out.single.label, 'unknown');
  });

  test('drops detections below the model noise floor', () {
    final out = adapter.toRawDetections(
      const TfliteModelOutput(
        boxes: [
          [0.1, 0.1, 0.4, 0.4],
          [0.1, 0.1, 0.4, 0.4],
        ],
        scores: [0.3, 0.9], // 0.3 < minimumRawScore (0.5)
        classes: [0, 1],
      ),
    );
    expect(out, hasLength(1));
    expect(out.single.label, 'doll');
  });

  test('drops degenerate boxes that collapse after clamping', () {
    final out = adapter.toRawDetections(
      const TfliteModelOutput(
        boxes: [
          [0.5, 0.5, 0.5, 0.9], // ymin==ymax -> zero height
        ],
        scores: [0.9],
        classes: [0],
      ),
    );
    expect(out, isEmpty);
  });
}
