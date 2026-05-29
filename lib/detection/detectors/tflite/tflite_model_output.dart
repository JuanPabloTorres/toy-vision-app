import 'dart:typed_data';

import '../../models/detection_frame.dart';
import '../../models/toy_model_config.dart';

/// Raw numeric output of an object-detection model for one frame, in the common
/// TFLite SSD layout. Boxes are normalized `[ymin, xmin, ymax, xmax]`.
///
/// This is the runtime-agnostic hand-off between the inference seam
/// ([ToyModelRuntime]) and the output-normalization adapter. It carries no
/// app types beyond primitives.
class TfliteModelOutput {
  const TfliteModelOutput({
    required this.boxes,
    required this.scores,
    required this.classes,
  });

  /// Each entry is `[ymin, xmin, ymax, xmax]` in normalized coordinates.
  final List<List<double>> boxes;
  final List<double> scores;
  final List<int> classes;
}

/// The inference seam. A concrete implementation (added in a later step, backed
/// by `tflite_flutter`) loads the model bytes and runs inference on a frame.
///
/// Keeping this behind an interface means the TFLite native dependency is the
/// only thing that changes when real inference is wired — the detector, adapter,
/// config, and validator stay untouched.
abstract class ToyModelRuntime {
  Future<void> load(Uint8List modelBytes, ToyModelConfig config);
  Future<TfliteModelOutput> infer(DetectionFrame frame);
  void close();
}
