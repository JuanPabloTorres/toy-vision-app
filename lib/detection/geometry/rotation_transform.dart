import '../models/bounding_box.dart';

/// Pure rotation of normalized bounding boxes by clockwise quarter-turns.
///
/// Coordinates are in the unit square `[0,1]` with origin top-left. A 90°/270°
/// rotation conceptually transposes the frame, but the result stays in the unit
/// square, so callers can keep working in normalized space.
class RotationTransform {
  const RotationTransform();

  /// Rotate [box] clockwise by [quarterTurns] (any int; reduced mod 4).
  static BoundingBox rotateNormalized(BoundingBox box, int quarterTurns) {
    final q = ((quarterTurns % 4) + 4) % 4;
    switch (q) {
      case 1: // 90° CW
        return BoundingBox(
          x: 1 - (box.y + box.height),
          y: box.x,
          width: box.height,
          height: box.width,
        );
      case 2: // 180°
        return BoundingBox(
          x: 1 - (box.x + box.width),
          y: 1 - (box.y + box.height),
          width: box.width,
          height: box.height,
        );
      case 3: // 270° CW
        return BoundingBox(
          x: box.y,
          y: 1 - (box.x + box.width),
          width: box.height,
          height: box.width,
        );
      case 0:
      default:
        return box;
    }
  }

  /// Clamp a normalized box into `[0,1]`, guarding against float drift after a
  /// chain of transforms.
  static BoundingBox clampNormalized(BoundingBox box) {
    final x = box.x.clamp(0.0, 1.0);
    final y = box.y.clamp(0.0, 1.0);
    final width = box.width.clamp(0.0, 1.0 - x);
    final height = box.height.clamp(0.0, 1.0 - y);
    return BoundingBox(x: x, y: y, width: width, height: height);
  }
}
