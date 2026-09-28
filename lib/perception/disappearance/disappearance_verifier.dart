import '../../core/math/vector_math.dart';
import '../../domain/scene/scene_descriptor.dart';
import '../../domain/toy/toy_track.dart';
import '../perception_models.dart';

enum RemovalDecision {
  keepTracking,
  temporarilyLost,
  removalConfirmed,
}

class RemovalEvaluation {
  const RemovalEvaluation({
    required this.decision,
    required this.evidence,
  });

  final RemovalDecision decision;
  final DisappearanceEvidence evidence;
}

abstract interface class ToyRemovalVerifier {
  RemovalEvaluation evaluate({
    required ToyTrack track,
    required SceneDescriptor scene,
    required List<double>? currentRegionEmbedding,
    required bool occluded,
    required bool reidentificationCandidate,
    required DateTime timestamp,
  });
}

class DisappearanceVerifier implements ToyRemovalVerifier {
  const DisappearanceVerifier({
    this.minimumMissingFrames = 8,
    this.minimumMissingDuration = const Duration(milliseconds: 1500),
    this.minimumObservedDuration = const Duration(seconds: 2),
    this.interactionWindow = const Duration(seconds: 5),
    this.confirmationThreshold = 0.82,
  });

  final int minimumMissingFrames;
  final Duration minimumMissingDuration;
  final Duration minimumObservedDuration;
  final Duration interactionWindow;
  final double confirmationThreshold;

  @override
  RemovalEvaluation evaluate({
    required ToyTrack track,
    required SceneDescriptor scene,
    required List<double>? currentRegionEmbedding,
    required bool occluded,
    required bool reidentificationCandidate,
    required DateTime timestamp,
  }) {
    final missingSince = track.missingSince ?? timestamp;
    final duration = timestamp.difference(missingSince);
    final rawLocalSimilarity = currentRegionEmbedding == null
        ? 1.0
        : cosineSimilarity(track.visualEmbedding, currentRegionEmbedding);
    final localSimilarity = rawLocalSimilarity.clamp(0.0, 1.0);
    final regionReobserved = scene.canVerifyDisappearance &&
        scene.similarityToPrevious >= 0.94 &&
        scene.similarityToStableAnchor >= 0.90 &&
        currentRegionEmbedding != null;
    final observedSince = track.confirmedAt ?? track.firstSeenAt;
    final stableObservation = track.visibleFrames >= 8 &&
        track.lastSeenAt.difference(observedSince) >= minimumObservedDuration;
    final stableSceneWindow = scene.canVerifyDisappearance &&
        scene.motion <= 0.06 &&
        scene.similarityToPrevious >= 0.94 &&
        scene.similarityToStableAnchor >= 0.90;
    final lastInteraction = track.lastInteractionAt;
    // Interaction belongs to a disappearance episode. Once the track has
    // vanished, compare the interaction with that onset rather than with the
    // ever-advancing current time; otherwise valid evidence expires while the
    // stable-scene/local-region gates are still being accumulated.
    final disappearanceStartedAt = track.missingSince ?? timestamp;
    final interactionLead = lastInteraction == null
        ? null
        : disappearanceStartedAt.difference(lastInteraction);
    final interactionObserved = interactionLead != null &&
        !interactionLead.isNegative &&
        interactionLead <= interactionWindow;
    final missingEvidence = (track.missingFrames / 8).clamp(0.0, 1.0);
    final durationEvidence = (duration.inMilliseconds / 2000).clamp(0.0, 1.0);
    final localChangeEvidence =
        ((0.95 - localSimilarity) / 0.20).clamp(0.0, 1.0);
    final interactionStrength =
        (track.interactionEvidence / 0.25).clamp(0.0, 1.0);
    final confidence = ((track.confirmedToy ? 0.10 : 0) +
            (stableObservation ? 0.10 : 0) +
            missingEvidence * 0.15 +
            durationEvidence * 0.10 +
            (stableSceneWindow ? 0.15 : 0) +
            (regionReobserved ? 0.10 : 0) +
            localChangeEvidence * 0.15 +
            interactionStrength * 0.15)
        .clamp(0.0, 1.0);
    final rejectionReasons = <String>[
      if (!track.confirmedToy) 'track_not_confirmed_toy',
      if (!stableObservation) 'observation_history_insufficient',
      if (!stableSceneWindow) 'scene_not_stable_long_enough',
      if (!regionReobserved) 'original_region_not_reobserved',
      if (track.missingFrames < minimumMissingFrames)
        'missing_window_incomplete',
      if (duration < minimumMissingDuration) 'missing_duration_incomplete',
      if (localSimilarity > 0.90) 'object_or_similar_visual_still_present',
      if (occluded) 'occlusion_possible',
      if (reidentificationCandidate) 'possible_reidentification',
      if (!interactionObserved) 'physical_interaction_not_observed',
      if (confidence < confirmationThreshold) 'confidence_below_safety_gate',
    ];
    final confirmed = rejectionReasons.isEmpty;
    final evidence = DisappearanceEvidence(
      trackId: track.id,
      missingFrames: track.missingFrames,
      missingDuration: duration,
      sceneStable: scene.canVerifyDisappearance,
      sceneSimilarity: scene.similarityToPrevious,
      localSimilarity: localSimilarity,
      regionReobserved: regionReobserved,
      occluded: occluded,
      trackConfirmed: track.confirmedToy,
      stableObservation: stableObservation,
      stableSceneWindow: stableSceneWindow,
      interactionObserved: interactionObserved,
      reidentificationCandidate: reidentificationCandidate,
      rejectionReasons: rejectionReasons,
      confidence: confidence,
      confirmed: confirmed,
    );
    return RemovalEvaluation(
      decision: confirmed
          ? RemovalDecision.removalConfirmed
          : track.missingFrames > 0
              ? RemovalDecision.temporarilyLost
              : RemovalDecision.keepTracking,
      evidence: evidence,
    );
  }
}
