import 'dart:isolate';

import '../core/performance/adaptive_inference_scheduler.dart';
import '../domain/scene/room_world_model.dart';
import '../domain/scene/scene_state.dart';
import '../domain/toy/normalized_box.dart';
import '../domain/toy/toy_track.dart';
import 'detector/object_detector.dart';
import 'disappearance/disappearance_verifier.dart';
import 'fusion/toy_candidate_fusion.dart';
import 'fusion/sensor_fusion_engine.dart';
import 'perception_models.dart';
import 'scene/scene_stability_service.dart';
import 'scene/scene_anchor_update_policy.dart';
import 'tracking/occlusion_reasoner.dart';
import 'tracking/reidentification_candidate_policy.dart';
import 'tracking/toy_tracker.dart';
import 'visual_frame_analyzer.dart';

abstract interface class PerceptionEngine {
  Future<PerceptionResult> processFrame(
    CameraPerceptionFrame frame, {
    required bool discoveryMode,
  });

  void updateDeviceHealth(DeviceHealth health);
  void recordDroppedFrame();
  void markCollected(int trackId, DateTime timestamp);
  void reset();
}

class HybridToyPerceptionEngine implements PerceptionEngine {
  HybridToyPerceptionEngine({
    ObjectDetector? detector,
    VisualFrameAnalyzer? analyzer,
    ToyCandidateFusion? fusion,
    ToyTracker? tracker,
    SceneStabilityService? sceneStability,
    ToyRemovalVerifier? removalVerifier,
    OcclusionReasoner? occlusionReasoner,
    ReidentificationCandidatePolicy? reidentificationPolicy,
    SceneAnchorUpdatePolicy? sceneAnchorUpdatePolicy,
    AdaptiveInferenceScheduler? scheduler,
    SensorFusionEngine? sensorFusion,
  })  : _detector = detector ?? const NativeProposalObjectDetector(),
        _analyzer = analyzer ?? const VisualFrameAnalyzer(),
        _fusion = fusion ?? ToyCandidateFusion(),
        _tracker = tracker ?? ToyTracker(),
        _sceneStability = sceneStability ?? SceneStabilityService(),
        _removalVerifier = removalVerifier ?? const DisappearanceVerifier(),
        _occlusionReasoner = occlusionReasoner ?? const OcclusionReasoner(),
        _reidentificationPolicy =
            reidentificationPolicy ?? const ReidentificationCandidatePolicy(),
        _sceneAnchorUpdatePolicy =
            sceneAnchorUpdatePolicy ?? const SceneAnchorUpdatePolicy(),
        _scheduler = scheduler ?? const AdaptiveInferenceScheduler(),
        _sensorFusion = sensorFusion ?? const SensorFusionEngine();

  final ObjectDetector _detector;
  final VisualFrameAnalyzer _analyzer;
  final ToyCandidateFusion _fusion;
  final ToyTracker _tracker;
  final SceneStabilityService _sceneStability;
  final ToyRemovalVerifier _removalVerifier;
  final OcclusionReasoner _occlusionReasoner;
  final ReidentificationCandidatePolicy _reidentificationPolicy;
  final SceneAnchorUpdatePolicy _sceneAnchorUpdatePolicy;
  final AdaptiveInferenceScheduler _scheduler;
  final SensorFusionEngine _sensorFusion;

  DeviceHealth _deviceHealth = const DeviceHealth();
  InferencePolicy _lastPolicy = const InferencePolicy(
    targetFps: 8,
    runOpenSetProposals: true,
    reason: 'initial_scan',
  );
  int _droppedFrames = 0;

  @override
  Future<PerceptionResult> processFrame(
    CameraPerceptionFrame frame, {
    required bool discoveryMode,
  }) async {
    final proposals = await _detector.detect(frame);
    final enrichedFrame = CameraPerceptionFrame(
      frameId: frame.frameId,
      timestamp: frame.timestamp,
      encodedImage: frame.encodedImage,
      detectorProposals: proposals,
      nativeInferenceMs: frame.nativeInferenceMs,
      nativeFps: frame.nativeFps,
      detectorCoordinatesAreUpright: frame.detectorCoordinatesAreUpright,
      spatial: frame.spatial,
    );
    final regions = <int, NormalizedBox>{
      for (final track in _tracker.tracks)
        if (track.presence != TrackPresence.collected)
          track.id: track.lastBounds,
    };
    final sceneAnchorRegions = <NormalizedBox>{
      for (final track in _tracker.tracks) track.initialBounds,
      for (final track in _tracker.tracks) track.lastBounds,
    };
    final generateOpenSet = _lastPolicy.runOpenSetProposals &&
        _deviceHealth.thermalState != ThermalState.serious &&
        _deviceHealth.thermalState != ThermalState.critical;
    final analysis = await Isolate.run<FrameAnalysis>(
      () => _analyzer.analyze(
        enrichedFrame,
        trackedRegions: regions,
        sceneAnchorRegions: sceneAnchorRegions,
        // Global scene motion describes the room, not a toy being picked up.
        // Mask semantic proposals in every phase so local object movement can
        // produce interaction evidence while a true camera pan remains global.
        maskDetectorProposalsForScene: true,
        generateOpenSetProposals: generateOpenSet,
      ),
    );
    final scene = _sceneStability.evaluate(
      analysis,
      frame.timestamp,
      allowAnchorUpdate: _sceneAnchorUpdatePolicy.canUpdate(
        discoveryMode: discoveryMode,
        tracks: _tracker.tracks,
      ),
      spatial: frame.spatial,
    );

    final fusionStopwatch = Stopwatch()..start();
    final sceneContext = scene.state == SceneState.stable
        ? 1.0
        : (analysis.isObscured ? 0.0 : 0.55);
    final fused = _fusion.evaluate(
      analysis,
      frameId: frame.frameId,
      timestamp: frame.timestamp,
      sceneContextScore: sceneContext,
    );
    fusionStopwatch.stop();

    final trackingStopwatch = Stopwatch()..start();
    var tracking = _tracker.update(
      [...fused.accepted, ...fused.uncertain],
      frame.timestamp,
      scene.state,
    );
    final disappearance = <int, DisappearanceEvidence>{};
    final occludedTrackIds = <int>{};
    for (final track in tracking.tracks) {
      if (track.presence != TrackPresence.missingCandidate) continue;
      final occluded =
          _occlusionReasoner.isOccluded(track, analysis, scene.state);
      if (occluded) occludedTrackIds.add(track.id);
      final evaluation = _removalVerifier.evaluate(
        track: track,
        scene: scene,
        currentRegionEmbedding: analysis.trackedRegionEmbeddings[track.id],
        occluded: occluded,
        reidentificationCandidate:
            _reidentificationPolicy.hasPlausibleCandidate(
          missingTrack: track,
          observations: [...fused.accepted, ...fused.uncertain],
        ),
        timestamp: frame.timestamp,
        fusionEvidence: _sensorFusion.evaluateRemoval(
          track: track,
          scene: scene,
          currentRegionEmbedding: analysis.trackedRegionEmbeddings[track.id],
          spatial: frame.spatial,
        ),
      );
      disappearance[track.id] = evaluation.evidence;
      if (evaluation.decision == RemovalDecision.removalConfirmed) {
        _tracker.confirmMissing(track.id, frame.timestamp);
      }
    }
    if (disappearance.values.any((evidence) => evidence.confirmed)) {
      tracking = TrackingUpdate(
        tracks: _tracker.tracks,
        transitions: tracking.transitions,
        associations: tracking.associations,
      );
    }
    trackingStopwatch.stop();

    final active = <int, ToyTrack>{};
    final missing = <int, ToyTrack>{};
    final collected = <int, ToyTrack>{};
    for (final track in tracking.tracks) {
      switch (track.presence) {
        case TrackPresence.candidate:
        case TrackPresence.visible:
          active[track.id] = track;
        case TrackPresence.occluded:
        case TrackPresence.missingCandidate:
        case TrackPresence.confirmedMissing:
          missing[track.id] = track;
        case TrackPresence.collected:
          collected[track.id] = track;
      }
    }
    final world = RoomWorldModel(
      activeTracks: active,
      missingTracks: missing,
      collectedTracks: collected,
      sceneState: scene.state,
      scene: scene,
      updatedAt: frame.timestamp,
    );
    final possibleDisappearance = missing.values.any(
      (track) => track.presence == TrackPresence.missingCandidate,
    );
    final policy = _scheduler.evaluate(
      sceneState: scene.state,
      motion: scene.motion,
      deviceHealth: _deviceHealth,
      activeTracks: active.length,
      possibleDisappearance: possibleDisappearance,
      discoveryMode: discoveryMode,
    );
    _lastPolicy = policy;
    return PerceptionResult(
      worldModel: world,
      acceptedObservations: fused.accepted,
      uncertainObservations: fused.uncertain,
      transitions: tracking.transitions,
      disappearanceEvidence: disappearance,
      metrics: PerceptionMetrics(
        frameId: frame.frameId,
        nativeInferenceMs: frame.nativeInferenceMs,
        nativeFps: frame.nativeFps,
        analysisUs: analysis.decodeAndEmbeddingUs,
        fusionUs: fusionStopwatch.elapsedMicroseconds,
        trackingUs: trackingStopwatch.elapsedMicroseconds,
        detectorProposalCount: proposals.length,
        openSetProposalCount: analysis.candidates
            .where((candidate) => candidate.detectorConfidence == 0)
            .length,
        acceptedObservationCount: fused.accepted.length,
        uncertainObservationCount: fused.uncertain.length,
        droppedFrames: _droppedFrames,
        targetInferenceFps: policy.targetFps,
        sourceWidth: analysis.sourceWidth,
        sourceHeight: analysis.sourceHeight,
        schedulerReason: policy.reason,
      ),
      trace: PerceptionTrace(
        analysis: analysis,
        associations: tracking.associations,
        occludedTrackIds: occludedTrackIds,
      ),
    );
  }

  @override
  void markCollected(int trackId, DateTime timestamp) {
    _tracker.markCollected(trackId, timestamp);
  }

  @override
  void recordDroppedFrame() => _droppedFrames += 1;

  @override
  void updateDeviceHealth(DeviceHealth health) => _deviceHealth = health;

  @override
  void reset() {
    _fusion.reset();
    _tracker.reset();
    _sceneStability.reset();
    _lastPolicy = const InferencePolicy(
      targetFps: 8,
      runOpenSetProposals: true,
      reason: 'initial_scan',
    );
    _droppedFrames = 0;
  }
}
