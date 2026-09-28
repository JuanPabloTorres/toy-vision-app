import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/perception/embeddings/embedding_extractor.dart';
import 'package:toyvision_realtime/perception/perception_models.dart';
import 'package:toyvision_realtime/perception/visual_frame_analyzer.dart';

void main() {
  test('upright detector boxes crop the matching rotated sensor pixels', () {
    final sensorImage = img.Image(width: 80, height: 40);
    img.fill(sensorImage, color: img.ColorRgb8(0, 0, 180));
    // This raw-sensor region becomes x=.6, y=.2, w=.2, h=.3 after a
    // clockwise quarter-turn into the upright detector coordinate space.
    img.fillRect(
      sensorImage,
      x1: 16,
      y1: 8,
      x2: 39,
      y2: 15,
      color: img.ColorRgb8(255, 0, 0),
    );
    const detectorBox = NormalizedBox(
      x: 0.6,
      y: 0.2,
      width: 0.2,
      height: 0.3,
    );
    final analysis = const VisualFrameAnalyzer(
      embeddingExtractor: _MeanColorExtractor(),
    ).analyze(
      CameraPerceptionFrame(
        frameId: 1,
        timestamp: DateTime.utc(2026),
        encodedImage: Uint8List.fromList(img.encodePng(sensorImage)),
        detectorProposals: const [
          DetectorProposal(bounds: detectorBox, confidence: 0.9),
        ],
        nativeInferenceMs: 1,
        nativeFps: 8,
        detectorCoordinatesAreUpright: true,
      ),
      generateOpenSetProposals: false,
    );

    expect(analysis.sourceWidth, 40);
    expect(analysis.sourceHeight, 80);
    expect(analysis.candidates.single.bounds, detectorBox);
    expect(analysis.candidates.single.embedding.first, greaterThan(0.85));
    expect(analysis.candidates.single.embedding.last, lessThan(0.15));
  });
}

class _MeanColorExtractor implements EmbeddingExtractor {
  const _MeanColorExtractor();

  @override
  int get dimensions => 2;

  @override
  String get identifier => 'test-mean-red-blue';

  @override
  List<double> embed(img.Image image, NormalizedBox bounds) {
    final left = (bounds.x * image.width).floor();
    final top = (bounds.y * image.height).floor();
    final right = (bounds.right * image.width).ceil();
    final bottom = (bounds.bottom * image.height).ceil();
    var red = 0.0;
    var blue = 0.0;
    var count = 0;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final pixel = image.getPixel(x, y);
        red += pixel.r / 255;
        blue += pixel.b / 255;
        count++;
      }
    }
    return [red / count, blue / count];
  }
}
