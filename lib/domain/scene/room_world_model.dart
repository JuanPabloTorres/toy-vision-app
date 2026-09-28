import '../toy/toy_track.dart';
import 'scene_descriptor.dart';
import 'scene_state.dart';

class RoomWorldModel {
  RoomWorldModel({
    required Map<int, ToyTrack> activeTracks,
    required Map<int, ToyTrack> missingTracks,
    required Map<int, ToyTrack> collectedTracks,
    required this.sceneState,
    required this.scene,
    required this.updatedAt,
  })  : activeTracks = Map<int, ToyTrack>.unmodifiable(activeTracks),
        missingTracks = Map<int, ToyTrack>.unmodifiable(missingTracks),
        collectedTracks = Map<int, ToyTrack>.unmodifiable(collectedTracks);

  factory RoomWorldModel.empty(DateTime timestamp) => RoomWorldModel(
        activeTracks: const {},
        missingTracks: const {},
        collectedTracks: const {},
        sceneState: SceneState.unstable,
        scene: SceneDescriptor(
          embedding: const [],
          state: SceneState.unstable,
          similarityToPrevious: 0,
          motion: 1,
          sharpness: 0,
          luminance: 0,
          coverage: 0,
          timestamp: timestamp,
        ),
        updatedAt: timestamp,
      );

  final Map<int, ToyTrack> activeTracks;
  final Map<int, ToyTrack> missingTracks;
  final Map<int, ToyTrack> collectedTracks;
  final SceneState sceneState;
  final SceneDescriptor scene;
  final DateTime updatedAt;

  int get visibleCount =>
      activeTracks.values.where((track) => track.isVisible).length;
}
