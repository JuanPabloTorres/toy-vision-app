import '../../../business/toy_category_registry.dart';
import '../../models/toy_model_config.dart';

/// Result of validating a [ToyModelConfig] against structural rules and the
/// [ToyCategoryRegistry].
class ModelValidationResult {
  const ModelValidationResult(this.errors);

  final List<String> errors;

  bool get isValid => errors.isEmpty;

  static const ModelValidationResult ok = ModelValidationResult([]);
}

/// Validates model configuration and, critically, that the model's class list
/// stays in sync with the [ToyCategoryRegistry].
///
/// A label the registry does not know is a hard error: it forces the registry to
/// be updated in the same change rather than letting an unknown class silently
/// flow through (where it would be treated as `unknown` and ignored).
class ModelMetadataValidator {
  const ModelMetadataValidator();

  ModelValidationResult validate(
    ToyModelConfig config,
    ToyCategoryRegistry registry,
  ) {
    final errors = <String>[];

    if (config.assetPath.trim().isEmpty) {
      errors.add('Model assetPath is empty.');
    } else if (!config.assetPath.endsWith('.tflite')) {
      errors.add('Model assetPath must point to a .tflite file: '
          '${config.assetPath}');
    }

    if (config.inputWidth <= 0 || config.inputHeight <= 0) {
      errors.add('Model input size must be positive: '
          '${config.inputWidth}x${config.inputHeight}');
    }

    if (config.labels.isEmpty) {
      errors.add('Model label list is empty.');
    }

    final seen = <String>{};
    for (final label in config.labels) {
      if (!seen.add(label)) {
        errors.add('Duplicate label in model class list: $label');
      }
      if (!registry.isKnown(label)) {
        errors.add('Model label "$label" is not in ToyCategoryRegistry — '
            'update the registry to keep the class list in sync.');
      }
    }

    return ModelValidationResult(errors);
  }
}
