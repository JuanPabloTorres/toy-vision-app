import '../../models/toy_model_config.dart';
import 'tflite_model_output.dart';
import 'tflite_runtime_exception.dart';

/// Allocates, validates, and parses the raw TFLite output tensors into a
/// [TfliteModelOutput].
///
/// Expected SSD-style layout (indices configurable via [ToyModelConfig]):
///   - boxes:   `[1, N, 4]` as `[ymin, xmin, ymax, xmax]` (normalized)
///   - scores:  `[1, N]`
///   - classes: `[1, N]` (float indices, rounded to int)
///
/// This stays runtime-agnostic: it operates on nested-list buffers, so it is
/// unit-testable without a real interpreter. Converting these numbers into
/// [RawDetection]s remains the adapter's job.
class TfliteTensorOutputParser {
  const TfliteTensorOutputParser();

  /// Validate the interpreter's reported input/output tensor shapes against the
  /// expected layout. Throws [TfliteRuntimeException] on mismatch (→ fallback).
  void validateShapes(
    List<int> inputShape,
    List<List<int>> outputShapes,
    ToyModelConfig config,
  ) {
    if (inputShape.length != 4 ||
        inputShape[0] != 1 ||
        inputShape[1] != config.inputHeight ||
        inputShape[2] != config.inputWidth ||
        inputShape[3] != 3) {
      throw TfliteRuntimeException(
        'Unexpected input shape $inputShape (expected '
        '[1, ${config.inputHeight}, ${config.inputWidth}, 3]).',
      );
    }

    final maxIndex = [
      config.boxesTensorIndex,
      config.scoresTensorIndex,
      config.classesTensorIndex,
    ].reduce((a, b) => a > b ? a : b);
    if (outputShapes.length <= maxIndex) {
      throw TfliteRuntimeException(
        'Too few output tensors: ${outputShapes.length}.',
      );
    }

    final boxes = outputShapes[config.boxesTensorIndex];
    if (boxes.length != 3 || boxes.last != 4) {
      throw TfliteRuntimeException('Unexpected boxes tensor shape $boxes.');
    }
    if (outputShapes[config.scoresTensorIndex].length != 2) {
      throw const TfliteRuntimeException('Unexpected scores tensor shape.');
    }
    if (outputShapes[config.classesTensorIndex].length != 2) {
      throw const TfliteRuntimeException('Unexpected classes tensor shape.');
    }
  }

  /// Build zero-filled output buffers matching the expected layout for the
  /// interpreter to fill in place.
  Map<int, Object> allocateOutputs(ToyModelConfig config) {
    final n = config.maxDetections;
    return <int, Object>{
      config.boxesTensorIndex: [
        List.generate(n, (_) => List<double>.filled(4, 0.0)),
      ],
      config.scoresTensorIndex: [List<double>.filled(n, 0.0)],
      config.classesTensorIndex: [List<double>.filled(n, 0.0)],
    };
  }

  TfliteModelOutput parse(Map<int, Object> outputs, ToyModelConfig config) {
    final boxesT = outputs[config.boxesTensorIndex];
    final scoresT = outputs[config.scoresTensorIndex];
    final classesT = outputs[config.classesTensorIndex];
    if (boxesT is! List || scoresT is! List || classesT is! List) {
      throw const TfliteRuntimeException('Malformed output tensors.');
    }

    final boxBatch = boxesT[0] as List;
    final scoreBatch = scoresT[0] as List;
    final classBatch = classesT[0] as List;

    final n = [boxBatch.length, scoreBatch.length, classBatch.length]
        .reduce((a, b) => a < b ? a : b);

    final boxes = <List<double>>[];
    final scores = <double>[];
    final classes = <int>[];
    for (var i = 0; i < n; i++) {
      final row = (boxBatch[i] as List).cast<num>();
      if (row.length < 4) {
        throw const TfliteRuntimeException('Box tensor row is not length 4.');
      }
      boxes.add([
        row[0].toDouble(),
        row[1].toDouble(),
        row[2].toDouble(),
        row[3].toDouble(),
      ]);
      scores.add((scoreBatch[i] as num).toDouble());
      classes.add((classBatch[i] as num).round());
    }

    return TfliteModelOutput(boxes: boxes, scores: scores, classes: classes);
  }
}
