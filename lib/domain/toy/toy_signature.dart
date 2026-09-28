class ToySignature {
  ToySignature({
    required this.trackId,
    required List<double> embedding,
    required this.recordedAt,
  }) : embedding = List<double>.unmodifiable(embedding);

  final int trackId;
  final List<double> embedding;
  final DateTime recordedAt;
}
