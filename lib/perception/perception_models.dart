import 'dart:typed_data';

import '../domain/scene/room_world_model.dart';
import '../domain/scene/spatial_observation.dart';
import '../domain/toy/normalized_box.dart';
import '../domain/toy/toy_observation.dart';
import 'tracking/track_associator.dart';

class DetectorProposal {
  const DetectorProposal({
    required this.bounds,
    required this.confidence,
    this.knownClass,
  });

  final NormalizedBox bounds;
  final double confidence;
  final String? knownClass;
}

class CameraPerceptionFrame {
  CameraPerceptionFrame({
    required this.frameId,
    required this.timestamp,
    required Uint8List encodedImage,
    required List<DetectorProposal> detectorProposals,
    required this.nativeInferenceMs,
    required this.nativeFps,
    this.detectorCoordinatesAreUpright = false,
    this.spatial = const SpatialObservation.unavailable(),
  })  : encodedImage = Uint8List.fromList(encodedImage),
        detectorProposals =
            List<DetectorProposal>.unmodifiable(detectorProposals);

  final int frameId;
  final DateTime timestamp;
  final Uint8List encodedImage;
  final List<DetectorProposal> detectorProposals;
  final double nativeInferenceMs;
  final double nativeFps;

  /// Whether detector boxes use the upright camera-preview coordinate space.
  ///
  /// Android's YOLO stream rotates pixels for inference and returns upright
  /// boxes, while `originalImage` remains in landscape sensor orientation.
  /// The visual analyzer uses this marker to align the pixels before crops,
  /// tracking and preview projection consume the boxes.
  final bool detectorCoordinatesAreUpright;
  final SpatialObservation spatial;
}

class VisualCandidate {
  VisualCandidate({
    required this.bounds,
    required this.detectorConfidence,
    required this.proposalConfidence,
    required List<double> embedding,
    required this.source,
    this.knownClass,
  }) : embedding = List<double>.unmodifiable(embedding);

  final NormalizedBox bounds;
  final double detectorConfidence;
  final double proposalConfidence;
  final List<double> embedding;
  final ObservationSource source;
  final String? knownClass;
}

class FrameAnalysis {
  FrameAnalysis({
    required this.embeddingExtractorIdentifier,
    required List<VisualCandidate> candidates,
    required List<double> sceneEmbedding,
    required Map<int, List<double>> trackedRegionEmbeddings,
    required this.sharpness,
    required this.luminance,
    required this.coverage,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.decodeAndEmbeddingUs,
  })  : candidates = List<VisualCandidate>.unmodifiable(candidates),
        sceneEmbedding = List<double>.unmodifiable(sceneEmbedding),
        trackedRegionEmbeddings = Map<int, List<double>>.unmodifiable(
          trackedRegionEmbeddings.map(
            (key, value) => MapEntry(key, List<double>.unmodifiable(value)),
          ),
        );

  final String embeddingExtractorIdentifier;
  final List<VisualCandidate> candidates;
  final List<double> sceneEmbedding;
  final Map<int, List<double>> trackedRegionEmbeddings;
  final double sharpness;
  final double luminance;
  final double coverage;
  final int sourceWidth;
  final int sourceHeight;
  final int decodeAndEmbeddingUs;

  bool get isObscured => luminance < 0.025 || sharpness < 0.001;
}

enum TrackTransitionType { created, observed, temporarilyMissing, reappeared }

class TrackTransition {
  const TrackTransition(this.type, this.trackId);
  final TrackTransitionType type;
  final int trackId;
}

class DisappearanceEvidence {
  DisappearanceEvidence({
    required this.trackId,
    required this.missingFrames,
    required this.missingDuration,
    required this.sceneStable,
    required this.sceneSimilarity,
    required this.localSimilarity,
    required this.regionReobserved,
    required this.occluded,
    required this.trackConfirmed,
    required this.stableObservation,
    required this.stableSceneWindow,
    required this.interactionObserved,
    required this.reidentificationCandidate,
    this.deviceMotion = 0,
    this.backgroundRevealScore = 0,
    this.depthChangeScore,
    this.cameraTrackingGood = true,
    this.corroboratingSignalCount = 0,
    required List<String> rejectionReasons,
    required this.confidence,
    required this.confirmed,
  }) : rejectionReasons = List<String>.unmodifiable(rejectionReasons);

  final int trackId;
  final int missingFrames;
  final Duration missingDuration;
  final bool sceneStable;
  final double sceneSimilarity;
  final double localSimilarity;
  final bool regionReobserved;
  final bool occluded;
  final bool trackConfirmed;
  final bool stableObservation;
  final bool stableSceneWindow;
  final bool interactionObserved;
  final bool reidentificationCandidate;
  final double deviceMotion;
  final double backgroundRevealScore;
  final double? depthChangeScore;
  final bool cameraTrackingGood;
  final int corroboratingSignalCount;
  final List<String> rejectionReasons;
  final double confidence;
  final bool confirmed;
}

class PerceptionMetrics {
  const PerceptionMetrics({
    required this.frameId,
    required this.nativeInferenceMs,
    required this.nativeFps,
    required this.analysisUs,
    required this.fusionUs,
    required this.trackingUs,
    required this.detectorProposalCount,
    required this.openSetProposalCount,
    required this.acceptedObservationCount,
    required this.uncertainObservationCount,
    required this.droppedFrames,
    required this.targetInferenceFps,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.schedulerReason,
  });

  final int frameId;
  final double nativeInferenceMs;
  final double nativeFps;
  final int analysisUs;
  final int fusionUs;
  final int trackingUs;
  final int detectorProposalCount;
  final int openSetProposalCount;
  final int acceptedObservationCount;
  final int uncertainObservationCount;
  final int droppedFrames;
  final int targetInferenceFps;
  final int sourceWidth;
  final int sourceHeight;
  final String schedulerReason;
}

class PerceptionTrace {
  PerceptionTrace({
    required this.analysis,
    required List<TrackAssociation> associations,
    required Set<int> occludedTrackIds,
  })  : associations = List<TrackAssociation>.unmodifiable(associations),
        occludedTrackIds = Set<int>.unmodifiable(occludedTrackIds);

  final FrameAnalysis analysis;
  final List<TrackAssociation> associations;
  final Set<int> occludedTrackIds;
}

class PerceptionResult {
  PerceptionResult({
    required this.worldModel,
    required List<ToyObservation> acceptedObservations,
    required List<ToyObservation> uncertainObservations,
    required List<TrackTransition> transitions,
    required Map<int, DisappearanceEvidence> disappearanceEvidence,
    required this.metrics,
    required this.trace,
  })  : acceptedObservations =
            List<ToyObservation>.unmodifiable(acceptedObservations),
        uncertainObservations =
            List<ToyObservation>.unmodifiable(uncertainObservations),
        transitions = List<TrackTransition>.unmodifiable(transitions),
        disappearanceEvidence = Map<int, DisappearanceEvidence>.unmodifiable(
          disappearanceEvidence,
        );

  final RoomWorldModel worldModel;
  final List<ToyObservation> acceptedObservations;
  final List<ToyObservation> uncertainObservations;
  final List<TrackTransition> transitions;
  final Map<int, DisappearanceEvidence> disappearanceEvidence;
  final PerceptionMetrics metrics;
  final PerceptionTrace trace;
}
