/// Configuration for a TFLite toy-detection model.
///
/// This is the centralized, single source of model metadata — asset location,
/// input dimensions, the ordered class-label list (model index -> label), and a
/// model-level noise floor. It deliberately holds NO business thresholds: per
/// governance the model never decides whether a detection counts as a toy or
/// whether its confidence is acceptable — those gates live in the business layer
/// ([ToyDetectionRules] / [ToyCategoryRegistry]).
///
/// [labels] are listed in the model's output class-index order. Every label must
/// exist in the [ToyCategoryRegistry]; this is enforced by [ModelMetadataValidator].
class ToyModelConfig {
  const ToyModelConfig({
    required this.assetPath,
    required this.labels,
    required this.inputWidth,
    required this.inputHeight,
    this.minimumRawScore = 0.001,
    this.maxDetections = 25,
    this.inputMean = 0.0,
    this.inputStd = 255.0,
    this.boxesTensorIndex = 0,
    this.classesTensorIndex = 1,
    this.scoresTensorIndex = 2,
    this.modelName,
    this.modelVersion,
  });

  /// Bundled asset path of the `.tflite` model file.
  final String assetPath;

  /// Class labels in model output-index order. Must all be registry-known.
  final List<String> labels;

  final int inputWidth;
  final int inputHeight;

  /// Model-level score floor used only to drop near-zero noise detections.
  /// This is NOT the business confidence gate (that is per-category in the
  /// registry); it just prevents flooding the pipeline with empty boxes.
  final double minimumRawScore;

  /// Maximum detections the model emits per frame (output tensor length N).
  final int maxDetections;

  /// Input normalization: normalized = (pixel - [inputMean]) / [inputStd].
  /// Defaults give 0..1 scaling.
  final double inputMean;
  final double inputStd;

  // Expected output tensor layout (SSD-style). Boxes are `[ymin, xmin, ymax,
  // xmax]` normalized. If a chosen model differs, only these indices and the
  // adapter/parser change — never the business layer.
  final int boxesTensorIndex;
  final int classesTensorIndex;
  final int scoresTensorIndex;

  /// Optional model identity for traceability/versioning.
  final String? modelName;
  final String? modelVersion;

  /// Default foundation config. The model file is intentionally absent in this
  /// phase, so loading it fails gracefully and the app falls back to the mock.
  static const ToyModelConfig defaults = ToyModelConfig(
    assetPath: 'assets/models/toy_detector.tflite',
    inputWidth: 320,
    inputHeight: 320,
    labels: [
      'toy_car',
      'toy_truck',
      'doll',
      'stuffed_animal',
      'building_blocks',
      'ball',
      'action_figure',
      'toy_train',
      'puzzle',
      'board_game',
      'not_toy',
      'person',
      'pet',
      'book',
      'unknown',
    ],
  );
}
