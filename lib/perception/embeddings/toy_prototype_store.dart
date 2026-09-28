import '../../core/math/vector_math.dart';

class ToyPrototype {
  ToyPrototype({
    required this.id,
    required List<double> centroid,
    required this.sampleCount,
  }) : centroid = List<double>.unmodifiable(centroid);

  final String id;
  final List<double> centroid;
  final int sampleCount;
}

/// Session-local visual memory. It stores vectors, never room images.
class ToyPrototypeStore {
  final List<ToyPrototype> _prototypes = [];

  List<ToyPrototype> get prototypes => List.unmodifiable(_prototypes);

  double nearestSimilarity(List<double> embedding) {
    if (_prototypes.isEmpty) return 0;
    var best = -1.0;
    for (final prototype in _prototypes) {
      final similarity = cosineSimilarity(embedding, prototype.centroid);
      if (similarity > best) best = similarity;
    }
    return best.clamp(0.0, 1.0);
  }

  void learn(List<double> embedding) {
    if (embedding.isEmpty) return;
    var bestIndex = -1;
    var bestSimilarity = -1.0;
    for (var index = 0; index < _prototypes.length; index++) {
      final similarity = cosineSimilarity(
        embedding,
        _prototypes[index].centroid,
      );
      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestIndex = index;
      }
    }
    if (bestIndex >= 0 && bestSimilarity >= 0.86) {
      final previous = _prototypes[bestIndex];
      final weight = 1 / (previous.sampleCount + 1);
      _prototypes[bestIndex] = ToyPrototype(
        id: previous.id,
        centroid: blendEmbeddings(
          previous.centroid,
          embedding,
          currentWeight: weight,
        ),
        sampleCount: previous.sampleCount + 1,
      );
      return;
    }
    if (_prototypes.length >= 32) return;
    _prototypes.add(
      ToyPrototype(
        id: 'session_prototype_${_prototypes.length}',
        centroid: embedding,
        sampleCount: 1,
      ),
    );
  }

  void clear() => _prototypes.clear();
}
