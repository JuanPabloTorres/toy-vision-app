import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tracking/tracked_toy.dart';
import 'candidate_review_service.dart';
import 'candidate_review_state.dart';
import 'toy_candidate_status.dart';
import 'toy_review_category.dart';

/// Frames a candidate without a fresh observation may stay in the service
/// before being pruned. ~10 seconds at the project's typical 6 FPS throttle.
/// Confirmed and excluded candidates survive regardless (the user already
/// decided about them and the saved scan needs them).
const int _candidateRetentionFrames = 60;

/// Riverpod-aware controller around [CandidateReviewService]. Owns the
/// service instance and publishes immutable [CandidateReviewState] snapshots
/// for the UI to watch.
///
/// LiveDetectionController calls [ingest] each accepted frame; the review
/// panel calls [markToy] / [markNotToy] / [markUnsure] / [categorize] /
/// [reset] in response to user taps.
class CandidateReviewController extends Notifier<CandidateReviewState> {
  late final CandidateReviewService _service;

  @override
  CandidateReviewState build() {
    _service = CandidateReviewService();
    return CandidateReviewState.empty();
  }

  /// Called by `LiveDetectionController.processIncomingFrame` after the
  /// tracking engine update. Visible tracked toys (current frame) feed in
  /// and become candidates; stale pending candidates get pruned.
  void ingest(List<TrackedToy> tracked, int frameIndex) {
    if (kDebugMode) {
      debugPrint(
        'CandidateDX: ingest frame=$frameIndex tracked=${tracked.length} '
        'ids=${tracked.map((t) => t.id).toList()}',
      );
    }
    _service.ingest(tracked, frameIndex);
    _service.pruneOlderThan(frameIndex, _candidateRetentionFrames);
    _publish();
  }

  /// User intent: this candidate is a toy. Category may be supplied at the
  /// same time or assigned later through [categorize].
  void markToy(int id, {ToyReviewCategory? category}) {
    if (kDebugMode) {
      debugPrint(
        'CandidateDX: mark id=$id status=confirmedToy category=$category',
      );
    }
    _service.mark(id, ToyCandidateStatus.confirmedToy, category: category);
    _publish();
  }

  /// User intent: this candidate is not a toy.
  void markNotToy(int id) {
    if (kDebugMode) debugPrint('CandidateDX: mark id=$id status=notToy');
    _service.mark(id, ToyCandidateStatus.notToy);
    _publish();
  }

  /// User intent: undecided. Stays in the review list but does not count.
  void markUnsure(int id) {
    if (kDebugMode) debugPrint('CandidateDX: mark id=$id status=unsure');
    _service.mark(id, ToyCandidateStatus.unsure);
    _publish();
  }

  /// Auto-ignore by business rule (e.g. detector label `person`).
  /// Currently unused — the validate-before-track pipeline filters those
  /// before they ever become candidates. Exposed so the wiring can evolve
  /// without changing the service contract.
  void markIgnoredAutomatic(int id) {
    if (kDebugMode) {
      debugPrint('CandidateDX: mark id=$id status=ignoredAutomatic');
    }
    _service.mark(id, ToyCandidateStatus.ignoredAutomatic);
    _publish();
  }

  /// Assign a product category without changing the confirm/reject status.
  void categorize(int id, ToyReviewCategory category) {
    if (kDebugMode) {
      debugPrint('CandidateDX: categorize id=$id category=$category');
    }
    _service.categorize(id, category);
    _publish();
  }

  /// Remove the assigned category, leaving the status alone.
  void clearCategory(int id) {
    if (kDebugMode) debugPrint('CandidateDX: clearCategory id=$id');
    _service.clearCategory(id);
    _publish();
  }

  /// Wipe every candidate and every user decision. Called from the live
  /// screen's reset button alongside the existing tracking/counting reset.
  void reset() {
    if (kDebugMode) debugPrint('CandidateDX: reset');
    _service.reset();
    _publish();
  }

  void _publish() {
    final newState = CandidateReviewState(
      all: _service.all,
      summary: _service.summary(),
    );
    state = newState;
    if (kDebugMode) {
      final s = newState.summary;
      debugPrint(
        'CandidateDX: publish total=${s.detected} '
        'pending=${s.needsReview} confirmed=${s.confirmed} '
        'ignored=${s.ignored}',
      );
    }
  }
}

final candidateReviewControllerProvider =
    NotifierProvider<CandidateReviewController, CandidateReviewState>(
  CandidateReviewController.new,
);
