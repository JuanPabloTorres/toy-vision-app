import '../../models/toy_model_config.dart';
import 'coco_label_map.dart';

/// Opt-in [ToyModelConfig] for a stock COCO-trained SSD MobileNet TFLite
/// model. Phase 3.5 wires this behind `ToyDetectorMode.tfliteWithFallback`
/// once the `.tflite` is placed at the expected asset path.
///
/// The `labels` list comes from [CocoLabelMap.toyVisionLabels] (80 COCO indices
/// pre-mapped to ToyVision registry labels), so the existing
/// `TfliteToyDetectorAdapter` carries COCO model output through to the
/// business layer with no adapter changes. Validation against the registry
/// requires the relaxed validator
/// (`ModelMetadataValidator(allowDuplicateLabels: true)`) because the mapped
/// list legitimately repeats `'unknown'`, `'furniture'`, `'clothes'`, etc.
///
/// This config is **prototype-only** in practice: COCO contains real-world
/// cars and trucks, so its `car`/`truck` indices (mapped to `toy_car`/
/// `toy_truck`) will misclassify real vehicles as toys. See
/// `.toyvision/model-training/open-source-model-evaluation.md`.
const ToyModelConfig cocoSsdToyModelConfig = ToyModelConfig(
  assetPath: 'assets/models/toy_detector.tflite',
  inputWidth: 300,
  inputHeight: 300,
  labels: CocoLabelMap.toyVisionLabels,
  maxDetections: 10,
  modelName: 'coco_ssd_mobilenet_v1',
  modelVersion: 'prototype',
);
