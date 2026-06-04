import 'dart:math' as math;

/// Axis-aligned bounding box in normalized coordinates (0..1) relative to the
/// frame. Origin is top-left; [x],[y] are the top-left corner.
class BoundingBox {
  const BoundingBox({
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
  double get area => width * height;

  double get centerX => x + width / 2;
  double get centerY => y + height / 2;

  /// A box is valid when it is non-degenerate and lies within the frame.
  bool get isValid =>
      width > 0 &&
      height > 0 &&
      x >= 0 &&
      y >= 0 &&
      right <= 1.0 + _epsilon &&
      bottom <= 1.0 + _epsilon &&
      area >= _minArea;

  /// Intersection area with [other] in normalized units.
  double intersectionArea(BoundingBox other) {
    final left = math.max(x, other.x);
    final top = math.max(y, other.y);
    final r = math.min(right, other.right);
    final b = math.min(bottom, other.bottom);
    final w = r - left;
    final h = b - top;
    if (w <= 0 || h <= 0) return 0;
    return w * h;
  }

  /// Linearly interpolates from [a] toward [b] by [t] (0 = stay at a, 1 = jump
  /// to b). Used to smooth the live highlight so it glides onto a moving toy
  /// instead of snapping frame-to-frame. [t] is clamped to [0, 1].
  static BoundingBox lerp(BoundingBox a, BoundingBox b, double t) {
    final f = t.clamp(0.0, 1.0);
    return BoundingBox(
      x: a.x + (b.x - a.x) * f,
      y: a.y + (b.y - a.y) * f,
      width: a.width + (b.width - a.width) * f,
      height: a.height + (b.height - a.height) * f,
    );
  }

  static const double _epsilon = 1e-6;
  static const double _minArea = 1e-4;

  @override
  String toString() => 'BoundingBox(x: $x, y: $y, w: $width, h: $height)';
}
