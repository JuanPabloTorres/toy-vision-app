/// How a category should be surfaced in the UI.
enum UiDisplayBehavior {
  /// Shown to all users (valid toys).
  show,

  /// Hidden unless debug mode is enabled (ignored / negative categories).
  hideUnlessDebug,
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
  });

  final String label;
  final String displayName;
  final bool countsAsToy;
  final double minimumConfidence;
  final bool isIgnored;
  final UiDisplayBehavior uiDisplayBehavior;
}
