import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/camera_image_preprocessor.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/tflite_interpreter_factory.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/tflite_model_output.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/tflite_runtime_exception.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/tflite_toy_model_runtime.dart';
import 'package:toyvision_realtime/detection/models/detection_frame.dart';
import 'package:toyvision_realtime/detection/models/toy_model_config.dart';

const _config = ToyModelConfig(
  assetPath: 'assets/models/toy_detector.tflite',
  inputWidth: 2,
  inputHeight: 2,
  labels: ['toy_car', 'doll'],
  maxDetections: 2,
);

/// Handle with configurable shapes; on run it fills outputs from a canned result.
class _FakeHandle implements TfliteInterpreterHandle {
  _FakeHandle({
    required this.inShape,
    required this.outShapes,
    required this.canned,
  });

  final List<int> inShape;
  final List<List<int>> outShapes;
  final TfliteModelOutput canned;
  bool closed = false;

  @override
  List<int> inputShape() => inShape;

  @override
  List<List<int>> outputShapes() => outShapes;

  @override
  void run(ModelInput input, Map<int, Object> outputs) {
    final boxes = (outputs[_config.boxesTensorIndex]! as List)[0] as List;
    final scores = (outputs[_config.scoresTensorIndex]! as List)[0] as List;
    final classes = (outputs[_config.classesTensorIndex]! as List)[0] as List;
    for (var i = 0; i < canned.scores.length; i++) {
      (boxes[i] as List).setAll(0, canned.boxes[i]);
      scores[i] = canned.scores[i];
      classes[i] = canned.classes[i].toDouble();
    }
  }

  @override
  void close() => closed = true;
}

class _FakeFactory implements TfliteInterpreterFactory {
  _FakeFactory(this.handle, {this.throwOnCreate = false});
  final TfliteInterpreterHandle handle;
  final bool throwOnCreate;

  @override
  TfliteInterpreterHandle create(Uint8List modelBytes) {
    if (throwOnCreate) throw Exception('bad model');
    return handle;
  }
}

/// Preprocessor that returns a fixed input without needing a real CameraImage.
class _FakePreprocessor extends CameraImagePreprocessor {
  const _FakePreprocessor();
  @override
  ModelInput preprocess(DetectionFrame frame, ToyModelConfig config) =>
      ModelInput(
        data: Float32List(config.inputWidth * config.inputHeight * 3),
        width: config.inputWidth,
        height: config.inputHeight,
      );
}

/// Preprocessor that always fails (e.g. unsupported frame format).
class _ThrowingPreprocessor extends CameraImagePreprocessor {
  const _ThrowingPreprocessor();
  @override
  ModelInput preprocess(DetectionFrame frame, ToyModelConfig config) =>
      throw const TfliteRuntimeException('boom');
}

TfliteModelOutput _canned() => const TfliteModelOutput(
      boxes: [
        [0.2, 0.1, 0.6, 0.5],
        [0.0, 0.0, 0.3, 0.3],
      ],
      scores: [0.9, 0.7],
      classes: [0, 1],
    );

DetectionFrame _frame() => DetectionFrame(
      cameraImage: null,
      frameIndex: 0,
      capturedAt: DateTime(2026, 5, 29),
    );

void main() {
  final goodHandle = _FakeHandle(
    inShape: [1, 2, 2, 3],
    outShapes: [
      [1, 2, 4],
      [1, 2],
      [1, 2],
    ],
    canned: _canned(),
  );

  test('load throws when interpreter creation fails', () {
    final runtime = TfliteToyModelRuntime(
      interpreterFactory: _FakeFactory(goodHandle, throwOnCreate: true),
    );
    expect(
      runtime.load(Uint8List(4), _config),
      throwsA(isA<TfliteRuntimeException>()),
    );
  });

  test('load throws and closes the handle on unexpected tensor shapes', () {
    final badHandle = _FakeHandle(
      inShape: [1, 99, 99, 3], // wrong input size
      outShapes: [
        [1, 2, 4],
        [1, 2],
        [1, 2],
      ],
      canned: _canned(),
    );
    final runtime =
        TfliteToyModelRuntime(interpreterFactory: _FakeFactory(badHandle));
    expect(
      runtime.load(Uint8List(4), _config),
      throwsA(isA<TfliteRuntimeException>()),
    );
  });

  test('infer maps tensors into RawDetections via the parser', () async {
    final runtime = TfliteToyModelRuntime(
      interpreterFactory: _FakeFactory(goodHandle),
      preprocessor: const _FakePreprocessor(),
    );
    await runtime.load(Uint8List(4), _config);

    final output = await runtime.infer(_frame());
    expect(output.boxes, hasLength(2));
    expect(output.boxes.first, [0.2, 0.1, 0.6, 0.5]);
    expect(output.scores, [0.9, 0.7]);
    expect(output.classes, [0, 1]);
  });

  test('infer drops the frame (empty output) on preprocessing failure', () async {
    final runtime = TfliteToyModelRuntime(
      interpreterFactory: _FakeFactory(goodHandle),
      preprocessor: const _ThrowingPreprocessor(),
    );
    await runtime.load(Uint8List(4), _config);

    final output = await runtime.infer(_frame());
    expect(output.boxes, isEmpty);
    expect(output.scores, isEmpty);
    expect(output.classes, isEmpty);
  });

  test('infer before load returns empty output (no crash)', () async {
    final runtime = TfliteToyModelRuntime(
      interpreterFactory: _FakeFactory(goodHandle),
      preprocessor: const _FakePreprocessor(),
    );
    final output = await runtime.infer(_frame());
    expect(output.boxes, isEmpty);
  });
}
