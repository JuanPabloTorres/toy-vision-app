import '../models/bounding_box.dart';
import 'bounding_box_mapper.dart';

/// Maps normalized image-space boxes into preview-space pixels for a
/// `BoxFit.cover` preview (the layout `LiveCameraScreen` uses).
///
/// With cover, the image is scaled by `max(pw/iw, ph/ih)` to fill the viewport,
/// then centered — so it overflows on one axis and the edges are cropped. A
/// mapped box may therefore extend beyond `[0, previewWidth] × [0, previewHeight]`;
/// that is expected (the overlay clips). Pure math; non-positive dimensions
/// fail with [ArgumentError].
///
/// NOTE: not yet wired into the overlay. Correct alignment also depends on frame
/// rotation, which requires on-device validation (see ai-model-guidelines).
class PreviewCoordinateMapper {
  const PreviewCoordinateMapper();

  /// Cover scale factor: the larger of the two axis ratios.
  static double coverScale(
    int imageWidth,
    int imageHeight,
    double previewWidth,
    double previewHeight,
  ) {
    _require(imageWidth, imageHeight, previewWidth, previewHeight);
    final sx = previewWidth / imageWidth;
    final sy = previewHeight / imageHeight;
    return sx > sy ? sx : sy;
  }

  /// Centering offset (top-left) of the scaled image within the viewport.
  /// Components are <= 0 on the cropped axis.
  static ({double dx, double dy}) coverOffset(
    int imageWidth,
    int imageHeight,
    double previewWidth,
    double previewHeight,
  ) {
    final scale =
        coverScale(imageWidth, imageHeight, previewWidth, previewHeight);
    final scaledW = imageWidth * scale;
    final scaledH = imageHeight * scale;
    return (dx: (previewWidth - scaledW) / 2, dy: (previewHeight - scaledH) / 2);
  }

  /// Map a normalized image-space [box] into preview pixel coordinates.
  static PixelBox mapNormalizedBoxToPreview(
    BoundingBox box, {
    required int imageWidth,
    required int imageHeight,
    required double previewWidth,
    required double previewHeight,
  }) {
    final scale =
        coverScale(imageWidth, imageHeight, previewWidth, previewHeight);
    final scaledW = imageWidth * scale;
    final scaledH = imageHeight * scale;
    final dx = (previewWidth - scaledW) / 2;
    final dy = (previewHeight - scaledH) / 2;
    return PixelBox(
      left: dx + box.x * scaledW,
      top: dy + box.y * scaledH,
      width: box.width * scaledW,
      height: box.height * scaledH,
    );
  }

  static void _require(int iw, int ih, double pw, double ph) {
    if (iw <= 0 || ih <= 0 || pw <= 0 || ph <= 0) {
      throw ArgumentError(
        'Image and preview dimensions must be positive '
        '(image ${iw}x$ih, preview ${pw}x$ph).',
      );
    }
  }
}
