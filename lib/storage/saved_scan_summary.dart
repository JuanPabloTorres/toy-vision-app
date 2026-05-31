/// A saved snapshot of a single scan — counts only. No frames, no images, no
/// video are ever stored alongside this object.
///
/// Per privacy-safety-guidelines.md, persistence carries only summary data:
/// counts by category, a timestamp, and which detector produced them.
class SavedScanSummary {
  const SavedScanSummary({
    required this.id,
    required this.createdAt,
    required this.totalToys,
    required this.perCategory,
    required this.detectorMode,
    this.note,
  });

  /// Stable identifier for this summary within the current session.
  final String id;
  final DateTime createdAt;
  final int totalToys;
  final Map<String, int> perCategory;

  /// Which detector produced these counts (e.g. "mock", "tfliteWithFallback").
  /// Recorded so a future history view can distinguish dev mock data from real
  /// inference, never to alter how the counts themselves are interpreted.
  final String detectorMode;

  final String? note;
}
