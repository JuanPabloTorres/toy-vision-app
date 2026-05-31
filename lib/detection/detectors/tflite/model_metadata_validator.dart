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
  const ModelMetadataValidator({this.allowDuplicateLabels = false});

  /// When true, repeated labels in `config.labels` are allowed.
  ///
  /// ToyVision-native configs map one model index to one unique business
  /// label, so duplicates indicate a likely typo (default). COCO-style
  /// configs (see `coco_ssd_toy_model_config.dart`) intentionally repeat
  /// labels like `'unknown'`, `'furniture'`, and `'clothes'` across many
  /// model indices — for those, callers opt in via this flag.
  final bool allowDuplicateLabels;

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
      if (!seen.add(label) && !allowDuplicateLabels) {
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
