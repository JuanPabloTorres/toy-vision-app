import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/domain/scene/scene_descriptor.dart';
import 'package:toyvision_realtime/domain/scene/scene_state.dart';
import 'package:toyvision_realtime/domain/scene/spatial_observation.dart';
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/domain/toy/toy_observation.dart';
import 'package:toyvision_realtime/domain/toy/toy_track.dart';
import 'package:toyvision_realtime/perception/disappearance/disappearance_verifier.dart';
import 'package:toyvision_realtime/perception/fusion/sensor_fusion_engine.dart';
import 'package:toyvision_realtime/perception/tracking/reidentification_candidate_policy.dart';
import 'package:toyvision_realtime/perception/tracking/toy_tracker.dart';

void main() {
  test('track game status preserves loss, verification and collection', () {
    final now = DateTime.utc(2026);
    final visible = _missingTrack(now).copyWith(
      presence: TrackPresence.visible,
      missingFrames: 0,
      clearMissingSince: true,
    );
    final lost = visible.copyWith(presence: TrackPresence.occluded);
    final verifying = visible.copyWith(
      presence: TrackPresence.missingCandidate,
      missingFrames: 1,
      missingSince: now,
    );
    final collected = verifying.copyWith(presence: TrackPresence.collected);

    expect(visible.status, ToyTrackStatus.visible);
    expect(lost.status, ToyTrackStatus.temporarilyLost);
    expect(verifying.status, ToyTrackStatus.verifyingRemoval);
    expect(collected.status, ToyTrackStatus.collected);
  });

  test('embedding-aware association keeps identities when order changes', () {
    final tracker = ToyTracker();
    final start = DateTime.utc(2026);
    tracker.update(
      [
        _observation(start, const [1, 0], 0.1),
        _observation(start, const [0, 1], 0.65),
      ],
      start,
      SceneState.stable,
    );
    final update = tracker.update(
      [
        _observation(start, const [0, 1], 0.60),
        _observation(start, const [1, 0], 0.15),
      ],
      start.add(const Duration(milliseconds: 200)),
      SceneState.stable,
    );
    expect(update.tracks, hasLength(2));
    expect(update.tracks.first.lastBounds.x, closeTo(0.15, 1e-9));
    expect(update.tracks.last.lastBounds.x, closeTo(0.60, 1e-9));
  });

  test('remote open-set region cannot hijack a detector identity', () {
    final tracker = ToyTracker();
    final start = DateTime.utc(2026);
    tracker.update(
      [_typedObservation(start, 0.2, ObservationSource.detector, true)],
      start,
      SceneState.stable,
    );

    final update = tracker.update(
      [
        _typedObservation(
          start.add(const Duration(milliseconds: 200)),
          0.62,
          ObservationSource.openSetProposal,
          false,
        ),
      ],
      start.add(const Duration(milliseconds: 200)),
      SceneState.stable,
    );

    expect(update.associations, isEmpty);
    expect(update.tracks.single.lastBounds.x, 0.2);
    expect(update.tracks.single.presence, TrackPresence.missingCandidate);
  });

  test('open-set fallback cannot keep a detector identity alive', () {
    final tracker = ToyTracker();
    final start = DateTime.utc(2026);
    tracker.update(
      [_typedObservation(start, 0.2, ObservationSource.detector, true)],
      start,
      SceneState.stable,
    );

    final update = tracker.update(
      [
        _typedObservation(
          start.add(const Duration(milliseconds: 200)),
          0.21,
          ObservationSource.openSetProposal,
          false,
        ),
      ],
      start.add(const Duration(milliseconds: 200)),
      SceneState.stable,
    );

    expect(update.associations, isEmpty);
    expect(update.tracks.single.lastBounds.x, 0.2);
    expect(update.tracks.single.source, ObservationSource.detector);
    expect(update.tracks.single.presence, TrackPresence.missingCandidate);
  });

  test('subthreshold detector jitter cannot become interaction evidence', () {
    final tracker = ToyTracker();
    final start = DateTime.utc(2026);
    tracker.update(
      [_typedObservation(start, 0.2, ObservationSource.detector, true)],
      start,
      SceneState.stable,
    );

    tracker.update(
      [
        _typedObservation(
          start.add(const Duration(milliseconds: 200)),
          0.22,
          ObservationSource.detector,
          false,
        ),
      ],
      start.add(const Duration(milliseconds: 200)),
      SceneState.stable,
    );

    expect(tracker.tracks.single.lastInteractionAt, isNull);
    expect(tracker.tracks.single.interactionEvidence, lessThan(.12));
  });

  test('stable object movement records physical interaction evidence', () {
    final tracker = ToyTracker();
    final start = DateTime.utc(2026);
    tracker.update(
      [_typedObservation(start, 0.2, ObservationSource.detector, true)],
      start,
      SceneState.stable,
    );
    final movedAt = start.add(const Duration(milliseconds: 200));

    tracker.update(
      [
        _typedObservation(
          movedAt,
          0.32,
          ObservationSource.detector,
          true,
        ),
      ],
      movedAt,
      SceneState.stable,
    );

    expect(tracker.tracks.single.lastInteractionAt, movedAt);
    expect(
      tracker.tracks.single.interactionEvidence,
      greaterThanOrEqualTo(.12),
    );
  });

  test('camera movement cannot become physical interaction evidence', () {
    final tracker = ToyTracker();
    final start = DateTime.utc(2026);
    tracker.update(
      [_typedObservation(start, 0.2, ObservationSource.detector, true)],
      start,
      SceneState.stable,
    );
    final movedAt = start.add(const Duration(milliseconds: 200));

    tracker.update(
      [
        _typedObservation(
          movedAt,
          0.32,
          ObservationSource.detector,
          true,
        ),
      ],
      movedAt,
      SceneState.moving,
    );

    expect(tracker.tracks.single.lastInteractionAt, isNull);
    expect(tracker.tracks.single.interactionEvidence, lessThan(.12));
  });

  test('camera occlusion does not accumulate a disappearance window', () {
    final tracker = ToyTracker();
    final start = DateTime.utc(2026);
    tracker.update(
      [_typedObservation(start, 0.2, ObservationSource.detector, true)],
      start,
      SceneState.stable,
    );

    final movingAt = start.add(const Duration(milliseconds: 200));
    tracker.update(const [], movingAt, SceneState.moving);
    var track = tracker.tracks.single;
    expect(track.presence, TrackPresence.occluded);
    expect(track.missingFrames, 0);
    expect(track.missingSince, isNull);
    expect(track.lostDuringCameraMotion, isTrue);

    final stableAt = start.add(const Duration(milliseconds: 400));
    tracker.update(const [], stableAt, SceneState.stable);
    track = tracker.tracks.single;
    expect(track.presence, TrackPresence.missingCandidate);
    expect(track.missingFrames, 1);
    expect(track.missingSince, stableAt);
    expect(track.lostDuringCameraMotion, isTrue);
  });

  test('confirmed identity template cannot drift across later crops', () {
    final tracker = ToyTracker();
    final start = DateTime.utc(2026);
    tracker.update(
      [
        _observation(start, const [1, 0], 0.2),
      ],
      start,
      SceneState.stable,
    );

    tracker.update(
      [
        _observation(
          start.add(const Duration(milliseconds: 200)),
          const [0, 1],
          0.2,
        ),
      ],
      start.add(const Duration(milliseconds: 200)),
      SceneState.stable,
    );

    expect(tracker.tracks.single.visualEmbedding, const [1, 0]);
  });

  test('progressive scale drift cannot hijack a confirmed identity', () {
    final tracker = ToyTracker();
    final start = DateTime.utc(2026);
    tracker.update(
      [_sizedObservation(start, 0.20, confirmed: true)],
      start,
      SceneState.stable,
    );

    for (var index = 1; index <= 8; index++) {
      final size = 0.20 * (1 - index * 0.085);
      tracker.update(
        [
          _sizedObservation(
            start.add(Duration(milliseconds: index * 200)),
            size,
            confirmed: false,
          ),
        ],
        start.add(Duration(milliseconds: index * 200)),
        SceneState.stable,
      );
    }

    final identity = tracker.tracks.first;
    expect(
      identity.initialBounds.sizeSimilarity(identity.lastBounds),
      greaterThanOrEqualTo(0.30),
    );
    expect(identity.visualEmbedding, const [1, 0]);
  });

  test('camera motion and occlusion block disappearance confirmation', () {
    const verifier = DisappearanceVerifier(
      minimumMissingFrames: 3,
      minimumMissingDuration: Duration(milliseconds: 600),
      confirmationThreshold: 0.6,
    );
    final now = DateTime.utc(2026);
    final track = _missingTrack(now);
    final moving = verifier
        .evaluate(
          track: track,
          scene: _scene(now, SceneState.moving, similarity: 0.95),
          currentRegionEmbedding: const [0, 1],
          occluded: false,
          reidentificationCandidate: false,
          timestamp: now,
        )
        .evidence;
    final occluded = verifier
        .evaluate(
          track: track,
          scene: _scene(now, SceneState.stable, similarity: 0.95),
          currentRegionEmbedding: const [0, 1],
          occluded: true,
          reidentificationCandidate: false,
          timestamp: now,
        )
        .evidence;
    expect(moving.confirmed, isFalse);
    expect(occluded.confirmed, isFalse);
  });

  test('stable reobservation with changed local appearance confirms removal',
      () {
    const verifier = DisappearanceVerifier(
      minimumMissingFrames: 3,
      minimumMissingDuration: Duration(milliseconds: 600),
      confirmationThreshold: 0.6,
    );
    final now = DateTime.utc(2026);
    final evidence = verifier
        .evaluate(
          track: _missingTrack(now),
          scene: _scene(now, SceneState.stable, similarity: 0.96),
          currentRegionEmbedding: const [0, 1],
          occluded: false,
          reidentificationCandidate: false,
          timestamp: now,
        )
        .evidence;
    expect(evidence.regionReobserved, isTrue);
    expect(evidence.confirmed, isTrue);
    expect(
      verifier
          .evaluate(
            track: _missingTrack(now),
            scene: _scene(now, SceneState.stable, similarity: 0.96),
            currentRegionEmbedding: const [0, 1],
            occluded: false,
            reidentificationCandidate: false,
            timestamp: now,
          )
          .decision,
      RemovalDecision.removalConfirmed,
    );
  });

  test('absence without observed interaction remains unknown', () {
    final now = DateTime.utc(2026);
    final evidence = const DisappearanceVerifier(
      minimumMissingFrames: 3,
      minimumMissingDuration: Duration(milliseconds: 600),
      confirmationThreshold: 0.6,
    )
        .evaluate(
          track: _missingTrack(now, interaction: false),
          scene: _scene(now, SceneState.stable, similarity: 0.96),
          currentRegionEmbedding: const [0, 1],
          occluded: false,
          reidentificationCandidate: false,
          timestamp: now,
        )
        .evidence;

    expect(evidence.confirmed, isFalse);
    expect(
      evidence.rejectionReasons,
      contains('physical_interaction_not_observed'),
    );
  });

  test('pickup between frames uses stable revealed background evidence', () {
    final now = DateTime.utc(2026);
    final scene = _scene(
      now,
      SceneState.stable,
      similarity: 0.99,
      spatial: SpatialObservation(
        timestamp: now,
        motionAvailable: true,
        orientationAvailable: true,
        gyroscopeRadPerSecond: 0.01,
        linearAccelerationMetersPerSecond2: 0.01,
        yawDegrees: 0,
        pitchDegrees: 0,
      ),
    );
    final track = _missingTrackAt(
      now,
      missingSince: now.subtract(const Duration(seconds: 2)),
      missingFrames: 10,
      interaction: false,
    );
    final fusion = const SensorFusionEngine().evaluateRemoval(
      track: track,
      scene: scene,
      currentRegionEmbedding: const [0, 1],
      spatial: scene.spatial,
    );

    final evaluation = const DisappearanceVerifier().evaluate(
      track: track,
      scene: scene,
      currentRegionEmbedding: const [0, 1],
      occluded: false,
      reidentificationCandidate: false,
      timestamp: now,
      fusionEvidence: fusion,
    );

    expect(evaluation.decision, RemovalDecision.removalConfirmed);
    expect(evaluation.evidence.interactionObserved, isFalse);
    expect(evaluation.evidence.directPickupEvidence, isTrue);
  });

  test('camera-caused loss cannot use direct pickup evidence later', () {
    final now = DateTime.utc(2026);
    final scene = _scene(
      now,
      SceneState.stable,
      similarity: 0.99,
      spatial: SpatialObservation(
        timestamp: now,
        motionAvailable: true,
        orientationAvailable: true,
        gyroscopeRadPerSecond: 0.01,
        linearAccelerationMetersPerSecond2: 0.01,
        yawDegrees: 0,
        pitchDegrees: 0,
      ),
    );
    final track = _missingTrackAt(
      now,
      missingSince: now.subtract(const Duration(seconds: 2)),
      missingFrames: 10,
      interaction: false,
    ).copyWith(lostDuringCameraMotion: true);
    final fusion = const SensorFusionEngine().evaluateRemoval(
      track: track,
      scene: scene,
      currentRegionEmbedding: const [0, 1],
      spatial: scene.spatial,
    );

    final evidence = const DisappearanceVerifier()
        .evaluate(
          track: track,
          scene: scene,
          currentRegionEmbedding: const [0, 1],
          occluded: false,
          reidentificationCandidate: false,
          timestamp: now,
          fusionEvidence: fusion,
        )
        .evidence;

    expect(evidence.confirmed, isFalse);
    expect(evidence.directPickupEvidence, isFalse);
    expect(
      evidence.rejectionReasons,
      contains('physical_interaction_not_observed'),
    );
  });

  test('pickup interaction stays attached to its disappearance episode', () {
    final now = DateTime.utc(2026);
    final missingSince = now.subtract(const Duration(seconds: 20));
    final track = _missingTrackAt(
      now,
      missingSince: missingSince,
      missingFrames: 40,
    ).copyWith(
      lastInteractionAt:
          missingSince.subtract(const Duration(milliseconds: 250)),
    );

    final evidence = const DisappearanceVerifier(
      minimumMissingFrames: 3,
      minimumMissingDuration: Duration(milliseconds: 600),
      confirmationThreshold: 0.6,
    )
        .evaluate(
          track: track,
          scene: _scene(now, SceneState.stable, similarity: 0.96),
          currentRegionEmbedding: const [0, 1],
          occluded: false,
          reidentificationCandidate: false,
          timestamp: now,
        )
        .evidence;

    expect(evidence.interactionObserved, isTrue);
    expect(evidence.confirmed, isTrue);
  });

  test('interaction stale before disappearance remains rejected', () {
    final now = DateTime.utc(2026);
    final missingSince = now.subtract(const Duration(seconds: 3));
    final track = _missingTrackAt(
      now,
      missingSince: missingSince,
      missingFrames: 20,
    ).copyWith(
      lastInteractionAt: missingSince.subtract(const Duration(seconds: 6)),
    );

    final evidence = const DisappearanceVerifier(
      minimumMissingFrames: 3,
      minimumMissingDuration: Duration(milliseconds: 600),
      confirmationThreshold: 0.6,
    )
        .evaluate(
          track: track,
          scene: _scene(now, SceneState.stable, similarity: 0.96),
          currentRegionEmbedding: const [0, 1],
          occluded: false,
          reidentificationCandidate: false,
          timestamp: now,
        )
        .evidence;

    expect(evidence.interactionObserved, isFalse);
    expect(
      evidence.rejectionReasons,
      contains('physical_interaction_not_observed'),
    );
  });

  test('open-set background cannot masquerade as toy reidentification', () {
    const policy = ReidentificationCandidatePolicy();
    final now = DateTime.utc(2026);
    final track = _missingTrack(now);
    final background = _typedObservation(
      now,
      track.lastBounds.x,
      ObservationSource.openSetProposal,
      false,
    );

    expect(
      policy.hasPlausibleCandidate(
        missingTrack: track,
        observations: [background],
      ),
      isFalse,
    );
  });

  test('detector-backed matching observation still blocks collection', () {
    const policy = ReidentificationCandidatePolicy();
    final now = DateTime.utc(2026);
    final track = _missingTrack(now);
    final detectorObservation = _typedObservation(
      now,
      track.lastBounds.x,
      ObservationSource.detector,
      true,
    );

    expect(
      policy.hasPlausibleCandidate(
        missingTrack: track,
        observations: [detectorObservation],
      ),
      isTrue,
    );
  });

  test('possible reidentification blocks collection', () {
    final now = DateTime.utc(2026);
    final evidence = const DisappearanceVerifier(
      minimumMissingFrames: 3,
      minimumMissingDuration: Duration(milliseconds: 600),
      confirmationThreshold: 0.6,
    )
        .evaluate(
          track: _missingTrack(now),
          scene: _scene(now, SceneState.stable, similarity: 0.96),
          currentRegionEmbedding: const [0, 1],
          occluded: false,
          reidentificationCandidate: true,
          timestamp: now,
        )
        .evidence;

    expect(evidence.confirmed, isFalse);
    expect(evidence.rejectionReasons, contains('possible_reidentification'));
  });

  test('default verifier rejects a one-second transient disappearance', () {
    final now = DateTime.utc(2026);
    final evidence = const DisappearanceVerifier()
        .evaluate(
          track: _missingTrackAt(
            now,
            missingSince: now.subtract(const Duration(seconds: 1)),
            missingFrames: 7,
          ),
          scene: _scene(now, SceneState.stable, similarity: 0.96),
          currentRegionEmbedding: const [0, 1],
          occluded: false,
          reidentificationCandidate: false,
          timestamp: now,
        )
        .evidence;

    expect(evidence.confirmed, isFalse);
    expect(evidence.rejectionReasons, contains('missing_duration_incomplete'));
  });

  test('default verifier advances after a sustained physical disappearance',
      () {
    final now = DateTime.utc(2026);
    final missingSince = now.subtract(const Duration(milliseconds: 1600));
    final track = _missingTrackAt(
      now,
      missingSince: missingSince,
      missingFrames: 10,
    ).copyWith(
      lastInteractionAt:
          missingSince.subtract(const Duration(milliseconds: 200)),
    );

    final evidence = const DisappearanceVerifier()
        .evaluate(
          track: track,
          scene: _scene(now, SceneState.stable, similarity: 0.96),
          currentRegionEmbedding: const [0, 1],
          occluded: false,
          reidentificationCandidate: false,
          timestamp: now,
        )
        .evidence;

    expect(evidence.confirmed, isTrue);
  });

  test('IMU motion keeps a missing toy temporarily lost', () {
    final now = DateTime.utc(2026);
    final scene = _scene(
      now,
      SceneState.stable,
      similarity: 0.99,
      spatial: SpatialObservation(
        timestamp: now,
        motionAvailable: true,
        orientationAvailable: true,
        gyroscopeRadPerSecond: 2.4,
        linearAccelerationMetersPerSecond2: 3.2,
        yawDegrees: 70,
        pitchDegrees: 0,
      ),
    );
    final track = _missingTrackAt(
      now,
      missingSince: now.subtract(const Duration(seconds: 2)),
      missingFrames: 10,
    ).copyWith(
      lastInteractionAt: now.subtract(const Duration(milliseconds: 2100)),
    );
    final fusion = const SensorFusionEngine().evaluateRemoval(
      track: track,
      scene: scene,
      currentRegionEmbedding: const [0, 1],
      spatial: scene.spatial,
    );

    final evaluation = const DisappearanceVerifier(
      minimumMissingFrames: 3,
      minimumMissingDuration: Duration(milliseconds: 600),
      confirmationThreshold: 0.6,
    ).evaluate(
      track: track,
      scene: scene,
      currentRegionEmbedding: const [0, 1],
      occluded: false,
      reidentificationCandidate: false,
      timestamp: now,
      fusionEvidence: fusion,
    );

    expect(evaluation.decision, RemovalDecision.temporarilyLost);
    expect(
      evaluation.evidence.rejectionReasons,
      contains('device_motion_too_high'),
    );
  });

  test('stable IMU plus revealed background corroborates pickup', () {
    final now = DateTime.utc(2026);
    final scene = _scene(
      now,
      SceneState.stable,
      similarity: 0.99,
      spatial: SpatialObservation(
        timestamp: now,
        motionAvailable: true,
        orientationAvailable: true,
        gyroscopeRadPerSecond: 0.03,
        linearAccelerationMetersPerSecond2: 0.05,
        yawDegrees: 0,
        pitchDegrees: 0,
      ),
    );
    final track = _missingTrackAt(
      now,
      missingSince: now.subtract(const Duration(seconds: 2)),
      missingFrames: 10,
    ).copyWith(
      lastInteractionAt: now.subtract(const Duration(milliseconds: 2100)),
    );
    final fusion = const SensorFusionEngine().evaluateRemoval(
      track: track,
      scene: scene,
      currentRegionEmbedding: const [0, 1],
      spatial: scene.spatial,
    );

    final evaluation = const DisappearanceVerifier(
      minimumMissingFrames: 3,
      minimumMissingDuration: Duration(milliseconds: 600),
      confirmationThreshold: 0.6,
    ).evaluate(
      track: track,
      scene: scene,
      currentRegionEmbedding: const [0, 1],
      occluded: false,
      reidentificationCandidate: false,
      timestamp: now,
      fusionEvidence: fusion,
    );

    expect(evaluation.decision, RemovalDecision.removalConfirmed);
    expect(evaluation.evidence.backgroundRevealScore, greaterThan(0.9));
    expect(evaluation.evidence.cameraTrackingGood, isTrue);
  });
}

ToyObservation _observation(DateTime at, List<double> embedding, double x) =>
    ToyObservation(
      bounds: NormalizedBox(x: x, y: 0.2, width: 0.2, height: 0.2),
      detectionConfidence: 0.9,
      proposalConfidence: 0.8,
      embeddingSimilarity: 0.8,
      temporalPersistence: 1,
      spatialStability: 1,
      sceneContextScore: 1,
      toyProbability: 0.9,
      stage: ToyEvidenceStage.confirmedToy,
      embedding: embedding,
      frameId: 1,
      timestamp: at,
      source: ObservationSource.fused,
    );

ToyObservation _typedObservation(
  DateTime at,
  double x,
  ObservationSource source,
  bool confirmed,
) =>
    ToyObservation(
      bounds: NormalizedBox(x: x, y: 0.2, width: 0.2, height: 0.2),
      detectionConfidence: source == ObservationSource.detector ? 0.9 : 0,
      proposalConfidence: 0.8,
      embeddingSimilarity: 0.8,
      temporalPersistence: 1,
      spatialStability: 1,
      sceneContextScore: 1,
      toyProbability: 0.9,
      stage: confirmed
          ? ToyEvidenceStage.confirmedToy
          : ToyEvidenceStage.candidate,
      embedding: const [1, 0],
      frameId: 1,
      timestamp: at,
      source: source,
    );

ToyObservation _sizedObservation(
  DateTime at,
  double size, {
  required bool confirmed,
}) =>
    ToyObservation(
      bounds: NormalizedBox(
        x: 0.5 - size / 2,
        y: 0.5 - size / 2,
        width: size,
        height: size,
      ),
      detectionConfidence: confirmed ? 0.9 : 0.55,
      proposalConfidence: 0,
      embeddingSimilarity: 0.9,
      temporalPersistence: 1,
      spatialStability: 1,
      sceneContextScore: 1,
      toyProbability: confirmed ? 0.9 : 0.6,
      stage: confirmed
          ? ToyEvidenceStage.confirmedToy
          : ToyEvidenceStage.candidate,
      embedding: const [1, 0],
      frameId: 1,
      timestamp: at,
      source: ObservationSource.detector,
    );

ToyTrack _missingTrack(DateTime now, {bool interaction = true}) => ToyTrack(
      id: 7,
      lastBounds: const NormalizedBox(x: 0.2, y: 0.2, width: 0.2, height: 0.2),
      initialBounds:
          const NormalizedBox(x: 0.2, y: 0.2, width: 0.2, height: 0.2),
      visualEmbedding: const [1, 0],
      visibleFrames: 10,
      missingFrames: 5,
      confidence: 0.9,
      presence: TrackPresence.missingCandidate,
      firstSeenAt: now.subtract(const Duration(seconds: 4)),
      lastSeenAt: now.subtract(const Duration(seconds: 2)),
      updatedAt: now,
      source: ObservationSource.fused,
      confirmedToy: true,
      confirmedAt: now.subtract(const Duration(seconds: 4)),
      interactionEvidence: interaction ? 1 : 0,
      lastInteractionAt:
          interaction ? now.subtract(const Duration(seconds: 1)) : null,
      missingSince: now.subtract(const Duration(seconds: 1)),
    );

ToyTrack _missingTrackAt(
  DateTime now, {
  required DateTime missingSince,
  required int missingFrames,
  bool interaction = true,
}) {
  final track = _missingTrack(now, interaction: interaction);
  return track.copyWith(
    missingSince: missingSince,
    missingFrames: missingFrames,
  );
}

SceneDescriptor _scene(
  DateTime now,
  SceneState state, {
  required double similarity,
  SpatialObservation spatial = const SpatialObservation.unavailable(),
}) =>
    SceneDescriptor(
      embedding: const [1, 0],
      state: state,
      similarityToPrevious: similarity,
      motion: 1 - similarity,
      sharpness: 0.2,
      luminance: 0.5,
      coverage: 1,
      timestamp: now,
      stableFrameCount: state == SceneState.stable ? 10 : 0,
      similarityToStableAnchor: similarity,
      spatial: spatial,
    );
