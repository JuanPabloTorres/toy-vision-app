import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/core/math/vector_math.dart';

void main() {
  test('cosine similarity handles identity, opposition, and invalid vectors',
      () {
    expect(cosineSimilarity([1, 0], [1, 0]), closeTo(1, 1e-9));
    expect(cosineSimilarity([1, 0], [-1, 0]), closeTo(-1, 1e-9));
    expect(cosineSimilarity([1], [1, 2]), 0);
    expect(cosineSimilarity([0, 0], [1, 2]), 0);
  });

  test('blend produces a normalized appearance vector', () {
    final blended = blendEmbeddings([1, 0], [0, 1], currentWeight: 0.5);
    expect(blended[0], closeTo(blended[1], 1e-9));
    expect(blended[0] * blended[0] + blended[1] * blended[1], closeTo(1, 1e-9));
  });
}
