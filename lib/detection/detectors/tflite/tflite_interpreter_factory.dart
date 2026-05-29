import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'camera_image_preprocessor.dart';

/// Thin handle over a loaded interpreter. Abstracted so the runtime and tests
/// can work without the native `tflite_flutter` library.
abstract class TfliteInterpreterHandle {
  List<int> inputShape();
  List<List<int>> outputShapes();

  /// Run inference, filling [outputs] in place.
  void run(ModelInput input, Map<int, Object> outputs);

  void close();
}

/// Creates a [TfliteInterpreterHandle] from model bytes. Tests inject a fake.
abstract class TfliteInterpreterFactory {
  TfliteInterpreterHandle create(Uint8List modelBytes);
}

/// Default factory backed by `tflite_flutter`. This is the ONLY file that
/// imports the native TFLite package, keeping the dependency at one seam.
class DefaultTfliteInterpreterFactory implements TfliteInterpreterFactory {
  const DefaultTfliteInterpreterFactory();

  @override
  TfliteInterpreterHandle create(Uint8List modelBytes) =>
      _InterpreterHandle(Interpreter.fromBuffer(modelBytes));
}

class _InterpreterHandle implements TfliteInterpreterHandle {
  _InterpreterHandle(this._interpreter);

  final Interpreter _interpreter;

  @override
  List<int> inputShape() => _interpreter.getInputTensor(0).shape;

  @override
  List<List<int>> outputShapes() =>
      _interpreter.getOutputTensors().map((t) => t.shape).toList();

  @override
  void run(ModelInput input, Map<int, Object> outputs) {
    final reshaped = input.data.reshape(
      [input.batch, input.height, input.width, input.channels],
    );
    _interpreter.runForMultipleInputs([reshaped], outputs);
  }

  @override
  void close() => _interpreter.close();
}
