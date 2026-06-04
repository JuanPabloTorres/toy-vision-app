/// Maps Google ML Kit's default object-detector category strings to the
/// ToyVision [ToyCategoryRegistry] labels.
///
/// ML Kit's stock classifier emits five high-level categories — `Home good`,
/// `Fashion good`, `Food`, `Place`, `Plant` — plus an "unclassified" state
/// (zero labels on the detected object) when it found an object but couldn't
/// confidently label it. None of these are toy-specific; they exist so the
/// pipeline can be validated end-to-end with a real on-device detector while
/// the toy-specific classifier model is still in training.
///
/// Mapping rationale:
/// - `Home good` → `home_good` (counts as a toy candidate; a stuffed bear,
///   doll, car-shaped object in a home will usually classify here).
/// - Unclassified box → `object` (the detector found something but isn't sure;
///   in a toy-on-floor scene this is the common case).
/// - `Fashion good` → `clothes`, `Place` → `furniture` (both already in the
///   registry as ignored categories).
/// - `Food`, `Plant` → new ignored entries.
class MlKitLabelMap {
  MlKitLabelMap._();

  /// Registry label used for an ML Kit object that came back with no
  /// classification label. The detector localized a box but didn't recognize
  /// the category — for toy detection we still want to surface it.
  static const String unclassifiedLabel = 'object';

  /// Translate one ML Kit category string (case-insensitive, English locale)
  /// into a ToyVision registry label. Unrecognized text falls back to
  /// [unclassifiedLabel] so the registry's "unknown handling" semantics still
  /// apply rather than crashing the pipeline.
  static String toRegistryLabel(String mlKitCategory) {
    switch (mlKitCategory.toLowerCase().trim()) {
      case 'home good':
        return 'home_good';
      case 'fashion good':
        return 'clothes';
      case 'food':
        return 'food';
      case 'place':
        return 'furniture';
      case 'plant':
        return 'plant';
      default:
        return unclassifiedLabel;
    }
  }

  /// The complete set of registry labels this mapping can produce. Used by
  /// validators to keep the registry and detector in sync.
  static const Set<String> producedLabels = {
    'home_good',
    'clothes',
    'food',
    'furniture',
    'plant',
    unclassifiedLabel,
  };
}
