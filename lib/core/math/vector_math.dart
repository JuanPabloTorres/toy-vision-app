import 'dart:math' as math;

/// Numerically safe cosine similarity used by perception and tracking.
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty || a.length != b.length) return 0;
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var index = 0; index < a.length; index++) {
    final av = a[index];
    final bv = b[index];
    dot += av * bv;
    normA += av * av;
    normB += bv * bv;
  }
  if (normA <= 1e-12 || normB <= 1e-12) return 0;
  return (dot / math.sqrt(normA * normB)).clamp(-1.0, 1.0);
}

List<double> l2Normalize(List<double> values) {
  var sumSquares = 0.0;
  for (final value in values) {
    sumSquares += value * value;
  }
  if (sumSquares <= 1e-12) {
    return List<double>.filled(values.length, 0, growable: false);
  }
  final magnitude = math.sqrt(sumSquares);
  return List<double>.unmodifiable(
    values.map((value) => value / magnitude),
  );
}

List<double> blendEmbeddings(
  List<double> previous,
  List<double> current, {
  double currentWeight = 0.25,
}) {
  if (previous.length != current.length || previous.isEmpty) {
    return l2Normalize(current);
  }
  final previousWeight = 1 - currentWeight;
  return l2Normalize([
    for (var index = 0; index < current.length; index++)
      previous[index] * previousWeight + current[index] * currentWeight,
  ]);
}
