import 'dart:typed_data';

import 'package:camera/camera.dart' show ImageFormatGroup;

import 'tflite_runtime_exception.dart';

/// One image plane's bytes plus its strides — a runtime-agnostic copy of the
/// camera plugin's `Plane`, so conversion can be unit-tested with synthetic data.
class RawImagePlane {
  const RawImagePlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
}

/// A camera frame reduced to primitives. Built from a `CameraImage` by the
/// preprocessor; consumed by [ImageFormatConverter]. Carries no plugin types
/// beyond the format enum.
class RawCameraFrame {
  const RawCameraFrame({
    required this.format,
    required this.width,
    required this.height,
    required this.planes,
  });

  final ImageFormatGroup format;
  final int width;
  final int height;
  final List<RawImagePlane> planes;
}

/// Packed RGB image (`width * height * 3` bytes, R,G,B order).
class RgbImage {
  const RgbImage(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

/// Converts a [RawCameraFrame] to packed RGB.
///
/// Pure and synthetic-plane-testable. Supports Android YUV420 (planar or
/// semi-planar, honoring row/pixel strides) and iOS BGRA8888. Unsupported
/// formats and short/empty planes fail with [TfliteRuntimeException] so callers
/// can fall back or drop the frame — never crash.
class ImageFormatConverter {
  const ImageFormatConverter();

  RgbImage convert(RawCameraFrame frame) {
    switch (frame.format) {
      case ImageFormatGroup.yuv420:
        return _yuv420ToRgb(frame);
      case ImageFormatGroup.bgra8888:
        return _bgra8888ToRgb(frame);
      default:
        throw TfliteRuntimeException(
          'Unsupported camera image format: ${frame.format}',
        );
    }
  }

  RgbImage _yuv420ToRgb(RawCameraFrame frame) {
    if (frame.planes.length < 3) {
      throw const TfliteRuntimeException('YUV420 requires 3 planes.');
    }
    final w = frame.width;
    final h = frame.height;
    if (w <= 0 || h <= 0) {
      throw const TfliteRuntimeException('Invalid frame dimensions.');
    }

    final yp = frame.planes[0];
    final up = frame.planes[1];
    final vp = frame.planes[2];
    final yStride = yp.bytesPerRow;
    final uvStride = up.bytesPerRow;
    final uvPixel = up.bytesPerPixel ?? 1;

    // Bounds pre-check so the hot loop needs no per-pixel guards.
    final maxY = (h - 1) * yStride + (w - 1);
    final maxUv = ((h - 1) >> 1) * uvStride + ((w - 1) >> 1) * uvPixel;
    if (yp.bytes.length <= maxY ||
        up.bytes.length <= maxUv ||
        vp.bytes.length <= maxUv) {
      throw const TfliteRuntimeException('YUV420 planes are too short.');
    }

    final yb = yp.bytes;
    final ub = up.bytes;
    final vb = vp.bytes;
    final rgb = Uint8List(w * h * 3);

    var o = 0;
    for (var y = 0; y < h; y++) {
      final yRow = y * yStride;
      final uvRow = (y >> 1) * uvStride;
      for (var x = 0; x < w; x++) {
        final yv = yb[yRow + x];
        final uvIndex = uvRow + (x >> 1) * uvPixel;
        final u = ub[uvIndex] - 128;
        final v = vb[uvIndex] - 128;

        // BT.601 full-range YUV -> RGB.
        final r = yv + (1.402 * v);
        final g = yv - (0.344136 * u) - (0.714136 * v);
        final b = yv + (1.772 * u);

        rgb[o++] = _clamp255(r);
        rgb[o++] = _clamp255(g);
        rgb[o++] = _clamp255(b);
      }
    }
    return RgbImage(rgb, w, h);
  }

  RgbImage _bgra8888ToRgb(RawCameraFrame frame) {
    if (frame.planes.isEmpty) {
      throw const TfliteRuntimeException('BGRA8888 requires 1 plane.');
    }
    final w = frame.width;
    final h = frame.height;
    if (w <= 0 || h <= 0) {
      throw const TfliteRuntimeException('Invalid frame dimensions.');
    }

    final plane = frame.planes[0];
    final stride = plane.bytesPerRow;
    final bytes = plane.bytes;
    final maxIndex = (h - 1) * stride + (w - 1) * 4 + 3;
    if (bytes.length <= maxIndex) {
      throw const TfliteRuntimeException('BGRA8888 plane is too short.');
    }

    final rgb = Uint8List(w * h * 3);
    var o = 0;
    for (var y = 0; y < h; y++) {
      final row = y * stride;
      for (var x = 0; x < w; x++) {
        final i = row + x * 4;
        rgb[o++] = bytes[i + 2]; // R
        rgb[o++] = bytes[i + 1]; // G
        rgb[o++] = bytes[i]; // B
      }
    }
    return RgbImage(rgb, w, h);
  }

  static int _clamp255(double v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());
}
