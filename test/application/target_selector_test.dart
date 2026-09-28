import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/application/cleanup/target_selector.dart';
import 'package:toyvision_realtime/domain/scene/room_snapshot.dart';
import 'package:toyvision_realtime/domain/scene/room_world_model.dart';
import 'package:toyvision_realtime/domain/scene/scene_descriptor.dart';
import 'package:toyvision_realtime/domain/scene/scene_state.dart';
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/domain/toy/toy_observation.dart';
import 'package:toyvision_realtime/domain/toy/toy_track.dart';

void main() {
  test('selects the largest stable visible toy and respects exclusions', () {
    final now = DateTime.utc(2026);
    final small = _track(1, now, 0.08);
    final large = _track(2, now, 0.25);
    final snapshot = RoomSnapshot(
      id: 'room',
      createdAt: now,
      toys: [
        ToyTrackSnapshot.fromTrack(small),
        ToyTrackSnapshot.fromTrack(large),
      ],
      sceneEmbedding: const [1, 0],
      geometry: const SceneGeometry(coverage: 1, anchorCount: 2),
      confidence: 0.9,
    );
    final world = RoomWorldModel(
      activeTracks: {1: small, 2: large},
      missingTracks: const {},
      collectedTracks: const {},
      sceneState: SceneState.stable,
      scene: _scene(now),
      updatedAt: now,
    );
    const selector = VisibleStableTargetSelector();

    expect(
      selector.selectNext(
        snapshot: snapshot,
        tracking: world,
        excludedTrackIds: const {},
      ),
      2,
    );
    expect(
      selector.selectNext(
        snapshot: snapshot,
        tracking: world,
        excludedTrackIds: const {2},
      ),
      1,
    );
  });
}

ToyTrack _track(int id, DateTime at, double size) => ToyTrack(
      id: id,
      lastBounds: NormalizedBox(x: 0.1 * id, y: 0.2, width: size, height: size),
      initialBounds:
          NormalizedBox(x: 0.1 * id, y: 0.2, width: size, height: size),
      visualEmbedding: [id.toDouble(), 1],
      visibleFrames: 10,
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

SceneDescriptor _scene(DateTime at) => SceneDescriptor(
      embedding: const [1, 0],
      state: SceneState.stable,
      similarityToPrevious: 1,
      motion: 0,
      sharpness: 1,
      luminance: 1,
      coverage: 1,
      timestamp: at,
      stableFrameCount: 10,
      similarityToStableAnchor: 1,
    );
