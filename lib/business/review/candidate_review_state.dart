import 'candidate_object.dart';
import 'candidate_review_summary.dart';

/// Immutable snapshot the UI watches for the candidate-review flow.
///
/// Built by [CandidateReviewController] from the underlying
/// [CandidateReviewService]. The UI never mutates this object; it requests
/// changes through the controller, which then publishes a new state.
class CandidateReviewState {
  CandidateReviewState({
    required this.all,
    required this.summary,
  }) : byId = Map.unmodifiable({for (final c in all) c.id: c});

  /// All currently-tracked candidates, in insertion order. Sort in the UI
  /// when a specific order is needed (e.g. by `lastSeenFrameIndex` desc).
  final List<CandidateObject> all;

  /// Pre-computed summary for the UI counter panel.
  final CandidateReviewSummary summary;

  /// O(1) lookup by tracking id. Built once at construction and is
  /// unmodifiable; the painter and tap-routing code can rely on it.
  final Map<int, CandidateObject> byId;

  /// Empty state for the initial publish, before the first frame ingests.
  factory CandidateReviewState.empty() => CandidateReviewState(
        all: const [],
        summary: CandidateReviewSummary.empty,
      );
}
