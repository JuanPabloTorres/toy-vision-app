import 'toy_review_category.dart';

/// Immutable summary of the current review state, computed by
/// [CandidateReviewService.summary]. Renders directly in the UI alongside the
/// existing [ToyCountSummary] without replacing it.
///
/// Numerical invariant:
///   detected == confirmed + needsReview + ignored
///
/// The fields are kept as plain ints (not derived getters) so the UI does not
/// have to know which statuses roll up into which bucket.
class CandidateReviewSummary {
  const CandidateReviewSummary({
    required this.detected,
    required this.confirmed,
    required this.needsReview,
    required this.ignored,
    required this.byCategory,
  });

  /// Total candidates currently tracked, regardless of review status.
  final int detected;

  /// User-confirmed toys (status == [ToyCandidateStatus.confirmedToy]).
  final int confirmed;

  /// Pending + unsure — candidates that still want human attention.
  final int needsReview;

  /// notToy + ignoredAutomatic — explicitly excluded from the toy count.
  final int ignored;

  /// Per-category breakdown of confirmed toys. Only categories with at least
  /// one confirmed candidate appear; absent keys mean zero.
  final Map<ToyReviewCategory, int> byCategory;

  static const CandidateReviewSummary empty = CandidateReviewSummary(
    detected: 0,
    confirmed: 0,
    needsReview: 0,
    ignored: 0,
    byCategory: {},
  );
}
