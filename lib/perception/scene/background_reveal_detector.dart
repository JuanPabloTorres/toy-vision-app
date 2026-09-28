import '../../core/math/vector_math.dart';

/// Scores whether a previously occupied region now contains different stable
/// visual structure. Detector absence is not used by this signal.
class BackgroundRevealDetector {
  const BackgroundRevealDetector({
    this.sameObjectSimilarity = 0.93,
    this.fullRevealSimilarity = 0.65,
  });

  final double sameObjectSimilarity;
  final double fullRevealSimilarity;

  double score({
    required List<double> objectEmbedding,
    required List<double>? currentRegionEmbedding,
  }) {
    if (currentRegionEmbedding == null) return 0;
    final similarity = cosineSimilarity(objectEmbedding, currentRegionEmbedding)
        .clamp(0.0, 1.0);
    final range = sameObjectSimilarity - fullRevealSimilarity;
    if (range <= 0) return 0;
    return ((sameObjectSimilarity - similarity) / range).clamp(0.0, 1.0);
  }
}
