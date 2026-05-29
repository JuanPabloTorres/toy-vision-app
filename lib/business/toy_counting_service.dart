import '../core/config/realtime_detection_config.dart';
import '../tracking/tracked_toy.dart';
import 'live_detection_state.dart';

/// Decides the final, stable, deduplicated toy count.
///
/// Second half of the counting decision (after ToyDetectionRules). A tracked toy
/// is counted exactly once: when it has been seen for at least
/// [RealtimeDetectionConfig.minimumStableFrames] and has not already been
/// counted. Counting flips the toy's `hasBeenCounted` flag so camera movement or
/// re-detection never inflates the total.
class ToyCountingService {
  ToyCountingService({required this.config});

  final RealtimeDetectionConfig config;

  int _total = 0;
  final Map<String, int> _perCategory = {};

  /// Promote newly-stable, uncounted toys to the running totals and return the
  /// current summary.
  ToyCountSummary update(List<TrackedToy> tracked) {
    for (final toy in tracked) {
      if (toy.hasBeenCounted) continue;
      if (toy.framesSeen < config.minimumStableFrames) continue;
      toy.hasBeenCounted = true;
      _total += 1;
      _perCategory.update(
        toy.displayName,
        (v) => v + 1,
        ifAbsent: () => 1,
      );
    }
    return summary;
  }

  ToyCountSummary get summary => ToyCountSummary(
        total: _total,
        perCategory: Map.unmodifiable(_perCategory),
      );

  /// Clear all accumulated counts (used by the reset action).
  void reset() {
    _total = 0;
    _perCategory.clear();
  }
}
