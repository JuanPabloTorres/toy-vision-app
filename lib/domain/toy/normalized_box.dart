import 'dart:math' as math;

/// Framework-free rectangle in normalized camera coordinates.
class NormalizedBox {
  const NormalizedBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  double get right => x + width;
  double get bottom => y + height;
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;
  double get area => width * height;

  bool get isValid =>
      x.isFinite &&
      y.isFinite &&
      width.isFinite &&
      height.isFinite &&
      width > 0 &&
      height > 0 &&
      x >= 0 &&
      y >= 0 &&
      right <= 1 &&
      bottom <= 1;

  NormalizedBox clamp() {
    final left = x.clamp(0.0, 1.0);
    final top = y.clamp(0.0, 1.0);
    final clampedRight = right.clamp(left, 1.0);
    final clampedBottom = bottom.clamp(top, 1.0);
    return NormalizedBox(
      x: left,
      y: top,
      width: clampedRight - left,
      height: clampedBottom - top,
    );
  }

  double intersectionOverUnion(NormalizedBox other) {
    final intersection = intersectionArea(other);
    final union = area + other.area - intersection;
    return union <= 0 ? 0 : intersection / union;
  }

  double intersectionArea(NormalizedBox other) {
    final left = math.max(x, other.x);
    final top = math.max(y, other.y);
    final intersectionRight = math.min(right, other.right);
    final intersectionBottom = math.min(bottom, other.bottom);
    final intersectionWidth = math.max(0.0, intersectionRight - left);
    final intersectionHeight = math.max(0.0, intersectionBottom - top);
    return intersectionWidth * intersectionHeight;
  }

  double intersectionOverSmaller(NormalizedBox other) {
    final smaller = math.min(area, other.area);
    return smaller <= 0 ? 0 : intersectionArea(other) / smaller;
  }

  double centroidSimilarity(NormalizedBox other) {
    final dx = centerX - other.centerX;
    final dy = centerY - other.centerY;
    final distance = math.sqrt(dx * dx + dy * dy);
    return (1 - distance / math.sqrt(2)).clamp(0.0, 1.0);
  }

  double sizeSimilarity(NormalizedBox other) {
    final largest = math.max(area, other.area);
    return largest <= 0 ? 0 : math.min(area, other.area) / largest;
  }

  @override
  bool operator ==(Object other) =>
      other is NormalizedBox &&
      x == other.x &&
      y == other.y &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(x, y, width, height);
}
