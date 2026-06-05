/// How a category should be surfaced in the UI.
enum UiDisplayBehavior {
  /// Shown to all users (valid toys).
  show,

  /// Hidden unless debug mode is enabled (ignored / negative categories).
  hideUnlessDebug,
}

/// Semantic identity assigned after detector labels are mapped into ToyVision.
/// It keeps business decisions clear: a generic toy-like object is not a named
/// toy, and an uncertain sighting is not a confirmed toy.
enum ToyObjectIdentity {
  recognizedToy,
  unknownToy,
  notToy,
  uncertain,
}

/// Definition of a single category in the [ToyCategoryRegistry].
///
/// This is the single place that decides, per label, whether something counts
/// as a toy, the minimum confidence to accept it, whether it is ignored, and
/// how it is displayed. No other file may define a parallel category map.
class ToyCategoryDefinition {
  const ToyCategoryDefinition({
    required this.label,
    required this.displayName,
    required this.countsAsToy,
    required this.minimumConfidence,
    required this.isIgnored,
    required this.uiDisplayBehavior,
    required this.identity,
  });

  final String label;
  final String displayName;
  final bool countsAsToy;
  final double minimumConfidence;
  final bool isIgnored;
  final UiDisplayBehavior uiDisplayBehavior;
  final ToyObjectIdentity identity;
}
