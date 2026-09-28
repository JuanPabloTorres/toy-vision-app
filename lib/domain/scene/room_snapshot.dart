import '../toy/normalized_box.dart';
import '../toy/toy_track.dart';

class ToyTrackSnapshot {
  ToyTrackSnapshot({
    required this.trackId,
    required this.bounds,
    required List<double> embedding,
    required this.confidence,
  }) : embedding = List<double>.unmodifiable(embedding);

  factory ToyTrackSnapshot.fromTrack(ToyTrack track) => ToyTrackSnapshot(
        trackId: track.id,
        bounds: track.lastBounds,
        embedding: track.visualEmbedding,
        confidence: track.confidence,
      );

  final int trackId;
  final NormalizedBox bounds;
  final List<double> embedding;
  final double confidence;
}

class SceneGeometry {
  const SceneGeometry({
    required this.coverage,
    required this.anchorCount,
  });

  final double coverage;
  final int anchorCount;
}

class RoomSnapshot {
  RoomSnapshot({
    required this.id,
    required this.createdAt,
    required List<ToyTrackSnapshot> toys,
    required List<double> sceneEmbedding,
    required this.geometry,
    required this.confidence,
  })  : toys = List<ToyTrackSnapshot>.unmodifiable(toys),
        sceneEmbedding = List<double>.unmodifiable(sceneEmbedding);

  final String id;
  final DateTime createdAt;
  final List<ToyTrackSnapshot> toys;
  final List<double> sceneEmbedding;
  final SceneGeometry geometry;
  final double confidence;

  RoomSnapshot withToy(ToyTrackSnapshot toy) {
    if (toys.any((existing) => existing.trackId == toy.trackId)) return this;
    final expanded = [...toys, toy];
    final averageConfidence = expanded.fold<double>(
          0,
          (sum, item) => sum + item.confidence,
        ) /
        expanded.length;
    return RoomSnapshot(
      id: id,
      createdAt: createdAt,
      toys: expanded,
      sceneEmbedding: sceneEmbedding,
      geometry: SceneGeometry(
        coverage: geometry.coverage,
        anchorCount: expanded.length,
      ),
      confidence: averageConfidence,
    );
  }
}
