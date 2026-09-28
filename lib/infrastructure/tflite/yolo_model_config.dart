import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart' show YOLOTask;

class YoloModelConfig {
  const YoloModelConfig({
    this.modelPath = customModelAsset,
    this.task = YOLOTask.detect,
    this.confidenceThreshold = 0.25,
    this.iouThreshold = 0.5,
    this.cameraResolution = '720p',
    this.useGpu = gpuEnabled,
  });

  static const String customModelAsset = 'assets/models/toys.tflite';
  static const bool gpuEnabled = bool.fromEnvironment('TOYVISION_USE_GPU');

  final String modelPath;
  final YOLOTask task;
  final double confidenceThreshold;
  final double iouThreshold;
  final String cameraResolution;
  final bool useGpu;

  static Future<YoloModelConfig> resolve() async {
    try {
      await rootBundle.load(customModelAsset);
      return const YoloModelConfig();
    } catch (error) {
      throw StateError(
        'Required on-device model is missing: $customModelAsset ($error)',
      );
    }
  }
}

final resolvedYoloConfigProvider = FutureProvider<YoloModelConfig>(
  (ref) => YoloModelConfig.resolve(),
);
