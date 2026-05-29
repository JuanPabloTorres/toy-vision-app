import '../models/bounding_box.dart';

/// A bounding box in pixel coordinates (not normalized).
class PixelBox {
  const PixelBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  @override
  String toString() => 'PixelBox(l: $left, t: $top, w: $width, h: $height)';
}

/// Converts between normalized boxes (`[0,1]`) and pixel boxes for a given image
/// size. Pure math; invalid (non-positive) dimensions fail with [ArgumentError]
/// so callers can handle it safely.
class BoundingBoxMapper {
  const BoundingBoxMapper();

  static PixelBox normalizedToPixel(
    BoundingBox box,
    int imageWidth,
    int imageHeight,
  ) {
    _requirePositive(imageWidth, imageHeight);
    return PixelBox(
      left: box.x * imageWidth,
      top: box.y * imageHeight,
      width: box.width * imageWidth,
      height: box.height * imageHeight,
    );
  }

  static BoundingBox pixelToNormalized(
    PixelBox px,
    int imageWidth,
    int imageHeight,
  ) {
    _requirePositive(imageWidth, imageHeight);
    return BoundingBox(
      x: px.left / imageWidth,
      y: px.top / imageHeight,
      width: px.width / imageWidth,
      height: px.height / imageHeight,
    );
  }

  static void _requirePositive(int w, int h) {
    if (w <= 0 || h <= 0) {
      throw ArgumentError('Image dimensions must be positive (got ${w}x$h).');
    }
  }
}
