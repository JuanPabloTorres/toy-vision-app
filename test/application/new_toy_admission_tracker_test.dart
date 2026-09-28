import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/application/cleanup/new_toy_admission_tracker.dart';
import 'package:toyvision_realtime/domain/scene/room_world_model.dart';
import 'package:toyvision_realtime/domain/scene/scene_descriptor.dart';
import 'package:toyvision_realtime/domain/scene/scene_state.dart';
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/domain/toy/toy_observation.dart';
import 'package:toyvision_realtime/domain/toy/toy_track.dart';

void main() {
  test('camera motion cannot immediately add a new mission target', () {
    final origin = DateTime.utc(2026);
    final tracker = NewToyAdmissionTracker(
      policy: const NewToyAdmissionPolicy(
        minimumStableDuration: Duration(seconds: 1),
      ),
    );

    expect(
      tracker.observe(
        _world(origin, state: SceneState.moving, stableFrames: 0),
        knownTrackIds: {1},
      ),
      isEmpty,
    );
    expect(tracker.pendingCount, 1);

    expect(
      tracker.observe(
        _world(origin.add(const Duration(milliseconds: 500))),
        knownTrackIds: {1},
      ),
      isEmpty,
    );
    expect(tracker.pendingCount, 1);

    expect(
      tracker.observe(
        _world(origin.add(const Duration(milliseconds: 1200))),
        knownTrackIds: {1},
      ),
      isEmpty,
    );
    expect(tracker.pendingCount, 1);

    expect(
      tracker.observe(
        _world(origin.add(const Duration(milliseconds: 1600))),
        knownTrackIds: {1},
      ),
      {2},
    );
    expect(tracker.pendingCount, 0);
  });

  test('weak open-set identity can never expand the mission', () {
    final now = DateTime.utc(2026);
    final tracker = NewToyAdmissionTracker(
      policy: const NewToyAdmissionPolicy(minimumStableDuration: Duration.zero),
    );

    final admitted = tracker.observe(
      _world(now, source: ObservationSource.openSetProposal),
      knownTrackIds: {1},
    );

    expect(admitted, isEmpty);
    expect(tracker.pendingCount, 0);
  });

  test('fresh detector-confirmed identity blocks clean before admission', () {
    final now = DateTime.utc(2026);
    final tracker = NewToyAdmissionTracker();

    final admitted = tracker.observe(
      _world(now, visibleFrames: 1),
      knownTrackIds: {1},
    );

    expect(admitted, isEmpty);
    expect(tracker.pendingCount, 1);
  });

  test('confirmed identity below admission confidence still blocks clean', () {
    final now = DateTime.utc(2026);
    final tracker = NewToyAdmissionTracker();

    final admitted = tracker.observe(
      _world(now, confidence: 0.72),
      knownTrackIds: {1},
    );

    expect(admitted, isEmpty);
    expect(tracker.pendingCount, 1);
  });
}

RoomWorldModel _world(
  DateTime at, {
  SceneState state = SceneState.stable,
  int stableFrames = 8,
  ObservationSource source = ObservationSource.detector,
  int visibleFrames = 12,
  double confidence = 0.9,
}) =>
    RoomWorldModel(
      activeTracks: {
        2: _track(
          at,
          source,
          visibleFrames: visibleFrames,
          confidence: confidence,
        ),
      },
      missingTracks: const {},
      collectedTracks: const {},
      sceneState: state,
      scene: SceneDescriptor(
        embedding: const [1, 0],
        state: state,
        similarityToPrevious: 0.99,
        motion: state == SceneState.stable ? 0.01 : 0.8,
        sharpness: 1,
        luminance: 1,
        coverage: 1,
        timestamp: at,
        stableFrameCount: stableFrames,
        similarityToStableAnchor: 0.99,
      ),
      updatedAt: at,
    );

ToyTrack _track(
  DateTime at,
  ObservationSource source, {
  required int visibleFrames,
  required double confidence,
}) =>
    ToyTrack(
      id: 2,
      lastBounds: const NormalizedBox(x: 0.5, y: 0.5, width: 0.2, height: 0.2),
      initialBounds:
          const NormalizedBox(x: 0.5, y: 0.5, width: 0.2, height: 0.2),
      visualEmbedding: const [0, 1],
      visibleFrames: visibleFrames,
      missingFrames: 0,
      confidence: confidence,
      presence: TrackPresence.visible,
      firstSeenAt: at.subtract(const Duration(seconds: 3)),
      lastSeenAt: at,
      updatedAt: at,
      source: source,
      confirmedToy: true,
      confirmedAt: at.subtract(const Duration(seconds: 3)),
      interactionEvidence: 0,
    );
