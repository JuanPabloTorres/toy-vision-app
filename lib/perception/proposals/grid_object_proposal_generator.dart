import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../../domain/toy/normalized_box.dart';

class OpenSetProposal {
  const OpenSetProposal(this.bounds, this.objectness);
  final NormalizedBox bounds;
  final double objectness;
}

/// Produces label-free object regions from contrast, texture and edges.
///
/// This is deliberately conservative: candidates still require temporal
/// persistence and fusion evidence before becoming a toy observation.
class GridObjectProposalGenerator {
  const GridObjectProposalGenerator({
    this.gridSize = 12,
    this.maxProposals = 10,
  });

  final int gridSize;
  final int maxProposals;

  List<OpenSetProposal> generate(img.Image image) {
    final border = _borderMean(image);
    final scores = List<double>.filled(gridSize * gridSize, 0);
    for (var gy = 0; gy < gridSize; gy++) {
      for (var gx = 0; gx < gridSize; gx++) {
        scores[gy * gridSize + gx] = _cellScore(image, gx, gy, border);
      }
    }

    // A connected region is preferable to several cell-centred fallbacks:
    // otherwise one object spanning a grid boundary can become many tracks.
    final active = [
      for (final score in scores) score >= 0.14,
    ];
    final seen = List<bool>.filled(active.length, false);
    final proposals = <OpenSetProposal>[];
    for (var start = 0; start < active.length; start++) {
      if (!active[start] || seen[start]) continue;
      final queue = <int>[start];
      seen[start] = true;
      var minX = gridSize;
      var minY = gridSize;
      var maxX = 0;
      var maxY = 0;
      var totalScore = 0.0;
      var cells = 0;
      while (queue.isNotEmpty) {
        final index = queue.removeLast();
        final x = index % gridSize;
        final y = index ~/ gridSize;
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
        totalScore += scores[index];
        cells += 1;
        for (final neighbor in _neighbors(x, y)) {
          final next = neighbor.$2 * gridSize + neighbor.$1;
          if (!seen[next] && active[next]) {
            seen[next] = true;
            queue.add(next);
          }
        }
      }
      final fraction = cells / (gridSize * gridSize);
      if (cells < 2 || fraction > 0.55) continue;
      const paddingCells = 0.35;
      final left = ((minX - paddingCells) / gridSize).clamp(0.0, 1.0);
      final top = ((minY - paddingCells) / gridSize).clamp(0.0, 1.0);
      final right = ((maxX + 1 + paddingCells) / gridSize).clamp(0.0, 1.0);
      final bottom = ((maxY + 1 + paddingCells) / gridSize).clamp(0.0, 1.0);
      final bounds = NormalizedBox(
        x: left,
        y: top,
        width: right - left,
        height: bottom - top,
      );
      if (bounds.area < 0.006 || bounds.area > 0.6) continue;
      proposals.add(
        OpenSetProposal(
          bounds,
          ((totalScore / cells - 0.10) / 0.28).clamp(0.0, 1.0),
        ),
      );
    }
    proposals.sort((a, b) => b.objectness.compareTo(a.objectness));
    if (proposals.isEmpty) {
      final ranked = List<int>.generate(scores.length, (index) => index)
        ..sort((a, b) => scores[b].compareTo(scores[a]));
      for (final index in ranked) {
        final score = scores[index];
        if (score < 0.12 || proposals.length >= maxProposals) break;
        final x = index % gridSize;
        final y = index ~/ gridSize;
        final left = ((x - 0.75) / gridSize).clamp(0.0, 1.0);
        final top = ((y - 0.75) / gridSize).clamp(0.0, 1.0);
        final right = ((x + 1.75) / gridSize).clamp(0.0, 1.0);
        final bottom = ((y + 1.75) / gridSize).clamp(0.0, 1.0);
        final bounds = NormalizedBox(
          x: left,
          y: top,
          width: right - left,
          height: bottom - top,
        );
        if (proposals.any(
          (proposal) => proposal.bounds.intersectionOverUnion(bounds) >= 0.35,
        )) {
          continue;
        }
        proposals.add(
          OpenSetProposal(
            bounds,
            ((score - 0.10) / 0.28).clamp(0.0, 1.0),
          ),
        );
      }
    }
    return proposals.take(maxProposals).toList(growable: false);
  }

  Iterable<(int, int)> _neighbors(int x, int y) sync* {
    if (x > 0) yield (x - 1, y);
    if (x + 1 < gridSize) yield (x + 1, y);
    if (y > 0) yield (x, y - 1);
    if (y + 1 < gridSize) yield (x, y + 1);
  }

  (double, double, double) _borderMean(img.Image image) {
    var red = 0.0;
    var green = 0.0;
    var blue = 0.0;
    var count = 0;
    final step = math.max(1, math.min(image.width, image.height) ~/ 40);
    for (var x = 0; x < image.width; x += step) {
      for (final y in [0, image.height - 1]) {
        final pixel = image.getPixel(x, y);
        red += pixel.r;
        green += pixel.g;
        blue += pixel.b;
        count += 1;
      }
    }
    for (var y = step; y < image.height - step; y += step) {
      for (final x in [0, image.width - 1]) {
        final pixel = image.getPixel(x, y);
        red += pixel.r;
        green += pixel.g;
        blue += pixel.b;
        count += 1;
      }
    }
    return (red / count, green / count, blue / count);
  }

  double _cellScore(
    img.Image image,
    int gridX,
    int gridY,
    (double, double, double) border,
  ) {
    final left = gridX * image.width ~/ gridSize;
    final top = gridY * image.height ~/ gridSize;
    final right = (gridX + 1) * image.width ~/ gridSize;
    final bottom = (gridY + 1) * image.height ~/ gridSize;
    var red = 0.0;
    var green = 0.0;
    var blue = 0.0;
    var luminance = 0.0;
    var luminanceSquared = 0.0;
    var edge = 0.0;
    var count = 0;
    final step = math.max(1, math.min(right - left, bottom - top) ~/ 5);
    for (var y = top; y < bottom; y += step) {
      for (var x = left; x < right; x += step) {
        final pixel = image.getPixel(x, y);
        red += pixel.r;
        green += pixel.g;
        blue += pixel.b;
        final value =
            (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114).toDouble();
        luminance += value;
        luminanceSquared += value * value;
        if (x + step < right) {
          final next = image.getPixel(x + step, y);
          final nextValue =
              (next.r * 0.299 + next.g * 0.587 + next.b * 0.114).toDouble();
          edge += (nextValue - value).abs();
        }
        count += 1;
      }
    }
    if (count == 0) return 0;
    red /= count;
    green /= count;
    blue /= count;
    final colorDistance = math.sqrt(
          math.pow(red - border.$1, 2) +
              math.pow(green - border.$2, 2) +
              math.pow(blue - border.$3, 2),
        ) /
        441.7;
    final meanLuminance = luminance / count;
    final variance =
        math.max(0.0, luminanceSquared / count - meanLuminance * meanLuminance);
    final texture = (math.sqrt(variance) / 80).clamp(0.0, 1.0);
    final edgeScore = (edge / count / 55).clamp(0.0, 1.0);
    return (colorDistance * 0.50 + texture * 0.25 + edgeScore * 0.25)
        .clamp(0.0, 1.0);
  }
}
