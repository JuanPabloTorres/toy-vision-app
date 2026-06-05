import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/detection/yolo/yolo_model_config.dart';

void main() {
  group('YoloModelConfig.copyWith (debug threshold override)', () {
    test('overriding the confidence threshold preserves every other field', () {
      const base = YoloModelConfig(
        modelPath: YoloModelConfig.customModelAsset,
        confidenceThreshold: 0.25,
        isCustomToyModel: true,
      );
      final tuned = base.copyWith(confidenceThreshold: 0.15);

      expect(tuned.confidenceThreshold, 0.15);
      // Everything else is untouched — the override changes only the floor.
      expect(tuned.modelPath, base.modelPath);
      expect(tuned.isCustomToyModel, isTrue);
      expect(tuned.iouThreshold, base.iouThreshold);
      expect(tuned.cameraResolution, base.cameraResolution);
      expect(tuned.useGpu, base.useGpu);
      expect(tuned.task, base.task);
    });

    test('copyWith with no arguments is identical to the source (inert)', () {
      const base = YoloModelConfig.fallback;
      final copy = base.copyWith();
      expect(copy.confidenceThreshold, base.confidenceThreshold);
      expect(copy.modelPath, base.modelPath);
      expect(copy.isCustomToyModel, base.isCustomToyModel);
    });
  });
}
