import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/review/candidate_review_service.dart';
import 'package:toyvision_realtime/business/review/toy_candidate_status.dart';
import 'package:toyvision_realtime/business/review/toy_review_category.dart';
import 'package:toyvision_realtime/detection/models/bounding_box.dart';
import 'package:toyvision_realtime/tracking/tracked_toy.dart';

TrackedToy _t({
  int id = 1,
  String label = 'home_good',
  double confidence = 0.7,
  BoundingBox? box,
}) {
  return TrackedToy(
    id: id,
    label: label,
    displayName: label,
    box: box ?? const BoundingBox(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
    confidence: confidence,
  );
}

void main() {
  group('CandidateReviewService.ingest', () {
    test('new tracked id becomes a pending candidate', () {
      final svc = CandidateReviewService();
      svc.ingest([_t(id: 42)], 100);

      final c = svc.candidate(42);
      expect(c, isNotNull);
      expect(c!.status, ToyCandidateStatus.pending);
      expect(c.detectorLabel, 'home_good');
      expect(c.detectorConfidence, closeTo(0.7, 1e-9));
      expect(c.firstSeenFrameIndex, 100);
      expect(c.lastSeenFrameIndex, 100);
    });

    test('re-seen tracked id updates box/confidence/lastSeen and keeps status',
        () {
      final svc = CandidateReviewService();
      svc.ingest([_t(id: 42, confidence: 0.5)], 100);
      svc.mark(
        42,
        ToyCandidateStatus.confirmedToy,
        category: ToyReviewCategory.ball,
      );

      svc.ingest(
        [
          _t(
            id: 42,
            confidence: 0.9,
            box: const BoundingBox(x: 0.5, y: 0.5, width: 0.1, height: 0.1),
          ),
        ],
        110,
      );

      final c = svc.candidate(42)!;
      expect(c.status, ToyCandidateStatus.confirmedToy);
      expect(c.category, ToyReviewCategory.ball);
      expect(c.detectorConfidence, closeTo(0.9, 1e-9));
      expect(c.box.x, closeTo(0.5, 1e-9));
      expect(c.firstSeenFrameIndex, 100);
      expect(c.lastSeenFrameIndex, 110);
    });

    test('multiple ids in one frame all become candidates', () {
      final svc = CandidateReviewService();
      svc.ingest([_t(id: 1), _t(id: 2), _t(id: 3)], 1);
      expect(svc.all, hasLength(3));
      expect(svc.pendingReview, hasLength(3));
    });
  });

  group('CandidateReviewService.mark', () {
    test('confirmedToy moves out of pendingReview', () {
      final svc = CandidateReviewService();
      svc.ingest([_t(id: 1)], 0);
      svc.mark(
        1,
        ToyCandidateStatus.confirmedToy,
        category: ToyReviewCategory.plush,
      );

      expect(svc.pendingReview, isEmpty);
      expect(svc.confirmed, hasLength(1));
      expect(svc.confirmed.single.category, ToyReviewCategory.plush);
    });

    test('notToy moves into excluded; ignoredAutomatic does too', () {
      final svc = CandidateReviewService();
      svc.ingest([_t(id: 1), _t(id: 2)], 0);
      svc.mark(1, ToyCandidateStatus.notToy);
      svc.mark(2, ToyCandidateStatus.ignoredAutomatic);

      expect(svc.excluded, hasLength(2));
      expect(svc.pendingReview, isEmpty);
      expect(svc.confirmed, isEmpty);
    });

    test('unsure stays in pendingReview list', () {
      final svc = CandidateReviewService();
      svc.ingest([_t(id: 1)], 0);
      svc.mark(1, ToyCandidateStatus.unsure);

      expect(svc.pendingReview, hasLength(1));
      expect(svc.pendingReview.single.status, ToyCandidateStatus.unsure);
    });

    test('mark with unknown id is a no-op (does not throw)', () {
      final svc = CandidateReviewService();
      svc.mark(999, ToyCandidateStatus.confirmedToy);
      expect(svc.all, isEmpty);
    });
  });

  group('CandidateReviewService.categorize / clearCategory', () {
    test('categorize sets category without changing status', () {
      final svc = CandidateReviewService();
      svc.ingest([_t(id: 1)], 0);
      svc.categorize(1, ToyReviewCategory.blocks);

      final c = svc.candidate(1)!;
      expect(c.status, ToyCandidateStatus.pending);
      expect(c.category, ToyReviewCategory.blocks);
    });

    test('clearCategory removes category but keeps status', () {
      final svc = CandidateReviewService();
      svc.ingest([_t(id: 1)], 0);
      svc.mark(
        1,
        ToyCandidateStatus.confirmedToy,
        category: ToyReviewCategory.dollOrFigure,
      );

      svc.clearCategory(1);
      final c = svc.candidate(1)!;
      expect(c.status, ToyCandidateStatus.confirmedToy);
      expect(c.category, isNull);
    });
  });

  group('CandidateReviewService.summary', () {
    test('empty service produces zeros', () {
      final s = CandidateReviewService().summary();
      expect(s.detected, 0);
      expect(s.confirmed, 0);
      expect(s.needsReview, 0);
      expect(s.ignored, 0);
      expect(s.byCategory, isEmpty);
    });

    test('breakdown across all status buckets is correct', () {
      final svc = CandidateReviewService();
      svc.ingest([_t(id: 1), _t(id: 2), _t(id: 3), _t(id: 4), _t(id: 5)], 0);
      svc.mark(
        1,
        ToyCandidateStatus.confirmedToy,
        category: ToyReviewCategory.ball,
      );
      svc.mark(
        2,
        ToyCandidateStatus.confirmedToy,
        category: ToyReviewCategory.ball,
      );
      svc.mark(
        3,
        ToyCandidateStatus.confirmedToy,
        category: ToyReviewCategory.plush,
      );
      svc.mark(4, ToyCandidateStatus.notToy);
      // id 5 stays pending

      final s = svc.summary();
      expect(s.detected, 5);
      expect(s.confirmed, 3);
      expect(s.ignored, 1);
      expect(s.needsReview, 1);
      expect(s.byCategory[ToyReviewCategory.ball], 2);
      expect(s.byCategory[ToyReviewCategory.plush], 1);
    });

    test('confirmed candidates with no category are still counted', () {
      final svc = CandidateReviewService();
      svc.ingest([_t(id: 1)], 0);
      svc.mark(1, ToyCandidateStatus.confirmedToy); // no category

      final s = svc.summary();
      expect(s.confirmed, 1);
      expect(s.byCategory, isEmpty);
    });
  });

  group('CandidateReviewService.pruneOlderThan', () {
    test('removes stale pending candidates', () {
      final svc = CandidateReviewService();
      svc.ingest([_t(id: 1)], 0);
      svc.pruneOlderThan(50, 10);

      expect(svc.candidate(1), isNull);
    });

    test('keeps confirmed and excluded candidates regardless of age', () {
      final svc = CandidateReviewService();
      svc.ingest([_t(id: 1), _t(id: 2), _t(id: 3)], 0);
      svc.mark(1, ToyCandidateStatus.confirmedToy);
      svc.mark(2, ToyCandidateStatus.notToy);
      // id 3 stays pending

      svc.pruneOlderThan(1000, 10);

      expect(svc.candidate(1), isNotNull);
      expect(svc.candidate(2), isNotNull);
      expect(svc.candidate(3), isNull);
    });

    test('does not remove candidates inside the retention window', () {
      final svc = CandidateReviewService();
      svc.ingest([_t(id: 1)], 100);
      svc.pruneOlderThan(105, 10);

      expect(svc.candidate(1), isNotNull);
    });
  });

  group('CandidateReviewService.reset', () {
    test('clears all candidates including confirmed/ignored', () {
      final svc = CandidateReviewService();
      svc.ingest([_t(id: 1), _t(id: 2)], 0);
      svc.mark(1, ToyCandidateStatus.confirmedToy);
      svc.mark(2, ToyCandidateStatus.notToy);

      svc.reset();

      expect(svc.all, isEmpty);
      expect(svc.summary().detected, 0);
    });
  });

  group('ToyReviewCategory', () {
    test('every value has a non-empty displayName', () {
      for (final c in ToyReviewCategory.values) {
        expect(
          c.displayName,
          isNotEmpty,
          reason: '$c is missing a displayName',
        );
      }
    });

    test('countsAsToy is true only for the toy product categories', () {
      const toys = {
        ToyReviewCategory.carOrTruck,
        ToyReviewCategory.ball,
        ToyReviewCategory.plush,
        ToyReviewCategory.blocks,
        ToyReviewCategory.dollOrFigure,
        ToyReviewCategory.train,
        ToyReviewCategory.puzzleOrBoardGame,
        ToyReviewCategory.otherToy,
      };
      for (final c in ToyReviewCategory.values) {
        expect(
          c.countsAsToy,
          toys.contains(c),
          reason: '$c countsAsToy expected ${toys.contains(c)}',
        );
      }
    });
  });
}
