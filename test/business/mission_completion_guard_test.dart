import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/mission/mission_completion_guard.dart';
import 'package:toyvision_realtime/business/mission/scene_stability_service.dart';

void main() {
  const guard = MissionCompletionGuard();

  group('auto-collect guard', () {
    TargetCollectionEvidence evidence({
      int missedFrames = 16,
      SceneStabilityStatus sceneStability = SceneStabilityStatus.stable,
      bool targetStillVisibleNearby = false,
      bool hasNewUncollectedVisible = false,
      bool sceneHadAnchors = true,
    }) =>
        TargetCollectionEvidence(
          missedFrames: missedFrames,
          requiredMissedFrames: 16,
          timeSinceLastSeen: const Duration(seconds: 2),
          requiredTimeSinceLastSeen: const Duration(milliseconds: 1500),
          sceneStability: sceneStability,
          targetStillVisibleNearby: targetStillVisibleNearby,
          hasNewUncollectedVisible: hasNewUncollectedVisible,
          sceneHadAnchors: sceneHadAnchors,
        );

    test('stable scene and sustained target loss allows auto-collect', () {
      expect(guard.canAutoCollectTarget(evidence()), isTrue);
    });

    test('brief target loss does not allow auto-collect', () {
      expect(guard.canAutoCollectTarget(evidence(missedFrames: 4)), isFalse);
    });

    test('scene stability does NOT block a pickup — a hand reaching in (which '
        'the model sees as movement) must never stop counting', () {
      // The core fix: when the child reaches in to grab the toy, the model
      // briefly sees a hand/arm, which an over-cautious scene check reads as
      // "probably moved". That must not block the pickup. Sustained absence +
      // nothing nearby + no new toy IS the pickup, regardless of scene verdict.
      for (final scene in SceneStabilityStatus.values) {
        expect(
          guard.canAutoCollectTarget(evidence(sceneStability: scene)),
          isTrue,
          reason: 'scene=$scene should still allow the pickup',
        );
      }
    });

    test('the toy still visible nearby blocks the pickup (not taken yet)', () {
      expect(
        guard.canAutoCollectTarget(evidence(targetStillVisibleNearby: true)),
        isFalse,
      );
    });

    test('a different new toy in view blocks the pickup (that is a switch)', () {
      expect(
        guard.canAutoCollectTarget(evidence(hasNewUncollectedVisible: true)),
        isFalse,
      );
    });

    test('the lone-toy base case (no anchors) still counts', () {
      expect(
        guard.canAutoCollectTarget(
          evidence(
            sceneStability: SceneStabilityStatus.insufficientEvidence,
            sceneHadAnchors: false,
          ),
        ),
        isTrue,
      );
    });
  });

  group('mission completion guard', () {
    test('visible toys block completion', () {
      expect(
        guard.canCompleteMission(
          const MissionCompletionEvidence(
            pendingToyCount: 0,
            visibleToyCount: 1,
            validatedToyDetectionsInSweep: 1,
            sceneStability: SceneStabilityStatus.stable,
            sawOnlyRawNonToyDetections: false,
          ),
        ),
        isFalse,
      );
    });

    test('raw non-toy detections alone do not unlock completion', () {
      expect(
        guard.canCompleteMission(
          const MissionCompletionEvidence(
            pendingToyCount: 0,
            visibleToyCount: 0,
            validatedToyDetectionsInSweep: 0,
            sceneStability: SceneStabilityStatus.stable,
            sawOnlyRawNonToyDetections: true,
          ),
        ),
        isFalse,
      );
    });

    test('a painted green overlay box blocks completion even if the tracked '
        'count momentarily reads zero', () {
      // FASE 2 rule #1 made structural: the overlay and the guard share one
      // snapshot, so a green box on screen can never coexist with completion —
      // independent of the (possibly blipping) validated/visible counts.
      expect(
        guard.canCompleteMission(
          const MissionCompletionEvidence(
            pendingToyCount: 0,
            visibleToyCount: 0,
            validatedToyDetectionsInSweep: 0,
            sceneStability: SceneStabilityStatus.stable,
            sawOnlyRawNonToyDetections: false,
            greenOverlayDetectionCount: 1,
          ),
        ),
        isFalse,
      );
    });

    test('no visible toys with stable scene can complete', () {
      expect(
        guard.canCompleteMission(
          const MissionCompletionEvidence(
            pendingToyCount: 0,
            visibleToyCount: 0,
            validatedToyDetectionsInSweep: 0,
            sceneStability: SceneStabilityStatus.stable,
            sawOnlyRawNonToyDetections: false,
          ),
        ),
        isTrue,
      );
    });
  });

  // The ABSOLUTE rule: a fixed-goal challenge can never complete below the goal,
  // no matter how clean the area looks. This is the fix for the "completed at
  // 1/5 or 3/5" bug.
  group('goal completion gate', () {
    const cleanEvidence = MissionCompletionEvidence(
      pendingToyCount: 0,
      visibleToyCount: 0,
      validatedToyDetectionsInSweep: 0,
      sceneStability: SceneStabilityStatus.stable,
      sawOnlyRawNonToyDetections: false,
    );

    test('goalCompletionBlock: below goal → goalNotReached', () {
      expect(
        guard.goalCompletionBlock(collectedToyCount: 1, targetPickupGoal: 5),
        MissionCompletionBlockedReason.goalNotReached,
      );
      expect(
        guard.goalCompletionBlock(collectedToyCount: 3, targetPickupGoal: 5),
        MissionCompletionBlockedReason.goalNotReached,
      );
    });

    test('goalCompletionBlock: at/over goal → none', () {
      expect(
        guard.goalCompletionBlock(collectedToyCount: 5, targetPickupGoal: 5),
        MissionCompletionBlockedReason.none,
      );
      expect(
        guard.goalCompletionBlock(collectedToyCount: 6, targetPickupGoal: 5),
        MissionCompletionBlockedReason.none,
      );
    });

    test('goalCompletionBlock: free/record mode (null goal) → none', () {
      expect(
        guard.goalCompletionBlock(collectedToyCount: 0, targetPickupGoal: null),
        MissionCompletionBlockedReason.none,
      );
    });

    test('canCompleteGoalMission: blocked below goal even on a clean area', () {
      expect(
        guard.canCompleteGoalMission(
          collectedToyCount: 1,
          targetPickupGoal: 5,
          evidence: cleanEvidence,
        ),
        isFalse,
      );
      expect(
        guard.canCompleteGoalMission(
          collectedToyCount: 3,
          targetPickupGoal: 5,
          evidence: cleanEvidence,
        ),
        isFalse,
      );
    });

    test('canCompleteGoalMission: allowed at the goal with a clean area', () {
      expect(
        guard.canCompleteGoalMission(
          collectedToyCount: 5,
          targetPickupGoal: 5,
          evidence: cleanEvidence,
        ),
        isTrue,
      );
    });

    test('canCompleteGoalMission: at the goal but a toy is visible → blocked',
        () {
      expect(
        guard.canCompleteGoalMission(
          collectedToyCount: 5,
          targetPickupGoal: 5,
          evidence: const MissionCompletionEvidence(
            pendingToyCount: 0,
            visibleToyCount: 1,
            validatedToyDetectionsInSweep: 1,
            sceneStability: SceneStabilityStatus.stable,
            sawOnlyRawNonToyDetections: false,
          ),
        ),
        isFalse,
      );
    });

    test('canCompleteRecordMission: a clean area completes (no goal)', () {
      expect(guard.canCompleteRecordMission(cleanEvidence), isTrue);
    });
  });
}
