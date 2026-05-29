import 'dart:typed_data';

import '../../models/detection_frame.dart';
import '../../models/toy_model_config.dart';
import 'camera_image_preprocessor.dart';
import 'tflite_interpreter_factory.dart';
import 'tflite_model_output.dart';
import 'tflite_runtime_exception.dart';
import 'tflite_tensor_output_parser.dart';

/// Concrete [ToyModelRuntime] backed by a real interpreter.
///
/// Flow: load model bytes → create interpreter → validate tensor shapes. Then
/// per frame: preprocess → run inference → parse output tensors into a
/// [TfliteModelOutput] (which the adapter later turns into raw detections).
///
/// Failure policy:
///   - load failures (bad interpreter / unexpected shapes) throw
///     [TfliteRuntimeException] so the detector falls back to the mock;
///   - inference-time failures (preprocessing, runtime) never crash the live
///     loop — the frame is dropped (empty output) instead.
class TfliteToyModelRuntime implements ToyModelRuntime {
  TfliteToyModelRuntime({
    TfliteInterpreterFactory interpreterFactory =
        const DefaultTfliteInterpreterFactory(),
    CameraImagePreprocessor preprocessor = const CameraImagePreprocessor(),
    TfliteTensorOutputParser parser = const TfliteTensorOutputParser(),
  })  : _factory = interpreterFactory,
        _preprocessor = preprocessor,
        _parser = parser;

  final TfliteInterpreterFactory _factory;
  final CameraImagePreprocessor _preprocessor;
  final TfliteTensorOutputParser _parser;

  TfliteInterpreterHandle? _handle;
  ToyModelConfig? _config;

  static const TfliteModelOutput _empty =
      TfliteModelOutput(boxes: [], scores: [], classes: []);

  @override
  Future<void> load(Uint8List modelBytes, ToyModelConfig config) async {
    _config = config;

    final TfliteInterpreterHandle handle;
    try {
      handle = _factory.create(modelBytes);
    } catch (e) {
      throw TfliteRuntimeException('Failed to create interpreter: $e');
    }

    try {
      _parser.validateShapes(
        handle.inputShape(),
        handle.outputShapes(),
        config,
      );
    } catch (e) {
      handle.close();
      if (e is TfliteRuntimeException) rethrow;
      throw TfliteRuntimeException('Tensor shape validation failed: $e');
    }

    _handle = handle;
  }

  @override
  Future<TfliteModelOutput> infer(DetectionFrame frame) async {
    final handle = _handle;
    final config = _config;
    if (handle == null || config == null) return _empty;

    try {
      final input = _preprocessor.preprocess(frame, config);
      final outputs = _parser.allocateOutputs(config);
      handle.run(input, outputs);
      return _parser.parse(outputs, config);
    } catch (_) {
      // Graceful: drop this frame rather than crash the live detection loop.
      return _empty;
    }
  }

  @override
  void close() {
    _handle?.close();
    _handle = null;
  }
}
