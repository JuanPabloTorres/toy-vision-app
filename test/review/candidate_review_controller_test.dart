import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/review/candidate_review_controller.dart';
import 'package:toyvision_realtime/business/review/toy_candidate_status.dart';
import 'package:toyvision_realtime/business/review/toy_review_category.dart';
import 'package:toyvision_realtime/detection/models/bounding_box.dart';
import 'package:toyvision_realtime/tracking/tracked_toy.dart';

TrackedToy _t({int id = 1, double conf = 0.7, String label = 'home_good'}) {
  return TrackedToy(
    id: id,
    label: label,
    displayName: label,
    box: const BoundingBox(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
    confidence: conf,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initial state is empty', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final s = container.read(candidateReviewControllerProvider);
    expect(s.all, isEmpty);
    expect(s.byId, isEmpty);
    expect(s.summary.detected, 0);
  });

  test('ingest publishes new state with one pending candidate', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(candidateReviewControllerProvider.notifier);

    controller.ingest([_t(id: 42)], 0);
    final s = container.read(candidateReviewControllerProvider);

    expect(s.all, hasLength(1));
    expect(s.byId[42], isNotNull);
    expect(s.byId[42]!.status, ToyCandidateStatus.pending);
    expect(s.summary.detected, 1);
    expect(s.summary.needsReview, 1);
    expect(s.summary.confirmed, 0);
  });

  test('user decision persists across subsequent ingests of the same id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(candidateReviewControllerProvider.notifier);

    controller.ingest([_t(id: 1)], 0);
    controller.markToy(1, category: ToyReviewCategory.ball);

    // Same id reappears in a later frame with a new confidence — review state
    // must stick.
    controller.ingest([_t(id: 1, conf: 0.9)], 5);

    final c = container.read(candidateReviewControllerProvider).byId[1]!;
    expect(c.status, ToyCandidateStatus.confirmedToy);
    expect(c.category, ToyReviewCategory.ball);
    expect(c.detectorConfidence, closeTo(0.9, 1e-9));
  });

  test('markNotToy / markUnsure / categorize update the published state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(candidateReviewControllerProvider.notifier);
    controller.ingest([_t(id: 1), _t(id: 2), _t(id: 3)], 0);

    controller.markNotToy(1);
    controller.markUnsure(2);
    controller.categorize(3, ToyReviewCategory.blocks);

    final s = container.read(candidateReviewControllerProvider);
    expect(s.byId[1]!.status, ToyCandidateStatus.notToy);
    expect(s.byId[2]!.status, ToyCandidateStatus.unsure);
    expect(s.byId[3]!.category, ToyReviewCategory.blocks);
    expect(s.byId[3]!.status, ToyCandidateStatus.pending);
  });

  test('summary buckets are correct after a mixed review session', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(candidateReviewControllerProvider.notifier);

    controller.ingest(
      [
        _t(id: 1),
        _t(id: 2),
        _t(id: 3),
        _t(id: 4),
        _t(id: 5),
      ],
      0,
    );
    controller.markToy(1, category: ToyReviewCategory.ball);
    controller.markToy(2, category: ToyReviewCategory.ball);
    controller.markToy(3, category: ToyReviewCategory.plush);
    controller.markNotToy(4);
    controller.markUnsure(5);

    final s = container.read(candidateReviewControllerProvider).summary;
    expect(s.detected, 5);
    expect(s.confirmed, 3);
    expect(s.needsReview, 1);
    expect(s.ignored, 1);
    expect(s.byCategory[ToyReviewCategory.ball], 2);
    expect(s.byCategory[ToyReviewCategory.plush], 1);
  });

  test('reset clears every candidate and republishes empty state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(candidateReviewControllerProvider.notifier);

    controller.ingest([_t(id: 1), _t(id: 2)], 0);
    controller.markToy(1);
    controller.reset();

    final s = container.read(candidateReviewControllerProvider);
    expect(s.all, isEmpty);
    expect(s.summary.detected, 0);
  });

  test('pruning runs as part of ingest and drops stale pending candidates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(candidateReviewControllerProvider.notifier);

    controller.ingest([_t(id: 1)], 0);
    // Push the frame index far past the retention window without re-seeing 1.
    controller.ingest([_t(id: 2)], 200);

    final s = container.read(candidateReviewControllerProvider);
    expect(
      s.byId[1],
      isNull,
      reason: 'stale pending candidate should be pruned',
    );
    expect(s.byId[2], isNotNull);
  });

  test('pruning never drops a confirmed candidate', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(candidateReviewControllerProvider.notifier);

    controller.ingest([_t(id: 1)], 0);
    controller.markToy(1, category: ToyReviewCategory.ball);

    controller.ingest([_t(id: 2)], 1000);

    final s = container.read(candidateReviewControllerProvider);
    expect(s.byId[1]!.status, ToyCandidateStatus.confirmedToy);
  });

  test('byId is unmodifiable so the UI cannot accidentally mutate state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(candidateReviewControllerProvider.notifier);
    controller.ingest([_t(id: 1)], 0);

    final s = container.read(candidateReviewControllerProvider);
    expect(() => s.byId[2] = s.byId[1]!, throwsUnsupportedError);
  });
}
