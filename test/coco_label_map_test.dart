import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/toy_category_registry.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/coco_label_map.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/coco_ssd_toy_model_config.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/model_metadata_validator.dart';

void main() {
  final registry = ToyCategoryRegistry.standard();

  test('COCO label list has the canonical 80 classes', () {
    expect(CocoLabelMap.cocoLabels, hasLength(80));
    expect(CocoLabelMap.cocoLabels.first, 'person');
    expect(CocoLabelMap.cocoLabels.last, 'toothbrush');
    expect(CocoLabelMap.cocoLabels[32], 'sports ball');
    expect(CocoLabelMap.cocoLabels[77], 'teddy bear');
  });

  test('ToyVision-mapped list mirrors the 80 COCO indices', () {
    expect(CocoLabelMap.toyVisionLabels, hasLength(80));
  });

  test('every mapped label is known to the registry (class-list sync)', () {
    for (var i = 0; i < CocoLabelMap.toyVisionLabels.length; i++) {
      final label = CocoLabelMap.toyVisionLabels[i];
      expect(
        registry.isKnown(label),
        isTrue,
        reason:
            'COCO index $i ("${CocoLabelMap.cocoLabels[i]}") -> "$label" '
            'is not in ToyCategoryRegistry',
      );
    }
  });

  test('expected direct mappings hit the right ToyVision labels', () {
    expect(CocoLabelMap.toyVisionLabels[0], 'person');
    expect(CocoLabelMap.toyVisionLabels[15], 'pet'); // cat
    expect(CocoLabelMap.toyVisionLabels[16], 'pet'); // dog
    expect(CocoLabelMap.toyVisionLabels[32], 'ball'); // sports ball
    expect(CocoLabelMap.toyVisionLabels[39], 'bottle');
    expect(CocoLabelMap.toyVisionLabels[41], 'cup');
    expect(CocoLabelMap.toyVisionLabels[65], 'remote_control');
    expect(CocoLabelMap.toyVisionLabels[67], 'phone'); // cell phone
    expect(CocoLabelMap.toyVisionLabels[73], 'book');
    expect(CocoLabelMap.toyVisionLabels[77], 'stuffed_animal');
  });

  test('car (2) and truck (7) are flagged prototype-only', () {
    expect(CocoLabelMap.prototypeOnlyIndices, {2, 7});
    expect(CocoLabelMap.isPrototypeOnly(2), isTrue);
    expect(CocoLabelMap.isPrototypeOnly(7), isTrue);
    expect(CocoLabelMap.isPrototypeOnly(0), isFalse);
    expect(CocoLabelMap.toyVisionLabels[2], 'toy_car');
    expect(CocoLabelMap.toyVisionLabels[7], 'toy_truck');
  });

  test(
      'cocoSsdToyModelConfig validates only with allowDuplicateLabels enabled',
      () {
    const strict = ModelMetadataValidator();
    const relaxed = ModelMetadataValidator(allowDuplicateLabels: true);

    final strictResult = strict.validate(cocoSsdToyModelConfig, registry);
    final relaxedResult = relaxed.validate(cocoSsdToyModelConfig, registry);

    // Strict mode rejects the COCO config because of the legitimate repeats.
    expect(strictResult.isValid, isFalse);
    expect(
      strictResult.errors.any((e) => e.contains('Duplicate')),
      isTrue,
    );

    // Relaxed mode accepts it.
    expect(
      relaxedResult.isValid,
      isTrue,
      reason: relaxedResult.errors.join('; '),
    );
  });

  test('config carries the COCO-mapped 80-entry label list', () {
    expect(cocoSsdToyModelConfig.labels, hasLength(80));
    expect(cocoSsdToyModelConfig.labels, CocoLabelMap.toyVisionLabels);
    expect(cocoSsdToyModelConfig.inputWidth, 300);
    expect(cocoSsdToyModelConfig.inputHeight, 300);
    expect(cocoSsdToyModelConfig.modelName, 'coco_ssd_mobilenet_v1');
    expect(cocoSsdToyModelConfig.modelVersion, 'prototype');
  });
}
