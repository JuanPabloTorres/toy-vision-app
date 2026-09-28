import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/application/cleanup/room_clean_verifier.dart';
import 'package:toyvision_realtime/domain/cleanup/cleanup_session.dart';
import 'package:toyvision_realtime/domain/scene/room_snapshot.dart';
import 'package:toyvision_realtime/domain/scene/room_world_model.dart';
import 'package:toyvision_realtime/domain/scene/scene_descriptor.dart';
import 'package:toyvision_realtime/domain/scene/scene_state.dart';
import 'package:toyvision_realtime/domain/scene/spatial_observation.dart';
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/domain/toy/toy_observation.dart';
import 'package:toyvision_realtime/domain/toy/toy_track.dart';

void main() {
  test('zero confirmed toys can never complete', () {
    final now = DateTime.utc(2026);
    final snapshot = _snapshot(now, includeToy: false);
    final evaluation = EvidenceBasedRoomCleanVerifier().evaluate(
      snapshot: snapshot,
      world: _world(now, const [1, 0]),
      session: CleanupSession.start(
        id: 'session',
        snapshot: snapshot,
        startedAt: now.subtract(const Duration(seconds: 5)),
      ),
      uncertainTracks: 0,
    );

    expect(evaluation.decision, RoomCleanDecision.needMoreCoverage);
    expect(
      evaluation.evidence.blockingReasons,
      contains('initial_snapshot_empty'),
    );
  });

  test('lost detections without verified progress cannot complete', () {
    final now = DateTime.utc(2026);
    final snapshot = _snapshot(now);
    final evaluation = EvidenceBasedRoomCleanVerifier().evaluate(
      snapshot: snapshot,
      world: _world(now, const [1, 0]),
      session: CleanupSession.start(
        id: 'session',
        snapshot: snapshot,
        startedAt: now.subtract(const Duration(seconds: 5)),
      ),
      uncertainTracks: 0,
    );

    expect(evaluation.decision, RoomCleanDecision.needMoreCoverage);
    expect(
      evaluation.evidence.blockingReasons,
      contains('no_verified_progress'),
    );
    expect(
      evaluation.evidence.blockingReasons,
      contains('not_all_snapshot_toys_collected'),
    );
  });

  test('clean requires sustained absence and final-room coverage', () {
    final origin = DateTime.utc(2026);
    final snapshot = _snapshot(origin);
    final session = CleanupSession.start(
      id: 'session',
      snapshot: snapshot,
      startedAt: origin.subtract(const Duration(seconds: 5)),
    ).collect(1);
    final verifier = EvidenceBasedRoomCleanVerifier(
      policy: const RoomCleanPolicy(
        minimumCleanDuration: Duration(seconds: 2),
        minimumCleanFrames: 3,
        minimumViewpoints: 2,
        minimumCameraMotion: 0.05,
      ),
    );

    final first = verifier.evaluate(
      snapshot: snapshot,
      world: _world(origin, const [1, 0]),
      session: session,
      uncertainTracks: 0,
    );
    final second = verifier.evaluate(
      snapshot: snapshot,
      world: _world(
        origin.add(const Duration(seconds: 1)),
        const [0.8, 0.6],
      ),
      session: session,
      uncertainTracks: 0,
    );
    final third = verifier.evaluate(
      snapshot: snapshot,
      world: _world(
        origin.add(const Duration(milliseconds: 2100)),
        const [0.8, 0.6],
      ),
      session: session,
      uncertainTracks: 0,
    );

    expect(first.verificationStarted, isTrue);
    expect(first.decision, RoomCleanDecision.needMoreCoverage);
    expect(second.decision, RoomCleanDecision.needMoreCoverage);
    expect(third.decision, RoomCleanDecision.roomClean);
    expect(third.evidence.sceneCoverage, 1);
  });

  test('a stable toy found during final verification cancels completion', () {
    final origin = DateTime.utc(2026);
    final snapshot = _snapshot(origin);
    final session = CleanupSession.start(
      id: 'session',
      snapshot: snapshot,
      startedAt: origin.subtract(const Duration(seconds: 5)),
    ).collect(1);
    final verifier = EvidenceBasedRoomCleanVerifier();
    verifier.evaluate(
      snapshot: snapshot,
      world: _world(origin, const [1, 0]),
      session: session,
      uncertainTracks: 0,
    );

    final evaluation = verifier.evaluate(
      snapshot: snapshot,
      world: _world(
        origin.add(const Duration(seconds: 1)),
        const [0.8, 0.6],
        activeTracks: {2: _track(2, origin)},
      ),
      session: session,
      uncertainTracks: 0,
    );

    expect(evaluation.decision, RoomCleanDecision.toyFound);
    expect(evaluation.verifying, isFalse);
  });

  test('directional coverage explains what remains and completes', () {
    final origin = DateTime.utc(2026);
    final snapshot = _snapshot(origin);
    final session = CleanupSession.start(
      id: 'session',
      snapshot: snapshot,
      startedAt: origin.subtract(const Duration(seconds: 5)),
    ).collect(1);
    final verifier = EvidenceBasedRoomCleanVerifier(
      policy: const RoomCleanPolicy(
        minimumCleanDuration: Duration(seconds: 2),
        minimumCleanFrames: 3,
        minimumDirectionalSectors: 4,
      ),
    );

    final observations = [
      (0, 0.0, 0.0),
      (700, -35.0, 0.0),
      (1400, 35.0, 0.0),
      (2200, 0.0, 25.0),
    ];
    RoomCleanEvaluation? evaluation;
    for (final observation in observations) {
      evaluation = verifier.evaluate(
        snapshot: snapshot,
        world: _world(
          origin.add(Duration(milliseconds: observation.$1)),
          const [1, 0],
          spatial: _spatial(
            origin,
            yaw: observation.$2,
            pitch: observation.$3,
          ),
        ),
        session: session,
        uncertainTracks: 0,
      );
    }

    expect(evaluation?.decision, RoomCleanDecision.roomClean);
    expect(evaluation?.evidence.sceneCoverage, 1);
    expect(evaluation?.evidence.coverageSectors, hasLength(4));
    expect(evaluation?.evidence.cleanDecision, RoomCleanDecision.roomClean);
  });
}

RoomSnapshot _snapshot(DateTime now, {bool includeToy = true}) => RoomSnapshot(
      id: includeToy ? 'one-toy' : 'empty',
      createdAt: now.subtract(const Duration(seconds: 5)),
      toys:
          includeToy ? [ToyTrackSnapshot.fromTrack(_track(1, now))] : const [],
      sceneEmbedding: const [1, 0],
      geometry: SceneGeometry(
        coverage: 1,
        anchorCount: includeToy ? 1 : 0,
      ),
      confidence: includeToy ? 0.9 : 0,
    );

ToyTrack _track(int id, DateTime now) => ToyTrack(
      id: id,
      lastBounds: const NormalizedBox(x: 0.2, y: 0.2, width: 0.2, height: 0.2),
      initialBounds:
          const NormalizedBox(x: 0.2, y: 0.2, width: 0.2, height: 0.2),
      visualEmbedding: const [1, 0],
      visibleFrames: 10,
      missingFrames: 0,
      confidence: 0.9,
      presence: TrackPresence.visible,
      firstSeenAt: now.subtract(const Duration(seconds: 4)),
      lastSeenAt: now,
      updatedAt: now,
      source: ObservationSource.detector,
      confirmedToy: true,
      confirmedAt: now.subtract(const Duration(seconds: 4)),
      interactionEvidence: 0,
    );

RoomWorldModel _world(
  DateTime now,
  List<double> embedding, {
  Map<int, ToyTrack> activeTracks = const {},
  SpatialObservation spatial = const SpatialObservation.unavailable(),
}) =>
    RoomWorldModel(
      activeTracks: activeTracks,
      missingTracks: const {},
      collectedTracks: const {},
      sceneState: SceneState.stable,
      scene: SceneDescriptor(
        embedding: embedding,
        state: SceneState.stable,
        similarityToPrevious: 0.99,
        motion: 0.01,
        sharpness: 0.2,
        luminance: 0.5,
        coverage: 1,
        timestamp: now,
        stableFrameCount: 10,
        similarityToStableAnchor: 0.99,
        spatial: spatial,
      ),
      updatedAt: now,
    );

SpatialObservation _spatial(
  DateTime timestamp, {
  required double yaw,
  required double pitch,
}) =>
    SpatialObservation(
      timestamp: timestamp,
      motionAvailable: true,
      orientationAvailable: true,
      gyroscopeRadPerSecond: 0.01,
      linearAccelerationMetersPerSecond2: 0.01,
      yawDegrees: yaw,
      pitchDegrees: pitch,
    );
