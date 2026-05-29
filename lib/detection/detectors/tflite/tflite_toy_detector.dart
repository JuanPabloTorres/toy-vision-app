import 'dart:typed_data';

import '../../../business/toy_category_registry.dart';
import '../../models/detection_frame.dart';
import '../../models/raw_detection.dart';
import '../../models/toy_model_config.dart';
import '../toy_detector.dart';
import 'model_asset_loader.dart';
import 'model_metadata_validator.dart';
import 'tflite_model_output.dart';
import 'tflite_toy_detector_adapter.dart';

/// TFLite-backed detector. Returns the same raw detection contract as the mock
/// (label, confidence, normalized box). It performs NO business decisions.
///
/// Initialization is staged and fails safe:
///   1. validate the config against structural rules + the registry;
///   2. load the model asset bytes;
///   3. hand the bytes to the inference [ToyModelRuntime].
///
/// If a [ToyModelRuntime] is not supplied (the Phase 2b foundation state, with
/// no native TFLite runtime wired and no model file present), initialization
/// throws [ModelUnavailableException] so callers fall back to the mock detector.
class TfliteToyDetector implements ToyDetector {
  TfliteToyDetector({
    required this.config,
    required this.registry,
    ModelAssetLoader? assetLoader,
    this.validator = const ModelMetadataValidator(),
    TfliteToyDetectorAdapter? adapter,
    this.runtime,
  })  : assetLoader = assetLoader ?? const RootBundleModelAssetLoader(),
        adapter = adapter ?? TfliteToyDetectorAdapter(config);

  final ToyModelConfig config;
  final ToyCategoryRegistry registry;
  final ModelAssetLoader assetLoader;
  final ModelMetadataValidator validator;
  final TfliteToyDetectorAdapter adapter;

  /// Inference seam. Null until the native TFLite runtime is wired.
  final ToyModelRuntime? runtime;

  bool _ready = false;

  @override
  Future<void> initialize() async {
    final result = validator.validate(config, registry);
    if (!result.isValid) {
      throw ModelUnavailableException(
        'Invalid model config: ${result.errors.join('; ')}',
      );
    }

    final Uint8List bytes;
    try {
      bytes = await assetLoader.load(config.assetPath);
    } catch (_) {
      throw ModelUnavailableException(
        'Model asset not found at ${config.assetPath}',
      );
    }

    final r = runtime;
    if (r == null) {
      throw const ModelUnavailableException(
        'TFLite inference runtime is not wired yet (no ToyModelRuntime). '
        'Falling back to the mock detector.',
      );
    }

    await r.load(bytes, config);
    _ready = true;
  }

  @override
  Future<List<RawDetection>> detect(DetectionFrame frame) async {
    final r = runtime;
    if (!_ready || r == null) {
      throw const ModelUnavailableException('Detector not initialized.');
    }
    final output = await r.infer(frame);
    return adapter.toRawDetections(output);
  }

  @override
  void dispose() {
    runtime?.close();
    _ready = false;
  }
}
