import 'dart:math' as math;

import '../../core/math/vector_math.dart';
import '../../domain/cleanup/cleanup_session.dart';
import '../../domain/scene/room_snapshot.dart';
import '../../domain/scene/room_world_model.dart';

enum CompletionConfidence { insufficient, probable, strong }

enum RoomCleanDecision {
  keepChecking,
  toyFound,
  clean,
}

class RoomCleanPolicy {
  const RoomCleanPolicy({
    this.minimumCleanDuration = const Duration(seconds: 2),
    this.minimumCleanFrames = 5,
    this.minimumViewpoints = 2,
    this.minimumCameraMotion = 0.08,
    this.viewpointSimilarityThreshold = 0.92,
  });

  final Duration minimumCleanDuration;
  final int minimumCleanFrames;
  final int minimumViewpoints;
  final double minimumCameraMotion;
  final double viewpointSimilarityThreshold;
}

class CompletionEvidence {
  CompletionEvidence({
    required this.confidence,
    required this.collectedRatio,
    required this.remainingStableToys,
    required this.sceneCoverage,
    required this.uncertainTracks,
    required List<String> blockingReasons,
  }) : blockingReasons = List<String>.unmodifiable(blockingReasons);

  final CompletionConfidence confidence;
  final double collectedRatio;
  final int remainingStableToys;
  final double sceneCoverage;
  final int uncertainTracks;
  final List<String> blockingReasons;
}

class RoomCleanEvaluation {
  const RoomCleanEvaluation({
    required this.decision,
    required this.evidence,
    required this.verifying,
    required this.verificationStarted,
  });

  final RoomCleanDecision decision;
  final CompletionEvidence evidence;
  final bool verifying;
  final bool verificationStarted;
}

abstract interface class RoomCleanVerifier {
  RoomCleanEvaluation evaluate({
    required RoomSnapshot snapshot,
    required RoomWorldModel world,
    required CleanupSession session,
    required int uncertainTracks,
  });

  void reset();
}

/// Verifies room cleanliness across time and more than one camera viewpoint.
///
/// The verifier only returns evidence and a decision. It cannot mutate the
/// cleanup session or publish completion events.
class EvidenceBasedRoomCleanVerifier implements RoomCleanVerifier {
  EvidenceBasedRoomCleanVerifier({
    this.policy = const RoomCleanPolicy(),
  });

  final RoomCleanPolicy policy;

  DateTime? _verificationStartedAt;
  DateTime? _cleanWindowStartedAt;
  List<double>? _previousSceneEmbedding;
  final List<List<double>> _viewpoints = [];
  double _cameraMotion = 0;
  int _cleanFrames = 0;

  @override
  RoomCleanEvaluation evaluate({
    required RoomSnapshot snapshot,
    required RoomWorldModel world,
    required CleanupSession session,
    required int uncertainTracks,
  }) {
    final total = snapshot.toys.length;
    final initialIds = snapshot.toys.map((toy) => toy.trackId).toSet();
    final remainingStable = world.activeTracks.values
        .where(
          (track) =>
              track.isStable && !session.collectedTrackIds.contains(track.id),
        )
        .length;
    final unresolved = world.missingTracks.values.where(
      (track) =>
          initialIds.contains(track.id) &&
          !session.collectedTrackIds.contains(track.id),
    );
    final ratio = total == 0 ? 0.0 : session.confirmedCollected / total;
    final snapshotEstablished = total > 0 &&
        snapshot.confidence >= 0.68 &&
        snapshot.geometry.anchorCount == total &&
        snapshot.toys.every((toy) => toy.confidence >= 0.68);
    final allCollected = total > 0 &&
        session.confirmedCollected == total &&
        initialIds.difference(session.collectedTrackIds).isEmpty;
    final toyPresent = session.remainingEstimate > 0 || remainingStable > 0;
    final wasVerifying = _verificationStartedAt != null;

    if (toyPresent || !allCollected) {
      reset();
      final blockers = <String>[
        if (total == 0) 'initial_snapshot_empty',
        if (!snapshotEstablished) 'initial_snapshot_not_established',
        if (session.confirmedCollected == 0) 'no_verified_progress',
        if (!allCollected) 'not_all_snapshot_toys_collected',
        if (remainingStable > 0) 'confirmed_toys_still_visible',
        if (unresolved.isNotEmpty) 'ambiguous_snapshot_tracks',
      ];
      return RoomCleanEvaluation(
        decision: wasVerifying && toyPresent
            ? RoomCleanDecision.toyFound
            : RoomCleanDecision.keepChecking,
        evidence: CompletionEvidence(
          confidence: snapshotEstablished && ratio >= 0.7
              ? CompletionConfidence.probable
              : CompletionConfidence.insufficient,
          collectedRatio: ratio,
          remainingStableToys: remainingStable,
          sceneCoverage: 0,
          uncertainTracks: uncertainTracks,
          blockingReasons: blockers,
        ),
        verifying: false,
        verificationStarted: false,
      );
    }

    final verificationStarted = _verificationStartedAt == null;
    _verificationStartedAt ??= world.updatedAt;
    _observeViewpoint(world);

    final sceneStable = world.scene.canVerifyDisappearance;
    if (uncertainTracks == 0 && sceneStable) {
      _cleanWindowStartedAt ??= world.updatedAt;
      _cleanFrames += 1;
    } else {
      _cleanWindowStartedAt = null;
      _cleanFrames = 0;
    }

    final viewpointCoverage = policy.minimumViewpoints <= 0
        ? 1.0
        : (_viewpoints.length / policy.minimumViewpoints).clamp(0.0, 1.0);
    final motionCoverage = policy.minimumCameraMotion <= 0
        ? 1.0
        : (_cameraMotion / policy.minimumCameraMotion).clamp(0.0, 1.0);
    final coverage = math.min(viewpointCoverage, motionCoverage);
    final cleanDuration = _cleanWindowStartedAt == null
        ? Duration.zero
        : world.updatedAt.difference(_cleanWindowStartedAt!);
    final cleanWindowComplete = cleanDuration >= policy.minimumCleanDuration &&
        _cleanFrames >= policy.minimumCleanFrames;
    final coverageComplete = _viewpoints.length >= policy.minimumViewpoints &&
        _cameraMotion >= policy.minimumCameraMotion;
    final blockers = <String>[
      if (!snapshotEstablished) 'initial_snapshot_not_established',
      if (session.confirmedCollected == 0) 'no_verified_progress',
      if (!allCollected) 'not_all_snapshot_toys_collected',
      if (remainingStable > 0) 'confirmed_toys_still_visible',
      if (unresolved.isNotEmpty) 'ambiguous_snapshot_tracks',
      if (uncertainTracks > 0) 'ambiguous_toy_candidates',
      if (!sceneStable) 'scene_not_stable',
      if (!coverageComplete) 'room_coverage_incomplete',
      if (!cleanWindowComplete) 'clean_window_incomplete',
    ];
    final clean = blockers.isEmpty;
    return RoomCleanEvaluation(
      decision:
          clean ? RoomCleanDecision.clean : RoomCleanDecision.keepChecking,
      evidence: CompletionEvidence(
        confidence:
            clean ? CompletionConfidence.strong : CompletionConfidence.probable,
        collectedRatio: ratio,
        remainingStableToys: remainingStable,
        sceneCoverage: coverage,
        uncertainTracks: uncertainTracks,
        blockingReasons: blockers,
      ),
      verifying: !clean,
      verificationStarted: verificationStarted,
    );
  }

  void _observeViewpoint(RoomWorldModel world) {
    final embedding = world.scene.embedding;
    final previous = _previousSceneEmbedding;
    if (previous != null) {
      final stepMotion =
          (1 - cosineSimilarity(previous, embedding)).clamp(0, 1);
      if (stepMotion <= 0.65) _cameraMotion += stepMotion;
    }
    _previousSceneEmbedding = embedding;
    if (embedding.isNotEmpty &&
        _viewpoints.every(
          (viewpoint) =>
              cosineSimilarity(viewpoint, embedding) <
              policy.viewpointSimilarityThreshold,
        )) {
      _viewpoints.add(List<double>.from(embedding));
    }
  }

  @override
  void reset() {
    _verificationStartedAt = null;
    _cleanWindowStartedAt = null;
    _previousSceneEmbedding = null;
    _viewpoints.clear();
    _cameraMotion = 0;
    _cleanFrames = 0;
  }
}
