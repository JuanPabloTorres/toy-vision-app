import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/toy_category_registry.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/model_metadata_validator.dart';
import 'package:toyvision_realtime/detection/models/toy_model_config.dart';

void main() {
  final registry = ToyCategoryRegistry.standard();
  const validator = ModelMetadataValidator();

  test('the default foundation config is valid', () {
    final result = validator.validate(ToyModelConfig.defaults, registry);
    expect(result.isValid, isTrue, reason: result.errors.join('; '));
  });

  test('every default model label is known to the registry (class sync)', () {
    for (final label in ToyModelConfig.defaults.labels) {
      expect(registry.isKnown(label), isTrue, reason: label);
    }
  });

  test('an unknown model label fails validation (forces registry sync)', () {
    const config = ToyModelConfig(
      assetPath: 'assets/models/toy_detector.tflite',
      inputWidth: 320,
      inputHeight: 320,
      labels: ['toy_car', 'spaceship'],
    );
    final result = validator.validate(config, registry);
    expect(result.isValid, isFalse);
    expect(result.errors.any((e) => e.contains('spaceship')), isTrue);
  });

  test('a non-.tflite asset path fails validation', () {
    const config = ToyModelConfig(
      assetPath: 'assets/models/toy_detector.bin',
      inputWidth: 320,
      inputHeight: 320,
      labels: ['toy_car'],
    );
    expect(validator.validate(config, registry).isValid, isFalse);
  });

  test('an empty label list fails validation', () {
    const config = ToyModelConfig(
      assetPath: 'assets/models/toy_detector.tflite',
      inputWidth: 320,
      inputHeight: 320,
      labels: [],
    );
    expect(validator.validate(config, registry).isValid, isFalse);
  });

  test('duplicate labels fail validation', () {
    const config = ToyModelConfig(
      assetPath: 'assets/models/toy_detector.tflite',
      inputWidth: 320,
      inputHeight: 320,
      labels: ['toy_car', 'toy_car'],
    );
    final result = validator.validate(config, registry);
    expect(result.isValid, isFalse);
    expect(result.errors.any((e) => e.contains('Duplicate')), isTrue);
  });

  test('a non-positive input size fails validation', () {
    const config = ToyModelConfig(
      assetPath: 'assets/models/toy_detector.tflite',
      inputWidth: 0,
      inputHeight: 320,
      labels: ['toy_car'],
    );
    expect(validator.validate(config, registry).isValid, isFalse);
  });
}
