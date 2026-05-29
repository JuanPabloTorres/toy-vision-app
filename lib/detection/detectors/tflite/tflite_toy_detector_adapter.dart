import '../../models/bounding_box.dart';
import '../../models/raw_detection.dart';
import '../../models/toy_model_config.dart';
import 'tflite_model_output.dart';

/// Adapts raw TFLite model output into the app's [RawDetection] contract.
///
/// This is pure output normalization: it converts `[ymin, xmin, ymax, xmax]`
/// boxes into top-left `x, y, w, h` normalized boxes (clamped to the frame),
/// clamps confidence to [0, 1], and maps class indices to labels via the model
/// config. It makes NO business decisions (no toy-ness, no confidence gate, no
/// ignore rules) — it only reshapes data so the business layer can validate it.
class TfliteToyDetectorAdapter {
  const TfliteToyDetectorAdapter(this.config);

  final ToyModelConfig config;

  List<RawDetection> toRawDetections(TfliteModelOutput output) {
    final count = [
      output.boxes.length,
      output.scores.length,
      output.classes.length,
    ].reduce((a, b) => a < b ? a : b);

    final results = <RawDetection>[];
    for (var i = 0; i < count; i++) {
      final score = output.scores[i];
      if (score < config.minimumRawScore) continue;

      final box = output.boxes[i];
      if (box.length < 4) continue;

      final ymin = _clamp01(box[0]);
      final xmin = _clamp01(box[1]);
      final ymax = _clamp01(box[2]);
      final xmax = _clamp01(box[3]);
      final width = xmax - xmin;
      final height = ymax - ymin;
      if (width <= 0 || height <= 0) continue; // degenerate after clamping

      final classIndex = output.classes[i];
      final label = (classIndex >= 0 && classIndex < config.labels.length)
          ? config.labels[classIndex]
          : 'unknown';

      results.add(
        RawDetection(
          label: label,
          confidence: _clamp01(score),
          box: BoundingBox(x: xmin, y: ymin, width: width, height: height),
        ),
      );
    }
    return results;
  }

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
}
