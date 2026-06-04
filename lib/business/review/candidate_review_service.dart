import '../../tracking/tracked_toy.dart';
import 'candidate_object.dart';
import 'candidate_review_summary.dart';
import 'toy_candidate_status.dart';
import 'toy_review_category.dart';

/// Tracks candidate objects across frames and persists the user's review
/// decisions on each.
///
/// Phase 4.1 product reframe: the tracking engine already produces stable ids
/// per physical object. This service consumes those ids and remembers what
/// the user said about each one (toy / not toy / unsure, and which product
/// category), so a "this is a ball" tap survives the next frame's update.
///
/// Independent of the existing `ToyDetectionRules` / `ToyTrackingEngine` /
/// `ToyCountingService` pipeline. Those keep running unchanged; this service
/// is an **additional** layer the UI can read.
///
/// This file owns no UI, no timers, no platform calls. Every method is pure
/// over its own in-memory state, which makes it trivially testable.
class CandidateReviewService {
  CandidateReviewService();

  final Map<int, CandidateObject> _byId = {};

  /// Read-only snapshot of every candidate currently tracked, in
  /// no-guaranteed order. Use [pendingReview] / [confirmed] / [ignored] for
  /// filtered views.
  List<CandidateObject> get all => List.unmodifiable(_byId.values);

  /// Candidates the user still needs to look at. Sorted by
  /// `lastSeenFrameIndex` descending so the most recently seen come first.
  List<CandidateObject> get pendingReview {
    final pending =
        _byId.values.where((c) => c.needsReview).toList(growable: false);
    pending.sort(
      (a, b) => b.lastSeenFrameIndex.compareTo(a.lastSeenFrameIndex),
    );
    return List.unmodifiable(pending);
  }

  /// Candidates the user has confirmed as toys.
  List<CandidateObject> get confirmed => List.unmodifiable(
        _byId.values.where((c) => c.isConfirmedToy),
      );

  /// Candidates the user (or auto-ignore) has excluded.
  List<CandidateObject> get excluded => List.unmodifiable(
        _byId.values.where((c) => c.isExcluded),
      );

  /// Lookup a candidate by tracking id. Returns null if it was never seen
  /// or has been pruned.
  CandidateObject? candidate(int id) => _byId[id];

  /// Update internal state from one frame of tracked detections.
  ///
  /// - New tracked ids are added as `ToyCandidateStatus.pending`.
  /// - Re-seen ids have their box / confidence / lastSeenFrameIndex updated;
  ///   the user-set [status] and [category] are preserved.
  /// - Tracked ids that disappear from `trackedNow` are NOT removed here;
  ///   retention is handled by [pruneOlderThan] (the controller calls that
  ///   on a separate cadence).
  ///
  /// `frameIndex` is the monotonic accepted-frame counter from
  /// `FrameProcessingService`, used to compute candidate age.
  void ingest(List<TrackedToy> trackedNow, int frameIndex) {
    for (final t in trackedNow) {
      final existing = _byId[t.id];
      if (existing == null) {
        _byId[t.id] = CandidateObject(
          id: t.id,
          detectorLabel: t.label,
          detectorConfidence: t.confidence,
          box: t.box,
          status: ToyCandidateStatus.pending,
          firstSeenFrameIndex: frameIndex,
          lastSeenFrameIndex: frameIndex,
        );
      } else {
        _byId[t.id] = existing.copyWith(
          detectorLabel: t.label,
          detectorConfidence: t.confidence,
          box: t.box,
          lastSeenFrameIndex: frameIndex,
        );
      }
    }
  }

  /// User action: assign a new status (and optionally a category) to one
  /// candidate. Setting [status] to [ToyCandidateStatus.confirmedToy]
  /// without a [category] is allowed — the UI may collect the category in
  /// a follow-up step. No-op if the id is unknown.
  void mark(
    int id,
    ToyCandidateStatus status, {
    ToyReviewCategory? category,
  }) {
    final existing = _byId[id];
    if (existing == null) return;
    _byId[id] = existing.copyWith(
      status: status,
      category: category,
    );
  }

  /// User action: assign a product category without touching the
  /// confirm/reject decision. Useful when the user pre-categorizes
  /// then decides confirm/reject later.
  void categorize(int id, ToyReviewCategory category) {
    final existing = _byId[id];
    if (existing == null) return;
    _byId[id] = existing.copyWith(category: category);
  }

  /// User action: clear the category back to null without changing status.
  void clearCategory(int id) {
    final existing = _byId[id];
    if (existing == null) return;
    _byId[id] = existing.copyWith(clearCategory: true);
  }

  /// Remove candidates whose last observation is more than [retentionFrames]
  /// frames behind [currentFrameIndex]. Confirmed and excluded candidates
  /// are kept regardless — the user already made a decision about them and
  /// the saved scan summary needs them.
  void pruneOlderThan(int currentFrameIndex, int retentionFrames) {
    _byId.removeWhere((id, c) {
      if (c.isConfirmedToy || c.isExcluded) return false;
      return (currentFrameIndex - c.lastSeenFrameIndex) > retentionFrames;
    });
  }

  /// Snapshot of the current review state, suitable for the UI summary panel.
  CandidateReviewSummary summary() {
    var detected = 0;
    var confirmed = 0;
    var needsReview = 0;
    var ignored = 0;
    final byCat = <ToyReviewCategory, int>{};

    for (final c in _byId.values) {
      detected++;
      switch (c.status) {
        case ToyCandidateStatus.confirmedToy:
          confirmed++;
          final cat = c.category;
          if (cat != null) {
            byCat.update(cat, (n) => n + 1, ifAbsent: () => 1);
          }
        case ToyCandidateStatus.pending:
        case ToyCandidateStatus.unsure:
          needsReview++;
        case ToyCandidateStatus.notToy:
        case ToyCandidateStatus.ignoredAutomatic:
          ignored++;
      }
    }

    return CandidateReviewSummary(
      detected: detected,
      confirmed: confirmed,
      needsReview: needsReview,
      ignored: ignored,
      byCategory: Map.unmodifiable(byCat),
    );
  }

  /// Clear every candidate and every user decision. Used by the live screen's
  /// "Reset" button alongside the existing tracking/counting reset.
  void reset() {
    _byId.clear();
  }
}
