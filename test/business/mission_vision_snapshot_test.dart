import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/mission/mission_completion_guard.dart';
import 'package:toyvision_realtime/business/mission/mission_vision_snapshot.dart';
import 'package:toyvision_realtime/business/mission/scene_stability_service.dart';

void main() {
  const guard = MissionCompletionGuard();

  MissionVisionSnapshot snapshot({
    int rawDetectionCount = 5,
    int visibleToyCount = 0,
    int greenOverlayCount = 0,
    int? activeTargetId,
    int? pendingPickupTargetId,
  }) =>
      MissionVisionSnapshot(
        frameIndex: 1,
        rawDetectionCount: rawDetectionCount,
        mappedDetectionCount: greenOverlayCount,
        visibleToyCount: visibleToyCount,
        greenOverlayCount: greenOverlayCount,
        activeTargetId: activeTargetId,
        pendingPickupTargetId: pendingPickupTargetId,
        sceneStability: SceneStabilityStatus.stable,
      );

  group('MissionVisionSnapshot', () {
    test('empty snapshot sees nothing and has no target', () {
      const empty = MissionVisionSnapshot.empty;
      expect(empty.hasGreenOverlay, isFalse);
      expect(empty.hasVisibleToys, isFalse);
      expect(empty.sawArea, isFalse);
      expect(empty.hasUnresolvedTarget, isFalse);
    });

    test('green overlay and visible toys are reported from the same fields',
        () {
      final s = snapshot(visibleToyCount: 2, greenOverlayCount: 2);
      expect(s.hasGreenOverlay, isTrue);
      expect(s.hasVisibleToys, isTrue);
    });

    test('an active or pending target counts as unresolved', () {
      expect(snapshot(activeTargetId: 7).hasUnresolvedTarget, isTrue);
      expect(snapshot(pendingPickupTargetId: 9).hasUnresolvedTarget, isTrue);
      expect(snapshot().hasUnresolvedTarget, isFalse);
    });
  });

  group('overlay and guard read one source of truth', () {
    // The invariant the FASE 3 unification guarantees: feed the guard the
    // snapshot's greenOverlayCount and a painted box can never coexist with a
    // completion verdict.
    MissionCompletionEvidence evidenceFrom(MissionVisionSnapshot s) =>
        MissionCompletionEvidence(
          pendingToyCount: 0,
          visibleToyCount: s.visibleToyCount,
          validatedToyDetectionsInSweep: 0,
          sceneStability:
              s.sceneStability ?? SceneStabilityStatus.insufficientEvidence,
          sawOnlyRawNonToyDetections: false,
          greenOverlayDetectionCount: s.greenOverlayCount,
        );

    test('a snapshot painting a green box cannot complete the mission', () {
      final s = snapshot(visibleToyCount: 1, greenOverlayCount: 1);
      expect(guard.canCompleteMission(evidenceFrom(s)), isFalse);
    });

    test('a clean, stable, seen snapshot can complete the mission', () {
      final s = snapshot(visibleToyCount: 0, greenOverlayCount: 0);
      expect(guard.canCompleteMission(evidenceFrom(s)), isTrue);
    });
  });
}
