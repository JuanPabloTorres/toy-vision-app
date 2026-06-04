import '../../detection/models/bounding_box.dart';
import 'toy_candidate_status.dart';
import 'toy_review_category.dart';

/// One detected candidate, tied to a stable tracking identity across frames.
///
/// Phase 4.1 product reframe: this replaces the implicit assumption that the
/// detector's label IS the truth. The detector contributes
/// [detectorLabel] / [detectorConfidence] / [box] as observations; the user
/// contributes [status] and [category] via the review flow. Both halves live
/// in the same object so the UI can render either dimension without joining
/// across collections.
///
/// [id] is the [TrackedToy.id] from the tracking engine. It is stable across
/// frames for the same physical object, which is what lets the review state
/// stick: when the user marks candidate `#7` as `confirmedToy / blocks`, that
/// decision survives the next frame's ingest even though the box moves.
class CandidateObject {
  const CandidateObject({
    required this.id,
    required this.detectorLabel,
    required this.detectorConfidence,
    required this.box,
    required this.status,
    this.category,
    required this.firstSeenFrameIndex,
    required this.lastSeenFrameIndex,
  });

  /// Stable identity from the tracking engine (`TrackedToy.id`).
  final int id;

  /// Raw label from the active detector (e.g. `home_good`, `sports_ball`,
  /// `toy_car`, or the mock detector's hardcoded labels). NEVER used to
  /// decide whether this candidate counts as a toy — only the user does.
  final String detectorLabel;

  /// Raw detector confidence, 0..1. For display only at this layer; the
  /// counting decision is the user's.
  final double detectorConfidence;

  /// Latest known bounding box, normalized 0..1, in upright orientation.
  final BoundingBox box;

  /// User's review verdict on this candidate. Starts at
  /// [ToyCandidateStatus.pending] when the candidate is first seen.
  final ToyCandidateStatus status;

  /// User-assigned product category. Null until the user assigns one.
  /// Independent of [status] so a user can pre-categorize a candidate
  /// without committing to confirm/reject.
  final ToyReviewCategory? category;

  /// Frame index at which the tracking engine first reported this id.
  final int firstSeenFrameIndex;

  /// Frame index of the most recent observation. Used by retention pruning
  /// in [CandidateReviewService.pruneOlderThan].
  final int lastSeenFrameIndex;

  /// True if [status] indicates the user counts this as a toy.
  bool get isConfirmedToy => status == ToyCandidateStatus.confirmedToy;

  /// True if [status] indicates an explicit "not a toy" decision or auto-
  /// ignore. Mirrors [ToyCandidateStatus.notToy] | `ignoredAutomatic`.
  bool get isExcluded =>
      status == ToyCandidateStatus.notToy ||
      status == ToyCandidateStatus.ignoredAutomatic;

  /// True if [status] still needs human attention.
  bool get needsReview =>
      status == ToyCandidateStatus.pending ||
      status == ToyCandidateStatus.unsure;

  /// Build a copy with selected fields replaced. Pass a sentinel via the
  /// dedicated `clearCategory` flag when you want to set category back to
  /// null — the default `category: null` argument means "leave unchanged".
  CandidateObject copyWith({
    String? detectorLabel,
    double? detectorConfidence,
    BoundingBox? box,
    ToyCandidateStatus? status,
    ToyReviewCategory? category,
    bool clearCategory = false,
    int? firstSeenFrameIndex,
    int? lastSeenFrameIndex,
  }) {
    return CandidateObject(
      id: id,
      detectorLabel: detectorLabel ?? this.detectorLabel,
      detectorConfidence: detectorConfidence ?? this.detectorConfidence,
      box: box ?? this.box,
      status: status ?? this.status,
      category: clearCategory ? null : (category ?? this.category),
      firstSeenFrameIndex: firstSeenFrameIndex ?? this.firstSeenFrameIndex,
      lastSeenFrameIndex: lastSeenFrameIndex ?? this.lastSeenFrameIndex,
    );
  }
}
