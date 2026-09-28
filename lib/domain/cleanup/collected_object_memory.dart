import '../../core/math/vector_math.dart';
import '../toy/normalized_box.dart';
import '../toy/toy_signature.dart';

class CollectedToySignature extends ToySignature {
  CollectedToySignature({
    required super.trackId,
    required super.embedding,
    required super.recordedAt,
    required this.lastBounds,
  });

  final NormalizedBox lastBounds;
}

class CollectedObjectMemory {
  final List<CollectedToySignature> _signatures = [];

  bool probablyAlreadyCollected({
    required int trackId,
    required List<double> embedding,
    required NormalizedBox bounds,
    required DateTime timestamp,
  }) {
    for (final signature in _signatures) {
      if (signature.trackId == trackId) return true;
      final closeInTime = timestamp.difference(signature.recordedAt).abs() <=
          const Duration(seconds: 4);
      final sameRegion =
          signature.lastBounds.centroidSimilarity(bounds) >= 0.82;
      final sameAppearance =
          cosineSimilarity(signature.embedding, embedding) >= 0.96;
      if (closeInTime && sameRegion && sameAppearance) return true;
    }
    return false;
  }

  void remember(CollectedToySignature signature) {
    _signatures.add(signature);
    if (_signatures.length > 64) _signatures.removeAt(0);
  }

  void clear() => _signatures.clear();
}
