import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../../core/math/vector_math.dart';
import '../../domain/toy/normalized_box.dart';
import 'embedding_extractor.dart';

/// A compact, deterministic visual embedding computed from real crop pixels.
///
/// It combines color distributions, luminance, oriented gradients and a 4x4
/// spatial luminance layout. It is intentionally model-independent so the
/// hybrid path remains functional offline when a semantic embedding TFLite
/// artifact is unavailable. The extractor never uses class names.
class PerceptualEmbeddingExtractor implements EmbeddingExtractor {
  const PerceptualEmbeddingExtractor();

  static const int vectorDimensions = 52;

  @override
  String get identifier => 'perceptual-v1-non-semantic';

  @override
  int get dimensions => vectorDimensions;

  @override
  List<double> embed(img.Image image, NormalizedBox bounds) {
    final box = bounds.clamp();
    final left = (box.x * image.width).floor().clamp(0, image.width - 1);
    final top = (box.y * image.height).floor().clamp(0, image.height - 1);
    final right = (box.right * image.width).ceil().clamp(left + 1, image.width);
    final bottom =
        (box.bottom * image.height).ceil().clamp(top + 1, image.height);
    final width = right - left;
    final height = bottom - top;

    final redHistogram = List<double>.filled(6, 0);
    final greenHistogram = List<double>.filled(6, 0);
    final blueHistogram = List<double>.filled(6, 0);
    final luminanceHistogram = List<double>.filled(8, 0);
    final gradients = List<double>.filled(8, 0);
    final spatial = List<double>.filled(16, 0);
    final spatialCounts = List<int>.filled(16, 0);
    var saturationSum = 0.0;
    var edgeSum = 0.0;
    var samples = 0;

    final step = math.max(1, math.min(width, height) ~/ 24);
    for (var y = top; y < bottom; y += step) {
      for (var x = left; x < right; x += step) {
        final pixel = image.getPixel(x, y);
        final red = pixel.r.toDouble() / 255;
        final green = pixel.g.toDouble() / 255;
        final blue = pixel.b.toDouble() / 255;
        final luminance = red * 0.299 + green * 0.587 + blue * 0.114;
        redHistogram[(red * 5.999).floor()] += 1;
        greenHistogram[(green * 5.999).floor()] += 1;
        blueHistogram[(blue * 5.999).floor()] += 1;
        luminanceHistogram[(luminance * 7.999).floor()] += 1;
        final maxChannel = math.max(red, math.max(green, blue));
        final minChannel = math.min(red, math.min(green, blue));
        saturationSum +=
            maxChannel <= 1e-6 ? 0 : (maxChannel - minChannel) / maxChannel;

        final localX = ((x - left) * 4 ~/ width).clamp(0, 3);
        final localY = ((y - top) * 4 ~/ height).clamp(0, 3);
        final spatialIndex = localY * 4 + localX;
        spatial[spatialIndex] += luminance;
        spatialCounts[spatialIndex] += 1;

        if (x + step < right && y + step < bottom) {
          final rightPixel = image.getPixel(x + step, y);
          final bottomPixel = image.getPixel(x, y + step);
          final rightLuminance = _luminance(rightPixel);
          final bottomLuminance = _luminance(bottomPixel);
          final dx = rightLuminance - luminance;
          final dy = bottomLuminance - luminance;
          final magnitude = math.sqrt(dx * dx + dy * dy);
          edgeSum += magnitude;
          var angle = math.atan2(dy, dx);
          if (angle < 0) angle += math.pi * 2;
          final bin = (angle / (math.pi * 2) * 8).floor().clamp(0, 7);
          gradients[bin] += magnitude;
        }
        samples += 1;
      }
    }

    if (samples == 0) return List<double>.filled(vectorDimensions, 0);
    for (var index = 0; index < spatial.length; index++) {
      final count = spatialCounts[index];
      if (count > 0) spatial[index] /= count;
    }
    final scale = samples.toDouble();
    final values = <double>[
      ...redHistogram.map((value) => value / scale),
      ...greenHistogram.map((value) => value / scale),
      ...blueHistogram.map((value) => value / scale),
      ...luminanceHistogram.map((value) => value / scale),
      ...gradients,
      ...spatial,
      saturationSum / samples,
      edgeSum / samples,
    ];
    return l2Normalize(values);
  }

  double _luminance(img.Pixel pixel) =>
      (pixel.r.toDouble() * 0.299 +
          pixel.g.toDouble() * 0.587 +
          pixel.b.toDouble() * 0.114) /
      255;
}
