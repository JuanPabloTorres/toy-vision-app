import '../detection/models/bounding_box.dart';

/// Computes Intersection-over-Union between two bounding boxes.
///
/// IoU is the overlap area divided by the union area, in [0, 1]. The tracking
/// engine uses it to decide whether a new detection is the same physical toy as
/// an existing tracked one.
class IoUCalculator {
  const IoUCalculator();

  double iou(BoundingBox a, BoundingBox b) {
    final intersection = a.intersectionArea(b);
    if (intersection <= 0) return 0;
    final union = a.area + b.area - intersection;
    if (union <= 0) return 0;
    return intersection / union;
  }
}
