import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/tflite_runtime_exception.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/tflite_tensor_output_parser.dart';
import 'package:toyvision_realtime/detection/models/toy_model_config.dart';

void main() {
  const parser = TfliteTensorOutputParser();
  const config = ToyModelConfig(
    assetPath: 'assets/models/toy_detector.tflite',
    inputWidth: 320,
    inputHeight: 320,
    labels: ['toy_car', 'doll'],
    maxDetections: 2,
  );

  test('parses SSD-style output tensors into TfliteModelOutput', () {
    final outputs = <int, Object>{
      0: [
        [
          [0.2, 0.1, 0.6, 0.5],
          [0.0, 0.0, 0.3, 0.3],
        ],
      ],
      1: [
        [0.0, 1.0],
      ],
      2: [
        [0.9, 0.7],
      ],
    };

    final result = parser.parse(outputs, config);
    expect(result.boxes, hasLength(2));
    expect(result.boxes.first, [0.2, 0.1, 0.6, 0.5]);
    expect(result.classes, [0, 1]);
    expect(result.scores, [0.9, 0.7]);
  });

  test('allocateOutputs builds buffers sized to maxDetections', () {
    final buffers = parser.allocateOutputs(config);
    final boxes = (buffers[0]! as List)[0] as List;
    expect(boxes, hasLength(2));
    expect((boxes.first as List), hasLength(4));
  });

  test('throws on a box row that is not length 4', () {
    final outputs = <int, Object>{
      0: [
        [
          [0.2, 0.1, 0.6], // too short
        ],
      ],
      1: [
        [0.0],
      ],
      2: [
        [0.9],
      ],
    };
    expect(
      () => parser.parse(outputs, config),
      throwsA(isA<TfliteRuntimeException>()),
    );
  });

  test('validateShapes accepts the expected layout', () {
    expect(
      () => parser.validateShapes(
        [1, 320, 320, 3],
        [
          [1, 2, 4],
          [1, 2],
          [1, 2],
        ],
        config,
      ),
      returnsNormally,
    );
  });

  test('validateShapes rejects a wrong input shape', () {
    expect(
      () => parser.validateShapes(
        [1, 224, 224, 3],
        [
          [1, 2, 4],
          [1, 2],
          [1, 2],
        ],
        config,
      ),
      throwsA(isA<TfliteRuntimeException>()),
    );
  });

  test('validateShapes rejects a wrong boxes shape', () {
    expect(
      () => parser.validateShapes(
        [1, 320, 320, 3],
        [
          [1, 2, 5], // last dim must be 4
          [1, 2],
          [1, 2],
        ],
        config,
      ),
      throwsA(isA<TfliteRuntimeException>()),
    );
  });
}
