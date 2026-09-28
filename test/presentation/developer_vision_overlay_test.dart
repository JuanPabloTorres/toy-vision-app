import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/application/cleanup/cleanup_state.dart';
import 'package:toyvision_realtime/application/cleanup/room_clean_verifier.dart';
import 'package:toyvision_realtime/domain/scene/room_world_model.dart';
import 'package:toyvision_realtime/domain/scene/scene_descriptor.dart';
import 'package:toyvision_realtime/domain/scene/scene_state.dart';
import 'package:toyvision_realtime/perception/perception_models.dart';
import 'package:toyvision_realtime/presentation/cleanup/developer_vision_overlay.dart';

void main() {
  test('debug summary explains removal and room verification decisions', () {
    final at = DateTime.utc(2026, 9, 28);
    final analysis = FrameAnalysis(
      embeddingExtractorIdentifier: 'test',
      candidates: const [],
      sceneEmbedding: const [1, 0],
      trackedRegionEmbeddings: const {},
      sharpness: 1,
      luminance: 1,
      coverage: 1,
      sourceWidth: 320,
      sourceHeight: 240,
      decodeAndEmbeddingUs: 1,
    );
    final result = PerceptionResult(
      worldModel: RoomWorldModel(
        activeTracks: const {},
        missingTracks: const {},
        collectedTracks: const {},
        sceneState: SceneState.stable,
        scene: SceneDescriptor(
          embedding: const [1, 0],
          state: SceneState.stable,
          similarityToPrevious: 0.99,
          similarityToStableAnchor: 0.98,
          motion: 0.01,
          sharpness: 1,
          luminance: 1,
          coverage: 1,
          timestamp: at,
          stableFrameCount: 8,
        ),
        updatedAt: at,
      ),
      acceptedObservations: const [],
      uncertainObservations: const [],
      transitions: const [
        TrackTransition(TrackTransitionType.reappeared, 7),
      ],
      disappearanceEvidence: {
        7: DisappearanceEvidence(
          trackId: 7,
          missingFrames: 6,
          missingDuration: const Duration(milliseconds: 842),
          sceneStable: true,
          sceneSimilarity: 0.99,
          localSimilarity: 0.1,
          regionReobserved: true,
          occluded: false,
          trackConfirmed: true,
          stableObservation: true,
          stableSceneWindow: true,
          interactionObserved: true,
          reidentificationCandidate: false,
          rejectionReasons: const [],
          confidence: 0.96,
          confirmed: true,
        ),
      },
      metrics: const PerceptionMetrics(
        frameId: 42,
        nativeInferenceMs: 25,
        nativeFps: 8,
        analysisUs: 100,
        fusionUs: 10,
        trackingUs: 10,
        detectorProposalCount: 3,
        openSetProposalCount: 2,
        acceptedObservationCount: 0,
        uncertainObservationCount: 0,
        droppedFrames: 0,
        targetInferenceFps: 8,
        sourceWidth: 320,
        sourceHeight: 240,
        schedulerReason: 'test',
      ),
      trace: PerceptionTrace(
        analysis: analysis,
        associations: const [],
        occludedTrackIds: const {},
      ),
    );
    final summary = buildDeveloperVisionSummary(
      result: result,
      phase: CleanupPhase.verifyingRoom,
      collected: 2,
      remainingEstimate: 0,
      activeToyId: 7,
      completionEvidence: CompletionEvidence(
        confidence: CompletionConfidence.probable,
        collectedRatio: 1,
        remainingStableToys: 0,
        sceneCoverage: 0.82,
        uncertainTracks: 0,
        blockingReasons: const ['room_coverage_incomplete'],
        noToyDuration: const Duration(milliseconds: 2400),
        sceneStable: true,
        cameraTrackingGood: true,
      ),
    );

    expect(summary, contains('PHASE:verifyingRoom'));
    expect(summary, contains('collected:2 remaining:0'));
    expect(summary, contains('REMOVE:CONFIRMED missingMs:842'));
    expect(summary, contains('reacquired:7'));
    expect(summary, contains('coverage:0.82'));
    expect(summary, contains('emptyMs:2400'));
    expect(summary, contains('BLOCK:room_coverage_incomplete'));
  });
}
