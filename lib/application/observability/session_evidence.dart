import '../../domain/cleanup/cleanup_event.dart';
import '../../domain/cleanup/cleanup_session.dart';
import '../../domain/toy/normalized_box.dart';
import '../../domain/toy/toy_observation.dart';
import '../../domain/toy/toy_track.dart';
import '../../perception/perception_models.dart';
import '../cleanup/room_clean_verifier.dart';

class SessionEvidenceFrame {
  const SessionEvidenceFrame({
    required this.frame,
    required this.perception,
    required this.events,
    required this.session,
    required this.completionEvidence,
  });

  final CameraPerceptionFrame frame;
  final PerceptionResult perception;
  final List<CleanupEvent> events;
  final CleanupSession? session;
  final CompletionEvidence? completionEvidence;
}

abstract interface class PerceptionEvidenceSink {
  Future<void> startSession(DateTime startedAt);
  Future<void> record(SessionEvidenceFrame evidence);
  Future<void> close();
}

class DisabledPerceptionEvidenceSink implements PerceptionEvidenceSink {
  const DisabledPerceptionEvidenceSink();

  @override
  Future<void> startSession(DateTime startedAt) async {}

  @override
  Future<void> record(SessionEvidenceFrame evidence) async {}

  @override
  Future<void> close() async {}
}

Map<String, Object?> sessionEvidenceToJson(
  SessionEvidenceFrame evidence, {
  String? imagePath,
}) {
  final result = evidence.perception;
  final analysis = result.trace.analysis;
  final world = result.worldModel;
  return <String, Object?>{
    'schemaVersion': 1,
    'frameId': evidence.frame.frameId,
    'timestamp': evidence.frame.timestamp.toUtc().toIso8601String(),
    if (imagePath != null) 'imagePath': imagePath,
    'input': {
      'nativeInferenceMs': evidence.frame.nativeInferenceMs,
      'nativeFps': evidence.frame.nativeFps,
      'detectorCoordinatesAreUpright':
          evidence.frame.detectorCoordinatesAreUpright,
      'spatial': {
        'motionAvailable': evidence.frame.spatial.motionAvailable,
        'orientationAvailable': evidence.frame.spatial.orientationAvailable,
        'poseAvailable': evidence.frame.spatial.poseAvailable,
        'depthAvailable': evidence.frame.spatial.depthAvailable,
        'gyroMotion': evidence.frame.spatial.gyroscopeRadPerSecond,
        'linearAcceleration':
            evidence.frame.spatial.linearAccelerationMetersPerSecond2,
        'yawDegrees': evidence.frame.spatial.yawDegrees,
        'pitchDegrees': evidence.frame.spatial.pitchDegrees,
        'rollDegrees': evidence.frame.spatial.rollDegrees,
      },
      'detections': evidence.frame.detectorProposals
          .map(
            (proposal) => {
              'bounds': _box(proposal.bounds),
              'confidence': proposal.confidence,
              'knownClassDiagnostic': proposal.knownClass,
            },
          )
          .toList(growable: false),
    },
    'analysis': {
      'embeddingExtractor': analysis.embeddingExtractorIdentifier,
      'sceneEmbedding': analysis.sceneEmbedding,
      'sharpness': analysis.sharpness,
      'luminance': analysis.luminance,
      'coverage': analysis.coverage,
      'sourceWidth': analysis.sourceWidth,
      'sourceHeight': analysis.sourceHeight,
      'candidates': analysis.candidates
          .map(
            (candidate) => {
              'bounds': _box(candidate.bounds),
              'detectorConfidence': candidate.detectorConfidence,
              'proposalConfidence': candidate.proposalConfidence,
              'embedding': candidate.embedding,
              'source': candidate.source.name,
              'knownClassDiagnostic': candidate.knownClass,
            },
          )
          .toList(growable: false),
      'trackedRegionEmbeddings': {
        for (final entry in analysis.trackedRegionEmbeddings.entries)
          entry.key.toString(): entry.value,
      },
    },
    'fusion': {
      'accepted': result.acceptedObservations.map(_observation).toList(),
      'uncertain': result.uncertainObservations.map(_observation).toList(),
    },
    'tracking': {
      'associations': result.trace.associations
          .map(
            (association) => {
              'trackId': association.trackId,
              'observationIndex': association.observationIndex,
              'score': association.score,
              'iou': association.intersectionOverUnion,
              'centroidSimilarity': association.centroidSimilarity,
              'embeddingCosineSimilarity': association.embeddingSimilarity,
              'sizeSimilarity': association.sizeSimilarity,
            },
          )
          .toList(growable: false),
      'active': world.activeTracks.values.map(_track).toList(),
      'missing': world.missingTracks.values.map(_track).toList(),
      'collected': world.collectedTracks.values.map(_track).toList(),
      'transitions': result.transitions
          .map(
            (transition) => {
              'type': transition.type.name,
              'trackId': transition.trackId,
            },
          )
          .toList(growable: false),
    },
    'scene': {
      'state': world.scene.state.name,
      'similarityToPrevious': world.scene.similarityToPrevious,
      'motion': world.scene.motion,
      'sharpness': world.scene.sharpness,
      'luminance': world.scene.luminance,
      'coverage': world.scene.coverage,
      'occludedTrackIds': result.trace.occludedTrackIds.toList()..sort(),
      'stableFrameCount': world.scene.stableFrameCount,
      'similarityToStableAnchor': world.scene.similarityToStableAnchor,
    },
    'disappearance': result.disappearanceEvidence.values
        .map(
          (item) => {
            'trackId': item.trackId,
            'missingFrames': item.missingFrames,
            'missingDurationMs': item.missingDuration.inMilliseconds,
            'sceneStable': item.sceneStable,
            'sceneSimilarity': item.sceneSimilarity,
            'localSimilarity': item.localSimilarity,
            'regionReobserved': item.regionReobserved,
            'occluded': item.occluded,
            'trackConfirmed': item.trackConfirmed,
            'stableObservation': item.stableObservation,
            'stableSceneWindow': item.stableSceneWindow,
            'interactionObserved': item.interactionObserved,
            'directPickupEvidence': item.directPickupEvidence,
            'returnToAnchorPickupEvidence': item.returnToAnchorPickupEvidence,
            'reidentificationCandidate': item.reidentificationCandidate,
            'deviceMotion': item.deviceMotion,
            'backgroundRevealScore': item.backgroundRevealScore,
            'depthChangeScore': item.depthChangeScore,
            'cameraTrackingGood': item.cameraTrackingGood,
            'corroboratingSignalCount': item.corroboratingSignalCount,
            'rejectionReasons': item.rejectionReasons,
            'confidence': item.confidence,
            'confirmed': item.confirmed,
          },
        )
        .toList(growable: false),
    'domain': {
      'events': evidence.events.map(_event).toList(growable: false),
      'session': evidence.session == null
          ? null
          : {
              'id': evidence.session!.id,
              'status': evidence.session!.status.name,
              'initialToyCount': evidence.session!.initialSnapshot.toys.length,
              'confirmedCollected': evidence.session!.confirmedCollected,
              'collectedTrackIds': evidence.session!.collectedTrackIds.toList()
                ..sort(),
            },
      'completion': evidence.completionEvidence == null
          ? null
          : {
              'confidence': evidence.completionEvidence!.confidence.name,
              'collectedRatio': evidence.completionEvidence!.collectedRatio,
              'remainingStableToys':
                  evidence.completionEvidence!.remainingStableToys,
              'uncertainTracks': evidence.completionEvidence!.uncertainTracks,
              'sceneCoverage': evidence.completionEvidence!.sceneCoverage,
              'blockingReasons': evidence.completionEvidence!.blockingReasons,
              'cleanDecision': evidence.completionEvidence!.cleanDecision.name,
              'verificationStage':
                  evidence.completionEvidence!.verificationStage.name,
              'guidance': evidence.completionEvidence!.guidance,
              'coverageSectors': evidence.completionEvidence!.coverageSectors,
              'confirmedToyCount':
                  evidence.completionEvidence!.confirmedToyCount,
              'candidateToyCount':
                  evidence.completionEvidence!.candidateToyCount,
              'noToyDurationMs':
                  evidence.completionEvidence!.noToyDuration.inMilliseconds,
              'cameraTrackingGood':
                  evidence.completionEvidence!.cameraTrackingGood,
              'depthConsistency': evidence.completionEvidence!.depthConsistency,
            },
    },
    'latency': {
      'nativeInferenceMs': result.metrics.nativeInferenceMs,
      'analysisUs': result.metrics.analysisUs,
      'fusionUs': result.metrics.fusionUs,
      'trackingUs': result.metrics.trackingUs,
      'nativeFps': result.metrics.nativeFps,
      'droppedFrames': result.metrics.droppedFrames,
      'targetInferenceFps': result.metrics.targetInferenceFps,
      'schedulerReason': result.metrics.schedulerReason,
    },
  };
}

Map<String, Object?> _box(NormalizedBox box) => {
      'x': box.x,
      'y': box.y,
      'width': box.width,
      'height': box.height,
    };

Map<String, Object?> _observation(ToyObservation observation) => {
      'bounds': _box(observation.bounds),
      'detectionConfidence': observation.detectionConfidence,
      'proposalConfidence': observation.proposalConfidence,
      'prototypeCosineSimilarity': observation.embeddingSimilarity,
      'temporalPersistence': observation.temporalPersistence,
      'spatialStability': observation.spatialStability,
      'sceneContextScore': observation.sceneContextScore,
      'toyProbability': observation.toyProbability,
      'stage': observation.stage.name,
      'confirmationBlockers': observation.confirmationBlockers,
      'embedding': observation.embedding,
      'source': observation.source.name,
      'knownClassDiagnostic': observation.knownClass,
    };

Map<String, Object?> _track(ToyTrack track) => {
      'trackId': track.id,
      'bounds': _box(track.lastBounds),
      'initialBounds': _box(track.initialBounds),
      'embedding': track.visualEmbedding,
      'visibleFrames': track.visibleFrames,
      'missingFrames': track.missingFrames,
      'confidence': track.confidence,
      'confirmedToy': track.confirmedToy,
      'confirmedAt': track.confirmedAt?.toUtc().toIso8601String(),
      'interactionEvidence': track.interactionEvidence,
      'lastInteractionAt': track.lastInteractionAt?.toUtc().toIso8601String(),
      'lostDuringCameraMotion': track.lostDuringCameraMotion,
      'cameraMotionAtLoss': track.cameraMotionAtLoss,
      'presence': track.presence.name,
      'gameStatus': track.status.name,
      'firstSeenAt': track.firstSeenAt.toUtc().toIso8601String(),
      'lastSeenAt': track.lastSeenAt.toUtc().toIso8601String(),
      'missingSince': track.missingSince?.toUtc().toIso8601String(),
      'collectedAt': track.collectedAt?.toUtc().toIso8601String(),
      'source': track.source.name,
      'knownClassDiagnostic': track.knownClass,
    };

Map<String, Object?> _event(CleanupEvent event) => switch (event) {
      CleanupStarted() => {'type': 'cleanupStarted'},
      ActiveToyChanged(:final trackId) => {
          'type': 'activeToyChanged',
          'trackId': trackId,
        },
      ToyObserved(:final trackId) => {
          'type': 'toyObserved',
          'trackId': trackId,
        },
      ToyTrackCreated(:final trackId) => {
          'type': 'toyTrackCreated',
          'trackId': trackId,
        },
      ToyTemporarilyMissing(:final trackId) => {
          'type': 'toyTemporarilyMissing',
          'trackId': trackId,
        },
      ToyReappeared(:final trackId) => {
          'type': 'toyReappeared',
          'trackId': trackId,
        },
      NewToyDiscovered(:final trackId) => {
          'type': 'newToyDiscovered',
          'trackId': trackId,
        },
      ToyCollected(:final trackId) => {
          'type': 'toyCollected',
          'trackId': trackId,
        },
      CleanupProgressChanged(:final collected, :final remainingEstimate) => {
          'type': 'cleanupProgressChanged',
          'collected': collected,
          'remainingEstimate': remainingEstimate,
        },
      RoomAlmostClean() => {'type': 'roomAlmostClean'},
      EmptyRoomVerificationStarted() => {
          'type': 'emptyRoomVerificationStarted',
        },
      RoomCleanConfirmed() => {'type': 'roomCleanConfirmed'},
      CleanupCompleted(:final collected) => {
          'type': 'cleanupCompleted',
          'collected': collected,
        },
      PerceptionUncertain(:final reason) => {
          'type': 'perceptionUncertain',
          'reason': reason,
        },
    };
