import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/application/cleanup/cleanup_controller.dart';
import 'package:toyvision_realtime/application/cleanup/room_clean_verifier.dart';
import 'package:toyvision_realtime/application/cleanup/cleanup_state.dart';
import 'package:toyvision_realtime/application/events/domain_event_bus.dart';
import 'package:toyvision_realtime/application/history/cleanup_history_provider.dart';
import 'package:toyvision_realtime/core/performance/adaptive_inference_scheduler.dart';
import 'package:toyvision_realtime/domain/cleanup/cleanup_event.dart';
import 'package:toyvision_realtime/domain/progress/progress_models.dart';
import 'package:toyvision_realtime/domain/repositories/cleanup_history_repository.dart';
import 'package:toyvision_realtime/domain/repositories/progress_repository.dart';
import 'package:toyvision_realtime/domain/scene/room_world_model.dart';
import 'package:toyvision_realtime/domain/scene/scene_descriptor.dart';
import 'package:toyvision_realtime/domain/scene/scene_state.dart';
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/domain/toy/toy_observation.dart';
import 'package:toyvision_realtime/domain/toy/toy_track.dart';
import 'package:toyvision_realtime/perception/perception_engine.dart';
import 'package:toyvision_realtime/perception/perception_models.dart';

void main() {
  test(
      'pickup advances targets and room verification completes without rediscovery',
      () async {
    final origin = DateTime.utc(2026);
    final first = _track(1, origin, size: 0.28);
    final second = _track(2, origin, size: 0.18);
    final missingFirst =
        _missing(first, origin.add(const Duration(seconds: 6)));
    final missingSecond =
        _missing(second, origin.add(const Duration(seconds: 7)));
    final results = <PerceptionResult>[
      _result(
        origin,
        const [1, 0],
        active: {1: first, 2: second},
      ),
      _result(
        origin.add(const Duration(seconds: 4)),
        const [0.8, 0.6],
        active: {1: first, 2: second},
      ),
      _result(
        origin.add(const Duration(seconds: 6)),
        const [0.8, 0.6],
        active: {2: second},
        missing: {1: missingFirst},
        disappearance: {1: _confirmedRemoval(missingFirst)},
      ),
      _result(
        origin.add(const Duration(seconds: 7)),
        const [0.8, 0.6],
        missing: {1: missingFirst, 2: missingSecond},
        disappearance: {2: _confirmedRemoval(missingSecond)},
      ),
      for (var index = 1; index <= 6; index++)
        _result(
          origin.add(Duration(seconds: 7 + index)),
          const [1, 0],
          missing: {1: missingFirst, 2: missingSecond},
          uncertain: index == 1
              ? [_uncertainOpenSet(origin.add(const Duration(seconds: 8)))]
              : const [],
        ),
    ];
    final engine = _SequencePerceptionEngine(results);
    final eventBus = DomainEventBus();
    final events = <CleanupEvent>[];
    final subscription = eventBus.events.listen(events.add);
    final history = _MemoryHistory(
      onComplete: () {
        expect(events.whereType<CleanupCompleted>(), isEmpty);
      },
    );
    final container = ProviderContainer(
      overrides: [
        perceptionEngineProvider.overrideWithValue(engine),
        progressRepositoryProvider.overrideWithValue(history),
        domainEventBusProvider.overrideWithValue(eventBus),
      ],
    );
    addTearDown(() async {
      await subscription.cancel();
      container.dispose();
      await eventBus.dispose();
    });
    final controller = container.read(cleanupControllerProvider.notifier);

    controller.start();
    controller.markModelReady();
    expect(
      container.read(cleanupControllerProvider).visionStatus,
      VisionStatus.running,
    );
    controller.beginDiscovery();
    await controller.ingest(_frame(0, origin));
    await controller.ingest(_frame(1, origin.add(const Duration(seconds: 4))));
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    var state = container.read(cleanupControllerProvider);
    expect(state.phase, CleanupPhase.cleaning);
    expect(state.activeTargetTrackId, 1);

    await controller.ingest(_frame(2, origin.add(const Duration(seconds: 6))));
    state = container.read(cleanupControllerProvider);
    expect(state.phase, CleanupPhase.cleaning);
    expect(state.collected, 1);
    expect(state.remainingEstimate, 1);
    expect(state.activeTargetTrackId, 2);

    await controller.ingest(_frame(3, origin.add(const Duration(seconds: 7))));
    state = container.read(cleanupControllerProvider);
    expect(state.phase, CleanupPhase.verifyingRoom);
    expect(state.collected, 2);
    expect(state.remainingEstimate, 0);
    expect(state.completionEvidence, isNotNull);

    await controller.ingest(_frame(4, origin.add(const Duration(seconds: 8))));
    state = container.read(cleanupControllerProvider);
    expect(state.phase, CleanupPhase.verifyingRoom);
    expect(state.completionEvidence?.candidateToyCount, 1);
    expect(
      state.completionEvidence?.blockingReasons,
      contains('ambiguous_toy_candidates'),
    );

    for (var index = 5; index < results.length; index++) {
      await controller.ingest(
        _frame(index, origin.add(Duration(seconds: index + 4))),
      );
    }
    state = container.read(cleanupControllerProvider);
    expect(state.phase, CleanupPhase.completed);
    expect(state.visionStatus, VisionStatus.stopped);
    expect(
      state.completionEvidence?.confidence,
      CompletionConfidence.strong,
    );
    expect(history.saved, hasLength(1));
    expect(events.whereType<ToyCollected>(), hasLength(2));
    expect(
      events.whereType<ActiveToyChanged>().map((event) => event.trackId),
      [1, 2],
    );
    expect(events.whereType<RoomCleanConfirmed>(), hasLength(1));
    expect(events.whereType<CleanupCompleted>(), hasLength(1));
  });
}

class _SequencePerceptionEngine implements PerceptionEngine {
  _SequencePerceptionEngine(this.results);

  final List<PerceptionResult> results;
  int _index = 0;

  @override
  Future<PerceptionResult> processFrame(
    CameraPerceptionFrame frame, {
    required bool discoveryMode,
  }) async =>
      results[_index++];

  @override
  void markCollected(int trackId, DateTime timestamp) {}

  @override
  void recordDroppedFrame() {}

  @override
  void reset() => _index = 0;

  @override
  void updateDeviceHealth(DeviceHealth health) {}
}

class _MemoryHistory implements ProgressRepository {
  _MemoryHistory({this.onComplete});

  final void Function()? onComplete;
  final List<CleanupSessionSummary> saved = [];

  @override
  Future<void> clear(String childId) async => saved.clear();

  @override
  Future<CleanupCompletionResult> completeCleanup(
    CleanupCompletionRequest request,
    CleanupCompletionDecider decide,
  ) async {
    onComplete?.call();
    saved.add(request.session);
    return CleanupCompletionResult(
      sessionId: request.session.id,
      starsAwarded: 1,
      wasAlreadyCompleted: false,
    );
  }

  @override
  Future<ChildProgress> getProgress(String childId) async =>
      ChildProgress.empty(childId);
}

CameraPerceptionFrame _frame(int id, DateTime at) => CameraPerceptionFrame(
      frameId: id,
      timestamp: at,
      encodedImage: Uint8List(0),
      detectorProposals: const [],
      nativeInferenceMs: 1,
      nativeFps: 8,
    );

ToyTrack _track(int id, DateTime at, {required double size}) => ToyTrack(
      id: id,
      lastBounds: NormalizedBox(x: id * 0.2, y: 0.2, width: size, height: size),
      initialBounds:
          NormalizedBox(x: id * 0.2, y: 0.2, width: size, height: size),
      visualEmbedding: id == 1 ? const [1, 0] : const [0, 1],
      visibleFrames: 12,
      missingFrames: 0,
      confidence: 0.92,
      presence: TrackPresence.visible,
      firstSeenAt: at.subtract(const Duration(seconds: 4)),
      lastSeenAt: at,
      updatedAt: at,
      source: ObservationSource.detector,
      confirmedToy: true,
      confirmedAt: at.subtract(const Duration(seconds: 4)),
      interactionEvidence: 1,
      lastInteractionAt: at,
    );

ToyTrack _missing(ToyTrack track, DateTime at) => track.copyWith(
      missingFrames: 12,
      presence: TrackPresence.confirmedMissing,
      updatedAt: at,
      missingSince: at.subtract(const Duration(seconds: 3)),
    );

DisappearanceEvidence _confirmedRemoval(ToyTrack track) =>
    DisappearanceEvidence(
      trackId: track.id,
      missingFrames: track.missingFrames,
      missingDuration: const Duration(seconds: 3),
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
      confidence: 1,
      confirmed: true,
    );

PerceptionResult _result(
  DateTime at,
  List<double> sceneEmbedding, {
  Map<int, ToyTrack> active = const {},
  Map<int, ToyTrack> missing = const {},
  Map<int, DisappearanceEvidence> disappearance = const {},
  List<ToyObservation> uncertain = const [],
}) {
  final analysis = FrameAnalysis(
    embeddingExtractorIdentifier: 'test',
    candidates: const [],
    sceneEmbedding: sceneEmbedding,
    trackedRegionEmbeddings: const {},
    sharpness: 1,
    luminance: 1,
    coverage: 1,
    sourceWidth: 320,
    sourceHeight: 240,
    decodeAndEmbeddingUs: 1,
  );
  return PerceptionResult(
    worldModel: RoomWorldModel(
      activeTracks: active,
      missingTracks: missing,
      collectedTracks: const {},
      sceneState: SceneState.stable,
      scene: SceneDescriptor(
        embedding: sceneEmbedding,
        state: SceneState.stable,
        similarityToPrevious: 0.99,
        motion: 0.01,
        sharpness: 1,
        luminance: 1,
        coverage: 1,
        timestamp: at,
        stableFrameCount: 10,
        similarityToStableAnchor: 0.99,
      ),
      updatedAt: at,
    ),
    acceptedObservations: const [],
    uncertainObservations: uncertain,
    transitions: const [],
    disappearanceEvidence: disappearance,
    metrics: const PerceptionMetrics(
      frameId: 0,
      nativeInferenceMs: 1,
      nativeFps: 8,
      analysisUs: 1,
      fusionUs: 1,
      trackingUs: 1,
      detectorProposalCount: 0,
      openSetProposalCount: 0,
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
}

ToyObservation _uncertainOpenSet(DateTime at) => ToyObservation(
      bounds: const NormalizedBox(x: 0.4, y: 0.4, width: 0.15, height: 0.15),
      detectionConfidence: 0,
      proposalConfidence: 0.72,
      embeddingSimilarity: 0.6,
      temporalPersistence: 2,
      spatialStability: 0.8,
      sceneContextScore: 1,
      toyProbability: 0.62,
      stage: ToyEvidenceStage.candidate,
      embedding: const [0.5, 0.5],
      frameId: 4,
      timestamp: at,
      source: ObservationSource.openSetProposal,
    );
