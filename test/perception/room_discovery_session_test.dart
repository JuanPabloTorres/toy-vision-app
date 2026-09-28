import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/domain/scene/room_world_model.dart';
import 'package:toyvision_realtime/domain/scene/scene_descriptor.dart';
import 'package:toyvision_realtime/domain/scene/scene_state.dart';
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/domain/toy/toy_observation.dart';
import 'package:toyvision_realtime/domain/toy/toy_track.dart';
import 'package:toyvision_realtime/perception/room_discovery/room_discovery_session.dart';

void main() {
  const policy = RoomDiscoveryPolicy(
    minimumDuration: Duration(seconds: 2),
    quietPeriod: Duration(milliseconds: 500),
    minimumViewpoints: 2,
    minimumCameraMotion: 0.05,
  );

  test('a single static viewpoint never completes room discovery', () {
    final discovery = RoomDiscoverySession(policy: policy);
    final origin = DateTime.utc(2026);

    expect(discovery.createSnapshot(_world(origin, const [1, 0])), isNull);
    expect(
      discovery.createSnapshot(
        _world(origin.add(const Duration(seconds: 5)), const [1, 0]),
      ),
      isNull,
    );
    expect(discovery.progress.viewpointCount, 1);
    expect(discovery.progress.cameraMotion, 0);
  });

  test('movement, multiple viewpoints and a quiet window freeze a snapshot',
      () {
    final discovery = RoomDiscoverySession(policy: policy);
    final origin = DateTime.utc(2026);

    expect(discovery.createSnapshot(_world(origin, const [1, 0])), isNull);
    final snapshot = discovery.createSnapshot(
      _world(origin.add(const Duration(seconds: 3)), const [0.8, 0.6]),
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.toys, hasLength(1));
    expect(snapshot.geometry.coverage, 1);
    expect(discovery.progress.complete, isTrue);
  });
}

RoomWorldModel _world(DateTime at, List<double> sceneEmbedding) {
  final track = ToyTrack(
    id: 1,
    lastBounds: const NormalizedBox(x: 0.2, y: 0.3, width: 0.2, height: 0.2),
    initialBounds: const NormalizedBox(x: 0.2, y: 0.3, width: 0.2, height: 0.2),
    visualEmbedding: const [1, 0],
    visibleFrames: 8,
    missingFrames: 0,
    confidence: 0.9,
    presence: TrackPresence.visible,
    firstSeenAt: at.subtract(const Duration(seconds: 2)),
    lastSeenAt: at,
    updatedAt: at,
    source: ObservationSource.detector,
    confirmedToy: true,
    confirmedAt: at.subtract(const Duration(seconds: 1)),
    interactionEvidence: 0,
  );
  return RoomWorldModel(
    activeTracks: {1: track},
    missingTracks: const {},
    collectedTracks: const {},
    sceneState: SceneState.stable,
    scene: SceneDescriptor(
      embedding: sceneEmbedding,
      state: SceneState.stable,
      similarityToPrevious: 0.99,
      motion: 0.01,
      sharpness: 0.5,
      luminance: 0.5,
      coverage: 1,
      timestamp: at,
      stableFrameCount: 8,
      similarityToStableAnchor: 0.99,
    ),
    updatedAt: at,
  );
}
