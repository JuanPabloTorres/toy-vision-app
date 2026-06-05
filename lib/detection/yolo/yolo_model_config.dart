import 'package:flutter/services.dart' show rootBundle;
import 'package:ultralytics_yolo/ultralytics_yolo.dart' show YOLOTask;

/// Configuration for the YOLO detector that powers Toy Vision.
///
/// Two model sources, resolved at runtime by [resolve]:
/// 1. **Custom toy model** — if `assets/models/toys.tflite` is bundled
///    (exported via `tools/toy_model_export/`), it is used. This is the
///    purpose-built detector that actually recognizes dolls, blocks,
///    ring-stackers, etc.
/// 2. **Fallback** — otherwise the official `yolo26n` (COCO-80), which
///    the plugin downloads on first run. It only knows a handful of
///    toy-ish classes (teddy bear, sports ball, car/truck/train).
class YoloModelConfig {
  const YoloModelConfig({
    this.modelPath = fallbackModelId,
    this.task = YOLOTask.detect,
    // Lower (0.30) so faint toy detections surface — non-toy COCO classes
    // are dropped by the mapper anyway, so this only adds toy candidates.
    this.confidenceThreshold = 0.30,
    this.iouThreshold = 0.5,
    this.cameraResolution = '720p',
    this.useGpu = true,
    this.isCustomToyModel = false,
  });

  /// Official Ultralytics model id (downloaded + cached by the plugin).
  static const String fallbackModelId = 'yolo26n';

  /// Bundled custom toy model. Drop the exported file here and it is
  /// picked up automatically on the next launch.
  static const String customModelAsset = 'assets/models/toys.tflite';

  final String modelPath;
  final YOLOTask task;
  final double confidenceThreshold;
  final double iouThreshold;

  /// One of '480p' | '720p' | '1080p' | '4K'.
  final String cameraResolution;

  final bool useGpu;

  /// True when [modelPath] points at the bundled toy model. Lets the UI
  /// (parent panel) show which detector is live.
  final bool isCustomToyModel;

  static const YoloModelConfig fallback = YoloModelConfig();

  /// A copy with selected fields replaced. Used by the debug-only confidence
  /// override in the Detection Recall Lab — never on a production path.
  YoloModelConfig copyWith({
    double? confidenceThreshold,
    double? iouThreshold,
  }) =>
      YoloModelConfig(
        modelPath: modelPath,
        task: task,
        confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
        iouThreshold: iouThreshold ?? this.iouThreshold,
        cameraResolution: cameraResolution,
        useGpu: useGpu,
        isCustomToyModel: isCustomToyModel,
      );

  /// Resolve which model to use. Checks the asset bundle for the custom
  /// toy model; returns a config pointed at it when present, else the
  /// COCO fallback. Cheap (one bundle probe) and safe to call on build.
  static Future<YoloModelConfig> resolve() async {
    final hasCustom = await _assetExists(customModelAsset);
    if (hasCustom) {
      return const YoloModelConfig(
        modelPath: customModelAsset,
        // The toy model's classes are ALL toys, so a low threshold only adds
        // toy candidates (no non-toy classes to leak). Favor recall — 0.25
        // to catch weakly-detected items (helicopters, red/saturated toys).
        confidenceThreshold: 0.25,
        isCustomToyModel: true,
      );
    }
    return fallback;
  }

  static Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }
}
