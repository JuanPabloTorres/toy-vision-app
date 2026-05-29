import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/camera_image_preprocessor.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/tflite_runtime_exception.dart';
import 'package:toyvision_realtime/detection/models/detection_frame.dart';
import 'package:toyvision_realtime/detection/models/toy_model_config.dart';

void main() {
  const config = ToyModelConfig(
    assetPath: 'assets/models/toy_detector.tflite',
    inputWidth: 2,
    inputHeight: 2,
    labels: ['toy_car'],
  );

  test('buildInputFromRgb returns a [1,h,w,3] normalized buffer', () {
    // 2x2 RGB source, values 0/255 so normalization is exact.
    final rgb = Uint8List.fromList([
      0, 0, 0, 255, 255, 255, //
      255, 255, 255, 0, 0, 0,
    ]);
    final input =
        CameraImagePreprocessor.buildInputFromRgb(rgb, 2, 2, config);

    expect(input.width, 2);
    expect(input.height, 2);
    expect(input.channels, 3);
    expect(input.data.length, input.expectedLength);
    expect(input.data.length, 2 * 2 * 3);
    // Every value is normalized into [0, 1].
    expect(input.data.every((v) => v >= 0.0 && v <= 1.0), isTrue);
    expect(input.data.first, closeTo(0.0, 1e-9));
  });

  test('downscales by nearest-neighbor to the model input size', () {
    final rgb = Uint8List(4 * 4 * 3)..fillRange(0, 4 * 4 * 3, 128);
    final input =
        CameraImagePreprocessor.buildInputFromRgb(rgb, 4, 4, config);
    expect(input.data.length, 2 * 2 * 3);
    expect(input.data.first, closeTo(128 / 255.0, 1e-6)); // float32 precision
  });

  test('preprocess fails safely when there is no camera image', () {
    const preprocessor = CameraImagePreprocessor();
    final frame = DetectionFrame(
      cameraImage: null,
      frameIndex: 0,
      capturedAt: DateTime(2026, 5, 29),
    );
    expect(
      () => preprocessor.preprocess(frame, config),
      throwsA(isA<TfliteRuntimeException>()),
    );
  });
}
