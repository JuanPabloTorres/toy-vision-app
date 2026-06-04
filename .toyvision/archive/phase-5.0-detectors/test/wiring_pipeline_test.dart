import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/review/candidate_review_controller.dart';
import 'package:toyvision_realtime/business/review/toy_candidate_status.dart';
import 'package:toyvision_realtime/business/toy_category_registry.dart';
import 'package:toyvision_realtime/business/toy_detection_rules.dart';
import 'package:toyvision_realtime/core/config/realtime_detection_config.dart';
import 'package:toyvision_realtime/detection/detectors/mock_toy_detector.dart';
import 'package:toyvision_realtime/detection/models/detection_frame.dart';
import 'package:toyvision_realtime/tracking/toy_tracking_engine.dart';

/// Phase 4.2.1 — verifies that the wiring `LiveDetectionController` performs
/// for each accepted frame actually produces candidate state. The
/// LiveDetectionController itself is hard to unit-test because of its camera
/// dependencies, so we reproduce the same MockToyDetector → rules → tracking
/// → ingest sequence directly against a real ProviderContainer.
///
/// If this test passes but the app on device still shows no candidates, the
/// bug is in the LiveDetectionController wiring, not the building blocks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mock detector emits 4, rules pass 2, tracking yields 2 visible', () async {
    final mock = MockToyDetector();
    final rules = ToyDetectionRules(ToyCategoryRegistry.standard());
    final engine = ToyTrackingEngine(config: RealtimeDetectionConfig.defaults);

    final raw = await mock.detect(
      DetectionFrame(
        cameraImage: null,
        frameIndex: 0,
        capturedAt: DateTime(2026, 5, 31),
      ),
    );
    expect(raw, hasLength(4), reason: 'mock should emit 4 detections per frame');

    final validated = rules.validate(raw);
    expect(
      validated,
      hasLength(2),
      reason: 'person + low-conf doll should be dropped, 2 should pass',
    );

    final tracked = engine.update(validated);
    final visible = tracked.where((t) => t.isVisible).toList(growable: false);
    expect(visible, hasLength(2), reason: 'both validated should be visible');
  });

  test('one frame of the mock pipeline populates candidate review state',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reviewController =
        container.read(candidateReviewControllerProvider.notifier);

    final mock = MockToyDetector();
    final rules = ToyDetectionRules(ToyCategoryRegistry.standard());
    final engine = ToyTrackingEngine(config: RealtimeDetectionConfig.defaults);

    final raw = await mock.detect(
      DetectionFrame(
        cameraImage: null,
        frameIndex: 0,
        capturedAt: DateTime(2026, 5, 31),
      ),
    );
    final validated = rules.validate(raw);
    final tracked = engine.update(validated);
    final visible = tracked.where((t) => t.isVisible).toList(growable: false);

    reviewController.ingest(visible, 0);

    final state = container.read(candidateReviewControllerProvider);
    expect(
      state.summary.detected,
      2,
      reason: 'two visible tracked toys should become two candidates',
    );
    expect(state.summary.needsReview, 2);
    expect(state.summary.confirmed, 0);
    expect(
      state.byId.values.every((c) => c.status == ToyCandidateStatus.pending),
      isTrue,
    );
  });

  test(
      'ten frames of the deterministic mock keep the same two ids and the '
      'same two candidates', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reviewController =
        container.read(candidateReviewControllerProvider.notifier);
    final mock = MockToyDetector();
    final rules = ToyDetectionRules(ToyCategoryRegistry.standard());
    final engine = ToyTrackingEngine(config: RealtimeDetectionConfig.defaults);

    Set<int>? seenIds;
    for (var i = 0; i < 10; i++) {
      final raw = await mock.detect(
        DetectionFrame(
          cameraImage: null,
          frameIndex: i,
          capturedAt: DateTime(2026, 5, 31),
        ),
      );
      final validated = rules.validate(raw);
      final tracked = engine.update(validated);
      final visible =
          tracked.where((t) => t.isVisible).toList(growable: false);
      reviewController.ingest(visible, i);

      final ids = visible.map((t) => t.id).toSet();
      if (seenIds == null) {
        seenIds = ids;
      } else {
        expect(
          ids,
          seenIds,
          reason:
              'mock + tracking should produce stable ids across frames; '
              'this is what lets user decisions persist',
        );
      }
    }
    final state = container.read(candidateReviewControllerProvider);
    expect(state.summary.detected, 2);
    expect(state.summary.needsReview, 2);
  });

  test('user "Toy" decision survives the next frame ingest of the same id',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reviewController =
        container.read(candidateReviewControllerProvider.notifier);
    final mock = MockToyDetector();
    final rules = ToyDetectionRules(ToyCategoryRegistry.standard());
    final engine = ToyTrackingEngine(config: RealtimeDetectionConfig.defaults);

    Future<List<int>> oneFrame(int frameIndex) async {
      final raw = await mock.detect(
        DetectionFrame(
          cameraImage: null,
          frameIndex: frameIndex,
          capturedAt: DateTime(2026, 5, 31),
        ),
      );
      final validated = rules.validate(raw);
      final tracked = engine.update(validated);
      final visible =
          tracked.where((t) => t.isVisible).toList(growable: false);
      reviewController.ingest(visible, frameIndex);
      return visible.map((t) => t.id).toList();
    }

    final firstIds = await oneFrame(0);
    expect(firstIds, hasLength(2));
    reviewController.markToy(firstIds.first);

    await oneFrame(1);

    final state = container.read(candidateReviewControllerProvider);
    expect(
      state.byId[firstIds.first]!.status,
      ToyCandidateStatus.confirmedToy,
      reason:
          'a confirmed candidate must NOT revert to pending when its '
          'tracked id is re-ingested next frame',
    );
  });
}
